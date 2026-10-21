import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/auth_controller.dart';

/// Premium lock screen — dark gradient with centered vault icon and unlock CTA.
/// Handles normal locked state, failed-closed security lockout, and no-device-lock fallback.
class LockScreen extends StatefulWidget {
  final AuthController authController;

  const LockScreen({super.key, required this.authController});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  @override
  void initState() {
    super.initState();
    widget.authController.checkBiometrics();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authController,
      builder: (context, _) {
        final authController = widget.authController;
        final isFailedClosed = authController.status == AuthStatus.failedClosed;
        final isDeviceLockMissing = authController.isDeviceLockMissing;

        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(gradient: AppColors.headerGradient),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon badge
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: isDeviceLockMissing
                              ? const Color(0xFFFFD54F).withValues(alpha: 0.18)
                              : isFailedClosed
                              ? const Color(0xFFFF5252).withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDeviceLockMissing
                                ? const Color(
                                    0xFFFFD54F,
                                  ).withValues(alpha: 0.45)
                                : isFailedClosed
                                ? const Color(
                                    0xFFFF5252,
                                  ).withValues(alpha: 0.45)
                                : Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isDeviceLockMissing
                              ? Icons.phonelink_lock_rounded
                              : isFailedClosed
                              ? Icons.lock_person_rounded
                              : Icons.lock_rounded,
                          size: 48,
                          color: isDeviceLockMissing
                              ? const Color(0xFFFFD54F)
                              : isFailedClosed
                              ? const Color(0xFFFFB3B3)
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Title
                      Text(
                        isDeviceLockMissing
                            ? 'Device Lock Required'
                            : isFailedClosed
                            ? 'Security Lockout'
                            : 'FeesVault is Locked',
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),

                      // Description
                      Text(
                        isDeviceLockMissing
                            ? 'FeesVault encrypts sensitive fee records using your device\'s secure lock. Please set up a screen lock (PIN, Pattern, Password, or Fingerprint) in your device settings to continue.'
                            : isFailedClosed
                            ? (authController.errorMessage ??
                                'Decryption key unavailable. Cannot open records.')
                            : 'Your fee records are encrypted and offline.\nAuthenticate to open FeesVault.',
                        style: TextStyle(
                          fontSize: 14.5,
                          color: isDeviceLockMissing
                              ? const Color(0xFFFFE082)
                              : const Color(0xFFB0B8FF),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 36),

                      if (isDeviceLockMissing) ...[
                        // Primary button: Open Settings
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                authController.openSecuritySettings(),
                            icon: const Icon(Icons.settings_rounded, size: 22),
                            label: const Text(
                              'Open Device Settings',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.brand,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Secondary button: Retry
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => authController.unlock(),
                            icon: const Icon(
                              Icons.refresh_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "I've Set a Lock — Try Again",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Explanatory note
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 20,
                                color: Color(0xFFFFD54F),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'FeesVault keeps all student financial records private on this device. A screen lock guarantees that only you can access them.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white70,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (!isFailedClosed) ...[
                        // Primary Action: Unlock with Face ID
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            key: const ValueKey('unlock_face_id_btn'),
                            onPressed: () => authController.unlock(
                              reason: 'Verify your face to open FeesVault',
                            ),
                            icon: const Icon(Icons.face_rounded, size: 24),
                            label: Text(
                              authController.hasFaceBiometrics
                                  ? 'Unlock with Face ID'
                                  : (authController.hasBiometrics
                                      ? 'Unlock with Face ID / Biometrics'
                                      : 'Unlock with Face ID'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.brand,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Secondary Action: Unlock with Device Passcode
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const ValueKey('unlock_passcode_btn'),
                            onPressed: () => authController.unlock(
                              reason:
                                  'Enter your device screen lock to open FeesVault',
                            ),
                            icon: const Icon(
                              Icons.pin_outlined,
                              size: 20,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Unlock with Device Passcode',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                    if (authController.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          authController.errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFFFB3B3),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Text(
                        'ATTENTION: Never wipe or recreate an empty database to bypass this error. '
                        'Check platform secure storage or device migration logs.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFFB3B3),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),
                  // Offline badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              size: 12,
                              color: Color(0xFFB0B8FF),
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Fully Offline & Encrypted',
                              style: TextStyle(
                                color: Color(0xFFB0B8FF),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  },
);
  }
}
