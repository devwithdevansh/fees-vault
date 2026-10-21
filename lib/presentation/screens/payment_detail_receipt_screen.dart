import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/audit_event.dart';
import '../../data/models/payment.dart';
import '../controllers/vault_controller.dart';
import '../widgets/receipt_card.dart';
import 'payment_form_screen.dart';

/// Screen displaying the on-screen receipt and audit correction history.
class PaymentDetailReceiptScreen extends StatefulWidget {
  final String paymentId;
  final VaultController controller;

  const PaymentDetailReceiptScreen({
    super.key,
    required this.paymentId,
    required this.controller,
  });

  @override
  State<PaymentDetailReceiptScreen> createState() =>
      _PaymentDetailReceiptScreenState();
}

class _PaymentDetailReceiptScreenState
    extends State<PaymentDetailReceiptScreen> {
  Payment? _payment;
  List<AuditEvent> _auditEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final pm = await widget.controller.paymentRepo.getPaymentById(
        widget.paymentId,
      );
      final history = await widget.controller.auditRepo
          .getAuditHistoryForEntity(widget.paymentId);

      if (mounted) {
        setState(() {
          _payment = pm;
          _auditEvents = history;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (_payment == null) return;

    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment Entry?'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deleting Receipt #${_payment!.receiptNumber} will restore '
                '${CurrencyFormatter.formatPaise(_payment!.amountPaise)} to the outstanding dues. '
                'This action is permanently recorded in the local audit history.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: reasonController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Correction Reason *',
                  hintText: 'e.g. Mistyped amount, duplicate check',
                  filled: true,
                  fillColor: AppColors.surfaceSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter a reason'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.overdueRed,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text(
              'Delete Entry',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final receiptNum = _payment!.receiptNumber;
        final restoredAmount = CurrencyFormatter.formatPaise(
          _payment!.amountPaise,
        );
        await widget.controller.deletePayment(
          paymentId: _payment!.id,
          correctionReason: reasonController.text.trim(),
        );

        HapticFeedback.mediumImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Receipt #$receiptNum voided. $restoredAmount restored to fee balance.',
              ),
              backgroundColor: AppColors.textPrimary,
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.pop(context);
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

    if (_payment == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Receipt Unavailable')),
        body: const Center(
          child: Text(
            'This payment record has been deleted or does not exist.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final pm = _payment!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#${pm.receiptNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Receipt',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetails,
        color: AppColors.brand,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ReceiptCard(
              payment: pm,
              businessName: widget.controller.businessName,
              onEdit: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentFormScreen(
                      controller: widget.controller,
                      paymentToEdit: pm,
                    ),
                  ),
                );
                await _loadDetails();
              },
              onDelete: _confirmDelete,
            ),
            const SizedBox(height: 24),

            // ── Audit Correction Trail ───────────────────────────────
            if (_auditEvents.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.unpaidAmberBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        size: 14,
                        color: AppColors.unpaidAmber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'LOCAL CORRECTION HISTORY',
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
              ..._auditEvents.map((ev) {
                final dt =
                    DateTime.fromMillisecondsSinceEpoch(ev.timestamp);
                final formattedTime =
                    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 4,
                            color: AppColors.unpaidAmber,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.brandLight,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          ev.action.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.brand,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        formattedTime,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (ev.reason != null &&
                                      ev.reason!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      ev.reason!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
