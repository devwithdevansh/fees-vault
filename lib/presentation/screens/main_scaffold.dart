import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/database/app_database.dart';
import '../controllers/auth_controller.dart';
import '../controllers/vault_controller.dart';
import 'batches_screen.dart';
import 'dashboard_screen.dart';
import 'payers_screen.dart';
import 'payments_screen.dart';
import 'settings_screen.dart';

/// Root navigation scaffold hosting the 5 core bottom tabs:
/// Dashboard, Batches, Students, Receipts, and Settings.
class MainScaffold extends StatefulWidget {
  final VaultController controller;
  final AuthController authController;
  final AppDatabase database;

  const MainScaffold({
    super.key,
    required this.controller,
    required this.authController,
    required this.database,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(controller: widget.controller),
      BatchesScreen(controller: widget.controller),
      PayersScreen(controller: widget.controller),
      PaymentsScreen(controller: widget.controller),
      SettingsScreen(
        controller: widget.controller,
        authController: widget.authController,
        database: widget.database,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primaryTealDark,
          unselectedItemColor: AppColors.slate,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              activeIcon: Icon(Icons.groups),
              label: 'Batches',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school_outlined),
              activeIcon: Icon(Icons.school),
              label: 'Students',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Receipts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
