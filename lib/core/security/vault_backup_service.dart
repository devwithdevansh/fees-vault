import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../presentation/controllers/vault_controller.dart';

/// Provides offline, AES-256 encrypted backup export and restore capabilities.
/// Protects tuition fee records with user-chosen passphrase and HMAC integrity checks.
class VaultBackupService {
  static const String backupHeader = 'FEESVAULT-BACKUP-V1::';
  static const String backupFooter = '::END';

  /// Generates a complete AES-256 encrypted backup of the entire vault database.
  static Future<String> createEncryptedBackup({
    required VaultController controller,
    required String passphrase,
  }) async {
    if (passphrase.trim().length < 4) {
      throw ArgumentError('Passphrase must be at least 4 characters long.');
    }

    final db = controller.payerRepo.dbManager.database;

    // 1. Export all tables in strict order
    final settingsRows = await db.query('settings');
    final academicYearsRows = await db.query('academic_years');
    final batchesRows = await db.query('batches');
    final templatesRows = await db.query('batch_fee_templates');
    final payersRows = await db.query('payers');
    final chargesRows = await db.query('charges');
    final paymentsRows = await db.query('payments');

    final payload = {
      'metadata': {
        'version': 1,
        'appName': 'FeesVault',
        'exportDate': DateTime.now().toIso8601String(),
        'counts': {
          'batches': batchesRows.length,
          'students': payersRows.length,
          'charges': chargesRows.length,
          'payments': paymentsRows.length,
        },
      },
      'data': {
        'settings': settingsRows,
        'academic_years': academicYearsRows,
        'batches': batchesRows,
        'batch_fee_templates': templatesRows,
        'payers': payersRows,
        'charges': chargesRows,
        'payments': paymentsRows,
      },
    };

    final jsonString = jsonEncode(payload);

    // 2. Generate random 16-byte salt & 16-byte IV
    final rng = Random.secure();
    final saltBytes = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
    final ivBytes = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));

    // 3. Derive 256-bit key from passphrase + salt
    final keyBytes = _deriveKey(passphrase, saltBytes);

    // 4. Encrypt using AES-CBC with PKCS7 padding
    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(jsonString, iv: iv);

    // 5. Compute HMAC-SHA256 integrity tag over (salt + iv + ciphertext)
    final hmacKey = sha256.convert(keyBytes).bytes;
    final hmac = Hmac(sha256, hmacKey);
    final macData = Uint8List.fromList([
      ...saltBytes,
      ...ivBytes,
      ...encrypted.bytes,
    ]);
    final macDigest = hmac.convert(macData).toString();

    // 6. Assemble envelope
    final envelope = {
      'v': 1,
      'salt': base64Encode(saltBytes),
      'iv': base64Encode(ivBytes),
      'mac': macDigest,
      'data': encrypted.base64,
    };

    final envelopeJson = jsonEncode(envelope);
    final armoredString = '$backupHeader${base64Encode(utf8.encode(envelopeJson))}$backupFooter';
    return armoredString;
  }

  /// Decrypts and verifies the integrity of an armored backup string without modifying data.
  /// Throws clear exceptions if password is wrong or backup is malformed/corrupted.
  static Map<String, dynamic> verifyAndDecryptBackup({
    required String armoredBackup,
    required String passphrase,
  }) {
    if (passphrase.trim().length < 4) {
      throw const FormatException('Passphrase must be at least 4 characters long.');
    }

    String cleanString = armoredBackup.trim();
    if (cleanString.contains(backupHeader)) {
      final startIndex = cleanString.indexOf(backupHeader) + backupHeader.length;
      cleanString = cleanString.substring(startIndex);
    }
    if (cleanString.contains(backupFooter)) {
      final endIndex = cleanString.lastIndexOf(backupFooter);
      cleanString = cleanString.substring(0, endIndex);
    }
    // Remove all whitespace, line breaks, carriage returns, and tabs
    cleanString = cleanString.replaceAll(RegExp(r'\s+'), '');

    if (cleanString.isEmpty) {
      throw const FormatException('Empty backup code. Please paste the complete encrypted backup.');
    }

    Map<String, dynamic> envelope;
    try {
      final decodedJson = utf8.decode(base64Decode(cleanString));
      envelope = jsonDecode(decodedJson) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException(
        'Invalid backup data format. Please make sure the entire backup code was copied accurately.',
      );
    }

    final saltBase64 = (envelope['salt'] as String?)?.replaceAll(RegExp(r'\s+'), '');
    final ivBase64 = (envelope['iv'] as String?)?.replaceAll(RegExp(r'\s+'), '');
    final expectedMac = (envelope['mac'] as String?)?.trim();
    final ciphertextBase64 = (envelope['data'] as String?)?.replaceAll(RegExp(r'\s+'), '');

    if (saltBase64 == null || ivBase64 == null || expectedMac == null || ciphertextBase64 == null) {
      throw const FormatException(
        'Corrupted backup structure. Essential security fields are missing.',
      );
    }

    final saltBytes = base64Decode(saltBase64);
    final ivBytes = base64Decode(ivBase64);

    // Derive key
    final keyBytes = _deriveKey(passphrase.trim(), saltBytes);

    // Verify HMAC integrity
    final hmacKey = sha256.convert(keyBytes).bytes;
    final hmac = Hmac(sha256, hmacKey);
    final encryptedBytes = base64Decode(ciphertextBase64);
    final macData = Uint8List.fromList([
      ...saltBytes,
      ...ivBytes,
      ...encryptedBytes,
    ]);
    final computedMac = hmac.convert(macData).toString();

    if (computedMac != expectedMac) {
      throw const FormatException(
        'Incorrect backup password or corrupted backup data.',
      );
    }

    // Decrypt
    try {
      final key = enc.Key(keyBytes);
      final iv = enc.IV(ivBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decryptedJson = encrypter.decrypt(
        enc.Encrypted(encryptedBytes),
        iv: iv,
      );

      final payload = jsonDecode(decryptedJson) as Map<String, dynamic>;
      return payload;
    } catch (_) {
      throw const FormatException(
        'Incorrect backup password or corrupted backup data.',
      );
    }
  }

  /// Restores a verified decrypted backup payload into the encrypted vault database.
  /// Executes atomically inside a single SQLite transaction with full table clearing
  /// and conflict resolution.
  static Future<Map<String, int>> restoreBackupIntoVault({
    required VaultController controller,
    required Map<String, dynamic> decryptedPayload,
  }) async {
    final db = controller.payerRepo.dbManager.database;
    final data = decryptedPayload['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw const FormatException('Corrupt backup: missing data payload.');
    }

    final settings = (data['settings'] as List? ?? []).cast<Map<String, dynamic>>();
    final academicYears = (data['academic_years'] as List? ?? []).cast<Map<String, dynamic>>();
    final batches = (data['batches'] as List? ?? []).cast<Map<String, dynamic>>();
    final templates = (data['batch_fee_templates'] as List? ?? []).cast<Map<String, dynamic>>();
    final payers = (data['payers'] as List? ?? []).cast<Map<String, dynamic>>();
    final charges = (data['charges'] as List? ?? []).cast<Map<String, dynamic>>();
    final payments = (data['payments'] as List? ?? []).cast<Map<String, dynamic>>();

    await db.transaction((txn) async {
      // 1. Wipe existing records in strict reverse foreign key dependency order
      await txn.delete('payments');
      await txn.delete('audit_events');
      await txn.delete('charges');
      await txn.delete('batch_fee_templates');
      await txn.delete('payers');
      await txn.delete('batches');
      await txn.delete('academic_years');
      await txn.delete('settings');

      // 2. Restore settings with conflict replacement
      for (final s in settings) {
        await txn.insert(
          'settings',
          s,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 3. Restore academic years with conflict replacement
      for (final ay in academicYears) {
        await txn.insert(
          'academic_years',
          ay,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 4. Restore batches with conflict replacement
      for (final b in batches) {
        await txn.insert(
          'batches',
          b,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 5. Restore batch fee templates with conflict replacement
      for (final t in templates) {
        await txn.insert(
          'batch_fee_templates',
          t,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 6. Restore payers (students) with conflict replacement
      for (final p in payers) {
        await txn.insert(
          'payers',
          p,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 7. Restore fee charges with conflict replacement
      for (final ch in charges) {
        await txn.insert(
          'charges',
          ch,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 8. Restore payments with conflict replacement
      for (final py in payments) {
        await txn.insert(
          'payments',
          py,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    // Full refresh of state across all screens
    await controller.loadVaultData();

    return {
      'batches': batches.length,
      'students': payers.length,
      'charges': charges.length,
      'payments': payments.length,
    };
  }

  /// Saves the armored backup string to a file in the app documents directory
  /// and returns the File object.
  static Future<File> saveBackupToFile(String armoredBackup) async {
    final dir = await getApplicationDocumentsDirectory();
    final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/FeesVault_Backup_$dateStr.vault');
    return file.writeAsString(armoredBackup, flush: true);
  }

  /// Cryptographic Key Derivation using PBKDF2-like SHA256 iterations (10,000 rounds)
  static Uint8List _deriveKey(String passphrase, Uint8List salt) {
    var key = utf8.encode(passphrase) + salt;
    for (int i = 0; i < 10000; i++) {
      key = sha256.convert(key).bytes;
    }
    return Uint8List.fromList(key.sublist(0, 32));
  }
}
