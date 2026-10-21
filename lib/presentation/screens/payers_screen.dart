import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/payer.dart';
import '../../data/seeds/demo_data_seeder.dart';
import '../controllers/vault_controller.dart';
import '../widgets/status_badge.dart';
import 'payer_detail_screen.dart';
import 'payer_form_screen.dart';

/// Students management screen — professional Notion/Linear-grade design.
/// Bold header, search, tab bar, gradient avatar cards with rich data layout.
class PayersScreen extends StatefulWidget {
  final VaultController controller;

  const PayersScreen({super.key, required this.controller});

  @override
  State<PayersScreen> createState() => _PayersScreenState();
}

class _PayersScreenState extends State<PayersScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<Payer> _filtered(bool archived) {
    final query = _searchController.text.toLowerCase().trim();
    return widget.controller.payers.where((p) {
      if (p.archived != archived) return false;
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) ||
          (p.phone?.toLowerCase().contains(query) ?? false) ||
          (p.batch?.toLowerCase().contains(query) ?? false) ||
          (p.notes?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final activeStudents =
        widget.controller.payers.where((p) => !p.archived).toList();
    final archivedStudents =
        widget.controller.payers.where((p) => p.archived).toList();
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Sticky Header ──────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      EdgeInsets.fromLTRB(20, topPadding + 20, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Students',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${activeStudents.length} enrolled · ${archivedStudents.length} archived',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Count badge
                      if (activeStudents.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: AppColors.brandGlow,
                          ),
                          child: Text(
                            '${activeStudents.length}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _searchFocused
                            ? AppColors.brand
                            : AppColors.divider,
                        width: _searchFocused ? 1.5 : 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      onTap: () => setState(() => _searchFocused = true),
                      onTapOutside: (_) =>
                          setState(() => _searchFocused = false),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by name, phone, or batch…',
                        hintStyle: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 19,
                          color: AppColors.textTertiary,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 17,
                                  color: AppColors.textTertiary,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
                        filled: false,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Tab bar
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.brand,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.brand,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: [
                    Tab(text: 'Active (${activeStudents.length})'),
                    Tab(text: 'Archived (${archivedStudents.length})'),
                  ],
                ),
              ],
            ),
          ),

          // Divider
          const Divider(height: 1, color: AppColors.divider),

          // ── Tab Content ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _StudentList(
                  students: _filtered(false),
                  controller: widget.controller,
                  isEmpty: activeStudents.isEmpty,
                  isArchived: false,
                ),
                _StudentList(
                  students: _filtered(true),
                  controller: widget.controller,
                  isEmpty: archivedStudents.isEmpty,
                  isArchived: true,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.brandGlow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              HapticFeedback.lightImpact();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PayerFormScreen(controller: widget.controller),
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Add Student',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
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

// ─────────────────────────────────────────────────────────────────────────────
// Student list view — handles empty/search states
// ─────────────────────────────────────────────────────────────────────────────
class _StudentList extends StatelessWidget {
  final List<Payer> students;
  final VaultController controller;
  final bool isEmpty;
  final bool isArchived;

  const _StudentList({
    required this.students,
    required this.controller,
    required this.isEmpty,
    required this.isArchived,
  });

  Future<void> _seedDemoData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.science_rounded, color: AppColors.brand, size: 24),
            SizedBox(width: 10),
            Text('Load 50 Demo Students?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'This will populate your encrypted vault with 50 realistic student records across 5 academic batches with varied fees, discounts, and payment receipts.\n\n'
          'This allows you to visually test all screens, filters, status indicators, and metrics on your phone.',
          style: TextStyle(height: 1.5, fontSize: 13.5, color: AppColors.textSecondary),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Load 50 Students'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

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
                CircularProgressIndicator(strokeWidth: 3, color: AppColors.brand),
                SizedBox(height: 16),
                Text(
                  'Generating 50 students...',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Creating batches, charges & receipts',
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.settledGreen,
            content: Text(
              '✓ Seeded ${results['students']} students, ${results['charges']} charges, and ${results['payments']} receipts!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: isArchived ? null : AppColors.brandGradient,
                  color: isArchived ? AppColors.archivedGrayBg : null,
                  shape: BoxShape.circle,
                  boxShadow: isArchived ? null : AppColors.brandGlow,
                ),
                child: Icon(
                  isArchived ? Icons.archive_outlined : Icons.school_rounded,
                  size: 36,
                  color: isArchived ? AppColors.archivedGray : Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isArchived ? 'No Archived Students' : 'No Students Yet',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isArchived
                    ? 'Students you archive will appear here.'
                    : 'Register your first student to start managing\nfees and tracking payments.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              if (!isArchived) ...[
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PayerFormScreen(controller: controller),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 17),
                  label: const Text('Register First Student'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _seedDemoData(context),
                  icon: const Icon(Icons.science_rounded, size: 16, color: AppColors.brand),
                  label: const Text('Load 50 Test Students', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.brandMid),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 28,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No results found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Try a different name, phone, or batch.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.refreshAll(),
      color: AppColors.brand,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        itemCount: students.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _StudentCard(student: students[index], controller: controller),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student card — gradient avatar, rich info layout, status indicator
// ─────────────────────────────────────────────────────────────────────────────
class _StudentCard extends StatelessWidget {
  final Payer student;
  final VaultController controller;

  const _StudentCard({required this.student, required this.controller});

  @override
  Widget build(BuildContext context) {
    final hasOutstanding = student.totalOutstandingPaise > 0;
    final isArchived = student.archived;
    final initials = student.name.isNotEmpty
        ? student.name
              .trim()
              .split(' ')
              .map((w) => w[0])
              .take(2)
              .join()
              .toUpperCase()
        : '?';

    final gradientColors = isArchived
        ? [AppColors.archivedGrayBg, AppColors.archivedGrayBg]
        : AppColors.avatarGradientFor(student.name);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          HapticFeedback.selectionClick();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PayerDetailScreen(payerId: student.id, controller: controller),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasOutstanding && !isArchived
                  ? AppColors.unpaidAmberMid
                  : AppColors.divider,
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Gradient avatar
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: isArchived ? AppColors.archivedGray : Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name + metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              student.name,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isArchived) ...[
                            const SizedBox(width: 6),
                            StatusBadge.archived(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (student.batch != null &&
                              student.batch!.isNotEmpty)
                            _Tag(
                              label: student.batch!,
                              color: AppColors.brand,
                              bg: AppColors.brandLight,
                            ),
                          if (student.phone != null &&
                              student.phone!.isNotEmpty)
                            _Tag(
                              label: student.phone!,
                              color: AppColors.textSecondary,
                              bg: AppColors.surfaceSubtle,
                              icon: Icons.phone_outlined,
                            ),
                          _Tag(
                            label: '${student.chargeCount} installments',
                            color: AppColors.textTertiary,
                            bg: AppColors.surfaceSubtle,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Balance + status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.formatPaise(
                        student.totalOutstandingPaise,
                      ),
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: hasOutstanding
                            ? AppColors.unpaidAmber
                            : AppColors.settledGreen,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: hasOutstanding
                            ? AppColors.unpaidAmberBg
                            : AppColors.settledGreenBg,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        hasOutstanding ? 'Due' : 'Clear',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: hasOutstanding
                              ? AppColors.unpaidAmber
                              : AppColors.settledGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact tag chip
// ─────────────────────────────────────────────────────────────────────────────
class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final IconData? icon;

  const _Tag({
    required this.label,
    required this.color,
    required this.bg,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
