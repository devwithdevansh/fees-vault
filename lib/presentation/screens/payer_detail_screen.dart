import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/batch.dart';
import '../../data/models/charge.dart';
import '../../data/models/payer.dart';
import '../controllers/vault_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/status_badge.dart';
import 'charge_detail_screen.dart';
import 'charge_form_screen.dart';
import 'payer_form_screen.dart';
import 'payment_form_screen.dart';

/// Screen detailing a student's profile, financial overview, and linked fee installments.
class PayerDetailScreen extends StatefulWidget {
  final String payerId;
  final VaultController controller;

  const PayerDetailScreen({
    super.key,
    required this.payerId,
    required this.controller,
  });

  @override
  State<PayerDetailScreen> createState() => _PayerDetailScreenState();
}

class _PayerDetailScreenState extends State<PayerDetailScreen> {
  Payer? _payer;
  Batch? _payerBatch;
  List<Charge> _charges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayerDetails();
  }

  Future<void> _loadPayerDetails() async {
    setState(() => _isLoading = true);
    try {
      final p = await widget.controller.payerRepo.getPayerById(widget.payerId);
      final charges = await widget.controller.chargeRepo.getChargesForPayer(widget.payerId);

      Batch? b;
      if (p?.batchId != null) {
        b = await widget.controller.batchRepo.getBatchById(p!.batchId!);
      } else if (p?.batch != null) {
        final matches = widget.controller.batches.where((batch) => batch.name == p!.batch);
        if (matches.isNotEmpty) {
          b = await widget.controller.batchRepo.getBatchById(matches.first.id);
        }
      }

      if (mounted) {
        setState(() {
          _payer = p;
          _payerBatch = b;
          _charges = charges;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (_payer == null) return;

    if (_charges.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Deletion Blocked'),
          content: Text(
            'Cannot delete ${_payer!.name} because ${_charges.length} fee installment(s) '
            'are recorded for this student. To preserve accounting integrity, you can archive this student instead.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTealDark),
              onPressed: () async {
                Navigator.pop(ctx);
                await widget.controller.archivePayer(_payer!.id, true);
                await _loadPayerDetails();
              },
              child: const Text('Archive Student', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student?'),
        content: Text('Are you sure you want to permanently delete ${_payer!.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.overdueRed)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.controller.deletePayer(_payer!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _applyBatchFees(Batch batch) async {
    final concessionCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Apply ${batch.name} Fees'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will charge standard batch fee installments '
              '(${CurrencyFormatter.formatPaise(batch.standardBatchFeePaise)}) to ${_payer!.name}.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: concessionCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Scholarship / Concession (Optional)',
                hintText: 'e.g. 2000',
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTealDark),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Charge Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      int concessionPaise = 0;
      if (concessionCtrl.text.trim().isNotEmpty) {
        final rupees = double.tryParse(concessionCtrl.text.trim()) ?? 0;
        concessionPaise = (rupees * 100).round();
      }

      await widget.controller.chargeBatchFeesToStudent(
        payerId: _payer!.id,
        batchId: batch.id,
        concessionPaise: concessionPaise,
      );
      await _loadPayerDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Standard fees successfully charged to ${_payer!.name}.'),
            backgroundColor: AppColors.settledGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_payer == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Student Not Found')),
        body: const Center(child: Text('This student record does not exist.')),
      );
    }

    final p = _payer!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          p.name,
          style: const TextStyle(
            color: AppColors.navyDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.slate),
            tooltip: 'Edit Student',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PayerFormScreen(
                    controller: widget.controller,
                    payerToEdit: p,
                  ),
                ),
              );
              await _loadPayerDetails();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.slate),
            onSelected: (val) async {
              if (val == 'archive') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(p.archived ? 'Unarchive Student?' : 'Archive Student?'),
                    content: Text(
                      p.archived
                          ? 'This student will return to the active student list.'
                          : 'Archiving hides the student from the active list, but preserves all fee records and outstanding dues in financial totals.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTealDark),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(p.archived ? 'Unarchive' : 'Archive', style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await widget.controller.archivePayer(p.id, !p.archived);
                  await _loadPayerDetails();
                }
              } else if (val == 'delete') {
                await _confirmDelete();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'archive',
                child: Text(p.archived ? 'Unarchive Student' : 'Archive Student'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Student', style: TextStyle(color: AppColors.overdueRed)),
              ),
            ],
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPayerDetails,
        color: AppColors.primaryTealDark,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Student Overview Card
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navyDark,
                          ),
                        ),
                      ),
                      if (p.archived) StatusBadge.archived(),
                    ],
                  ),
                  if (p.batch != null && p.batch!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.school_outlined, size: 16, color: AppColors.primaryTealDark),
                        const SizedBox(width: 8),
                        Text(
                          'Course / Batch: ${p.batch!}',
                          style: const TextStyle(fontSize: 13.5, color: AppColors.navyDark, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                  if (p.phone != null && p.phone!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 16, color: AppColors.slate),
                        const SizedBox(width: 8),
                        Text(
                          'Parent / Guardian: ${p.phone!}',
                          style: const TextStyle(fontSize: 13.5, color: AppColors.slate),
                        ),
                      ],
                    ),
                  ],
                  if (p.notes != null && p.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.notes!,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.slate),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Financial Balance Header
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Fees', style: TextStyle(color: AppColors.slate, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatPaise(p.totalNetPaise),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navyDark),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: AppColors.divider),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Paid', style: TextStyle(color: AppColors.slate, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatPaise(p.totalPaidPaise),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.settledGreen),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: AppColors.divider),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Outstanding', style: TextStyle(color: AppColors.slate, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatPaise(p.totalOutstandingPaise),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: p.totalOutstandingPaise > 0 ? AppColors.unpaidAmber : AppColors.settledGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Batch Quick Charge Action Card
            if (_payerBatch != null && _payerBatch!.feeTemplates.isNotEmpty) ...[
              () {
                final existingTitles = _charges.map((c) => c.title.toLowerCase()).toSet();
                final uncharged = _payerBatch!.feeTemplates
                    .where((t) => !existingTitles.contains(t.title.toLowerCase()))
                    .toList();
                if (uncharged.isEmpty) return const SizedBox.shrink();

                final unchargedTotal = uncharged.fold<int>(0, (sum, t) => sum + t.grossPaise);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AppCard(
                    backgroundColor: AppColors.primaryTealLight.withValues(alpha: 0.4),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt, color: AppColors.primaryTealDark, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Batch Fee Structure: ${_payerBatch!.name}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navyDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${uncharged.length} installment(s) available (${CurrencyFormatter.formatPaise(unchargedTotal)})',
                          style: const TextStyle(fontSize: 12, color: AppColors.slate),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryTealDark,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _applyBatchFees(_payerBatch!),
                          icon: const Icon(Icons.bolt, size: 16, color: Colors.white),
                          label: Text(
                            'Charge ${uncharged.length} Batch Installment(s)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }(),
            ],

            // Fee Installments Header & Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'FEE INSTALLMENTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate,
                    letterSpacing: 0.6,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChargeFormScreen(
                          controller: widget.controller,
                          initialPayerId: p.id,
                        ),
                      ),
                    );
                    await _loadPayerDetails();
                  },
                  icon: const Icon(Icons.add, size: 16, color: AppColors.primaryTealDark),
                  label: const Text(
                    'Add Fee Installment',
                    style: TextStyle(color: AppColors.primaryTealDark, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_charges.isEmpty)
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.request_quote_outlined, size: 36, color: AppColors.slate),
                      const SizedBox(height: 8),
                      const Text(
                        'No Fee Installments Yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add a course fee or installment with a due date to start recording payments.',
                        style: TextStyle(fontSize: 12, color: AppColors.slate),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChargeFormScreen(
                                controller: widget.controller,
                                initialPayerId: p.id,
                              ),
                            ),
                          );
                          await _loadPayerDetails();
                        },
                        icon: const Icon(Icons.add, size: 16, color: Colors.white),
                        label: const Text('Add Fee Installment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryTealDark,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._charges.map((ch) => _chargeItem(context, ch)),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _chargeItem(BuildContext context, Charge ch) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChargeDetailScreen(
                chargeId: ch.id,
                controller: widget.controller,
              ),
            ),
          );
          await _loadPayerDetails();
        },
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ch.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyDark,
                        ),
                      ),
                      if (ch.period != null && ch.period!.isNotEmpty)
                        Text(
                          'Academic Year: ${ch.period!}',
                          style: const TextStyle(fontSize: 12, color: AppColors.slate),
                        ),
                    ],
                  ),
                ),
                StatusBadge.fromChargeStatus(ch.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Due: ${CurrencyFormatter.formatDisplayDate(ch.dueDate)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate),
                ),
                Text(
                  ch.outstandingPaise == 0
                      ? 'Settled (${CurrencyFormatter.formatPaise(ch.netChargePaise)})'
                      : 'Due: ${CurrencyFormatter.formatPaise(ch.outstandingPaise)} / ${CurrencyFormatter.formatPaise(ch.netChargePaise)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: ch.outstandingPaise > 0 ? AppColors.unpaidAmber : AppColors.settledGreen,
                  ),
                ),
              ],
            ),
            if (ch.discountPaise > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Includes Concession: -${CurrencyFormatter.formatPaise(ch.discountPaise)}',
                style: const TextStyle(fontSize: 11, color: AppColors.slateLight),
              ),
            ],
            if (ch.outstandingPaise > 0) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentFormScreen(
                          controller: widget.controller,
                          targetChargeId: ch.id,
                          suggestedAmountPaise: ch.outstandingPaise,
                        ),
                      ),
                    );
                    await _loadPayerDetails();
                  },
                  icon: const Icon(Icons.payments_outlined, size: 16, color: AppColors.primaryTealDark),
                  label: const Text('Record Payment', style: TextStyle(color: AppColors.primaryTealDark, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryTealDark),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
