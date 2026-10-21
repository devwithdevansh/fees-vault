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
    platformSecurityService: platformSecurity,
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

  // Safe global fallback widget replacing the default red screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.unpaidAmberBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      size: 32,
                      color: AppColors.unpaidAmber,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to display component',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A display issue occurred with this component. Your stored fee records and encrypted data remain safe.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };

  runApp(
    FeesVaultApp(
      authController: authController,
      vaultController: vaultController,
      database: database,
    ),
  );
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

class _FeesVaultAppState extends State<FeesVaultApp>
    with WidgetsBindingObserver {
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
          seedColor: AppColors.brand,
          primary: AppColors.brand,
          onPrimary: Colors.white,
          secondary: AppColors.brandDark,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),
        // Inter-style via system sans-serif — crisp, professional
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          // Display — hero numbers & page titles
          displayLarge: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -1.0,
            height: 1.1,
          ),
          displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.8,
            height: 1.15,
          ),
          displaySmall: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
          // Headlines — section titles
          headlineLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
          headlineMedium: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
          headlineSmall: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          // Body
          bodyLarge: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
            height: 1.4,
          ),
          // Labels
          labelLarge: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: 0.1,
          ),
          labelMedium: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 0.6,
          ),
          labelSmall: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          shadowColor: AppColors.divider,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        cardTheme: const CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: AppColors.divider),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppColors.brand, width: 2),
          ),
          errorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppColors.overdueRed),
          ),
          focusedErrorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppColors.overdueRed, width: 2),
          ),
          labelStyle: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
          ),
          floatingLabelStyle: const TextStyle(
            color: AppColors.brand,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.brand,
            side: const BorderSide(color: AppColors.brandMid, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceSubtle,
          selectedColor: AppColors.brandLight,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: AppColors.divider),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          titleTextStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          subtitleTextStyle: TextStyle(
            fontSize: 13,
            color: AppColors.textTertiary,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.textPrimary,
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          elevation: 0,
        ),
      ),
      home: ListenableBuilder(
        listenable: Listenable.merge([
          widget.authController,
          widget.vaultController,
        ]),
        builder: (context, _) {
          // 1. If vault is locked or halted in fail-closed state
          if (widget.authController.isLocked ||
              widget.authController.isObscured) {
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
