import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/auth_controller.dart';

/// Premium lock screen — dark gradient with centered vault icon and unlock CTA.
class LockScreen extends StatelessWidget {
  final AuthController authController;

  const LockScreen({super.key, required this.authController});

  @override
  Widget build(BuildContext context) {
    final isFailedClosed = authController.status == AuthStatus.failedClosed;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isFailedClosed
                          ? Icons.lock_person_rounded
                          : Icons.lock_rounded,
                      size: 48,
                      color: isFailedClosed
                          ? const Color(0xFFFFB3B3)
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Title
                  Text(
                    isFailedClosed ? 'Security Lockout' : 'FeesVault is Locked',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFailedClosed
                        ? (authController.errorMessage ??
                              'Decryption key unavailable. Cannot open records.')
                        : 'Your fee records are encrypted and offline.\nAuthenticate to open FeesVault.',
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: Color(0xFFB0B8FF),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  if (!isFailedClosed) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => authController.unlock(),
                        icon: const Icon(Icons.fingerprint_rounded, size: 22),
                        label: const Text(
                          'Unlock with Device Passcode',
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

                  const SizedBox(height: 24),
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
  }
}
