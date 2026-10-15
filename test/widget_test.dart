import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fees_vault/core/security/auth_service.dart';
import 'package:fees_vault/core/security/key_storage_service.dart';
import 'package:fees_vault/core/security/platform_security_service.dart';
import 'package:fees_vault/data/database/app_database.dart';
import 'package:fees_vault/presentation/controllers/auth_controller.dart';
import 'package:fees_vault/presentation/screens/lock_screen.dart';

void main() {
  testWidgets('LockScreen renders locked curtain and unlock action', (WidgetTester tester) async {
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
      MaterialApp(
        home: LockScreen(authController: authController),
      ),
    );

    expect(find.text('FeesVault is Locked'), findsOneWidget);
    expect(find.text('Unlock with Device Passcode'), findsOneWidget);
  });
}
