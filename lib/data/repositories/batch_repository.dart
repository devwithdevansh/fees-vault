import 'package:sqflite_sqlcipher/sqflite.dart' hide Batch;
import 'package:uuid/uuid.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/formatters/currency_formatter.dart';
import '../database/app_database.dart';
import '../models/batch.dart';
import '../models/batch_fee_template.dart';
import '../models/charge.dart';
import '../models/payer.dart';

/// Repository managing Batches (Courses), standard batch fee templates,
/// and automated fee charging to enrolled students.
class BatchRepository {
  final AppDatabase _dbManager;
  final Uuid _uuid = const Uuid();

  BatchRepository(this._dbManager);

  /// Retrieves batches with aggregated statistics (student count, fee totals)
  /// and configured fee structure templates.
  Future<List<Batch>> getBatches({String? academicYear}) async {
    final db = _dbManager.database;

    final where = academicYear != null ? 'WHERE b.academicYear = ?' : '';
    final args = academicYear != null ? [academicYear] : null;

    final sql = '''
      SELECT 
        b.*,
        (SELECT COUNT(*) FROM payers p 
         WHERE p.archived = 0 AND (p.batchId = b.id OR (p.batchId IS NULL AND p.batch = b.name))) AS studentCount,
        COALESCE(
          (SELECT SUM(c.grossPaise - c.discountPaise) 
           FROM charges c 
           WHERE c.batchId = b.id OR c.payerId IN (
             SELECT p.id FROM payers p 
             WHERE p.archived = 0 AND (p.batchId = b.id OR (p.batchId IS NULL AND p.batch = b.name))
           )), 0) AS totalFeePaise,
        COALESCE(
          (SELECT SUM(pm.amountPaise) 
           FROM payments pm 
           JOIN charges c ON pm.chargeId = c.id 
           WHERE c.batchId = b.id OR c.payerId IN (
             SELECT p.id FROM payers p 
             WHERE p.archived = 0 AND (p.batchId = b.id OR (p.batchId IS NULL AND p.batch = b.name))
           )), 0) AS totalCollectedPaise
      FROM batches b
      $where
      ORDER BY b.name COLLATE NOCASE ASC;
    ''';

    final rows = await db.rawQuery(sql, args);

    final batches = <Batch>[];
    for (final row in rows) {
      final batchId = row['id'] as String;
      final templates = await getFeeTemplates(batchId);
      final studentCount = (row['studentCount'] as int?) ?? 0;
      final feePaise = (row['totalFeePaise'] as int?) ?? 0;
      final collectedPaise = (row['totalCollectedPaise'] as int?) ?? 0;

      batches.add(Batch.fromMap(
        row,
        studentCount: studentCount,
        totalFeePaise: feePaise,
        totalCollectedPaise: collectedPaise,
        totalOutstandingPaise: feePaise - collectedPaise,
        feeTemplates: templates,
      ));
    }

    return batches;
  }

  /// Retrieves a single batch by ID with full hydrated statistics and fee templates.
  Future<Batch?> getBatchById(String id) async {
    final db = _dbManager.database;
    final sql = '''
      SELECT 
        b.*,
        (SELECT COUNT(*) FROM payers p 
         WHERE p.archived = 0 AND (p.batchId = b.id OR (p.batchId IS NULL AND p.batch = b.name))) AS studentCount,
        COALESCE(
          (SELECT SUM(c.grossPaise - c.discountPaise) 
           FROM charges c 
           WHERE c.batchId = b.id OR c.payerId IN (
             SELECT p.id FROM payers p 
             WHERE p.archived = 0 AND (p.batchId = b.id OR (p.batchId IS NULL AND p.batch = b.name))
           )), 0) AS totalFeePaise,
        COALESCE(
          (SELECT SUM(pm.amountPaise) 
           FROM payments pm 
           JOIN charges c ON pm.chargeId = c.id 
           WHERE c.batchId = b.id OR c.payerId IN (
             SELECT p.id FROM payers p 
             WHERE p.archived = 0 AND (p.batchId = b.id OR (p.batchId IS NULL AND p.batch = b.name))
           )), 0) AS totalCollectedPaise
      FROM batches b
      WHERE b.id = ?
      LIMIT 1;
    ''';

    final rows = await db.rawQuery(sql, [id]);
    if (rows.isEmpty) return null;

    final row = rows.first;
    final templates = await getFeeTemplates(id);
    final studentCount = (row['studentCount'] as int?) ?? 0;
    final feePaise = (row['totalFeePaise'] as int?) ?? 0;
    final collectedPaise = (row['totalCollectedPaise'] as int?) ?? 0;

    return Batch.fromMap(
      row,
      studentCount: studentCount,
      totalFeePaise: feePaise,
      totalCollectedPaise: collectedPaise,
      totalOutstandingPaise: feePaise - collectedPaise,
      feeTemplates: templates,
    );
  }

  /// Creates a new Batch.
  Future<Batch> createBatch({
    required String name,
    required String academicYear,
    String? notes,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const ValidationException('Batch / Course name cannot be empty');
    }
    final cleanYear = academicYear.trim();
    if (cleanYear.isEmpty) {
      throw const ValidationException('Academic Year must be specified');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = Batch(
      id: _uuid.v4(),
      name: cleanName,
      academicYear: cleanYear,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await _dbManager.database.insert('batches', batch.toMap());
    return batch;
  }

  /// Updates an existing Batch.
  Future<void> updateBatch(Batch batch) async {
    final cleanName = batch.name.trim();
    if (cleanName.isEmpty) {
      throw const ValidationException('Batch name cannot be empty');
    }

    final updated = batch.copyWith(
      name: cleanName,
      academicYear: batch.academicYear.trim(),
      notes: batch.notes?.trim().isEmpty == true ? null : batch.notes?.trim(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _dbManager.database.update(
      'batches',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [batch.id],
    );
  }

  /// Deletes a Batch. Fails if students are currently enrolled in it.
  Future<void> deleteBatch(String id) async {
    final db = _dbManager.database;

    final batch = await getBatchById(id);
    if (batch == null) return;

    final studentCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM payers WHERE batchId = ? OR (batchId IS NULL AND batch = ?);',
      [id, batch.name],
    )) ?? 0;

    if (studentCount > 0) {
      throw BusinessRuleException(
        'Cannot delete batch "${batch.name}" because $studentCount student(s) are assigned to it. '
        'Please reassign or archive those students first.',
      );
    }

    await db.transaction((txn) async {
      await txn.delete('batch_fee_templates', where: 'batchId = ?', whereArgs: [id]);
      await txn.delete('batches', where: 'id = ?', whereArgs: [id]);
    });
  }

  // --- Fee Templates (Standard Fee Structure per Batch) ---

  /// Retrieves standard fee templates for a batch.
  Future<List<BatchFeeTemplate>> getFeeTemplates(String batchId) async {
    final db = _dbManager.database;
    final rows = await db.query(
      'batch_fee_templates',
      where: 'batchId = ?',
      whereArgs: [batchId],
      orderBy: 'createdAt ASC',
    );
    return rows.map((r) => BatchFeeTemplate.fromMap(r)).toList();
  }

  /// Adds a standard fee installment to a batch.
  Future<BatchFeeTemplate> addFeeTemplate({
    required String batchId,
    required String title,
    required int grossPaise,
    String? defaultDueDate,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const ValidationException('Fee installment title cannot be empty');
    }
    if (grossPaise <= 0) {
      throw const ValidationException('Fee amount must be greater than zero');
    }

    if (defaultDueDate != null && defaultDueDate.trim().isNotEmpty) {
      CurrencyFormatter.parseDate(defaultDueDate.trim());
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final template = BatchFeeTemplate(
      id: _uuid.v4(),
      batchId: batchId,
      title: cleanTitle,
      grossPaise: grossPaise,
      defaultDueDate: defaultDueDate?.trim().isEmpty == true ? null : defaultDueDate?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await _dbManager.database.insert('batch_fee_templates', template.toMap());
    return template;
  }

  /// Updates an existing fee template.
  Future<void> updateFeeTemplate(BatchFeeTemplate template) async {
    final cleanTitle = template.title.trim();
    if (cleanTitle.isEmpty) {
      throw const ValidationException('Fee installment title cannot be empty');
    }
    if (template.grossPaise <= 0) {
      throw const ValidationException('Fee amount must be greater than zero');
    }

    if (template.defaultDueDate != null && template.defaultDueDate!.trim().isNotEmpty) {
      CurrencyFormatter.parseDate(template.defaultDueDate!.trim());
    }

    final updated = template.copyWith(
      title: cleanTitle,
      grossPaise: template.grossPaise,
      defaultDueDate: template.defaultDueDate?.trim().isEmpty == true ? null : template.defaultDueDate?.trim(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _dbManager.database.update(
      'batch_fee_templates',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  /// Deletes a fee template from a batch.
  Future<void> deleteFeeTemplate(String templateId) async {
    await _dbManager.database.delete(
      'batch_fee_templates',
      where: 'id = ?',
      whereArgs: [templateId],
    );
  }

  // --- Automated Batch Fee Charging ---

  /// Charges a batch's standard fee structure to a single student.
  /// Skips any installment with the same title that the student has already been charged.
  /// If [concessionPaise] > 0, applies the concession to the charges.
  Future<List<Charge>> chargeBatchFeesToStudent({
    required String payerId,
    required String batchId,
    int concessionPaise = 0,
  }) async {
    final db = _dbManager.database;
    final templates = await getFeeTemplates(batchId);
    if (templates.isEmpty) {
      throw const BusinessRuleException('No fee installments are configured for this batch yet.');
    }

    // Get batch information for labeling
    final batchRow = await db.query('batches', where: 'id = ?', whereArgs: [batchId], limit: 1);
    final academicYear = batchRow.isNotEmpty ? batchRow.first['academicYear'] as String? : null;

    // Check existing charges for this student to prevent duplicate charges
    final existingCharges = await db.query(
      'charges',
      where: 'payerId = ?',
      whereArgs: [payerId],
    );
    final existingTitles = existingCharges.map((c) => (c['title'] as String).toLowerCase()).toSet();

    final createdCharges = <Charge>[];
    int remainingConcession = concessionPaise;

    final defaultDue = CurrencyFormatter.toYmd(DateTime.now().add(const Duration(days: 30)));

    await db.transaction((txn) async {
      for (final template in templates) {
        // Skip if this fee title was already charged to the student
        if (existingTitles.contains(template.title.toLowerCase())) {
          continue;
        }

        // Apply remaining concession up to the gross fee
        int discountForThisCharge = 0;
        if (remainingConcession > 0) {
          discountForThisCharge = remainingConcession <= template.grossPaise ? remainingConcession : template.grossPaise;
          remainingConcession -= discountForThisCharge;
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        final charge = Charge(
          id: _uuid.v4(),
          payerId: payerId,
          batchId: batchId,
          title: template.title,
          period: academicYear,
          grossPaise: template.grossPaise,
          discountPaise: discountForThisCharge,
          dueDate: template.defaultDueDate ?? defaultDue,
          notes: 'Standard fee installment from batch structure',
          createdAt: now,
          updatedAt: now,
        );

        await txn.insert('charges', charge.toMap());
        createdCharges.add(charge);
      }
    });

    return createdCharges;
  }

  /// Applies standard batch fee structure to ALL enrolled students in the batch.
  /// Safely idempotently charges only the missing fee installments for each student.
  /// Returns total number of new fee charges created across all students.
  Future<int> chargeBatchFeesToAllStudents({required String batchId}) async {
    final db = _dbManager.database;
    final batch = await getBatchById(batchId);
    if (batch == null) throw const NotFoundException('Batch not found');

    if (batch.feeTemplates.isEmpty) {
      throw const BusinessRuleException('Please add fee installments to this batch before charging students.');
    }

    // Find all enrolled students (by batchId or batch name)
    final studentRows = await db.query(
      'payers',
      where: 'archived = 0 AND (batchId = ? OR (batchId IS NULL AND batch = ?))',
      whereArgs: [batchId, batch.name],
    );

    if (studentRows.isEmpty) {
      throw const BusinessRuleException('No students are currently enrolled in this batch.');
    }

    int totalCreated = 0;
    for (final sRow in studentRows) {
      final studentId = sRow['id'] as String;
      final created = await chargeBatchFeesToStudent(
        payerId: studentId,
        batchId: batchId,
        concessionPaise: 0,
      );
      totalCreated += created.length;
    }

    return totalCreated;
  }

  /// Retrieves all students enrolled in a specific batch.
  Future<List<Payer>> getStudentsInBatch(String batchId) async {
    final db = _dbManager.database;
    final batch = await getBatchById(batchId);
    final batchName = batch?.name ?? '';

    final sql = '''
      SELECT 
        p.*,
        COALESCE((SELECT SUM(c.grossPaise - c.discountPaise) FROM charges c WHERE c.payerId = p.id), 0) AS totalNetPaise,
        COALESCE((SELECT SUM(pm.amountPaise) FROM payments pm JOIN charges c ON pm.chargeId = c.id WHERE c.payerId = p.id), 0) AS totalPaidPaise,
        COALESCE((SELECT COUNT(*) FROM charges c WHERE c.payerId = p.id), 0) AS chargeCount
      FROM payers p
      WHERE p.archived = 0 AND (p.batchId = ? OR (p.batchId IS NULL AND p.batch = ?))
      ORDER BY p.name COLLATE NOCASE ASC;
    ''';

    final rows = await db.rawQuery(sql, [batchId, batchName]);
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
}
