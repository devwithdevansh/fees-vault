import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/errors/app_exceptions.dart';
import '../database/app_database.dart';
import '../models/payer.dart';

/// Repository managing Payer entities and their financial totals.
class PayerRepository {
  final AppDatabase _dbManager;
  final Uuid _uuid = const Uuid();

  PayerRepository(this._dbManager);

  AppDatabase get dbManager => _dbManager;

  /// Retrieves payers with search and archive filters, hydrating individual balances.
  /// Uses correlated subqueries to avoid JOIN multiplication.
  Future<List<Payer>> getPayers({
    String? query,
    bool includeArchived = false,
  }) async {
    final db = _dbManager.database;

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (!includeArchived) {
      whereClauses.add('p.archived = 0');
    }

    if (query != null && query.trim().isNotEmpty) {
      final pattern = '%${query.trim()}%';
      whereClauses.add('(p.name LIKE ? OR p.phone LIKE ? OR p.batch LIKE ?)');
      whereArgs.addAll([pattern, pattern, pattern]);
    }

    final whereSql = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    final sql =
        '''
      SELECT 
        p.*,
        COALESCE((SELECT SUM(c.grossPaise - c.discountPaise) FROM charges c WHERE c.payerId = p.id), 0) AS totalNetPaise,
        COALESCE((SELECT SUM(pm.amountPaise) FROM payments pm JOIN charges c ON pm.chargeId = c.id WHERE c.payerId = p.id), 0) AS totalPaidPaise,
        COALESCE((SELECT COUNT(*) FROM charges c WHERE c.payerId = p.id), 0) AS chargeCount
      FROM payers p
      $whereSql
      ORDER BY p.name COLLATE NOCASE ASC;
    ''';

    final rows = await db.rawQuery(sql, whereArgs);

    return rows.map((row) {
      final net = (row['totalNetPaise'] as int?) ?? 0;
      final paid = (row['totalPaidPaise'] as int?) ?? 0;
      final count = (row['chargeCount'] as int?) ?? 0;
      return Payer.fromMap(
        row,
        totalNetPaise: net,
        totalPaidPaise: paid,
        totalOutstandingPaise: net - paid,
        chargeCount: count,
      );
    }).toList();
  }

  /// Retrieves a single payer by ID with hydrated balances.
  Future<Payer?> getPayerById(String id) async {
    final db = _dbManager.database;
    final sql = '''
      SELECT 
        p.*,
        COALESCE((SELECT SUM(c.grossPaise - c.discountPaise) FROM charges c WHERE c.payerId = p.id), 0) AS totalNetPaise,
        COALESCE((SELECT SUM(pm.amountPaise) FROM payments pm JOIN charges c ON pm.chargeId = c.id WHERE c.payerId = p.id), 0) AS totalPaidPaise,
        COALESCE((SELECT COUNT(*) FROM charges c WHERE c.payerId = p.id), 0) AS chargeCount
      FROM payers p
      WHERE p.id = ?
      LIMIT 1;
    ''';

    final rows = await db.rawQuery(sql, [id]);
    if (rows.isEmpty) return null;

    final row = rows.first;
    final net = (row['totalNetPaise'] as int?) ?? 0;
    final paid = (row['totalPaidPaise'] as int?) ?? 0;
    final count = (row['chargeCount'] as int?) ?? 0;

    return Payer.fromMap(
      row,
      totalNetPaise: net,
      totalPaidPaise: paid,
      totalOutstandingPaise: net - paid,
      chargeCount: count,
    );
  }

  /// Creates a new Payer record.
  Future<Payer> createPayer({
    required String name,
    String? phone,
    String? batch,
    String? batchId,
    String? notes,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const ValidationException('Payer name cannot be blank');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final payer = Payer(
      id: _uuid.v4(),
      name: cleanName,
      phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
      batch: batch?.trim().isEmpty == true ? null : batch?.trim(),
      batchId: batchId?.trim().isEmpty == true ? null : batchId?.trim(),
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      archived: false,
      createdAt: now,
      updatedAt: now,
    );

    await _dbManager.database.insert('payers', payer.toMap());
    return payer;
  }

  /// Updates an existing Payer.
  Future<void> updatePayer(Payer payer) async {
    final cleanName = payer.name.trim();
    if (cleanName.isEmpty) {
      throw const ValidationException('Payer name cannot be blank');
    }

    final updated = payer.copyWith(
      name: cleanName,
      phone: payer.phone?.trim().isEmpty == true ? null : payer.phone?.trim(),
      batch: payer.batch?.trim().isEmpty == true ? null : payer.batch?.trim(),
      batchId: payer.batchId?.trim().isEmpty == true
          ? null
          : payer.batchId?.trim(),
      notes: payer.notes?.trim().isEmpty == true ? null : payer.notes?.trim(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _dbManager.database.update(
      'payers',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [payer.id],
    );
  }

  /// Toggles archived state. Outstanding debt remains counted.
  Future<void> setPayerArchived(String id, bool archived) async {
    await _dbManager.database.update(
      'payers',
      {
        'archived': archived ? 1 : 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes a Payer record.
  /// Hard deletion is allowed ONLY when there are zero linked charges.
  Future<void> deletePayer(String id) async {
    final db = _dbManager.database;
    final chargeCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM charges WHERE payerId = ?;', [
            id,
          ]),
        ) ??
        0;

    if (chargeCount > 0) {
      throw const BusinessRuleException(
        'Cannot permanently delete a payer who has recorded charges. '
        'You can archive this payer instead to keep records intact.',
      );
    }

    await db.delete('payers', where: 'id = ?', whereArgs: [id]);
  }
}
