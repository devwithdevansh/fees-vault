import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/errors/app_exceptions.dart';
import '../database/app_database.dart';
import '../models/academic_year.dart';

/// Repository managing Academic Years (e.g. 2026-2027).
class AcademicYearRepository {
  final AppDatabase _dbManager;
  final Uuid _uuid = const Uuid();

  AcademicYearRepository(this._dbManager);

  /// Retrieves all academic years sorted with current year first, then by creation date.
  Future<List<AcademicYear>> getAcademicYears() async {
    final db = _dbManager.database;
    final rows = await db.query(
      'academic_years',
      orderBy: 'isCurrent DESC, createdAt DESC',
    );
    return rows.map((r) => AcademicYear.fromMap(r)).toList();
  }

  /// Retrieves the active/current academic year.
  Future<AcademicYear?> getCurrentAcademicYear() async {
    final db = _dbManager.database;
    final rows = await db.query(
      'academic_years',
      where: 'isCurrent = 1',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return AcademicYear.fromMap(rows.first);
    }
    // Fallback: Return first record if none marked current
    final all = await db.query('academic_years', orderBy: 'createdAt DESC', limit: 1);
    if (all.isNotEmpty) {
      return AcademicYear.fromMap(all.first);
    }
    return null;
  }

  /// Creates a new academic year.
  Future<AcademicYear> createAcademicYear({
    required String name,
    bool isCurrent = false,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const ValidationException('Academic year name cannot be empty');
    }

    final db = _dbManager.database;

    // Check if name already exists
    final existing = await db.query(
      'academic_years',
      where: 'LOWER(name) = ?',
      whereArgs: [cleanName.toLowerCase()],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw ValidationException('Academic year "$cleanName" already exists');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final year = AcademicYear(
      id: 'ay_${_uuid.v4().substring(0, 8)}',
      name: cleanName,
      isCurrent: isCurrent,
      createdAt: now,
    );

    await db.transaction((txn) async {
      if (isCurrent) {
        await txn.update('academic_years', {'isCurrent': 0});
      }
      await txn.insert('academic_years', year.toMap());
    });

    return year;
  }

  /// Sets an academic year as the current active year.
  Future<void> setCurrentAcademicYear(String id) async {
    final db = _dbManager.database;
    await db.transaction((txn) async {
      await txn.update('academic_years', {'isCurrent': 0});
      final count = await txn.update(
        'academic_years',
        {'isCurrent': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) {
        throw const NotFoundException('Academic year not found');
      }
    });
  }

  /// Deletes an academic year if no batches are linked to it.
  Future<void> deleteAcademicYear(String id) async {
    final db = _dbManager.database;
    final yearRow = await db.query('academic_years', where: 'id = ?', whereArgs: [id], limit: 1);
    if (yearRow.isEmpty) return;

    final yearName = yearRow.first['name'] as String;

    final batchCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM batches WHERE academicYear = ?;',
      [yearName],
    )) ?? 0;

    if (batchCount > 0) {
      throw BusinessRuleException(
        'Cannot delete academic year "$yearName" because $batchCount batch(es) are linked to it.',
      );
    }

    await db.delete('academic_years', where: 'id = ?', whereArgs: [id]);
  }
}
