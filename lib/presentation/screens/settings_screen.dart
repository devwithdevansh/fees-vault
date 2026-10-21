import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/database/app_database.dart';
import '../../data/seeds/demo_data_seeder.dart';
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

  Future<void> _confirmResetAndSeedMonthlyData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              color: AppColors.brand,
              size: 24,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reset & Seed Monthly Tuition Data?',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Text(
          'This will safely clear existing test records and populate your encrypted database with a complete 12-month tuition fee system:\n\n'
          '• 5 Classes (Class 9 to 12 & Commerce)\n'
          '• 12 Monthly Tuition Cycles (April 2026 to March 2027)\n'
          '• Standard Due Dates on 10th of every month\n'
          '• Realistic timeline payments up to October 2026\n'
          '• 50 Students with phone numbers and roll numbers',
          style: TextStyle(
            height: 1.5,
            fontSize: 13,
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
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset & Load 12-Month Data'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    // Show loading progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.cardShadow,
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.brand,
                ),
                SizedBox(height: 16),
                Text(
                  'Setting up Tuition Demo Data...',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Creating 12 monthly fee cycles & receipts',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final results = await DemoDataSeeder.seed(controller, clearFirst: true);
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.settledGreen,
            content: Text(
              '✓ Loaded ${results['students']} students across ${results['batches']} classes with 12-month schedules!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.overdueRed,
            content: Text('Failed to load demo data: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
      await DemoDataSeeder.clearVaultData(controller);
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

              // ── DEMO & TESTING DATA ─────────────────────────────────
              _SectionLabel(label: 'DEMO DATA & SAMPLE SYSTEM'),
              const SizedBox(height: 10),
              Builder(
                builder: (context) => _SettingsCard(
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.calendar_month_rounded,
                        iconColor: AppColors.brand,
                        iconBg: AppColors.brandLight,
                        title: 'Reset & Seed Monthly Tuition Data',
                        subtitle:
                            'Safely replace data with 12-month tuition fee schedules',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: AppColors.brandGlow,
                          ),
                          child: const Text(
                            'Load Demo',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () => _confirmResetAndSeedMonthlyData(context),
                      ),
                      const _SettingsDivider(),
                      _SettingsTile(
                        icon: Icons.delete_outline_rounded,
                        iconColor: AppColors.overdueRed,
                        iconBg: AppColors.overdueRedBg,
                        title: 'Clear All Vault Data',
                        subtitle:
                            'Safely wipe all test records back to a clean slate',
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
