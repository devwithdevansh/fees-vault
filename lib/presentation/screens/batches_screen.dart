import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/batch.dart';
import '../controllers/vault_controller.dart';
import '../widgets/app_card.dart';
import 'batch_detail_screen.dart';
import 'batch_form_screen.dart';

/// Screen displaying Batches (Courses) grouped by Academic Year.
class BatchesScreen extends StatefulWidget {
  final VaultController controller;

  const BatchesScreen({
    super.key,
    required this.controller,
  });

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
                    'Select Academic Year',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyDark,
                    ),
                  ),
                ),
                const Divider(color: AppColors.divider),
                ...widget.controller.academicYears.map((ay) {
                  final isSelected = widget.controller.selectedAcademicYearFilter == ay.name;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isSelected ? AppColors.primaryTealDark : AppColors.slate,
                    ),
                    title: Text(
                      ay.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                              'Current Year',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryTealDark,
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
                    _showAddAcademicYearDialog();
                  },
                ),
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
                    await widget.controller.createAcademicYear(name, isCurrent: makeCurrent);
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
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final currentYear = widget.controller.selectedAcademicYearFilter ?? '2026-2027';
        final allBatches = widget.controller.batches;
        final batches = allBatches.where((b) {
          if (_searchQuery.isEmpty) return true;
          return b.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (b.notes?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Batches & Courses',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              // Academic Year selector pill
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ActionChip(
                  avatar: const Icon(Icons.calendar_month, size: 16, color: AppColors.primaryTealDark),
                  label: Text(
                    currentYear,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTealDark,
                    ),
                  ),
                  backgroundColor: AppColors.primaryTealLight,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: _showAcademicYearSelector,
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'add_batch_fab',
            backgroundColor: AppColors.primaryTealDark,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('New Batch', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BatchFormScreen(controller: widget.controller),
                ),
              );
            },
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Search bar
                if (allBatches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search batches or courses...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.slate),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                  ),

                // Batches List or Empty State
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => widget.controller.refreshAll(),
                    child: batches.isEmpty
                        ? _buildEmptyState(currentYear)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryTealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.groups_outlined, size: 40, color: AppColors.primaryTealDark),
            ),
            const SizedBox(height: 20),
            Text(
              'No Batches for $year',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect your academy workflow seamlessly:\n'
              '1. Create a Batch (e.g. Class 10 Science)\n'
              '2. Define standard fee installments once\n'
              '3. Enroll students into the batch\n'
              '4. Charge all students with one tap!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.slate,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BatchFormScreen(controller: widget.controller),
                  ),
                );
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create First Batch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTealDark,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchCard(Batch batch) {
    final collectedRatio = batch.totalFeePaise > 0
        ? (batch.totalCollectedPaise / batch.totalFeePaise).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batch.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyDark,
                        ),
                      ),
                      if (batch.notes != null && batch.notes!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          batch.notes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.slate),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.slate),
              ],
            ),
            const Divider(height: 20, color: AppColors.divider),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 16, color: AppColors.slate),
                    const SizedBox(width: 4),
                    Text(
                      '${batch.studentCount} student${batch.studentCount == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 13, color: AppColors.navyDark, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.slate),
                    const SizedBox(width: 4),
                    Text(
                      batch.feeTemplates.isNotEmpty
                          ? '${CurrencyFormatter.formatPaise(batch.standardBatchFeePaise)} / student'
                          : 'No fee setup yet',
                      style: const TextStyle(fontSize: 13, color: AppColors.navyDark, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            if (batch.totalFeePaise > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: collectedRatio,
                  backgroundColor: AppColors.divider,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.settledGreen),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Collected: ${CurrencyFormatter.formatPaise(batch.totalCollectedPaise)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.settledGreen, fontWeight: FontWeight.w600),
                  ),
                  if (batch.totalOutstandingPaise > 0)
                    Text(
                      'Pending: ${CurrencyFormatter.formatPaise(batch.totalOutstandingPaise)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.overdueRed, fontWeight: FontWeight.w600),
                    )
                  else
                    const Text(
                      'All Settled',
                      style: TextStyle(fontSize: 12, color: AppColors.settledGreen, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
