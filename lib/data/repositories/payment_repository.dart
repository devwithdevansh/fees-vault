import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/formatters/currency_formatter.dart';
import '../database/app_database.dart';
import '../models/audit_event.dart';
import '../models/payment.dart';
import 'settings_repository.dart';

/// Repository managing payment records, monotonic receipts, and audited corrections.
class PaymentRepository {
  final AppDatabase _dbManager;
  final SettingsRepository _settingsRepo;
  final Uuid _uuid = const Uuid();

  PaymentRepository(this._dbManager, this._settingsRepo);

  /// Retrieves list of payments with optional filters, hydrated with payer and charge details.
  Future<List<Payment>> getPayments({
    String? method,
    String? query,
    String? fromDate,
    String? toDate,
    int limit = 100,
  }) async {
    final db = _dbManager.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (method != null && method.isNotEmpty && method != 'All') {
      whereClauses.add('pm.method = ?');
      whereArgs.add(method);
    }

    if (fromDate != null && fromDate.isNotEmpty) {
      whereClauses.add('pm.paidDate >= ?');
      whereArgs.add(fromDate);
    }

    if (toDate != null && toDate.isNotEmpty) {
      whereClauses.add('pm.paidDate <= ?');
      whereArgs.add(toDate);
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      whereClauses.add('(p.name LIKE ? OR c.title LIKE ? OR pm.reference LIKE ? OR CAST(pm.receiptNumber AS TEXT) LIKE ?)');
      whereArgs.addAll([q, q, q, q]);
    }

    final whereSql = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final sql = '''
      SELECT 
        pm.*,
        c.title AS chargeTitle,
        p.name AS payerName,
        (c.grossPaise - c.discountPaise) - (
          SELECT COALESCE(SUM(p_sub.amountPaise), 0) FROM payments p_sub WHERE p_sub.chargeId = c.id
        ) AS remainingBalancePaise,
        (SELECT COUNT(*) FROM audit_events a WHERE a.entityId = pm.id AND a.action = 'update') AS updateAuditCount
      FROM payments pm
      JOIN charges c ON pm.chargeId = c.id
      JOIN payers p ON c.payerId = p.id
      $whereSql
      ORDER BY pm.paidDate DESC, pm.createdAt DESC
      LIMIT ?;
    ''';

    whereArgs.add(limit);
    final rows = await db.rawQuery(sql, whereArgs);

    return rows.map((r) {
      final updateCount = (r['updateAuditCount'] as int?) ?? 0;
      return Payment.fromMap(
        r,
        payerName: r['payerName'] as String?,
        chargeTitle: r['chargeTitle'] as String?,
        remainingBalancePaise: (r['remainingBalancePaise'] as int?) ?? 0,
        isEdited: updateCount > 0,
      );
    }).toList();
  }

  /// Retrieves payments for a specific charge.
  Future<List<Payment>> getPaymentsForCharge(String chargeId) async {
    final db = _dbManager.database;
    final sql = '''
      SELECT 
        pm.*,
        c.title AS chargeTitle,
        p.name AS payerName,
        (c.grossPaise - c.discountPaise) - (
          SELECT COALESCE(SUM(p_sub.amountPaise), 0) FROM payments p_sub WHERE p_sub.chargeId = c.id
        ) AS remainingBalancePaise,
        (SELECT COUNT(*) FROM audit_events a WHERE a.entityId = pm.id AND a.action = 'update') AS updateAuditCount
      FROM payments pm
      JOIN charges c ON pm.chargeId = c.id
      JOIN payers p ON c.payerId = p.id
      WHERE pm.chargeId = ?
      ORDER BY pm.paidDate DESC, pm.createdAt DESC;
    ''';

    final rows = await db.rawQuery(sql, [chargeId]);
    return rows.map((r) {
      final updateCount = (r['updateAuditCount'] as int?) ?? 0;
      return Payment.fromMap(
        r,
        payerName: r['payerName'] as String?,
        chargeTitle: r['chargeTitle'] as String?,
        remainingBalancePaise: (r['remainingBalancePaise'] as int?) ?? 0,
        isEdited: updateCount > 0,
      );
    }).toList();
  }

  /// Retrieves a single payment by ID.
  Future<Payment?> getPaymentById(String id) async {
    final db = _dbManager.database;
    final sql = '''
      SELECT 
        pm.*,
        c.title AS chargeTitle,
        p.name AS payerName,
        (c.grossPaise - c.discountPaise) - (
          SELECT COALESCE(SUM(p_sub.amountPaise), 0) FROM payments p_sub WHERE p_sub.chargeId = c.id
        ) AS remainingBalancePaise,
        (SELECT COUNT(*) FROM audit_events a WHERE a.entityId = pm.id AND a.action = 'update') AS updateAuditCount
      FROM payments pm
      JOIN charges c ON pm.chargeId = c.id
      JOIN payers p ON c.payerId = p.id
      WHERE pm.id = ?
      LIMIT 1;
    ''';

    final rows = await db.rawQuery(sql, [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    final updateCount = (r['updateAuditCount'] as int?) ?? 0;
    return Payment.fromMap(
      r,
      payerName: r['payerName'] as String?,
      chargeTitle: r['chargeTitle'] as String?,
      remainingBalancePaise: (r['remainingBalancePaise'] as int?) ?? 0,
      isEdited: updateCount > 0,
    );
  }

  /// Records a new payment in an atomic transaction.
  /// Validates headroom, increments monotonic counter, and creates an audit record.
  Future<Payment> recordPayment({
    required String chargeId,
    required int amountPaise,
    required String paidDate,
    required String method,
    String? reference,
    String? notes,
  }) async {
    if (amountPaise <= 0) {
      throw const ValidationException('Payment amount must be greater than zero');
    }
    if (!AppConstants.paymentMethods.contains(method)) {
      throw ValidationException('Invalid payment method: $method');
    }
    CurrencyFormatter.parseDate(paidDate);

    final db = _dbManager.database;

    return await db.transaction<Payment>((txn) async {
      // 1. Fetch charge details
      final chargeRows = await txn.query(
        'charges',
        where: 'id = ?',
        whereArgs: [chargeId],
        limit: 1,
      );
      if (chargeRows.isEmpty) {
        throw const BusinessRuleException('Target charge not found');
      }

      final charge = chargeRows.first;
      final gross = charge['grossPaise'] as int;
      final discount = (charge['discountPaise'] as int?) ?? 0;
      final netCharge = gross - discount;

      // 2. Compute current total paid for this charge
      final currentPaid = Sqflite.firstIntValue(await txn.rawQuery(
        'SELECT COALESCE(SUM(amountPaise), 0) FROM payments WHERE chargeId = ?;',
        [chargeId],
      )) ?? 0;

      final remaining = netCharge - currentPaid;
      if (amountPaise > remaining) {
        throw BusinessRuleException(
          'Payment amount (${CurrencyFormatter.formatPaise(amountPaise)}) exceeds '
          'the remaining outstanding dues of ${CurrencyFormatter.formatPaise(remaining)}. '
          'Credit balances are not accepted.',
        );
      }

      // 3. Atomically increment monotonic receipt counter
      final receiptNumber = await _settingsRepo.getNextReceiptNumber(txn);

      final now = DateTime.now().millisecondsSinceEpoch;
      final payment = Payment(
        id: _uuid.v4(),
        chargeId: chargeId,
        amountPaise: amountPaise,
        paidDate: paidDate,
        method: method,
        reference: reference?.trim().isEmpty == true ? null : reference?.trim(),
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        receiptNumber: receiptNumber,
        createdAt: now,
        updatedAt: now,
      );

      // 4. Insert payment
      await txn.insert('payments', payment.toMap());

      // 5. Insert audit event
      final audit = AuditEvent(
        id: _uuid.v4(),
        entityType: 'payment',
        entityId: payment.id,
        action: 'create',
        timestamp: now,
        reason: 'Payment recorded',
        detailsJson: jsonEncode({
          'receiptNumber': receiptNumber,
          'amountPaise': amountPaise,
          'method': method,
          'chargeId': chargeId,
        }),
      );
      await txn.insert('audit_events', audit.toMap());

      return payment;
    });
  }

  /// Edits an existing payment entry in an atomic transaction.
  /// Requires mandatory correction reason, validates available headroom excluding old value,
  /// and persists audit history with before/after state.
  Future<void> updatePayment({
    required Payment payment,
    required String correctionReason,
  }) async {
    final cleanReason = correctionReason.trim();
    if (cleanReason.isEmpty) {
      throw const ValidationException('A correction reason is required when editing a payment record');
    }
    if (payment.amountPaise <= 0) {
      throw const ValidationException('Payment amount must be greater than zero');
    }
    if (!AppConstants.paymentMethods.contains(payment.method)) {
      throw ValidationException('Invalid payment method: ${payment.method}');
    }
    CurrencyFormatter.parseDate(payment.paidDate);

    final db = _dbManager.database;

    await db.transaction((txn) async {
      // 1. Fetch existing payment
      final existingRows = await txn.query(
        'payments',
        where: 'id = ?',
        whereArgs: [payment.id],
        limit: 1,
      );
      if (existingRows.isEmpty) {
        throw const BusinessRuleException('Existing payment record not found');
      }
      final existingPayment = Payment.fromMap(existingRows.first);

      // Rule: Do not move an existing payment to another charge
      if (existingPayment.chargeId != payment.chargeId) {
        throw const BusinessRuleException('Moving a payment to a different charge is not permitted');
      }

      // 2. Fetch charge and compute allowed headroom excluding previous payment value
      final chargeRows = await txn.query(
        'charges',
        where: 'id = ?',
        whereArgs: [payment.chargeId],
        limit: 1,
      );
      if (chargeRows.isEmpty) {
        throw const BusinessRuleException('Target charge not found');
      }
      final charge = chargeRows.first;
      final netCharge = (charge['grossPaise'] as int) - ((charge['discountPaise'] as int?) ?? 0);

      final otherPaid = Sqflite.firstIntValue(await txn.rawQuery(
        'SELECT COALESCE(SUM(amountPaise), 0) FROM payments WHERE chargeId = ? AND id != ?;',
        [payment.chargeId, payment.id],
      )) ?? 0;

      final allowedMax = netCharge - otherPaid;
      if (payment.amountPaise > allowedMax) {
        throw BusinessRuleException(
          'Updated payment of ${CurrencyFormatter.formatPaise(payment.amountPaise)} '
          'exceeds remaining charge balance. Maximum allowable is ${CurrencyFormatter.formatPaise(allowedMax)}.',
        );
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final updated = payment.copyWith(
        reference: payment.reference?.trim().isEmpty == true ? null : payment.reference?.trim(),
        notes: payment.notes?.trim().isEmpty == true ? null : payment.notes?.trim(),
        updatedAt: now,
      );

      // 3. Update payment (receiptNumber is immutable and monotonic)
      await txn.update(
        'payments',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [payment.id],
      );

      // 4. Log audit event
      final audit = AuditEvent(
        id: _uuid.v4(),
        entityType: 'payment',
        entityId: payment.id,
        action: 'update',
        timestamp: now,
        reason: cleanReason,
        detailsJson: jsonEncode({
          'before': existingPayment.toMap(),
          'after': updated.toMap(),
        }),
      );
      await txn.insert('audit_events', audit.toMap());
    });
  }

  /// Deletes a payment entry in an atomic transaction.
  /// Requires mandatory correction reason and records the deleted record into the encrypted audit trail.
  /// The deleted payment immediately restores outstanding balance.
  Future<void> deletePayment({
    required String paymentId,
    required String correctionReason,
  }) async {
    final cleanReason = correctionReason.trim();
    if (cleanReason.isEmpty) {
      throw const ValidationException('A correction reason is required to delete a payment record');
    }

    final db = _dbManager.database;

    await db.transaction((txn) async {
      final existingRows = await txn.query(
        'payments',
        where: 'id = ?',
        whereArgs: [paymentId],
        limit: 1,
      );
      if (existingRows.isEmpty) {
        throw const BusinessRuleException('Payment record not found to delete');
      }
      final existingPayment = Payment.fromMap(existingRows.first);

      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Record full audit trail of deleted payment
      final audit = AuditEvent(
        id: _uuid.v4(),
        entityType: 'payment',
        entityId: paymentId,
        action: 'delete',
        timestamp: now,
        reason: cleanReason,
        detailsJson: jsonEncode({
          'deletedRecord': existingPayment.toMap(),
        }),
      );
      await txn.insert('audit_events', audit.toMap());

      // 2. Delete payment record (receiptNumber is NEVER reused)
      await txn.delete(
        'payments',
        where: 'id = ?',
        whereArgs: [paymentId],
      );
    });
  }
}
