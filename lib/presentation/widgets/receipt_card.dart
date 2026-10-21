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
          // ── Gradient Receipt Header ────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              gradient: AppColors.headerGradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                if (payment.isEdited)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.red.shade300.withValues(alpha: 0.6),
                      ),
                    ),
                    child: const Text(
                      'CORRECTED RECEIPT — AUDITED ENTRY',
                      style: TextStyle(
                        color: Color(0xFFFFB3B3),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                Text(
                  businessName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'FEE PAYMENT RECEIPT',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Receipt #${payment.receiptNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
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
                _receiptRow(
                  'Student Name',
                  payment.payerName ?? 'N/A',
                  isBold: true,
                ),
                const SizedBox(height: 12),
                _receiptRow('Fee / Installment', payment.chargeTitle ?? 'N/A'),
                const SizedBox(height: 12),
                _receiptRow(
                  'Date Paid',
                  CurrencyFormatter.formatDisplayDate(payment.paidDate),
                ),
                const SizedBox(height: 12),
                _receiptRow('Method', payment.method),
                if (payment.reference != null &&
                    payment.reference!.isNotEmpty) ...[
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

                // ── Amount Paid Banner ────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.settledGreenBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.settledGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'AMOUNT PAID',
                        style: TextStyle(
                          color: AppColors.settledGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatPaise(payment.amountPaise),
                        style: const TextStyle(
                          color: AppColors.settledGreen,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
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
                            : CurrencyFormatter.formatPaise(
                                payment.remainingBalancePaise!,
                              ),
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
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      label: const Text(
                        'Edit Entry',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  if (onDelete != null)
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: AppColors.overdueRed,
                      ),
                      label: const Text(
                        'Delete Entry',
                        style: TextStyle(color: AppColors.overdueRed),
                      ),
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
            color: AppColors.textTertiary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
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
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
