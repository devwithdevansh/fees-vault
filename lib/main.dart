import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_constants.dart';
import 'core/security/auth_service.dart';
import 'core/security/key_storage_service.dart';
import 'core/security/platform_security_service.dart';
import 'data/database/app_database.dart';
import 'data/repositories/academic_year_repository.dart';
import 'data/repositories/audit_repository.dart';
import 'data/repositories/batch_repository.dart';
import 'data/repositories/charge_repository.dart';
import 'data/repositories/payer_repository.dart';
import 'data/repositories/payment_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'presentation/controllers/auth_controller.dart';
import 'presentation/controllers/vault_controller.dart';
import 'presentation/screens/lock_screen.dart';
import 'presentation/screens/main_scaffold.dart';
import 'presentation/screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style matching iOS status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Initialize Core Services
  final keyStorage = KeyStorageService();
  final platformSecurity = PlatformSecurityService();
  final authService = AuthService();
  final database = AppDatabase(
    keyStorage: keyStorage,
    platformSecurity: platformSecurity,
  );

  // Initialize Repositories
  final settingsRepo = SettingsRepository(database);
  final auditRepo = AuditRepository(database);
  final payerRepo = PayerRepository(database);
  final chargeRepo = ChargeRepository(database);
  final paymentRepo = PaymentRepository(database, settingsRepo);
  final academicYearRepo = AcademicYearRepository(database);
  final batchRepo = BatchRepository(database);

  // Initialize State Controllers
  final authController = AuthController(
    authService: authService,
    database: database,
  );

  final vaultController = VaultController(
    payerRepo: payerRepo,
    chargeRepo: chargeRepo,
    paymentRepo: paymentRepo,
    settingsRepo: settingsRepo,
    auditRepo: auditRepo,
    academicYearRepo: academicYearRepo,
    batchRepo: batchRepo,
  );

  runApp(FeesVaultApp(
    authController: authController,
    vaultController: vaultController,
    database: database,
  ));
}

/// Root Application Widget with lifecycle listener and lock state gate.
class FeesVaultApp extends StatefulWidget {
  final AuthController authController;
  final VaultController vaultController;
  final AppDatabase database;

  const FeesVaultApp({
    super.key,
    required this.authController,
    required this.vaultController,
    required this.database,
  });

  @override
  State<FeesVaultApp> createState() => _FeesVaultAppState();
}

class _FeesVaultAppState extends State<FeesVaultApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Wire auth unlock to trigger data loading
    widget.authController.addListener(_onAuthStateChanged);

    // Initial launch unlock attempt
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryInitialUnlock();
    });
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (widget.authController.status == AuthStatus.unlocked) {
      widget.vaultController.loadVaultData();
    }
  }

  Future<void> _tryInitialUnlock() async {
    await widget.authController.unlock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.authController.handleAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appDisplayName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryTealDark,
          primary: AppColors.primaryTealDark,
          surface: AppColors.surface,
          onSurface: AppColors.navyDark,
        ),
        fontFamily: null, // System bundled font
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.navyDark,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home: ListenableBuilder(
        listenable: Listenable.merge([widget.authController, widget.vaultController]),
        builder: (context, _) {
          // 1. If vault is locked or halted in fail-closed state
          if (widget.authController.isLocked || widget.authController.isObscured) {
            return LockScreen(authController: widget.authController);
          }

          // 2. If first-run onboarding has not been acknowledged
          if (!widget.vaultController.onboardingDone) {
            return OnboardingScreen(controller: widget.vaultController);
          }

          // 3. Authenticated root scaffold
          return MainScaffold(
            controller: widget.vaultController,
            authController: widget.authController,
            database: widget.database,
          );
        },
      ),
    );
  }
}
