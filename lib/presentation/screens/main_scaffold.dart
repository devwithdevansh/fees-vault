import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _MainScaffoldState extends State<MainScaffold>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  static const _tabs = [
    _NavItem(Icons.grid_view_rounded, Icons.grid_view_rounded, 'Dashboard'),
    _NavItem(Icons.layers_outlined, Icons.layers_rounded, 'Batches'),
    _NavItem(Icons.school_outlined, Icons.school_rounded, 'Students'),
    _NavItem(
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
      'Receipts',
    ),
    _NavItem(Icons.tune_outlined, Icons.tune_rounded, 'Settings'),
  ];

  void _onTabTap(int index) {
    HapticFeedback.selectionClick();
    if (index == _currentIndex) {
      if (index == 3) {
        widget.controller.refreshAll();
      }
      return;
    }
    setState(() => _currentIndex = index);
    if (index == 3) {
      widget.controller.refreshAll();
    }
  }

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
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _PremiumNavBar(
        currentIndex: _currentIndex,
        tabs: _tabs,
        onTap: _onTabTap,
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

class _PremiumNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> tabs;
  final ValueChanged<int> onTap;

  const _PremiumNavBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.brandLight
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            isActive ? tab.activeIcon : tab.icon,
                            color: isActive
                                ? AppColors.brand
                                : AppColors.textTertiary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isActive
                                ? AppColors.brand
                                : AppColors.textTertiary,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
