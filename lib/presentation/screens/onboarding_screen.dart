import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/vault_controller.dart';
import 'walkthrough_screen.dart';

/// First-run onboarding disclosure screen detailing local storage and recovery boundaries.
class OnboardingScreen extends StatelessWidget {
  final VaultController controller;

  const OnboardingScreen({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Icon(
                Icons.shield_outlined,
                size: 56,
                color: AppColors.primaryTealDark,
              ),
              const SizedBox(height: 16),
              const Text(
                'Welcome to FeesVault',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Local-First, Offline Fee Management',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              Expanded(
                child: ListView(
                  children: [
                    _infoCard(
                      icon: Icons.school_outlined,
                      title: 'Education Academy Fee System',
                      description:
                          'Track student enrollments, course fee installments, parent contacts, concessions, and verifiable receipt numbering with zero cloud dependency.',
                    ),
                    const SizedBox(height: 14),
                    _infoCard(
                      icon: Icons.smartphone_outlined,
                      title: 'Strict Local Storage',
                      description:
                          'All student records, parent contact details, and payment histories stay strictly on this device inside an encrypted SQLCipher database. No backend, cloud server, or telemetry.',
                    ),
                    const SizedBox(height: 14),
                    _infoCard(
                      icon: Icons.warning_amber_rounded,
                      title: 'No Cloud Recovery Guarantee',
                      description:
                          'Because records never leave this device, there is no automatic cloud backup. If you delete this app or erase your device, records cannot be retrieved.',
                      isWarning: true,
                    ),
                    const SizedBox(height: 14),
                    _infoCard(
                      icon: Icons.vpn_key_outlined,
                      title: 'Device-Bound Hardware Key',
                      description:
                          'The 256-bit database key is stored in your secure hardware storage with device-only accessibility. It does not sync over cloud keychains.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AcademyWalkthroughScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.menu_book_outlined, color: AppColors.primaryTealDark, size: 20),
                label: const Text(
                  'How to Use FeesVault (Academy Guide)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryTealDark,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.primaryTealDark),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => controller.acknowledgeOnboarding(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTealDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'I Understand & Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String description,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWarning ? AppColors.unpaidAmberBg.withValues(alpha: 0.4) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWarning ? AppColors.unpaidAmber.withValues(alpha: 0.5) : AppColors.divider,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 24,
            color: isWarning ? AppColors.unpaidAmber : AppColors.primaryTealDark,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isWarning ? AppColors.unpaidAmber : AppColors.navyDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.slate,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
