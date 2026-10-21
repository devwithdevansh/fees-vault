import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/charge.dart';
import '../controllers/vault_controller.dart';

/// Universal 3-second Quick Collect Bottom Sheet for Indian tuition fee collection.
/// Eliminates the need for standalone multi-step payment forms and 200-item charge dropdowns.
/// Pre-fills student name, fee title, and remaining balance.
class QuickCollectSheet {
  static Future<bool?> show({
    required BuildContext context,
    required VaultController controller,
    required Charge charge,
    VoidCallback? onPaymentRecorded,
  }) async {
    final amountController = TextEditingController(
      text: CurrencyFormatter.paiseToEditableString(charge.outstandingPaise),
    );
    final refController = TextEditingController();
    String selectedMethod = 'UPI';
    bool isSaving = false;

    final recorded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Row with Student Info
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.settledGreenBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: AppColors.settledGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          charge.payerName ?? 'Student',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          charge.title,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx, false),
                    color: AppColors.textMuted,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 16),

              // Amount Field
              TextFormField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount to Collect',
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                  helperText:
                      'Outstanding due: ${CurrencyFormatter.formatPaise(charge.outstandingPaise)}',
                  helperStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.brand, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Payment Method Chips (UPI, Cash, Bank Transfer, Other)
              const Text(
                'Payment Mode',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: AppConstants.paymentMethods.map((method) {
                  final isSel = selectedMethod == method;
                  return ChoiceChip(
                    label: Text(method),
                    selected: isSel,
                    selectedColor: AppColors.brand,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                    onSelected: (_) =>
                        setModalState(() => selectedMethod = method),
                    backgroundColor: AppColors.surfaceSubtle,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSel ? AppColors.brand : AppColors.divider,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),

              // Optional Reference / Note
              TextFormField(
                controller: refController,
                decoration: InputDecoration(
                  labelText: 'Reference / Note (Optional)',
                  hintText: selectedMethod == 'UPI'
                      ? 'e.g. UPI Ref / GPay-1049'
                      : 'e.g. Cash voucher #42',
                  filled: true,
                  fillColor: AppColors.surfaceSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppColors.brandGlow,
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final rawText = amountController.text.trim();
                            if (rawText.isEmpty) return;

                            int paise;
                            try {
                              paise = CurrencyFormatter.parseToPaise(rawText);
                            } catch (e) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                              return;
                            }

                            if (paise > charge.outstandingPaise) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Amount cannot exceed outstanding dues.',
                                  ),
                                  backgroundColor: AppColors.overdueRed,
                                ),
                              );
                              return;
                            }

                            setModalState(() => isSaving = true);
                            try {
                              final today =
                                  CurrencyFormatter.toYmd(DateTime.now());
                              await controller.recordPayment(
                                chargeId: charge.id,
                                amountPaise: paise,
                                paidDate: today,
                                method: selectedMethod,
                                reference: refController.text.trim().isEmpty
                                    ? null
                                    : refController.text.trim(),
                              );
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (e) {
                              setModalState(() => isSaving = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString()),
                                    backgroundColor: AppColors.overdueRed,
                                  ),
                                );
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Record Payment & Issue Receipt',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (recorded == true) {
      if (onPaymentRecorded != null) onPaymentRecorded();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.settledGreen,
            content: Text(
              '✓ Payment recorded and receipt issued for ${charge.payerName ?? "Student"}!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    return recorded;
  }
}
