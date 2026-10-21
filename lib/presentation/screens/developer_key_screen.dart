import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/vault_controller.dart';

/// One-time Developer Authorization & License Activation screen.
/// Prevents unauthorized sharing of the app by gating access behind
/// a master developer key that permanently activates this specific device.
class DeveloperKeyScreen extends StatefulWidget {
  final VaultController controller;

  const DeveloperKeyScreen({super.key, required this.controller});

  /// Validates developer key — normalized uppercase, stripped spaces/dashes.
  static bool isValidKey(String input) {
    final sanitized = input
        .trim()
        .toUpperCase()
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('_', '');

    const validKeys = [
      'FEESVAULTDEVKEY',
      'VAULTDEV2026',
      'FEEVAULTKEY2026',
      'DEVKEY2026',
    ];

    return validKeys.contains(sanitized);
  }

  @override
  State<DeveloperKeyScreen> createState() => _DeveloperKeyScreenState();
}

class _DeveloperKeyScreenState extends State<DeveloperKeyScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _obscureKey = true;
  bool _isActivating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _handleActivation() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the developer activation key';
      });
      return;
    }

    setState(() {
      _isActivating = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 350));

    if (!DeveloperKeyScreen.isValidKey(key)) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _isActivating = false;
          _errorMessage =
              'Invalid developer key. Please contact the software developer to obtain authorization for this device.';
        });
      }
      return;
    }

    HapticFeedback.heavyImpact();
    await widget.controller.acknowledgeDeveloperKey();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.verified_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Device license successfully authorized!'),
              ),
            ],
          ),
          backgroundColor: AppColors.settledGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Hero Icon with Gradient Glow ────────────────────────
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brand.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 46,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Title & Subtitle ──────────────────────────────────
                  const Text(
                    'Developer Authorization',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'One-Time Device Activation',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brand,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'This installation of FeesVault is restricted and bound to authorized academy devices. Enter the master developer authorization key to unlock this device.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // ── Activation Card ───────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                      boxShadow: AppColors.cardShadow,
                    ),
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'MASTER DEVELOPER KEY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: _keyController,
                          obscureText: _obscureKey,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter Developer Key',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                              color: AppColors.textTertiary,
                            ),
                            prefixIcon: const Icon(
                              Icons.vpn_key_rounded,
                              color: AppColors.brand,
                              size: 20,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_keyController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                      color: AppColors.textTertiary,
                                    ),
                                    onPressed: () {
                                      _keyController.clear();
                                      setState(() => _errorMessage = null);
                                    },
                                  ),
                                IconButton(
                                  icon: Icon(
                                    _obscureKey
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 19,
                                    color: AppColors.textTertiary,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscureKey = !_obscureKey);
                                  },
                                ),
                              ],
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceSubtle,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.divider),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.divider),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.brand,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                          onFieldSubmitted: (_) => _handleActivation(),
                        ),

                        // Error Banner
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.overdueRedBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.overdueRed.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.overdueRed,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.overdueRed,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 22),

                        // Submit Button
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isActivating ? null : _handleActivation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              shadowColor: AppColors.brand.withValues(alpha: 0.4),
                            ),
                            child: _isActivating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Activate Device License',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Security Badges Footer ────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Device-Bound License · Offline',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
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
