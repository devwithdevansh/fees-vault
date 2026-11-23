import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/formatters/currency_formatter.dart';
import '../database/app_database.dart';
import '../models/audit_event.dart';
import '../models/charge.dart';
import '../models/vault_summary.dart';

/// Repository managing fee obligations (Charges) and global financial aggregations.
class ChargeRepository {
  final AppDatabase _dbManager;
  final Uuid _uuid = const Uuid();

  ChargeRepository(this._dbManager);

  /// Retrieves charges for a specific payer, hydrated with payer name and current paid total.
  Future<List<Charge>> getChargesForPayer(String payerId) async {
    final db = _dbManager.database;
    final sql = '''
      SELECT 
        c.*,
        p.name AS payerName,
        COALESCE((SELECT SUM(pm.amountPaise) FROM payments pm WHERE pm.chargeId = c.id), 0) AS paidPaise
      FROM charges c
      JOIN payers p ON c.payerId = p.id
      WHERE c.payerId = ?
      ORDER BY c.dueDate ASC, c.createdAt DESC;
    ''';

    final rows = await db.rawQuery(sql, [payerId]);
    return rows
        .map((r) => Charge.fromMap(r, paidPaise: (r['paidPaise'] as num?)?.round() ?? 0))
        .toList();
  }

  /// Retrieves all charges across the system with optional status filter.
  Future<List<Charge>> getAllCharges({String? payerId}) async {
    final db = _dbManager.database;
    final where = payerId != null ? 'WHERE c.payerId = ?' : '';
    final args = payerId != null ? [payerId] : null;

    final sql =
        '''
      SELECT 
        c.*,
        p.name AS payerName,
        COALESCE((SELECT SUM(pm.amountPaise) FROM payments pm WHERE pm.chargeId = c.id), 0) AS paidPaise
      FROM charges c
      JOIN payers p ON c.payerId = p.id
      $where
      ORDER BY c.dueDate ASC, c.createdAt DESC;
    ''';

    final rows = await db.rawQuery(sql, args);
    return rows
        .map((r) => Charge.fromMap(r, paidPaise: (r['paidPaise'] as num?)?.round() ?? 0))
        .toList();
  }

  /// Retrieves all charges associated with a specific batch/course.
  Future<List<Charge>> getChargesForBatch(String batchId) async {
    final db = _dbManager.database;
    final sql = '''
      SELECT 
        c.*,
        p.name AS payerName,
        COALESCE((SELECT SUM(pm.amountPaise) FROM payments pm WHERE pm.chargeId = c.id), 0) AS paidPaise
      FROM charges c
      JOIN payers p ON c.payerId = p.id
      WHERE (c.batchId = ? OR c.payerId IN (SELECT p2.id FROM payers p2 WHERE p2.batchId = ?))
      ORDER BY c.dueDate ASC, c.title ASC;
    ''';

    final rows = await db.rawQuery(sql, [batchId, batchId]);
    return rows
        .map((r) => Charge.fromMap(r, paidPaise: (r['paidPaise'] as num?)?.round() ?? 0))
        .toList();
  }

  /// Retrieves a single charge by ID with paid balance.
  Future<Charge?> getChargeById(String id) async {
    final db = _dbManager.database;
    final sql = '''
      SELECT 
        c.*,
        p.name AS payerName,
        COALESCE((SELECT SUM(pm.amountPaise) FROM payments pm WHERE pm.chargeId = c.id), 0) AS paidPaise
      FROM charges c
      JOIN payers p ON c.payerId = p.id
      WHERE c.id = ?
      LIMIT 1;
    ''';

    final rows = await db.rawQuery(sql, [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Charge.fromMap(r, paidPaise: (r['paidPaise'] as num?)?.round() ?? 0);
  }

  /// Retrieves overdue charges (dueDate strictly before today with outstanding balance).
  Future<List<Charge>> getOverdueCharges({int limit = 20}) async {
    final today = CurrencyFormatter.toYmd(DateTime.now());
    final db = _dbManager.database;
    final sql = '''
      SELECT 
        c.*,
        p.name AS payerName,
        COALESCE((SELECT SUM(pm.amountPaise) FROM payments pm WHERE pm.chargeId = c.id), 0) AS paidPaise
      FROM charges c
      JOIN payers p ON c.payerId = p.id
      WHERE c.dueDate < ?
        AND (c.grossPaise - c.discountPaise) > COALESCE((SELECT SUM(pm.amountPaise) FROM payments pm WHERE pm.chargeId = c.id), 0)
      ORDER BY c.dueDate ASC
      LIMIT ?;
    ''';

    final rows = await db.rawQuery(sql, [today, limit]);
    return rows
        .map((r) => Charge.fromMap(r, paidPaise: (r['paidPaise'] as num?)?.round() ?? 0))
        .toList();
  }

  /// Creates a new charge.
  Future<Charge> createCharge({
    required String payerId,
    required String title,
    String? period,
    required int grossPaise,
    int discountPaise = 0,
    required String dueDate,
    String? notes,
    String? batchId,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const ValidationException('Charge title cannot be empty');
    }
    if (grossPaise <= 0) {
      throw const ValidationException('Gross fee must be a positive amount');
    }
    if (discountPaise < 0) {
      throw const ValidationException('Discount cannot be negative');
    }
    if (discountPaise > grossPaise) {
      throw const ValidationException('Discount cannot exceed the gross fee');
    }

    // Validate dueDate format
    CurrencyFormatter.parseDate(dueDate);

    final now = DateTime.now().millisecondsSinceEpoch;
    final charge = Charge(
      id: _uuid.v4(),
      payerId: payerId,
      title: cleanTitle,
      period: period?.trim().isEmpty == true ? null : period?.trim(),
      grossPaise: grossPaise,
      discountPaise: discountPaise,
      dueDate: dueDate,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      batchId: batchId?.trim().isEmpty == true ? null : batchId?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await _dbManager.database.insert('charges', charge.toMap());
    return charge;
  }

  /// Updates an existing charge.
  /// Rejects any change that makes net charge lower than payments already recorded!
  Future<void> updateCharge(Charge charge) async {
    final cleanTitle = charge.title.trim();
    if (cleanTitle.isEmpty) {
      throw const ValidationException('Charge title cannot be empty');
    }
    if (charge.grossPaise <= 0) {
      throw const ValidationException('Gross fee must be a positive amount');
    }
    if (charge.discountPaise < 0) {
      throw const ValidationException('Discount cannot be negative');
    }
    if (charge.discountPaise > charge.grossPaise) {
      throw const ValidationException('Discount cannot exceed the gross fee');
    }

    CurrencyFormatter.parseDate(charge.dueDate);

    final db = _dbManager.database;
    // Check total payments already recorded for this charge
    final paidTotal =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COALESCE(SUM(amountPaise), 0) FROM payments WHERE chargeId = ?;',
            [charge.id],
          ),
        ) ??
        0;

    final newNetPaise = charge.grossPaise - charge.discountPaise;
    if (newNetPaise < paidTotal) {
      throw BusinessRuleException(
        'Cannot reduce net charge to ${CurrencyFormatter.formatPaise(newNetPaise)} '
        'because ${CurrencyFormatter.formatPaise(paidTotal)} has already been collected for this charge.',
      );
    }

    final updated = charge.copyWith(
      title: cleanTitle,
      period: charge.period?.trim().isEmpty == true
          ? null
          : charge.period?.trim(),
      notes: charge.notes?.trim().isEmpty == true ? null : charge.notes?.trim(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await db.update(
      'charges',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [charge.id],
    );
  }

  /// Deletes a charge.
  /// Strictly blocked if payments have been recorded for this charge!
  Future<void> deleteCharge(String id) async {
    final db = _dbManager.database;
    final paymentCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM payments WHERE chargeId = ?;',
            [id],
          ),
        ) ??
        0;

    if (paymentCount > 0) {
      throw const BusinessRuleException(
        'Cannot delete charge because payments have already been recorded against it. '
        'To delete this charge, you must first correct/delete the linked payments with a documented reason.',
      );
    }

    // Fetch charge details before deletion for the audit trail
    final chargeRows = await db.query(
      'charges',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    await db.transaction((txn) async {
      await txn.delete('charges', where: 'id = ?', whereArgs: [id]);

      // Record audit event for charge deletion
      if (chargeRows.isNotEmpty) {
        final c = chargeRows.first;
        final now = DateTime.now().millisecondsSinceEpoch;
        final audit = AuditEvent(
          id: _uuid.v4(),
          entityType: 'charge',
          entityId: id,
          action: 'delete',
          timestamp: now,
          reason: 'Charge deleted',
          detailsJson: jsonEncode({
            'title': c['title'],
            'grossPaise': c['grossPaise'],
            'discountPaise': c['discountPaise'],
            'payerId': c['payerId'],
            'batchId': c['batchId'],
          }),
        );
        await txn.insert('audit_events', audit.toMap());
      }
    });
  }

  /// Calculates global financial metrics strictly through independent aggregation queries.
  /// Pass [academicYear] to filter metrics to a specific academic year (matches batch.academicYear).
  /// If null, returns metrics across all years.
  Future<VaultSummary> getVaultSummary({String? academicYear}) async {
    final db = _dbManager.database;
    final now = DateTime.now();
    final today = CurrencyFormatter.toYmd(now);
    final currentMonthPrefix =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}%';

    // Optional WHERE clause joining charges to batches for academic year filter
    final yearFilter = academicYear != null && academicYear.isNotEmpty;
    final chargesAyWhere = yearFilter
        ? '''(
            (charges.batchId IS NOT NULL AND EXISTS (SELECT 1 FROM batches b WHERE b.id = charges.batchId AND b.academicYear = ? COLLATE NOCASE))
            OR (charges.period = ? COLLATE NOCASE)
            OR EXISTS (SELECT 1 FROM payers p JOIN batches b ON (p.batchId = b.id OR (p.batchId IS NULL AND TRIM(p.batch) = TRIM(b.name) COLLATE NOCASE)) WHERE p.id = charges.payerId AND b.academicYear = ? COLLATE NOCASE)
            OR (charges.batchId IS NULL AND (charges.period IS NULL OR charges.period = '') AND NOT EXISTS (SELECT 1 FROM payers p2 WHERE p2.id = charges.payerId AND p2.batchId IS NOT NULL))
          )'''
        : '1=1';
    final overdueAyWhere = yearFilter
        ? '''(
            (c.batchId IS NOT NULL AND EXISTS (SELECT 1 FROM batches b WHERE b.id = c.batchId AND b.academicYear = ? COLLATE NOCASE))
            OR (c.period = ? COLLATE NOCASE)
            OR EXISTS (SELECT 1 FROM payers p JOIN batches b ON (p.batchId = b.id OR (p.batchId IS NULL AND TRIM(p.batch) = TRIM(b.name) COLLATE NOCASE)) WHERE p.id = c.payerId AND b.academicYear = ? COLLATE NOCASE)
            OR (c.batchId IS NULL AND (c.period IS NULL OR c.period = '') AND NOT EXISTS (SELECT 1 FROM payers p2 WHERE p2.id = c.payerId AND p2.batchId IS NOT NULL))
          )'''
        : '1=1';
    final yearArg = yearFilter
        ? [academicYear, academicYear, academicYear]
        : <Object?>[];

    // 1. Total net fees raised (independent)
    final totalNetFees =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COALESCE(SUM(grossPaise - discountPaise), 0) FROM charges WHERE $chargesAyWhere;',
            yearArg,
          ),
        ) ??
        0;

    // 2. Total collected (independent)
    final totalCollected =
        Sqflite.firstIntValue(
          await db.rawQuery(
            yearFilter
                ? '''SELECT COALESCE(SUM(p.amountPaise), 0) FROM payments p 
                     JOIN charges c ON p.chargeId = c.id 
                     WHERE (
                       (c.batchId IS NOT NULL AND EXISTS (SELECT 1 FROM batches b WHERE b.id = c.batchId AND b.academicYear = ? COLLATE NOCASE))
                       OR (c.period = ? COLLATE NOCASE)
                       OR EXISTS (SELECT 1 FROM payers p2 JOIN batches b ON (p2.batchId = b.id OR (p2.batchId IS NULL AND TRIM(p2.batch) = TRIM(b.name) COLLATE NOCASE)) WHERE p2.id = c.payerId AND b.academicYear = ? COLLATE NOCASE)
                       OR (c.batchId IS NULL AND (c.period IS NULL OR c.period = '') AND NOT EXISTS (SELECT 1 FROM payers p3 WHERE p3.id = c.payerId AND p3.batchId IS NOT NULL))
                     );'''
                : 'SELECT COALESCE(SUM(amountPaise), 0) FROM payments;',
            yearFilter ? [academicYear, academicYear, academicYear] : <Object?>[],
          ),
        ) ??
        0;

    // 3. Total outstanding
    final totalOutstanding = totalNetFees - totalCollected;

    // 4. Overdue charges amount
    // Sum of outstanding for charges where dueDate < today
    final overdueRows = await db.rawQuery(
      '''
      SELECT 
        (c.grossPaise - c.discountPaise) - COALESCE((SELECT SUM(pm.amountPaise) FROM payments pm WHERE pm.chargeId = c.id), 0) AS remaining
      FROM charges c
      WHERE c.dueDate < ? AND $overdueAyWhere
    ''',
      [today, ...yearArg],
    );

    int totalOverdue = 0;
    int overdueCount = 0;
    for (final r in overdueRows) {
      final rem = (r['remaining'] as num?)?.round() ?? 0;
      if (rem > 0) {
        totalOverdue += rem;
        overdueCount++;
      }
    }

    // 5. Current month net fees raised (dueDate in current month)
    final monthNetFees =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COALESCE(SUM(grossPaise - discountPaise), 0) FROM charges WHERE dueDate LIKE ?;',
            [currentMonthPrefix],
          ),
        ) ??
        0;

    // 6. Current month collected (paidDate in current month)
    final monthCollected =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COALESCE(SUM(amountPaise), 0) FROM payments WHERE paidDate LIKE ?;',
            [currentMonthPrefix],
          ),
        ) ??
        0;

    // 7. Counts
    final activePayers =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM payers WHERE archived = 0;'),
        ) ??
        0;

    final archivedPayers =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM payers WHERE archived = 1;'),
        ) ??
        0;

    final totalCharges =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM charges;'),
        ) ??
        0;

    return VaultSummary(
      totalNetFeesPaise: totalNetFees,
      totalCollectedPaise: totalCollected,
      totalOutstandingPaise: totalOutstanding,
      totalOverduePaise: totalOverdue,
      monthNetFeesPaise: monthNetFees,
      monthCollectedPaise: monthCollected,
      activePayersCount: activePayers,
      archivedPayersCount: archivedPayers,
      totalChargesCount: totalCharges,
      overdueChargesCount: overdueCount,
    );
  }
}
