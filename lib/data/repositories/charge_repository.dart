import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/formatters/currency_formatter.dart';
import '../database/app_database.dart';
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
        .map((r) => Charge.fromMap(r, paidPaise: (r['paidPaise'] as int?) ?? 0))
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
        .map((r) => Charge.fromMap(r, paidPaise: (r['paidPaise'] as int?) ?? 0))
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
    return Charge.fromMap(r, paidPaise: (r['paidPaise'] as int?) ?? 0);
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
        .map((r) => Charge.fromMap(r, paidPaise: (r['paidPaise'] as int?) ?? 0))
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

    await db.delete('charges', where: 'id = ?', whereArgs: [id]);
  }

  /// Calculates global financial metrics strictly through independent aggregation queries.
  Future<VaultSummary> getVaultSummary() async {
    final db = _dbManager.database;
    final now = DateTime.now();
    final today = CurrencyFormatter.toYmd(now);
    final currentMonthPrefix =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}%';

    // 1. Total net fees raised (independent)
    final totalNetFees =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COALESCE(SUM(grossPaise - discountPaise), 0) FROM charges;',
          ),
        ) ??
        0;

    // 2. Total collected (independent)
    final totalCollected =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COALESCE(SUM(amountPaise), 0) FROM payments;',
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
      WHERE c.dueDate < ?
    ''',
      [today],
    );

    int totalOverdue = 0;
    int overdueCount = 0;
    for (final r in overdueRows) {
      final rem = (r['remaining'] as int?) ?? 0;
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
