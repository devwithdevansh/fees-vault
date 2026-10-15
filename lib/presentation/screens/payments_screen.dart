import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/payment.dart';
import '../controllers/vault_controller.dart';
import '../widgets/app_card.dart';
import 'payer_form_screen.dart';
import 'payment_detail_receipt_screen.dart';
import 'payment_form_screen.dart';

/// Payments & Receipts management screen featuring method filters,
/// verifiable receipts, and correction indicators.
class PaymentsScreen extends StatefulWidget {
  final VaultController controller;

  const PaymentsScreen({super.key, required this.controller});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _selectedMethod = 'All';
  List<Payment> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.controller.paymentRepo.getPayments(
        method: _selectedMethod == 'All' ? null : _selectedMethod,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _payments = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasStudents = widget.controller.payers.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Receipts & Payments',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (!hasStudents) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please register a student first.')),
            );
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PayerFormScreen(controller: widget.controller),
              ),
            );
            return;
          }
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentFormScreen(controller: widget.controller),
            ),
          );
          await _loadPayments();
        },
        backgroundColor: AppColors.brand,
        icon: const Icon(Icons.add, color: Colors.white, size: 20),
        label: const Text(
          'Record Payment',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      body: Column(
        children: [
          // Method Filter Chips Bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All'),
                  const SizedBox(width: 8),
                  ...AppConstants.paymentMethods.map((m) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _filterChip(m),
                    );
                  }),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // Payments & Receipts List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadPayments,
              color: AppColors.brand,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _payments.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedMethod == 'All'
                                  ? 'No Fee Payments Recorded'
                                  : 'No payments found for $_selectedMethod.',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _selectedMethod == 'All'
                                  ? 'Record fee payments received via Cash, UPI, or Bank Transfer to generate official receipts.'
                                  : 'Try selecting "All" to view all payment receipts.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_selectedMethod == 'All') ...[
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  if (!hasStudents) {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PayerFormScreen(
                                          controller: widget.controller,
                                        ),
                                      ),
                                    );
                                  } else {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PaymentFormScreen(
                                          controller: widget.controller,
                                        ),
                                      ),
                                    );
                                  }
                                  await _loadPayments();
                                },
                                icon: const Icon(
                                  Icons.payments_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                label: Text(
                                  hasStudents
                                      ? 'Record First Payment'
                                      : 'Register Student First',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brand,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: 80,
                      ),
                      itemCount: _payments.length,
                      itemBuilder: (context, index) {
                        final pm = _payments[index];
                        return _paymentItem(context, pm);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    final isSelected = _selectedMethod == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.brandLight,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.brand : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      onSelected: (_) {
        setState(() => _selectedMethod = label);
        _loadPayments();
      },
    );
  }

  Widget _paymentItem(BuildContext context, Payment pm) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
          await _loadPayments();
        },
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.settledGreenBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: AppColors.settledGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          pm.payerName ?? 'Student',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (pm.isEdited) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.unpaidAmberBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Edited',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.unpaidAmber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pm.chargeTitle ?? "Fee"} • Receipt #${pm.receiptNumber}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pm.method} • ${CurrencyFormatter.formatDisplayDate(pm.paidDate)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatPaise(pm.amountPaise),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.settledGreen,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Paid',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.settledGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
