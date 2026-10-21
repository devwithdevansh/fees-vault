import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';
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
    String cleanString = armoredBackup.trim();
    if (cleanString.startsWith(backupHeader)) {
      cleanString = cleanString.substring(backupHeader.length);
    }
    if (cleanString.endsWith(backupFooter)) {
      cleanString = cleanString.substring(0, cleanString.length - backupFooter.length);
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

    final saltBytes = base64Decode(envelope['salt'] as String);
    final ivBytes = base64Decode(envelope['iv'] as String);
    final expectedMac = envelope['mac'] as String;
    final ciphertextBase64 = envelope['data'] as String;

    // Derive key
    final keyBytes = _deriveKey(passphrase, saltBytes);

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
        'Incorrect backup passphrase or corrupted backup data.',
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
        'Incorrect backup passphrase or corrupted backup data.',
      );
    }
  }

  /// Restores a verified decrypted backup payload into the encrypted vault database.
  /// Executes atomically inside a single SQLite transaction.
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
      // 1. Wipe existing records in strict reverse dependency order
      await txn.delete('payments');
      await txn.delete('audit_events');
      await txn.delete('charges');
      await txn.delete('batch_fee_templates');
      await txn.delete('payers');
      await txn.delete('batches');

      // 2. Restore settings
      for (final s in settings) {
        await txn.insert('settings', s);
      }

      // 3. Restore academic years
      for (final ay in academicYears) {
        await txn.insert('academic_years', ay);
      }

      // 4. Restore batches
      for (final b in batches) {
        await txn.insert('batches', b);
      }

      // 5. Restore batch fee templates
      for (final t in templates) {
        await txn.insert('batch_fee_templates', t);
      }

      // 6. Restore payers (students)
      for (final p in payers) {
        await txn.insert('payers', p);
      }

      // 7. Restore fee charges
      for (final ch in charges) {
        await txn.insert('charges', ch);
      }

      // 8. Restore payments
      for (final py in payments) {
        await txn.insert('payments', py);
      }
    });

    // Refresh state
    await controller.refreshAll();

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

  /// Key derivation using multi-round SHA-256 with salt
  static Uint8List _deriveKey(String passphrase, Uint8List salt) {
    var digest = sha256.convert([
      ...salt,
      ...utf8.encode(passphrase),
      ...salt,
    ]).bytes;

    for (int i = 0; i < 1000; i++) {
      digest = sha256.convert([...digest, ...salt]).bytes;
    }

    return Uint8List.fromList(digest);
  }
}
