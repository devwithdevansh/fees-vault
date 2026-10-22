import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/payer.dart';
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
  String? _selectedBatchFilter; // null means 'All'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    widget.controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant PayersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerUpdate);
      widget.controller.addListener(_onControllerUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Extracts all distinct batches available in the academy
  List<_BatchFilterOption> _getBatchOptions() {
    final options = <_BatchFilterOption>[];
    final seenIds = <String>{};
    final seenNames = <String>{};

    for (final b in widget.controller.batches) {
      options.add(_BatchFilterOption(
        id: b.id,
        label: b.name,
        batchId: b.id,
        batchName: b.name,
      ));
      seenIds.add(b.id);
      seenNames.add(b.name.trim().toLowerCase());
    }

    // Also include any custom batch names from payers not already tracked
    for (final p in widget.controller.payers) {
      final bName = p.batch?.trim();
      if (bName != null &&
          bName.isNotEmpty &&
          !seenNames.contains(bName.toLowerCase())) {
        options.add(_BatchFilterOption(
          id: bName,
          label: bName,
          batchName: bName,
        ));
        seenNames.add(bName.toLowerCase());
      }
    }

    return options;
  }

  List<Payer> _filtered(bool archived) {
    final query = _searchController.text.toLowerCase().trim();
    final allScopeStudents =
        widget.controller.payers.where((p) => p.archived == archived).toList();
    final batchOptions = _getBatchOptions();

    _BatchFilterOption? selectedOption;
    if (_selectedBatchFilter != null) {
      if (_selectedBatchFilter == '__unassigned__') {
        selectedOption = const _BatchFilterOption(
          id: '__unassigned__',
          label: 'Unassigned',
        );
      } else {
        selectedOption = batchOptions.cast<_BatchFilterOption?>().firstWhere(
              (o) => o?.id == _selectedBatchFilter,
              orElse: () => null,
            );
      }
    }

    return allScopeStudents.where((p) {
      // 1. Batch filter
      if (selectedOption != null && !selectedOption.matches(p)) {
        return false;
      }

      // 2. Search query filter
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

    final currentScopeStudents =
        _tabController.index == 0 ? activeStudents : archivedStudents;
    final batchOptions = _getBatchOptions();
    final unassignedCount = currentScopeStudents.where((p) =>
        (p.batchId == null || p.batchId!.isEmpty) &&
        (p.batch == null || p.batch!.isEmpty)).length;

    final allFilterChips = <_BatchFilterOption>[
      ...batchOptions,
      if (unassignedCount > 0)
        const _BatchFilterOption(id: '__unassigned__', label: 'Unassigned'),
    ];

    final isFilterActive =
        _selectedBatchFilter != null || _searchController.text.isNotEmpty;

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

                // ── Horizontal Batch Filter Chips ───────────────────────────
                if (allFilterChips.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      itemCount: allFilterChips.length + 1, // +1 for 'All'
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final isSelected = _selectedBatchFilter == null;
                          final totalCount = currentScopeStudents.length;
                          return _FilterChipPill(
                            label: 'All Batches',
                            count: totalCount,
                            isSelected: isSelected,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedBatchFilter = null;
                              });
                            },
                          );
                        }

                        final option = allFilterChips[index - 1];
                        final isSelected = _selectedBatchFilter == option.id;
                        final count = currentScopeStudents
                            .where((p) => option.matches(p))
                            .length;

                        return _FilterChipPill(
                          label: option.label,
                          count: count,
                          isSelected: isSelected,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (_selectedBatchFilter == option.id) {
                                _selectedBatchFilter = null; // Toggle off to All
                              } else {
                                _selectedBatchFilter = option.id;
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],

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
                  isFilterActive: isFilterActive,
                  onClearFilters: () {
                    _searchController.clear();
                    setState(() {
                      _selectedBatchFilter = null;
                    });
                  },
                ),
                _StudentList(
                  students: _filtered(true),
                  controller: widget.controller,
                  isEmpty: archivedStudents.isEmpty,
                  isArchived: true,
                  isFilterActive: isFilterActive,
                  onClearFilters: () {
                    _searchController.clear();
                    setState(() {
                      _selectedBatchFilter = null;
                    });
                  },
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
// Batch Filter Option Helper
// ─────────────────────────────────────────────────────────────────────────────
class _BatchFilterOption {
  final String id;
  final String label;
  final String? batchId;
  final String? batchName;

  const _BatchFilterOption({
    required this.id,
    required this.label,
    this.batchId,
    this.batchName,
  });

  bool matches(Payer p) {
    if (id == '__unassigned__') {
      return (p.batchId == null || p.batchId!.isEmpty) &&
          (p.batch == null || p.batch!.isEmpty);
    }
    if (batchId != null && p.batchId == batchId) return true;
    if (batchName != null &&
        p.batch != null &&
        p.batch!.trim().toLowerCase() == batchName!.trim().toLowerCase()) {
      return true;
    }
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Chip Pill Widget
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChipPill extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipPill({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.brandGradient : null,
            color: isSelected ? null : AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.transparent : AppColors.divider,
              width: 1,
            ),
            boxShadow: isSelected ? AppColors.brandGlow : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.divider.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student list view — handles chunked progressive loading & empty states
// ─────────────────────────────────────────────────────────────────────────────
class _StudentList extends StatefulWidget {
  final List<Payer> students;
  final VaultController controller;
  final bool isEmpty;
  final bool isArchived;
  final bool isFilterActive;
  final VoidCallback? onClearFilters;

  const _StudentList({
    required this.students,
    required this.controller,
    required this.isEmpty,
    required this.isArchived,
    this.isFilterActive = false,
    this.onClearFilters,
  });

  @override
  State<_StudentList> createState() => _StudentListState();
}

class _StudentListState extends State<_StudentList> {
  static const int _initialPiece = 10;
  static const int _chunkSize = 15;
  int _visibleCount = _initialPiece;

  @override
  void didUpdateWidget(covariant _StudentList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset back to top piece of 10 whenever dataset changes
    if (oldWidget.students != widget.students ||
        oldWidget.isArchived != widget.isArchived) {
      _visibleCount = _initialPiece;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmpty) {
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
                  gradient:
                      widget.isArchived ? null : AppColors.brandGradient,
                  color:
                      widget.isArchived ? AppColors.archivedGrayBg : null,
                  shape: BoxShape.circle,
                  boxShadow:
                      widget.isArchived ? null : AppColors.brandGlow,
                ),
                child: Icon(
                  widget.isArchived
                      ? Icons.archive_outlined
                      : Icons.school_rounded,
                  size: 36,
                  color: widget.isArchived
                      ? AppColors.archivedGray
                      : Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.isArchived ? 'No Archived Students' : 'No Students Yet',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isArchived
                    ? 'Students you archive will appear here.'
                    : 'Register your first student to start managing\nfees and tracking payments.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              if (!widget.isArchived) ...[
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PayerFormScreen(controller: widget.controller),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 17),
                  label: const Text('Register First Student'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (widget.students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.filter_alt_off_rounded,
                  size: 30,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No matching students',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'No students found matching your selected batch or search criteria.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                  height: 1.4,
                ),
              ),
              if (widget.isFilterActive && widget.onClearFilters != null) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: widget.onClearFilters,
                  icon: const Icon(Icons.clear_all_rounded, size: 17),
                  label: const Text('Reset All Filters'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final totalCount = widget.students.length;
    final displayedCount = _visibleCount.clamp(0, totalCount);
    final visibleStudents = widget.students.take(displayedCount).toList();
    final hasMore = totalCount > displayedCount;
    final remaining = totalCount - displayedCount;
    final nextChunk = remaining > _chunkSize ? _chunkSize : remaining;

    // Has extra item for either "View More" card or "All Loaded" pill
    final showFooter = hasMore || totalCount > _initialPiece;
    final itemCount = visibleStudents.length + (showFooter ? 1 : 0);

    return RefreshIndicator(
      onRefresh: () => widget.controller.refreshAll(),
      color: AppColors.brand,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: itemCount,
        separatorBuilder: (_, index) {
          // No divider before or after footer
          if (index >= visibleStudents.length - 1) {
            return const SizedBox(height: 14);
          }
          return const SizedBox(height: 10);
        },
        itemBuilder: (context, index) {
          if (index < visibleStudents.length) {
            return _StudentCard(
              student: visibleStudents[index],
              controller: widget.controller,
            );
          }

          if (hasMore) {
            return _ViewMoreFooter(
              currentCount: displayedCount,
              totalCount: totalCount,
              nextChunk: nextChunk,
              onLoadMore: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _visibleCount += _chunkSize;
                });
              },
              onLoadAll: totalCount > 25
                  ? () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _visibleCount = totalCount;
                      });
                    }
                  : null,
            );
          } else {
            return _AllLoadedFooter(
              totalCount: totalCount,
              onCollapse: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _visibleCount = _initialPiece;
                });
              },
            );
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View More Footer Card
// ─────────────────────────────────────────────────────────────────────────────
class _ViewMoreFooter extends StatelessWidget {
  final int currentCount;
  final int totalCount;
  final int nextChunk;
  final VoidCallback onLoadMore;
  final VoidCallback? onLoadAll;

  const _ViewMoreFooter({
    required this.currentCount,
    required this.totalCount,
    required this.nextChunk,
    required this.onLoadMore,
    this.onLoadAll,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentCount / totalCount).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brandLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.unfold_more_rounded,
                  color: AppColors.brand,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Showing $currentCount of $totalCount students',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${totalCount - currentCount} more students in this view',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppColors.surfaceSubtle,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.brand),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onLoadMore,
                  icon: const Icon(Icons.expand_more_rounded, size: 18),
                  label: Text('View Next $nextChunk Students'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              if (onLoadAll != null) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: onLoadAll,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// All Loaded Footer Pill
// ─────────────────────────────────────────────────────────────────────────────
class _AllLoadedFooter extends StatelessWidget {
  final int totalCount;
  final VoidCallback onCollapse;

  const _AllLoadedFooter({
    required this.totalCount,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onCollapse,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 15,
                  color: AppColors.settledGreen,
                ),
                const SizedBox(width: 6),
                Text(
                  'All $totalCount students loaded · Tap to collapse',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Row: Avatar + Name/Batch + Balance/Status ────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gradient avatar
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isArchived
                              ? AppColors.archivedGray
                              : Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name + Batch (Expanded to prevent any horizontal overflow)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  student.name,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isArchived) ...[
                                const SizedBox(width: 6),
                                StatusBadge.archived(),
                              ],
                            ],
                          ),
                          if (student.batch != null &&
                              student.batch!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.school_outlined,
                                  size: 13,
                                  color: AppColors.brand,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    student.batch!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.brand,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
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

                // ── Bottom Metadata Row: Divider + Phone + Installments ─────
                if ((student.phone != null && student.phone!.isNotEmpty) ||
                    student.chargeCount > 0) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (student.phone != null && student.phone!.isNotEmpty)
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 13,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  student.phone!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 13,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${student.chargeCount} installments',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      if (student.archived) ...[
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: const Row(
                                  children: [
                                    Icon(
                                      Icons.unarchive_rounded,
                                      color: AppColors.settledGreen,
                                      size: 22,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Restore Student?'),
                                  ],
                                ),
                                content: Text(
                                  'Restore ${student.name} back to the active student list?\n\n'
                                  'All fee records and receipts remain completely intact.',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.45,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.settledGreen,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Restore Student'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await controller.archivePayer(student.id, false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '✓ ${student.name} restored to active list!',
                                    ),
                                    backgroundColor: AppColors.settledGreen,
                                  ),
                                );
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.settledGreenBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.settledGreenMid,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.unarchive_rounded,
                                  size: 14,
                                  color: AppColors.settledGreen,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Restore',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.settledGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
