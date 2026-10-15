import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/batch.dart';
import '../../data/models/batch_fee_template.dart';
import '../../data/models/charge.dart';
import '../../data/models/payer.dart';
import '../controllers/vault_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/status_badge.dart';
import 'batch_fee_template_form_screen.dart';
import 'batch_form_screen.dart';
import 'payer_detail_screen.dart';
import 'payer_form_screen.dart';

/// Screen detailing a Batch: its standard fee installments, enrolled students,
/// and one-tap automated fee charging.
class BatchDetailScreen extends StatefulWidget {
  final String batchId;
  final VaultController controller;

  const BatchDetailScreen({
    super.key,
    required this.batchId,
    required this.controller,
  });

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Batch? _batch;
  List<Payer> _students = [];
  bool _isLoading = true;
  bool _isChargingAll = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBatch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBatch() async {
    setState(() => _isLoading = true);
    try {
      final b = await widget.controller.batchRepo.getBatchById(widget.batchId);
      final s = await widget.controller.batchRepo.getStudentsInBatch(
        widget.batchId,
      );
      if (mounted) {
        setState(() {
          _batch = b;
          _students = s;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _chargeAllStudents() async {
    if (_batch == null || _batch!.feeTemplates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add fee installments to this batch first.'),
          backgroundColor: AppColors.overdueRed,
        ),
      );
      return;
    }

    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No students are enrolled in this batch yet.'),
          backgroundColor: AppColors.overdueRed,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Charge All Enrolled Students?'),
        content: Text(
          'This will automatically apply the standard ${_batch!.feeTemplates.length} fee installment(s) '
          '(Total: ${CurrencyFormatter.formatPaise(_batch!.standardBatchFeePaise)}) '
          'to all ${_students.length} student(s) in "${_batch!.name}".\n\n'
          'Existing fee charges with the same title will not be duplicated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Confirm & Charge',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isChargingAll = true);
    try {
      final createdCount = await widget.controller.chargeBatchFeesToAllStudents(
        batchId: widget.batchId,
      );
      await _loadBatch();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              createdCount > 0
                  ? 'Successfully created $createdCount fee charge(s) across ${_students.length} student(s).'
                  : 'All students are already charged up to date.',
            ),
            backgroundColor: AppColors.settledGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.overdueRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChargingAll = false);
    }
  }

  Future<void> _deleteTemplate(BatchFeeTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fee Installment?'),
        content: Text(
          'Remove "${template.title}" from this batch\'s standard fee structure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.overdueRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.controller.deleteBatchFeeTemplate(template.id);
      await _loadBatch();
    }
  }

  Future<void> _deleteBatch() async {
    if (_batch == null) return;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Batch?'),
          content: Text(
            'Are you sure you want to delete batch "${_batch!.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.overdueRed,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await widget.controller.deleteBatch(_batch!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Batch "${_batch!.name}" deleted.'),
              backgroundColor: AppColors.settledGreen,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Action Blocked'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.brand)),
      );
    }

    if (_batch == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Batch Details')),
        body: const Center(child: Text('Batch not found')),
      );
    }

    final b = _batch!;

    return Scaffold(
      appBar: AppBar(
        title: Text(b.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Batch',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BatchFormScreen(
                    controller: widget.controller,
                    batchToEdit: b,
                  ),
                ),
              );
              await _loadBatch();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Batch',
            onPressed: _deleteBatch,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Batch Overview Header Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            b.academicYear,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                        Text(
                          '${_students.length} Student(s)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (b.notes != null && b.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        b.notes!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const Divider(height: 24, color: AppColors.divider),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _metricCol(
                          'Standard Fee',
                          CurrencyFormatter.formatPaise(
                            b.standardBatchFeePaise,
                          ),
                          AppColors.brand,
                        ),
                        _metricCol(
                          'Total Billed',
                          CurrencyFormatter.formatPaise(b.totalFeePaise),
                          AppColors.textPrimary,
                        ),
                        _metricCol(
                          'Collected',
                          CurrencyFormatter.formatPaise(b.totalCollectedPaise),
                          AppColors.settledGreen,
                        ),
                        _metricCol(
                          'Pending',
                          CurrencyFormatter.formatPaise(
                            b.totalOutstandingPaise,
                          ),
                          b.totalOutstandingPaise > 0
                              ? AppColors.overdueRed
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Tab Bar
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.brand,
                labelColor: AppColors.brand,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: [
                  Tab(
                    icon: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                    ),
                    text: 'Fee Structure (${b.feeTemplates.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.people_outline, size: 20),
                    text: 'Students (${_students.length})',
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Fee Structure
                  _buildFeeStructureTab(b),

                  // Tab 2: Enrolled Students
                  _buildStudentsTab(b),
                ],
              ),
            ),

            // Bottom Action Bar: One-tap Charge All Students
            if (b.feeTemplates.isNotEmpty && _students.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: ElevatedButton.icon(
                  onPressed: _isChargingAll ? null : _chargeAllStudents,
                  icon: _isChargingAll
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.bolt, color: Colors.white),
                  label: Text(
                    _isChargingAll
                        ? 'Charging Students...'
                        : '⚡ Charge All ${_students.length} Students',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metricCol(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFeeStructureTab(Batch b) {
    if (b.feeTemplates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.receipt_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'No Fee Installments Defined',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Define standard installments once (e.g. Admission Fee, Term 1 Tuition). Then charge all students with one tap.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final added = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BatchFeeTemplateFormScreen(
                        controller: widget.controller,
                        batchId: widget.batchId,
                      ),
                    ),
                  );
                  if (added == true) await _loadBatch();
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Add First Installment',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Standard Installments',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BatchFeeTemplateFormScreen(
                      controller: widget.controller,
                      batchId: widget.batchId,
                    ),
                  ),
                );
                if (added == true) await _loadBatch();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Installment'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...b.feeTemplates.map((template) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.brandLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.payment,
                      color: AppColors.brand,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (template.defaultDueDate != null)
                          Text(
                            'Due: ${CurrencyFormatter.formatDisplayDate(template.defaultDueDate!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatPaise(template.grossPaise),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => _deleteTemplate(template),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStudentsTab(Batch b) {
    if (_students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.school_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'No Students in this Batch',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enroll students into this batch to track their fees and payments.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PayerFormScreen(
                        controller: widget.controller,
                        initialBatch: b,
                      ),
                    ),
                  );
                  await _loadBatch();
                },
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: const Text(
                  'Enroll First Student',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_students.length} Enrolled Student(s)',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PayerFormScreen(
                      controller: widget.controller,
                      initialBatch: b,
                    ),
                  ),
                );
                await _loadBatch();
              },
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Enroll Student'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._students.map((student) {
          final isSettled =
              student.chargeCount > 0 && student.totalOutstandingPaise == 0;
          final isPending = student.totalOutstandingPaise > 0;
          final hasNoCharges = student.chargeCount == 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PayerDetailScreen(
                      payerId: student.id,
                      controller: widget.controller,
                    ),
                  ),
                );
                await _loadBatch();
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.brandLight,
                    child: Text(
                      student.name.isNotEmpty
                          ? student.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
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
                          student.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (student.phone != null)
                          Text(
                            '📞 ${student.phone}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          hasNoCharges
                              ? 'No fee charges yet'
                              : 'Paid: ${CurrencyFormatter.formatPaise(student.totalPaidPaise)} / ${CurrencyFormatter.formatPaise(student.totalNetPaise)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasNoCharges && b.feeTemplates.isNotEmpty)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brand,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: () async {
                        await widget.controller.chargeBatchFeesToStudent(
                          payerId: student.id,
                          batchId: b.id,
                        );
                        await _loadBatch();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Standard fees charged to ${student.name}.',
                              ),
                              backgroundColor: AppColors.settledGreen,
                            ),
                          );
                        }
                      },
                      child: const Text(
                        '⚡ Charge',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )
                  else if (isSettled)
                    StatusBadge.fromChargeStatus(ChargeStatus.settled)
                  else if (isPending)
                    StatusBadge(
                      label:
                          'Due ${CurrencyFormatter.formatPaise(student.totalOutstandingPaise)}',
                      textColor: AppColors.unpaidAmber,
                      backgroundColor: AppColors.unpaidAmberBg,
                      icon: Icons.schedule_outlined,
                    )
                  else
                    const StatusBadge(
                      label: 'Unassigned',
                      textColor: AppColors.textSecondary,
                      backgroundColor: AppColors.surfaceSubtle,
                      icon: Icons.info_outline,
                    ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
