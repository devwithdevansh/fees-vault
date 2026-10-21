import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fees_vault/core/errors/app_exceptions.dart';
import 'package:fees_vault/core/security/auth_service.dart';
import 'package:fees_vault/core/security/key_storage_service.dart';
import 'package:fees_vault/core/security/platform_security_service.dart';
import 'package:fees_vault/data/database/app_database.dart';
import 'package:fees_vault/presentation/controllers/auth_controller.dart';
import 'package:fees_vault/presentation/screens/lock_screen.dart';

class MockPlatformSecurityService extends PlatformSecurityService {
  void Function()? callback;
  bool isEnrolled = true;
  bool settingsOpened = false;

  @override
  void setScreenshotCallback(void Function() onScreenshot) {
    callback = onScreenshot;
  }

  @override
  Future<bool> isDeviceLockEnrolled() async => isEnrolled;

  @override
  Future<bool> openSecuritySettings() async {
    settingsOpened = true;
    return true;
  }
}

class MockAuthServiceNoLock extends AuthService {
  @override
  Future<bool> authenticate({String reason = ''}) async {
    throw DeviceLockNotEnrolledException(
      'No screen lock is set up on this device.',
      'No credentials enrolled',
    );
  }
}

void main() {
  testWidgets('LockScreen renders locked curtain and unlock action', (
    WidgetTester tester,
  ) async {
    final keyStorage = KeyStorageService();
    final platformSecurity = PlatformSecurityService();
    final authService = AuthService();
    final database = AppDatabase(
      keyStorage: keyStorage,
      platformSecurity: platformSecurity,
    );

    final authController = AuthController(
      authService: authService,
      database: database,
    );

    await tester.pumpWidget(
      MaterialApp(home: LockScreen(authController: authController)),
    );

    expect(find.text('FeesVault is Locked'), findsOneWidget);
    expect(find.text('Unlock with Device Passcode'), findsOneWidget);
  });

  testWidgets(
    'LockScreen displays fallback guidance and Open Device Settings when no lock is set',
    (WidgetTester tester) async {
      final keyStorage = KeyStorageService();
      final mockPlatform = MockPlatformSecurityService()..isEnrolled = false;
      final authService = MockAuthServiceNoLock();
      final database = AppDatabase(
        keyStorage: keyStorage,
        platformSecurity: mockPlatform,
      );

      final authController = AuthController(
        authService: authService,
        database: database,
        platformSecurityService: mockPlatform,
      );

      // Attempt unlock without enrolled device lock
      await authController.unlock();

      expect(authController.isDeviceLockMissing, isTrue);

      await tester.pumpWidget(
        MaterialApp(home: LockScreen(authController: authController)),
      );

      expect(find.text('Device Lock Required'), findsOneWidget);
      expect(find.text('Open Device Settings'), findsOneWidget);
      expect(find.text("I've Set a Lock — Try Again"), findsOneWidget);

      // Tap Open Device Settings
      await tester.tap(find.text('Open Device Settings'));
      await tester.pump();
      expect(mockPlatform.settingsOpened, isTrue);
    },
  );

  test('Screenshot detection immediately forces re-lock', () async {
    final keyStorage = KeyStorageService();
    final mockPlatform = MockPlatformSecurityService();
    final authService = AuthService();
    final database = AppDatabase(
      keyStorage: keyStorage,
      platformSecurity: mockPlatform,
    );

    final authController = AuthController(
      authService: authService,
      database: database,
      platformSecurityService: mockPlatform,
    );

    // Verify callback was registered
    expect(mockPlatform.callback, isNotNull);

    // Trigger simulated screenshot event from native
    mockPlatform.callback!.call();

    expect(authController.isLocked, isTrue);
    expect(authController.isObscured, isTrue);
  });
}
