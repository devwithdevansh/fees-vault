import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/security/auth_service.dart';
import '../../core/security/platform_security_service.dart';
import '../../data/database/app_database.dart';

enum AuthStatus { locked, authenticating, unlocked, failedClosed }

/// Controller managing the lock/unlock state machine and app lifecycle security.
/// Guarantees that sensitive screens are obscured when inactive, locked when backgrounded,
/// and that screenshot attempts or lack of enrolled device lock are handled safely.
class AuthController extends ChangeNotifier {
  final AuthService authService;
  final AppDatabase database;
  final PlatformSecurityService platformSecurityService;

  AuthStatus _status = AuthStatus.locked;
  bool _isObscured = true;
  String? _errorMessage;
  bool _isAuthenticatingSheet = false;
  bool _isDeviceLockMissing = false;
  bool _hasFaceBiometrics = false;
  bool _hasBiometrics = false;
  List<BiometricType> _availableBiometrics = [];

  AuthController({
    required this.authService,
    required this.database,
    PlatformSecurityService? platformSecurityService,
  }) : platformSecurityService =
           platformSecurityService ?? PlatformSecurityService() {
    this.platformSecurityService.setScreenshotCallback(_onScreenshotDetected);
    checkBiometrics();
  }

  AuthStatus get status => _status;
  bool get isLocked =>
      _status == AuthStatus.locked || _status == AuthStatus.failedClosed;
  bool get isObscured => _isObscured || isLocked;
  String? get errorMessage => _errorMessage;
  bool get isDeviceLockMissing => _isDeviceLockMissing;
  bool get hasFaceBiometrics => _hasFaceBiometrics;
  bool get hasBiometrics => _hasBiometrics;
  List<BiometricType> get availableBiometrics => _availableBiometrics;

  /// Checks what biometrics are available on the current device.
  Future<void> checkBiometrics() async {
    try {
      final biometrics = await authService.getAvailableBiometrics();
      _availableBiometrics = biometrics;
      _hasFaceBiometrics = biometrics.contains(BiometricType.face);
      _hasBiometrics =
          biometrics.isNotEmpty || await authService.hasBiometrics();
      notifyListeners();
    } catch (_) {}
  }

  void _onScreenshotDetected() {
    debugPrint(
      '[FeesVault] Screenshot attempt detected! Relocking vault immediately...',
    );
    lock();
  }

  /// Opens the device settings so the user can configure a PIN, pattern, or biometrics.
  Future<bool> openSecuritySettings() async {
    return await platformSecurityService.openSecuritySettings();
  }

  /// Attempts to authenticate user using system biometrics / device passcode fallback
  /// and opens the encrypted database.
  Future<bool> unlock({
    bool biometricOnly = false,
    String? reason,
  }) async {
    if (_status == AuthStatus.unlocked) return true;
    if (_status == AuthStatus.failedClosed) return false;

    _errorMessage = null;
    _isDeviceLockMissing = false;
    _status = AuthStatus.authenticating;
    _isAuthenticatingSheet = true;
    notifyListeners();

    try {
      debugPrint('[FeesVault] AuthController: Starting unlock sequence...');
      final authenticated = await authService.authenticate(
        reason: reason ?? 'Authenticate to access FeesVault records',
        biometricOnly: biometricOnly,
      );

      _isAuthenticatingSheet = false;

      if (authenticated) {
        debugPrint(
          '[FeesVault] AuthController: User authenticated! Initializing encrypted database...',
        );
        // Open the encrypted database
        await database.initializeAndOpen();
        _status = AuthStatus.unlocked;
        _isObscured = false;
        _errorMessage = null;
        _isDeviceLockMissing = false;
        debugPrint('[FeesVault] AuthController: Vault unlocked successfully!');
        notifyListeners();
        return true;
      } else {
        debugPrint(
          '[FeesVault] AuthController: Authentication not successful or dismissed.',
        );
        _status = AuthStatus.locked;
        _isObscured = true;
        _errorMessage =
            'Authentication canceled or failed. Tap retry to unlock.';
        notifyListeners();
        return false;
      }
    } on DeviceLockNotEnrolledException catch (e) {
      debugPrint(
        '[FeesVault] AuthController DeviceLockNotEnrolledException: ${e.message}',
      );
      _isAuthenticatingSheet = false;
      _status = AuthStatus.locked;
      _isObscured = true;
      _isDeviceLockMissing = true;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } on DatabaseSecurityException catch (e) {
      debugPrint(
        '[FeesVault] AuthController DatabaseSecurityException: ${e.message}',
      );
      _isAuthenticatingSheet = false;
      _status = AuthStatus.failedClosed;
      _isObscured = true;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } on AppException catch (e) {
      debugPrint('[FeesVault] AuthController AppException: ${e.message}');
      _isAuthenticatingSheet = false;
      _status = AuthStatus.locked;
      _isObscured = true;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[FeesVault] AuthController unexpected error: $e');
      _isAuthenticatingSheet = false;
      _status = AuthStatus.locked;
      _isObscured = true;
      _errorMessage = 'Unlock failed: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Explicit user or system lock.
  /// Drains handles, closes database connection, and clears sensitive state.
  Future<void> lock() async {
    _status = AuthStatus.locked;
    _isObscured = true;
    _errorMessage = null;
    await database.close();
    notifyListeners();
  }

  /// Responds to app lifecycle transitions.
  /// Distinguishes transient system sheet transitions from real backgrounding.
  void handleAppLifecycleState(AppLifecycleState state) {
    if (_status == AuthStatus.failedClosed) return;

    switch (state) {
      case AppLifecycleState.inactive:
        // System sheet or app switcher active
        if (!_isAuthenticatingSheet) {
          _isObscured = true;
          notifyListeners();
        }
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // App has actually moved to background
        if (!_isAuthenticatingSheet) {
          _status = AuthStatus.locked;
          _isObscured = true;
          database.close();
          notifyListeners();
        }
        break;

      case AppLifecycleState.resumed:
        if (_status == AuthStatus.unlocked) {
          _isObscured = false;
          notifyListeners();
        }
        break;

      case AppLifecycleState.detached:
        database.close();
        break;
    }
  }
}
