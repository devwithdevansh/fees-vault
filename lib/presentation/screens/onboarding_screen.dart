import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/vault_controller.dart';
import 'walkthrough_screen.dart';

/// First-run onboarding disclosure screen — premium design with gradient header,
/// icon cards with container accents, and strong CTA hierarchy.
class OnboardingScreen extends StatelessWidget {
  final VaultController controller;

  const OnboardingScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero Header ──────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.headerGradient,
            ),
            child: Stack(
              children: [
                // Decorative circles
                Positioned(
                  right: -30,
                  top: -20,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                Positioned(
                  left: -20,
                  bottom: 0,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.03),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 34,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Welcome to FeesVault',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Local-First · Offline · Encrypted',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF93C5FD),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Info Cards ───────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              children: [
                _InfoCard(
                  icon: Icons.school_rounded,
                  iconColor: AppColors.brand,
                  iconBg: AppColors.brandLight,
                  title: 'Academy Fee System',
                  description:
                      'Track student enrollments, course fee installments, concessions, and verifiable receipt numbering — with zero cloud dependency.',
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  icon: Icons.smartphone_rounded,
                  iconColor: AppColors.settledGreen,
                  iconBg: AppColors.settledGreenBg,
                  title: 'Strict Local Storage',
                  description:
                      'All student records and payment histories stay on this device inside an encrypted SQLCipher database. No backend or cloud server.',
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.unpaidAmber,
                  iconBg: AppColors.unpaidAmberBg,
                  title: 'No Cloud Recovery',
                  description:
                      'Because records never leave this device, there is no automatic backup. If you delete the app or erase your device, records cannot be retrieved.',
                  isWarning: true,
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  icon: Icons.vpn_key_rounded,
                  iconColor: AppColors.partialBlue,
                  iconBg: AppColors.partialBlueBg,
                  title: 'Device-Bound Encryption Key',
                  description:
                      'A 256-bit AES key is stored in your secure hardware storage. It does not sync over cloud keychains and is tied to this device only.',
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── CTA Footer ───────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).padding.bottom + 20,
            ),
            child: Column(
              children: [
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AcademyWalkthroughScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book_rounded, size: 17),
                  label: const Text('View Academy Guide'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => controller.acknowledgeOnboarding(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'I Understand — Get Started',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
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

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String description;
  final bool isWarning;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.description,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarning ? AppColors.unpaidAmberMid : AppColors.divider,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isWarning ? AppColors.unpaidAmber : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
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
