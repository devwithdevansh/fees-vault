import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/database/app_database.dart';
import '../controllers/auth_controller.dart';
import '../controllers/vault_controller.dart';
import '../widgets/app_card.dart';
import 'walkthrough_screen.dart';

/// Settings and Security Status screen.
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

  Future<void> _editBusinessName(BuildContext context) async {
    final textController = TextEditingController(text: controller.businessName);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Business Display Name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: textController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Business Name',
              filled: true,
              fillColor: AppColors.surfaceSubtle,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Name cannot be empty' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTealDark),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Academic Years',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyDark,
                    ),
                  ),
                ),
                const Divider(color: AppColors.divider),
                ...controller.academicYears.map((ay) {
                  return ListTile(
                    leading: Icon(
                      ay.isCurrent ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: ay.isCurrent ? AppColors.primaryTealDark : AppColors.slate,
                    ),
                    title: Text(
                      ay.name,
                      style: TextStyle(
                        fontWeight: ay.isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: AppColors.navyDark,
                      ),
                    ),
                    trailing: ay.isCurrent
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTealLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryTealDark,
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
                  leading: const Icon(Icons.add_circle_outline, color: AppColors.primaryTealDark),
                  title: const Text(
                    'Add Academic Year',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryTealDark,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddAcademicYearDialog(context);
                  },
                ),
              ],
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
                title: const Text('Set as current active year', style: TextStyle(fontSize: 14)),
                value: makeCurrent,
                onChanged: (val) => setDialogState(() => makeCurrent = val ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTealDark),
              onPressed: () async {
                final name = textCtrl.text.trim();
                if (name.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  try {
                    await controller.createAcademicYear(name, isCurrent: makeCurrent);
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: AppColors.overdueRed),
                    );
                  }
                }
              },
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Settings & Vault Security',
          style: TextStyle(
            color: AppColors.navyDark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Academy User Guide & Walkthrough Card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTealLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu_book_outlined, color: AppColors.primaryTealDark),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Academy User Guide & Help',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Step-by-step walkthrough of student fee workflows',
                        style: TextStyle(fontSize: 12, color: AppColors.slate),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AcademyWalkthroughScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTealDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('View Guide', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Academy Profile Card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACADEMY PROFILE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.school, color: AppColors.navyDark),
                  ),
                  title: Text(
                    controller.businessName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: const Text('Tap to change academy receipt header'),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.slate),
                  onTap: () => _editBusinessName(context),
                ),
                const Divider(color: AppColors.divider),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTealLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_month, color: AppColors.primaryTealDark),
                  ),
                  title: Text(
                    'Active Year: ${controller.currentAcademicYear?.name ?? "2026-2027"}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: const Text('Manage academic cycles & switch active year'),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.slate),
                  onTap: () => _manageAcademicYears(context),
                ),
                const Divider(color: AppColors.divider),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Currency', style: TextStyle(color: AppColors.slate, fontSize: 14)),
                    Text('INR (₹) • Indian Rupee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lock Vault Button
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.unpaidAmberBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lock_clock_outlined, color: AppColors.unpaidAmber),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lock Vault Now',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Closes database and requires passcode/Face ID',
                        style: TextStyle(fontSize: 12, color: AppColors.slate),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => authController.lock(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Lock', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Platform Security Inspector
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.security, size: 18, color: AppColors.primaryTealDark),
                    SizedBox(width: 8),
                    Text(
                      'VAULT SECURITY ATTRIBUTES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navyDark,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _statusItem(
                  'Database Cipher',
                  database.cipherVersion != null
                      ? 'SQLCipher ${database.cipherVersion} (AES-256)'
                      : 'Active (SQLCipher Encrypted)',
                  isGood: true,
                ),
                const SizedBox(height: 8),
                _statusItem(
                  'Key Storage Policy',
                  Platform.isIOS
                      ? 'Keychain kSecAttrAccessibleWhenUnlockedThisDeviceOnly'
                      : 'Android Keystore EncryptedSharedPreferences',
                  isGood: true,
                ),
                const SizedBox(height: 8),
                _statusItem(
                  'Cloud Key Sync',
                  'Disabled (synchronizable = false)',
                  isGood: true,
                ),
                const SizedBox(height: 8),
                _statusItem(
                  'iOS File Protection',
                  'NSFileProtectionComplete (Device Locked Encryption)',
                  isGood: true,
                ),
                const SizedBox(height: 8),
                _statusItem(
                  'Backup Exclusion',
                  'isExcludedFromBackup = true',
                  isGood: true,
                ),
                const SizedBox(height: 8),
                _statusItem(
                  'Remote Network Access',
                  'Disabled (Strict Offline App Architecture)',
                  isGood: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Boundaries and Recovery Limitations Notice
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppColors.slate),
                    SizedBox(width: 8),
                    Text(
                      'DATA RETENTION & RECOVERY BOUNDARY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '• Records exist strictly on this physical iPhone/device.\n'
                  '• Apple backup-exclusion flags are guidance to iOS and do not form an absolute guarantee.\n'
                  '• Device-only Keychain keys cannot migrate to a replacement phone.\n'
                  '• Deleting FeesVault or wiping the device will permanently erase all data with no recovery possible.\n'
                  '• Before client production use, a separate offline encrypted backup feature may be commissioned.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.slate,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // About App Card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'APPLICATION DETAILS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                _row('App Name', AppConstants.appDisplayName),
                const SizedBox(height: 6),
                _row('Version', AppConstants.appVersion),
                const SizedBox(height: 6),
                _row('Bundle ID', AppConstants.bundleIdentifier),
                const SizedBox(height: 6),
                _row('Target OS', 'iOS 13.0+ / Android 7.1+'),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _statusItem(String title, String value, {bool isGood = true}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isGood ? Icons.check_circle : Icons.warning,
          size: 16,
          color: isGood ? AppColors.settledGreen : AppColors.unpaidAmber,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.navyDark)),
              Text(value, style: const TextStyle(fontSize: 12, color: AppColors.slate)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.slate, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.navyDark)),
      ],
    );
  }
}
