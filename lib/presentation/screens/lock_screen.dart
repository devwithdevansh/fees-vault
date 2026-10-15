import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/auth_controller.dart';

/// Screen displayed when the vault is locked or halted in a fail-closed state.
class LockScreen extends StatelessWidget {
  final AuthController authController;

  const LockScreen({
    super.key,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    final isFailedClosed = authController.status == AuthStatus.failedClosed;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isFailedClosed
                        ? AppColors.overdueRedBg
                        : AppColors.primaryTealLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFailedClosed
                        ? Icons.lock_person_outlined
                        : Icons.lock_outline,
                    size: 42,
                    color: isFailedClosed
                        ? AppColors.overdueRed
                        : AppColors.primaryTealDark,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isFailedClosed ? 'Security Lockout (Fail-Closed)' : 'FeesVault is Locked',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navyDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  isFailedClosed
                      ? (authController.errorMessage ??
                          'Decryption key missing or SQLCipher unavailable. Existing records cannot be decrypted. Halting to preserve data integrity.')
                      : 'Authenticate using Face ID, Touch ID, or your device passcode to decrypt and open your fee records.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.slate,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (!isFailedClosed) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => authController.unlock(),
                      icon: const Icon(Icons.fingerprint, color: Colors.white),
                      label: const Text(
                        'Unlock with Device Passcode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTealDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  if (authController.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      authController.errorMessage!,
                      style: const TextStyle(
                        color: AppColors.overdueRed,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.overdueRedBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.overdueRed.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'ATTENTION: Never wipe or recreate an empty database to bypass this error. '
                      'Check platform secure storage or device migration logs.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.overdueRed,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
