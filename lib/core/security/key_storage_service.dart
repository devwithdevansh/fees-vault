import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../errors/app_exceptions.dart';

/// Secure storage service managing the 256-bit SQLCipher database key.
/// Configured for iOS Keychain with:
/// - accessibility: KeychainAccessibility.unlocked_this_device (kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
/// - synchronizable: false (no iCloud keychain sync)
/// And for Android with EncryptedSharedPreferences (Android Keystore).
class KeyStorageService {
  final FlutterSecureStorage _storage;

  KeyStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.unlocked_this_device,
                synchronizable: false,
              ),
              aOptions: AndroidOptions(),
            );

  /// Retrieves the existing database key from Keychain / Keystore.
  /// Returns null if no key has been provisioned yet.
  Future<String?> getExistingKey() async {
    try {
      return await _storage.read(key: AppConstants.dbPassphraseKey);
    } catch (e) {
      throw DatabaseSecurityException(
        'Failed to read database key from platform secure storage',
        e.toString(),
      );
    }
  }

  /// Generates a fresh cryptographically secure 256-bit (32 bytes) key,
  /// persists it, and reads it back to verify persistence before returning.
  Future<String> generateAndPersistKey() async {
    try {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      final generatedHex = base64UrlEncode(bytes);

      // Persist to secure storage
      await _storage.write(
        key: AppConstants.dbPassphraseKey,
        value: generatedHex,
      );

      // Verify read-back immediately before confirming
      final readBack = await _storage.read(key: AppConstants.dbPassphraseKey);
      if (readBack != generatedHex) {
        throw const DatabaseSecurityException(
          'Keychain write-readback verification failed. Key could not be confirmed.',
        );
      }

      await _storage.write(
        key: AppConstants.keyInitializationStatusKey,
        value: 'initialized_v1',
      );

      return generatedHex;
    } catch (e) {
      if (e is DatabaseSecurityException) rethrow;
      throw DatabaseSecurityException(
        'Could not initialize database secret in secure storage',
        e.toString(),
      );
    }
  }
}
