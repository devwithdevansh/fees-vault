import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/security/vault_backup_service.dart';
import '../../data/database/app_database.dart';
import '../controllers/auth_controller.dart';
import '../controllers/vault_controller.dart';
import 'walkthrough_screen.dart';

/// Settings and Security Status screen — professional Notion/Linear-grade design.
/// Accurately discloses cryptographic storage, Keychain attributes,
/// and local data retention limits without deceptive cloud or sync controls.
class SettingsScreen extends StatelessWidget {
  final VaultController controller;
  final AuthController authController;
  final AppDatabase database;

  const SettingsScreen({
    super.key,
    required this.controller,
    required this.authController,
    required this.database,
  });

  void _showExportBackupSheet(BuildContext context) {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isGenerating = false;
    String? generatedArmored;
    String? savedFilePath;
    String? errorMessage;
    bool obscurePassword = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.brandLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.brand,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Export Encrypted Backup',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'AES-256 encrypted tuition records',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (generatedArmored == null) ...[
                      const Text(
                        'Set a password to protect your backup. You will need this exact password whenever you restore your data.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: passwordCtrl,
                              obscureText: obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Backup Password *',
                                hintText: 'At least 4 characters',
                                prefixIcon: const Icon(Icons.key_rounded, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    size: 20,
                                  ),
                                  onPressed: () => setSheetState(() => obscurePassword = !obscurePassword),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().length < 4) {
                                  return 'Password must be at least 4 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: confirmCtrl,
                              obscureText: obscurePassword,
                              decoration: const InputDecoration(
                                labelText: 'Confirm Password *',
                                prefixIcon: Icon(Icons.check_circle_outline, size: 20),
                              ),
                              validator: (val) {
                                if (val != passwordCtrl.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: AppColors.overdueRed, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isGenerating
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setSheetState(() {
                                    isGenerating = true;
                                    errorMessage = null;
                                  });
                                  try {
                                    final armored = await VaultBackupService.createEncryptedBackup(
                                      controller: controller,
                                      passphrase: passwordCtrl.text.trim(),
                                    );
                                    final file = await VaultBackupService.saveBackupToFile(armored);
                                    setSheetState(() {
                                      generatedArmored = armored;
                                      savedFilePath = file.path;
                                      isGenerating = false;
                                    });
                                  } catch (e) {
                                    setSheetState(() {
                                      errorMessage = e.toString();
                                      isGenerating = false;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isGenerating
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Encrypt & Generate Backup',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.settledGreenBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.settledGreenMid),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.settledGreen, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Encrypted Backup Ready!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Saved to ${savedFilePath != null ? savedFilePath!.split(Platform.pathSeparator).last : "device storage"}',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Copy the code below and paste it into your notes, email, or WhatsApp. You can paste this code anytime to restore everything.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 110,
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            generatedArmored!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: generatedArmored!));
                                HapticFeedback.lightImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✓ Copied encrypted backup code to clipboard!'),
                                    backgroundColor: AppColors.settledGreen,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.brand),
                              label: const Text('Copy Code', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.brandMid),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRestoreBackupSheet(BuildContext context) {
    final codeCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isVerifying = false;
    bool isRestoring = false;
    String? errorMessage;
    Map<String, dynamic>? verifiedPayload;
    bool obscurePassword = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final counts = verifiedPayload?['metadata']?['counts'] as Map<String, dynamic>?;

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.partialBlueBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.restore_page_outlined,
                            color: AppColors.partialBlue,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Restore from Backup',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Paste encrypted code to recover vault',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (verifiedPayload == null) ...[
                      const Text(
                        'Paste the encrypted backup code and enter the password you created when exporting.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: formKey,
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                TextFormField(
                                  controller: codeCtrl,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    labelText: 'Paste Encrypted Backup Code *',
                                    hintText: 'FEESVAULT-BACKUP-V1::...::END',
                                    alignLabelWithHint: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please paste the backup code';
                                    }
                                    return null;
                                  },
                                ),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: TextButton.icon(
                                    onPressed: () async {
                                      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
                                      if (clipData?.text != null && clipData!.text!.isNotEmpty) {
                                        codeCtrl.text = clipData.text!.trim();
                                        setSheetState(() {});
                                      }
                                    },
                                    icon: const Icon(Icons.paste_rounded, size: 16, color: AppColors.brand),
                                    label: const Text('Paste', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.brand)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: passwordCtrl,
                              obscureText: obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Backup Password *',
                                prefixIcon: const Icon(Icons.key_rounded, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    size: 20,
                                  ),
                                  onPressed: () => setSheetState(() => obscurePassword = !obscurePassword),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter the backup password';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.overdueRedBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.overdueRedMid),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.overdueRed, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(color: AppColors.overdueRed, fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isVerifying
                              ? null
                              : () {
                                  if (!formKey.currentState!.validate()) return;
                                  setSheetState(() {
                                    isVerifying = true;
                                    errorMessage = null;
                                  });
                                  try {
                                    final payload = VaultBackupService.verifyAndDecryptBackup(
                                      armoredBackup: codeCtrl.text.trim(),
                                      passphrase: passwordCtrl.text.trim(),
                                    );
                                    setSheetState(() {
                                      verifiedPayload = payload;
                                      isVerifying = false;
                                    });
                                  } catch (e) {
                                    setSheetState(() {
                                      errorMessage = e.toString().replaceFirst('FormatException: ', '');
                                      isVerifying = false;
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isVerifying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Verify & Preview Backup',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ] else ...[
                      // Verification success card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.settledGreenBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.settledGreenMid),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified_rounded, color: AppColors.settledGreen, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'Backup Verified Successfully',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
                                ),
                              ],
                            ),
                            const Divider(color: AppColors.settledGreenMid, height: 18),
                            _backupStatRow('Classes / Batches', '${counts?['batches'] ?? 0}'),
                            _backupStatRow('Students Enrolled', '${counts?['students'] ?? 0}'),
                            _backupStatRow('Fee Installments', '${counts?['charges'] ?? 0}'),
                            _backupStatRow('Payment Receipts', '${counts?['payments'] ?? 0}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.overdueRedBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.overdueRedMid),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppColors.overdueRed, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Restoring will replace your current records with this backup.',
                                style: TextStyle(color: AppColors.overdueRed, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.overdueRedBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.overdueRedMid),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.overdueRed,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.overdueRed,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setSheetState(() {
                                verifiedPayload = null;
                                errorMessage = null;
                              }),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.divider),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Back'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: isRestoring
                                  ? null
                                  : () async {
                                      setSheetState(() {
                                        isRestoring = true;
                                        errorMessage = null;
                                      });
                                      try {
                                        final res = await VaultBackupService.restoreBackupIntoVault(
                                          controller: controller,
                                          decryptedPayload: verifiedPayload!,
                                        );
                                        if (ctx.mounted) {
                                          Navigator.of(ctx).pop();
                                        }
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '✓ Restored ${res['students']} students, ${res['batches']} classes, and ${res['payments']} receipts!',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              backgroundColor: AppColors.settledGreen,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setSheetState(() {
                                          errorMessage = 'Restore failed: $e';
                                          isRestoring = false;
                                        });
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.settledGreen,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: isRestoring
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Text(
                                      'Restore Vault Now',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _backupStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Future<void> _confirmClearAllData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.delete_forever_rounded,
              color: AppColors.overdueRed,
              size: 24,
            ),
            SizedBox(width: 10),
            Text(
              'Clear All Vault Data?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'This will safely delete all students, classes, fee charges, and receipts from your encrypted database.\n\n'
          'Your academy settings and encryption keys will remain intact.',
          style: TextStyle(
            height: 1.5,
            fontSize: 13.5,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.overdueRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await controller.clearAllVaultData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.settledGreen,
            content: Text(
              '✓ Vault data cleared successfully.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.overdueRed,
            content: Text('Failed to clear data: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _editBusinessName(BuildContext context) async {
    final textController = TextEditingController(text: controller.businessName);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Edit Academy Name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Business Name',
              hintText: 'e.g. Sunrise Academy',
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Name cannot be empty' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, textController.text.trim());
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (updated != null && updated.isNotEmpty) {
      await controller.updateBusinessName(updated);
    }
  }

  void _manageAcademicYears(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Academic Years',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(color: AppColors.divider),
                ...controller.academicYears.map((ay) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: ay.isCurrent
                            ? AppColors.brandLight
                            : AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        ay.isCurrent
                            ? Icons.check_rounded
                            : Icons.calendar_today_outlined,
                        color: ay.isCurrent
                            ? AppColors.brand
                            : AppColors.textTertiary,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      ay.name,
                      style: TextStyle(
                        fontWeight: ay.isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: ay.isCurrent
                            ? AppColors.brand
                            : AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    trailing: ay.isCurrent
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.brandGradient,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : TextButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await controller.setCurrentAcademicYear(ay.id);
                            },
                            child: const Text('Set Active'),
                          ),
                  );
                }),
                const Divider(color: AppColors.divider),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.brandLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: AppColors.brand,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Add Academic Year',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                      fontSize: 15,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddAcademicYearDialog(context);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    },
    );
  }

  void _showAddAcademicYearDialog(BuildContext context) {
    final textCtrl = TextEditingController(text: '2027-2028');
    bool makeCurrent = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Add Academic Year'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(
                  labelText: 'Academic Year Name',
                  hintText: 'e.g. 2027-2028',
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Set as current active year',
                  style: TextStyle(fontSize: 14),
                ),
                value: makeCurrent,
                onChanged: (val) =>
                    setDialogState(() => makeCurrent = val ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
              onPressed: () async {
                final name = textCtrl.text.trim();
                if (name.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  try {
                    await controller.createAcademicYear(
                      name,
                      isCurrent: makeCurrent,
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: AppColors.overdueRed,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Create',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Custom Header ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.surface,
              padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.brandGlow,
                    ),
                    child: Text(
                      controller.businessName.isNotEmpty
                          ? controller.businessName[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.businessName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.settledGreenBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Offline · Encrypted',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.settledGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: const Divider(height: 1, color: AppColors.divider),
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 24),

              // ── HELP & RESOURCES ────────────────────────────────────
              _SectionLabel(label: 'HELP & RESOURCES'),
              const SizedBox(height: 10),
              _SettingsCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.brandLight,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.brand,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Academy User Guide',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Step-by-step walkthrough for fee management',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (context) => GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AcademyWalkthroughScreen(),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'View',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── ACADEMY PROFILE ─────────────────────────────────────
              _SectionLabel(label: 'ACADEMY PROFILE'),
              const SizedBox(height: 10),
              Builder(
                builder: (context) => _SettingsCard(
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.school_rounded,
                        iconColor: AppColors.brand,
                        iconBg: AppColors.brandLight,
                        title: controller.businessName,
                        subtitle: 'Tap to change academy receipt header',
                        onTap: () => _editBusinessName(context),
                      ),
                      const _SettingsDivider(),
                      _SettingsTile(
                        icon: Icons.calendar_month_rounded,
                        iconColor: AppColors.brand,
                        iconBg: AppColors.brandLight,
                        title:
                            'Active Year: ${controller.currentAcademicYear?.name ?? "2026-2027"}',
                        subtitle: 'Manage academic cycles & switch active year',
                        onTap: () => _manageAcademicYears(context),
                      ),
                      const _SettingsDivider(),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Currency',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'INR (₹) · Rupee',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── SECURITY ────────────────────────────────────────────
              _SectionLabel(label: 'SECURITY'),
              const SizedBox(height: 10),
              _SettingsCard(
                child: _SettingsTile(
                  icon: Icons.lock_clock_outlined,
                  iconColor: AppColors.unpaidAmber,
                  iconBg: AppColors.unpaidAmberBg,
                  title: 'Lock Vault Now',
                  subtitle: 'Closes database · requires passcode / Face ID',
                  trailing: Builder(
                    builder: (context) => GestureDetector(
                      onTap: () => authController.lock(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Lock',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── VAULT SECURITY ATTRIBUTES ───────────────────────────
              _SectionLabel(label: 'VAULT SECURITY ATTRIBUTES'),
              const SizedBox(height: 10),
              _SettingsCard(
                child: Column(
                  children: [
                    _statusItem(
                      'Database Cipher',
                      database.cipherVersion != null
                          ? 'SQLCipher ${database.cipherVersion} (AES-256)'
                          : 'Active (SQLCipher Encrypted)',
                      isGood: true,
                    ),
                    const _SettingsDivider(),
                    _statusItem(
                      'Key Storage Policy',
                      Platform.isIOS
                          ? 'Keychain kSecAttrAccessibleWhenUnlockedThisDeviceOnly'
                          : 'Android Keystore EncryptedSharedPreferences',
                      isGood: true,
                    ),
                    const _SettingsDivider(),
                    _statusItem(
                      'Cloud Key Sync',
                      'Disabled (synchronizable = false)',
                      isGood: true,
                    ),
                    const _SettingsDivider(),
                    _statusItem(
                      'iOS File Protection',
                      'NSFileProtectionComplete',
                      isGood: true,
                    ),
                    const _SettingsDivider(),
                    _statusItem(
                      'Backup Exclusion',
                      'isExcludedFromBackup = true',
                      isGood: true,
                    ),
                    const _SettingsDivider(),
                    _statusItem(
                      'Remote Network Access',
                      'Disabled (Offline Architecture)',
                      isGood: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── DATA RETENTION ──────────────────────────────────────
              _SectionLabel(label: 'DATA RETENTION & RECOVERY'),
              const SizedBox(height: 10),
              _SettingsCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    '• Records exist strictly on this physical device.\n'
                    '• Apple backup-exclusion flags are guidance to iOS and do not form an absolute guarantee.\n'
                    '• Device-only Keychain keys cannot migrate to a replacement phone.\n'
                    '• Deleting FeesVault or wiping the device will permanently erase all data.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── APPLICATION DETAILS ─────────────────────────────────
              _SectionLabel(label: 'APPLICATION DETAILS'),
              const SizedBox(height: 10),
              _SettingsCard(
                child: Column(
                  children: [
                    _row('App Name', AppConstants.appDisplayName),
                    const _SettingsDivider(),
                    _row('Version', AppConstants.appVersion),
                    const _SettingsDivider(),
                    _row('Bundle ID', AppConstants.bundleIdentifier),
                    const _SettingsDivider(),
                    _row('Target OS', 'iOS 13.0+ / Android 7.1+'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── DATA MANAGEMENT ─────────────────────────────────
              _SectionLabel(label: 'DATA MANAGEMENT'),
              const SizedBox(height: 10),
              Builder(
                builder: (context) => _SettingsCard(
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.cloud_upload_outlined,
                        iconColor: AppColors.brand,
                        iconBg: AppColors.brandLight,
                        title: 'Export Encrypted Backup',
                        subtitle:
                            'Safeguard records with password-protected AES-256 backup',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Backup',
                            style: TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () => _showExportBackupSheet(context),
                      ),
                      const _SettingsDivider(),
                      _SettingsTile(
                        icon: Icons.cloud_download_outlined,
                        iconColor: AppColors.partialBlue,
                        iconBg: AppColors.partialBlueBg,
                        title: 'Restore from Backup',
                        subtitle:
                            'Paste backup code to recover students, fees & receipts',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.partialBlueBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Restore',
                            style: TextStyle(
                              color: AppColors.partialBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () => _showRestoreBackupSheet(context),
                      ),
                      const _SettingsDivider(),
                      _SettingsTile(
                        icon: Icons.delete_outline_rounded,
                        iconColor: AppColors.overdueRed,
                        iconBg: AppColors.overdueRedBg,
                        title: 'Clear All Vault Records',
                        subtitle:
                            'Permanently erase all students, classes, and receipts',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.overdueRedBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              color: AppColors.overdueRed,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () => _confirmClearAllData(context),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 48),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _statusItem(String title, String value, {bool isGood = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isGood
                  ? AppColors.settledGreenBg
                  : AppColors.unpaidAmberBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGood ? Icons.check_rounded : Icons.warning_rounded,
              size: 12,
              color: isGood ? AppColors.settledGreen : AppColors.unpaidAmber,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared settings widgets
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
          boxShadow: AppColors.cardShadow,
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      color: AppColors.divider,
      indent: 16,
      endIndent: 16,
    );
  }
}
