import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/payment.dart';

/// On-screen receipt representation.
/// Displays business header, monotonic receipt number, payer, charge,
/// payment method, timestamp, and remaining charge balance.
class ReceiptCard extends StatelessWidget {
  final Payment payment;
  final String businessName;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ReceiptCard({
    super.key,
    required this.payment,
    required this.businessName,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Receipt Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                if (payment.isEdited)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.unpaidAmberBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.unpaidAmber),
                    ),
                    child: const Text(
                      'CORRECTED RECEIPT (Audited Entry)',
                      style: TextStyle(
                        color: AppColors.unpaidAmber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Text(
                  businessName.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'FEE PAYMENT RECEIPT',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Receipt #${payment.receiptNumber}',
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Divider with notches/dashes
          const Divider(height: 1, thickness: 1, color: AppColors.divider),

          // Receipt Body Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _receiptRow('Student Name', payment.payerName ?? 'N/A', isBold: true),
                const SizedBox(height: 12),
                _receiptRow('Fee / Installment', payment.chargeTitle ?? 'N/A'),
                const SizedBox(height: 12),
                _receiptRow('Date Paid', CurrencyFormatter.formatDisplayDate(payment.paidDate)),
                const SizedBox(height: 12),
                _receiptRow('Method', payment.method),
                if (payment.reference != null && payment.reference!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _receiptRow('Reference / Txn ID', payment.reference!),
                ],
                if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _receiptRow('Notes', payment.notes!),
                ],

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: AppColors.divider),
                ),

                // Amount Paid Banner
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AMOUNT PAID',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatPaise(payment.amountPaise),
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Remaining Balance
                if (payment.remainingBalancePaise != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Remaining Due on Fee',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        payment.remainingBalancePaise == 0
                            ? 'Settled (₹0)'
                            : CurrencyFormatter.formatPaise(payment.remainingBalancePaise!),
                        style: TextStyle(
                          color: payment.remainingBalancePaise == 0
                              ? AppColors.settledGreen
                              : AppColors.overdueRed,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Actions Footer (Edit / Delete)
          if (onEdit != null || onDelete != null) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEdit != null)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                      label: const Text('Edit Entry', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  if (onDelete != null)
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.overdueRed),
                      label: const Text('Delete Entry', style: TextStyle(color: AppColors.overdueRed)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
