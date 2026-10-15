import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/security/key_storage_service.dart';
import '../../core/security/platform_security_service.dart';
import 'migrations.dart';

enum DatabaseInitState {
  uninitialized,
  opening,
  ready,
  locked,
  failedClosed,
}

/// Encrypted SQLCipher database manager.
/// Enforces fail-closed security, private application support directory location,
/// native file protection, and device-only Keychain integration.
class AppDatabase {
  final KeyStorageService _keyStorage;
  final PlatformSecurityService _platformSecurity;

  Database? _db;
  DatabaseInitState _state = DatabaseInitState.uninitialized;
  String? _fatalError;
  String? _cipherVersion;
  String? _dbFilePath;

  AppDatabase({
    KeyStorageService? keyStorage,
    PlatformSecurityService? platformSecurity,
  })  : _keyStorage = keyStorage ?? KeyStorageService(),
        _platformSecurity = platformSecurity ?? PlatformSecurityService();

  DatabaseInitState get state => _state;
  bool get isOpen => _db != null && _db!.isOpen;
  String? get fatalError => _fatalError;
  String? get cipherVersion => _cipherVersion;
  String? get databasePath => _dbFilePath;

  Database get database {
    if (_db == null || !_db!.isOpen) {
      throw const DatabaseSecurityException(
        'Database is closed or locked. Authentication required.',
      );
    }
    return _db!;
  }

  /// Initializes the encrypted vault database.
  /// Enforces fail-closed policy: never overwrites or re-creates a database if key is missing!
  Future<void> initializeAndOpen() async {
    if (isOpen) return;
    _state = DatabaseInitState.opening;
    _fatalError = null;

    try {
      // 1. Resolve dedicated private Application Support directory
      final appSupportDir = await getApplicationSupportDirectory();
      final vaultDir = Directory(p.join(appSupportDir.path, AppConstants.vaultDirectoryName));
      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }

      // Apply complete file protection and backup exclusion to vault directory
      await _platformSecurity.applyProtectionAndBackupExclusion(vaultDir.path);

      final dbFile = File(p.join(vaultDir.path, AppConstants.databaseFileName));
      _dbFilePath = dbFile.path;
      final fileExists = await dbFile.exists();

      // 2. Fetch or provision encryption key
      String? key = await _keyStorage.getExistingKey();

      if (fileExists && (key == null || key.isEmpty)) {
        // FATAL FAIL-CLOSED: Database exists on disk but key is absent from Keychain/Keystore!
        // Never delete or create empty database!
        _state = DatabaseInitState.failedClosed;
        _fatalError =
            'Database exists on disk, but the decryption key is missing from secure storage. '
            'To protect existing records from destruction, automatic recovery is disallowed. '
            'Halting in fail-closed state.';
        throw KeyMissingException(_fatalError!);
      }

      if (key == null || key.isEmpty) {
        // First launch: Generate fresh 256-bit cryptographically secure random key
        key = await _keyStorage.generateAndPersistKey();
      }

      // 3. Open database with SQLCipher encryption
      _db = await openDatabase(
        _dbFilePath!,
        password: key,
        version: DatabaseMigrations.currentVersion,
        onConfigure: DatabaseMigrations.onConfigure,
        onCreate: DatabaseMigrations.onCreate,
        onUpgrade: DatabaseMigrations.onUpgrade,
      );

      // 4. Verify SQLCipher is actually linked and active (not plain SQLite fallback!)
      try {
        final pragmaResult = await _db!.rawQuery('PRAGMA cipher_version;');
        if (pragmaResult.isNotEmpty && pragmaResult.first.values.isNotEmpty) {
          _cipherVersion = pragmaResult.first.values.first?.toString();
        }
      } catch (e) {
        await close();
        _state = DatabaseInitState.failedClosed;
        _fatalError = 'Failed to verify SQLCipher linking: ${e.toString()}';
        throw DatabaseSecurityException(_fatalError!);
      }

      if (_cipherVersion == null || _cipherVersion!.isEmpty) {
        await close();
        _state = DatabaseInitState.failedClosed;
        _fatalError =
            'SQLCipher is not active on this build. Plain SQLite fallback is strictly prohibited.';
        throw DatabaseSecurityException(_fatalError!);
      }

      debugPrint('[FeesVault] SQLCipher successfully opened & verified! Cipher version: $_cipherVersion');

      // 5. Re-apply and verify file protection & backup exclusion on database and any sidecars
      await _platformSecurity.applyProtectionAndBackupExclusion(vaultDir.path);

      _state = DatabaseInitState.ready;
    } catch (e) {
      if (_state != DatabaseInitState.failedClosed) {
        _state = DatabaseInitState.failedClosed;
        _fatalError = e.toString();
      }
      rethrow;
    }
  }

  /// Closes database handle safely and clears internal state when locked or entering background.
  Future<void> close() async {
    try {
      if (_db != null && _db!.isOpen) {
        await _db!.close();
      }
    } catch (_) {}
    _db = null;
    if (_state != DatabaseInitState.failedClosed) {
      _state = DatabaseInitState.locked;
    }
  }
}
