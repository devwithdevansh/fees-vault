import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../core/constants/app_constants.dart';
import '../database/app_database.dart';

/// Repository for managing application preferences and atomic monotonic sequence counters.
class SettingsRepository {
  final AppDatabase _dbManager;

  SettingsRepository(this._dbManager);

  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    final results = await _dbManager.database.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (results.isEmpty) return defaultValue;
    return results.first['value'] as String? ?? defaultValue;
  }

  Future<void> setSetting(String key, String value) async {
    await _dbManager.database.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Transactionally increments and returns the next unique receipt number.
  /// Never reuses a receipt number even if previous payments are deleted,
  /// and never relies on row counts.
  Future<int> getNextReceiptNumber(Transaction txn) async {
    final results = await txn.query(
      'settings',
      where: 'key = ?',
      whereArgs: [AppConstants.settingReceiptCounter],
      limit: 1,
    );

    int currentCounter = 1000;
    if (results.isNotEmpty) {
      final valStr = results.first['value'] as String? ?? '1000';
      currentCounter = int.tryParse(valStr) ?? 1000;
    }

    final nextNumber = currentCounter + 1;

    await txn.insert('settings', {
      'key': AppConstants.settingReceiptCounter,
      'value': nextNumber.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return nextNumber;
  }
}
