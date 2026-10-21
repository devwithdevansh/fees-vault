import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/batch.dart';
import '../../data/models/charge.dart';
import '../../data/models/payer.dart';
import '../controllers/vault_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/quick_collect_sheet.dart';
import '../widgets/status_badge.dart';
import 'batch_detail_screen.dart';
import 'charge_detail_screen.dart';
import 'payer_form_screen.dart';

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
      final charges = await widget.controller.chargeRepo.getChargesForPayer(
        widget.payerId,
      );

      Batch? b;
      if (p?.batchId != null) {
        b = await widget.controller.batchRepo.getBatchById(p!.batchId!);
      } else if (p?.batch != null) {
        final matches = widget.controller.batches.where(
          (batch) => batch.name == p!.batch,
        );
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

  Future<void> _applyBatchFeeSchedule() async {
    if (_payer == null || _payerBatch == null) return;
    if (_payerBatch!.feeTemplates.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final created = await widget.controller.batchRepo.chargeBatchFeesToStudent(
        payerId: _payer!.id,
        batchId: _payerBatch!.id,
        concessionPaise: 0,
      );
      await widget.controller.refreshAll();
      await _loadPayerDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Applied ${created.length} fee installment(s) from ${_payerBatch!.name}!',
            ),
            backgroundColor: AppColors.settledGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying batch fees: $e'),
            backgroundColor: AppColors.overdueRed,
          ),
        );
      }
    } finally {
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
              onPressed: () async {
                Navigator.pop(ctx);
                await widget.controller.archivePayer(_payer!.id, true);
                await _loadPayerDetails();
              },
              child: const Text(
                'Archive Student',
                style: TextStyle(color: Colors.white),
              ),
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
        content: Text(
          'Are you sure you want to permanently delete ${_payer!.name}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.overdueRed),
            ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Charge Now',
              style: TextStyle(color: Colors.white),
            ),
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
            content: Text(
              'Standard fees successfully charged to ${_payer!.name}.',
            ),
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
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.textSecondary,
            ),
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
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onSelected: (val) async {
              if (val == 'archive') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(
                      p.archived ? 'Unarchive Student?' : 'Archive Student?',
                    ),
                    content: Text(
                      p.archived
                          ? 'This student will return to the active student list.'
                          : 'Archiving hides the student from the active list, but preserves all fee records and outstanding dues in financial totals.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          p.archived ? 'Unarchive' : 'Archive',
                          style: const TextStyle(color: Colors.white),
                        ),
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
                child: Text(
                  p.archived ? 'Unarchive Student' : 'Archive Student',
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete Student',
                  style: TextStyle(color: AppColors.overdueRed),
                ),
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
        color: AppColors.brand,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          // ── Student Hero Profile Card ─────────────────────────────
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.elevatedShadow,
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Large gradient avatar
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      p.name.isNotEmpty
                          ? p.name
                              .trim()
                              .split(' ')
                              .map((w) => w[0])
                              .take(2)
                              .join()
                              .toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (p.archived) ...[
                              const SizedBox(width: 8),
                              StatusBadge.archived(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (p.batch != null && p.batch!.isNotEmpty) ...[
                          _HeroPill(
                            icon: Icons.school_rounded,
                            label: p.batch!,
                          ),
                          const SizedBox(height: 5),
                        ],
                        if (p.phone != null && p.phone!.isNotEmpty) ...[
                          _HeroPill(
                            icon: Icons.phone_outlined,
                            label: p.phone!,
                          ),
                        ],
                        if (p.notes != null && p.notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            p.notes!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Financial Balance Card ───────────────────────────────
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.divider),
                boxShadow: AppColors.cardShadow,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _FinancialMetric(
                      label: 'Total Fees',
                      value: CurrencyFormatter.formatPaise(p.totalNetPaise),
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.divider,
                  ),
                  Expanded(
                    child: _FinancialMetric(
                      label: 'Paid',
                      value: CurrencyFormatter.formatPaise(p.totalPaidPaise),
                      color: AppColors.settledGreen,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.divider,
                  ),
                  Expanded(
                    child: _FinancialMetric(
                      label: 'Outstanding',
                      value: CurrencyFormatter.formatPaise(
                        p.totalOutstandingPaise,
                      ),
                      color: p.totalOutstandingPaise > 0
                          ? AppColors.unpaidAmber
                          : AppColors.settledGreen,
                    ),
                  ),
                ],
              ),
            ),

            // Batch Quick Charge Action Card
            if (_payerBatch != null &&
                _payerBatch!.feeTemplates.isNotEmpty) ...[
              () {
                final existingTitles = _charges
                    .map((c) => c.title.toLowerCase())
                    .toSet();
                final uncharged = _payerBatch!.feeTemplates
                    .where(
                      (t) => !existingTitles.contains(t.title.toLowerCase()),
                    )
                    .toList();
                if (uncharged.isEmpty) return const SizedBox.shrink();

                final unchargedTotal = uncharged.fold<int>(
                  0,
                  (sum, t) => sum + t.grossPaise,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AppCard(
                    backgroundColor: AppColors.brandLight.withValues(
                      alpha: 0.4,
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.bolt,
                              color: AppColors.brand,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Batch Fee Structure: ${_payerBatch!.name}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${uncharged.length} installment(s) available (${CurrencyFormatter.formatPaise(unchargedTotal)})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _applyBatchFees(_payerBatch!),
                          icon: const Icon(
                            Icons.bolt,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Charge ${uncharged.length} Batch Installment(s)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
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
                    color: AppColors.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
                if (_payerBatch != null &&
                    _payerBatch!.feeTemplates.isNotEmpty &&
                    _charges.length < _payerBatch!.feeTemplates.length)
                  TextButton.icon(
                    onPressed: _applyBatchFeeSchedule,
                    icon: const Icon(Icons.sync, size: 16, color: AppColors.brand),
                    label: const Text(
                      'Apply Batch Fees',
                      style: TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_charges.isEmpty)
              AppCard(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        _payerBatch != null &&
                                _payerBatch!.feeTemplates.isNotEmpty
                            ? Icons.calendar_month_outlined
                            : Icons.school_outlined,
                        size: 38,
                        color: AppColors.brand,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _payerBatch != null &&
                                _payerBatch!.feeTemplates.isNotEmpty
                            ? 'Batch Fee Schedule Available'
                            : (_payerBatch != null
                                ? 'No Fee Schedule for ${_payerBatch!.name}'
                                : 'No Batch Assigned'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _payerBatch != null &&
                                _payerBatch!.feeTemplates.isNotEmpty
                            ? '${_payerBatch!.feeTemplates.length} monthly fee installments are ready to be applied from ${_payerBatch!.name}.'
                            : (_payerBatch != null
                                ? 'Fees are managed at the Batch level. Go to "${_payerBatch!.name}" to generate the monthly tuition schedule.'
                                : 'Assign this student to a Batch (Class) to automatically apply monthly tuition fees.'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (_payerBatch != null &&
                          _payerBatch!.feeTemplates.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: _applyBatchFeeSchedule,
                          icon: const Icon(Icons.bolt,
                              size: 18, color: Colors.white),
                          label: Text(
                            'Apply ${_payerBatch!.name} Fees (${_payerBatch!.feeTemplates.length} Mos)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        )
                      else if (_payerBatch != null)
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BatchDetailScreen(
                                  batchId: _payerBatch!.id,
                                  controller: widget.controller,
                                ),
                              ),
                            );
                            await _loadPayerDetails();
                          },
                          icon: const Icon(Icons.arrow_forward,
                              size: 16, color: Colors.white),
                          label: Text(
                            'Go to ${_payerBatch!.name}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        )
                      else
                        ElevatedButton.icon(
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
                          icon: const Icon(Icons.edit,
                              size: 16, color: Colors.white),
                          label: const Text(
                            'Assign to Batch',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
    final statusColor = _statusColor(ch.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
              boxShadow: AppColors.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left status bar
                    Container(
                      width: 4,
                      color: statusColor,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    ch.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                StatusBadge.fromChargeStatus(ch.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (ch.period != null && ch.period!.isNotEmpty)
                                  Expanded(
                                    child: Text(
                                      'AY ${ch.period!}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  )
                                else
                                  const Spacer(),
                                Text(
                                  'Due ${CurrencyFormatter.formatDisplayDate(ch.dueDate)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Amount display
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (ch.discountPaise > 0)
                                      Text(
                                        '-${CurrencyFormatter.formatPaise(ch.discountPaise)} concession',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    Text(
                                      ch.outstandingPaise == 0
                                          ? 'Settled · ${CurrencyFormatter.formatPaise(ch.netChargePaise)}'
                                          : '${CurrencyFormatter.formatPaise(ch.outstandingPaise)} due of ${CurrencyFormatter.formatPaise(ch.netChargePaise)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: statusColor,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                                // Record Payment CTA
                                if (ch.outstandingPaise > 0)
                                  GestureDetector(
                                    onTap: () async {
                                      await QuickCollectSheet.show(
                                        context: context,
                                        controller: widget.controller,
                                        charge: ch,
                                        onPaymentRecorded: _loadPayerDetails,
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.brandGradient,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        boxShadow: AppColors.brandGlow,
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.bolt_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Collect',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(ChargeStatus s) {
    switch (s) {
      case ChargeStatus.settled:
        return AppColors.settledGreen;
      case ChargeStatus.overdue:
        return AppColors.overdueRed;
      case ChargeStatus.partial:
        return AppColors.partialBlue;
      case ChargeStatus.unpaid:
        return AppColors.unpaidAmber;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancialMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _FinancialMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
