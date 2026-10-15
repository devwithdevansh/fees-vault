import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../errors/app_exceptions.dart';

/// Local authentication service wrapping local_auth.
/// Supports Face ID, Touch ID, and device passcode fallback.
class AuthService {
  final LocalAuthentication _localAuth;

  AuthService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  /// Checks if the device has passcode or biometrics set up.
  Future<bool> isDeviceSecure() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return isSupported || canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Prompts user for system authentication (Face ID / Touch ID / Passcode).
  /// Allows device passcode fallback per specification.
  Future<bool> authenticate({
    String reason = 'Unlock FeesVault to access fee records',
  }) async {
    try {
      debugPrint('[FeesVault] Requesting system authentication (biometric + passcode fallback)...');
      final result = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: false, // Allows device passcode fallback!
      );
      debugPrint('[FeesVault] System authentication result: $result');
      return result;
    } on PlatformException catch (e) {
      debugPrint('[FeesVault] PlatformException during auth: code=${e.code}, message=${e.message}, details=${e.details}');
      if (e.code == 'NotAvailable' || e.code == 'PasscodeNotSet') {
        throw BiometricAuthException(
          'Device passcode or biometrics not configured on this device. A device passcode is required to secure FeesVault.',
          e.message,
        );
      }
      return false;
    } catch (e) {
      debugPrint('[FeesVault] Unexpected error during auth: $e');
      return false;
    }
  }

  /// Cancels any ongoing authentication dialog
  Future<void> cancelAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (_) {}
  }
}
