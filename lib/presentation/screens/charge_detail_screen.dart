import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/charge.dart';
import '../../data/models/payment.dart';
import '../controllers/vault_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/quick_collect_sheet.dart';
import '../widgets/status_badge.dart';
import 'charge_form_screen.dart';
import 'payment_detail_receipt_screen.dart';

/// Screen displaying fee installment details, financial breakdown, and linked payments.
class ChargeDetailScreen extends StatefulWidget {
  final String chargeId;
  final VaultController controller;

  const ChargeDetailScreen({
    super.key,
    required this.chargeId,
    required this.controller,
  });

  @override
  State<ChargeDetailScreen> createState() => _ChargeDetailScreenState();
}

class _ChargeDetailScreenState extends State<ChargeDetailScreen> {
  Charge? _charge;
  List<Payment> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final ch = await widget.controller.chargeRepo.getChargeById(
        widget.chargeId,
      );
      final payments = await widget.controller.paymentRepo.getPaymentsForCharge(
        widget.chargeId,
      );

      if (mounted) {
        setState(() {
          _charge = ch;
          _payments = payments;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (_charge == null) return;

    if (_payments.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Deletion Blocked'),
          content: Text(
            'Cannot delete this fee installment because ${_payments.length} payment receipt(s) '
            'are associated with it. To protect accounting integrity, you must first void '
            'or delete the payment entries with documented correction reasons.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fee Installment?'),
        content: Text(
          'Are you sure you want to delete "${_charge!.title}"? This cannot be undone.',
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
      await widget.controller.deleteCharge(_charge!.id);
      if (mounted) Navigator.pop(context);
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

    if (_charge == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Fee Record Not Found')),
        body: const Center(child: Text('This fee installment does not exist.')),
      );
    }

    final ch = _charge!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          ch.title,
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
            tooltip: 'Edit Fee Installment',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChargeFormScreen(
                    controller: widget.controller,
                    chargeToEdit: ch,
                  ),
                ),
              );
              await _loadDetails();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.overdueRed),
            tooltip: 'Delete Fee Installment',
            onPressed: _confirmDelete,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadDetails,
          color: AppColors.brand,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
            children: [
            // ── Hero Header Card ───────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.elevatedShadow,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ch.payerName ?? 'Student',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ch.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      StatusBadge.fromChargeStatus(ch.status),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(
                    color: Colors.white24,
                    height: 1,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (ch.period != null && ch.period!.isNotEmpty) ...[  
                        _HeroChip(
                          icon: Icons.calendar_today_rounded,
                          label: ch.period!,
                        ),
                        const SizedBox(width: 8),
                      ],
                      _HeroChip(
                        icon: ch.isOverdue
                            ? Icons.warning_rounded
                            : Icons.event_rounded,
                        label: 'Due ${CurrencyFormatter.formatDisplayDate(ch.dueDate)}',
                        isWarning: ch.isOverdue,
                      ),
                    ],
                  ),
                  if (ch.notes != null && ch.notes!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      ch.notes!,
                      style: TextStyle(
                        fontSize: 12.5,
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
            const SizedBox(height: 14),

            // ── Financial Breakdown Card ─────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.divider),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.brandLight,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.receipt_rounded,
                            size: 15,
                            color: AppColors.brand,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'FINANCIAL BREAKDOWN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _breakdownRow(
                    'Gross Course Fee',
                    CurrencyFormatter.formatPaise(ch.grossPaise),
                  ),
                  if (ch.discountPaise > 0) ...[
                    const Divider(
                      height: 1,
                      color: AppColors.divider,
                      indent: 16,
                      endIndent: 16,
                    ),
                    _breakdownRow(
                      'Concession / Scholarship',
                      '- ${CurrencyFormatter.formatPaise(ch.discountPaise)}',
                      valueColor: AppColors.settledGreen,
                    ),
                  ],
                  const Divider(
                    height: 1,
                    color: AppColors.divider,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _breakdownRow(
                    'Net Fee Payable',
                    CurrencyFormatter.formatPaise(ch.netChargePaise),
                    isBold: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Divider(
                      height: 1,
                      color: AppColors.divider,
                      thickness: 2,
                    ),
                  ),
                  _breakdownRow(
                    'Total Collected',
                    CurrencyFormatter.formatPaise(ch.paidPaise),
                    valueColor: AppColors.settledGreen,
                  ),
                  const Divider(
                    height: 1,
                    color: AppColors.divider,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _breakdownRow(
                    'Remaining Dues',
                    ch.outstandingPaise == 0
                        ? 'Settled (₹0)'
                        : CurrencyFormatter.formatPaise(ch.outstandingPaise),
                    isBold: true,
                    valueColor: ch.outstandingPaise > 0
                        ? AppColors.overdueRed
                        : AppColors.settledGreen,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Quick Payment CTA ─────────────────────────────────────
            if (ch.outstandingPaise > 0)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await QuickCollectSheet.show(
                      context: context,
                      controller: widget.controller,
                      charge: ch,
                      onPaymentRecorded: _loadDetails,
                    );
                  },
                  icon: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: Text(
                    '⚡ Collect Fee  ·  ${CurrencyFormatter.formatPaise(ch.outstandingPaise)} Due',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    shadowColor: AppColors.brand.withValues(alpha: 0.4),
                    elevation: 6,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Payment Receipts History
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PAYMENT RECEIPTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  '${_payments.length} receipt(s)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_payments.isEmpty)
              const AppCard(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No payments recorded against this fee installment yet.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              ..._payments.map((pm) => _paymentHistoryItem(context, pm)),

            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
  }

  Widget _breakdownRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 15.5 : 13.5,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentHistoryItem(BuildContext context, Payment pm) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentDetailReceiptScreen(
                  paymentId: pm.id,
                  controller: widget.controller,
                ),
              ),
            );
            await _loadDetails();
          },
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
              boxShadow: AppColors.cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.settledGreenBg,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.settledGreen,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Receipt #${pm.receiptNumber}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (pm.isEdited) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.unpaidAmberBg,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  'Edited',
                                  style: TextStyle(
                                    color: AppColors.unpaidAmber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                pm.method,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              CurrencyFormatter.formatDisplayDate(pm.paidDate),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatPaise(pm.amountPaise),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.settledGreen,
                      letterSpacing: -0.2,
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
// Hero chip widget
// ─────────────────────────────────────────────────────────────────────────────
class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isWarning;

  const _HeroChip({
    required this.icon,
    required this.label,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isWarning
            ? Colors.red.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: isWarning
            ? Border.all(color: Colors.red.shade300.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isWarning ? Colors.red.shade200 : Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isWarning ? Colors.red.shade200 : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
