import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/payer.dart';
import '../controllers/vault_controller.dart';
import '../widgets/status_badge.dart';
import 'payer_detail_screen.dart';
import 'payer_form_screen.dart';

/// Students management screen — premium redesign with gradient header,
/// real-time search, active/archived tabs, and rich student cards.
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
    final activeStudents = widget.controller.payers
        .where((p) => !p.archived)
        .toList();
    final archivedStudents = widget.controller.payers
        .where((p) => p.archived)
        .toList();
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Students',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    // Student count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${activeStudents.length} active',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, or batch…',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    fillColor: AppColors.surfaceSubtle,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Tab bar
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.brand,
                  unselectedLabelColor: AppColors.textTertiary,
                  indicatorColor: AppColors.brand,
                  indicatorWeight: 2,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
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

          const Divider(height: 1),

          // ── Tab Content ─────────────────────────────────────────────────
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          HapticFeedback.lightImpact();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PayerFormScreen(controller: widget.controller),
            ),
          );
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Add Student',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

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
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.brandLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isArchived ? Icons.archive_outlined : Icons.school_rounded,
                  size: 40,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isArchived ? 'No Archived Students' : 'No Students Yet',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isArchived
                    ? 'Students you archive will appear here.'
                    : 'Add your first student to start managing fees and tracking payments.',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (!isArchived) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PayerFormScreen(controller: controller),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Register First Student'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (students.isEmpty) {
      return const Center(
        child: Text(
          'No students match your search.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.refreshAll(),
      color: AppColors.brand,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: students.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _StudentCard(student: students[index], controller: controller),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Payer student;
  final VaultController controller;

  const _StudentCard({required this.student, required this.controller});

  @override
  Widget build(BuildContext context) {
    final hasOutstanding = student.totalOutstandingPaise > 0;
    final initials = student.name.isNotEmpty
        ? student.name
              .trim()
              .split(' ')
              .map((w) => w[0])
              .take(2)
              .join()
              .toUpperCase()
        : '?';

    return GestureDetector(
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasOutstanding && !student.archived
                ? AppColors.unpaidAmberBg
                : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: student.archived
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: student.archived ? AppColors.archivedGrayBg : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                initials,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: student.archived
                      ? AppColors.archivedGray
                      : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
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
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (student.archived) ...[
                        const SizedBox(width: 6),
                        StatusBadge.archived(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (student.batch != null && student.batch!.isNotEmpty)
                        _BatchTag(label: student.batch!),
                      if (student.phone != null && student.phone!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 10,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                student.phone!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        '${student.chargeCount} fee installments',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Balance
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatPaise(student.totalOutstandingPaise),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: hasOutstanding
                        ? AppColors.unpaidAmber
                        : AppColors.settledGreen,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: hasOutstanding
                        ? AppColors.unpaidAmberBg
                        : AppColors.settledGreenBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hasOutstanding ? 'Due' : 'Clear',
                    style: TextStyle(
                      fontSize: 10.5,
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
    );
  }
}

class _BatchTag extends StatelessWidget {
  final String label;
  const _BatchTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.brand,
        ),
      ),
    );
  }
}
