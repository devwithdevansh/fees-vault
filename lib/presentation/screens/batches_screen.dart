import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/batch.dart';
import '../controllers/vault_controller.dart';
import 'batch_detail_screen.dart';
import 'batch_form_screen.dart';

/// Screen displaying Batches (Courses) grouped by Academic Year.
class BatchesScreen extends StatefulWidget {
  final VaultController controller;

  const BatchesScreen({super.key, required this.controller});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAcademicYearSelector() {
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
                  child: Row(
                    children: [
                      Text(
                        'Academic Year',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(color: AppColors.divider),
                ...widget.controller.academicYears.map((ay) {
                  final isSelected =
                      widget.controller.selectedAcademicYearFilter == ay.name;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.brandLight
                            : AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isSelected
                            ? Icons.check_rounded
                            : Icons.calendar_today_outlined,
                        color: isSelected
                            ? AppColors.brand
                            : AppColors.textTertiary,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      ay.name,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
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
                              'Current',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      widget.controller.filterBatchesByAcademicYear(ay.name);
                      Navigator.pop(ctx);
                    },
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
                    _showAddAcademicYearDialog();
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

  void _showAddAcademicYearDialog() {
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
                    await widget.controller.createAcademicYear(
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
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final currentYear =
            widget.controller.selectedAcademicYearFilter ?? '2026-2027';
        final allBatches = widget.controller.batches;
        final batches = allBatches.where((b) {
          if (_searchQuery.isEmpty) return true;
          return b.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (b.notes?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                  false);
        }).toList();

        return Scaffold(
          // — Header
          appBar: AppBar(
            title: const Text('Batches & Courses'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: _showAcademicYearSelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.brandMid),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          size: 14,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          currentYear,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.expand_more_rounded,
                          size: 14,
                          color: AppColors.brand,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: batches.isEmpty
              ? null
              : Container(
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
                                BatchFormScreen(controller: widget.controller),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'New Batch',
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
          body: SafeArea(
            child: Column(
              children: [
                // Search bar
                if (allBatches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search batches or courses...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textTertiary,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.divider,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.divider,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.brand,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.trim()),
                    ),
                  ),

                // Batches List or Empty State
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => widget.controller.refreshAll(),
                    color: AppColors.brand,
                    child: batches.isEmpty
                        ? _buildEmptyState(currentYear)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: batches.length,
                            itemBuilder: (context, index) {
                              final batch = batches[index];
                              return _buildBatchCard(batch);
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String year) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.brandLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.layers_outlined,
                size: 36,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Batches for $year',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Organize your students into classes or subjects to manage standard fee schedules seamlessly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            // Structured 3-step guide card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  _emptyStepRow(
                    '1',
                    'Create Batch',
                    'e.g., "Class 10 Science" or "NEET Morning"',
                  ),
                  const Divider(height: 20, color: AppColors.divider),
                  _emptyStepRow(
                    '2',
                    'Set Standard Fees',
                    'Define installment amounts & due dates once',
                  ),
                  const Divider(height: 20, color: AppColors.divider),
                  _emptyStepRow(
                    '3',
                    'Enroll & Charge',
                    'Enroll students and charge all with 1 tap',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          BatchFormScreen(controller: widget.controller),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Create First Batch',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyStepRow(String stepNum, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.brandLight,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            stepNum,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.brand,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBatchCard(Batch batch) {
    final collectedRatio = batch.totalFeePaise > 0
        ? (batch.totalCollectedPaise / batch.totalFeePaise).clamp(0.0, 1.0)
        : 0.0;
    final pct = (collectedRatio * 100).round();
    final gradColors = AppColors.avatarGradientFor(batch.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BatchDetailScreen(
                  batchId: batch.id,
                  controller: widget.controller,
                ),
              ),
            );
          },
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
              boxShadow: AppColors.cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Batch icon avatar
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          batch.name.isNotEmpty
                              ? batch.name[0].toUpperCase()
                              : 'B',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              batch.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (batch.notes != null &&
                                batch.notes!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                batch.notes!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                        size: 22,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: AppColors.divider, height: 1),
                  const SizedBox(height: 14),

                  // Stats row
                  Row(
                    children: [
                      _BatchStat(
                        icon: Icons.people_outline_rounded,
                        label:
                            '${batch.studentCount} student${batch.studentCount == 1 ? '' : 's'}',
                      ),
                      const SizedBox(width: 16),
                      _BatchStat(
                        icon: Icons.receipt_long_outlined,
                        label: batch.feeTemplates.isNotEmpty
                            ? '${CurrencyFormatter.formatPaise(batch.standardBatchFeePaise)} / student'
                            : 'No fee setup',
                        color: batch.feeTemplates.isNotEmpty
                            ? AppColors.textSecondary
                            : AppColors.textMuted,
                      ),
                    ],
                  ),

                  // Progress bar
                  if (batch.totalFeePaise > 0) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Collected ${CurrencyFormatter.formatPaise(batch.totalCollectedPaise)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.settledGreen,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '$pct%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textTertiary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: collectedRatio,
                                  backgroundColor: AppColors.divider,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                    pct >= 100
                                        ? AppColors.settledGreen
                                        : pct >= 50
                                            ? AppColors.brand
                                            : AppColors.unpaidAmber,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (batch.totalOutstandingPaise > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Outstanding: ${CurrencyFormatter.formatPaise(batch.totalOutstandingPaise)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.unpaidAmber,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BatchStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _BatchStat({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: c,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
