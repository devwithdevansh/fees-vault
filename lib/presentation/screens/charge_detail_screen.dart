import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/charge.dart';
import '../../data/models/payment.dart';
import '../controllers/vault_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/status_badge.dart';
import 'charge_form_screen.dart';
import 'payment_detail_receipt_screen.dart';
import 'payment_form_screen.dart';

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
      body: RefreshIndicator(
        onRefresh: _loadDetails,
        color: AppColors.brand,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Student & Fee Header Card
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
                          ch.payerName ?? 'Student',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      StatusBadge.fromChargeStatus(ch.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ch.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brand,
                    ),
                  ),
                  if (ch.period != null && ch.period!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Academic Year: ${ch.period!}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Due Date: ${CurrencyFormatter.formatDisplayDate(ch.dueDate)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: ch.isOverdue
                          ? AppColors.overdueRed
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (ch.notes != null && ch.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ch.notes!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Financial Breakdown Card
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FINANCIAL BREAKDOWN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _breakdownRow(
                    'Gross Course Fee',
                    CurrencyFormatter.formatPaise(ch.grossPaise),
                  ),
                  if (ch.discountPaise > 0) ...[
                    const SizedBox(height: 8),
                    _breakdownRow(
                      'Concession / Scholarship',
                      '- ${CurrencyFormatter.formatPaise(ch.discountPaise)}',
                      valueColor: AppColors.settledGreen,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _breakdownRow(
                    'Net Fee Payable',
                    CurrencyFormatter.formatPaise(ch.netChargePaise),
                    isBold: true,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(color: AppColors.divider),
                  ),
                  _breakdownRow(
                    'Total Collected',
                    CurrencyFormatter.formatPaise(ch.paidPaise),
                  ),
                  const SizedBox(height: 8),
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
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Payment Action
            if (ch.outstandingPaise > 0)
              ElevatedButton.icon(
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
                  await _loadDetails();
                },
                icon: const Icon(Icons.payments_outlined, color: Colors.white),
                label: Text(
                  'Record Payment (${CurrencyFormatter.formatPaise(ch.outstandingPaise)} Due)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
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
    );
  }

  Widget _breakdownRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color:
                valueColor ??
                (isBold ? AppColors.textPrimary : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _paymentHistoryItem(BuildContext context, Payment pm) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.settledGreenBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: AppColors.settledGreen,
                size: 20,
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
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (pm.isEdited) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.unpaidAmberBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Edited',
                            style: TextStyle(
                              color: AppColors.unpaidAmber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pm.method} • ${CurrencyFormatter.formatDisplayDate(pm.paidDate)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.formatPaise(pm.amountPaise),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.settledGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
