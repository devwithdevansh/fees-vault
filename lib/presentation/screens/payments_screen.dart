import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/payment.dart';
import '../controllers/vault_controller.dart';
import 'payer_form_screen.dart';
import 'payment_detail_receipt_screen.dart';

/// Payments & Receipts screen — professional design with method filter chips,
/// gradient avatar tiles, and rich receipt cards.
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
  bool _isFetching = false;
  bool _needsReload = false;

  @override
  void initState() {
    super.initState();
    _loadPayments();
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) {
      _loadPayments(silent: true);
    }
  }

  @override
  void didUpdateWidget(covariant PaymentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  Future<void> _loadPayments({bool silent = false}) async {
    if (_isFetching) {
      _needsReload = true;
      return;
    }
    _isFetching = true;
    if (!silent && _payments.isEmpty) {
      setState(() => _isLoading = true);
    }
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
    } finally {
      _isFetching = false;
      if (_needsReload && mounted) {
        _needsReload = false;
        _loadPayments(silent: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasStudents = widget.controller.payers.isNotEmpty;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Receipts',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.6,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Fee payments & official receipts',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_payments.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.settledGreenBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_payments.length} ${_payments.length == 1 ? "receipt" : "receipts"}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.settledGreen,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // Method filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _MethodChip(
                        label: 'All',
                        selected: _selectedMethod == 'All',
                        onTap: () {
                          setState(() => _selectedMethod = 'All');
                          _loadPayments();
                        },
                      ),
                      ...AppConstants.paymentMethods.map((m) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _MethodChip(
                            label: m,
                            selected: _selectedMethod == m,
                            onTap: () {
                              setState(() => _selectedMethod = m);
                              _loadPayments();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // ── Payments List ─────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadPayments,
              color: AppColors.brand,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                        strokeWidth: 2,
                      ),
                    )
                  : _payments.isEmpty
                  ? _EmptyState(
                      method: _selectedMethod,
                      hasStudents: hasStudents,
                      onRegisterStudent: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PayerFormScreen(
                              controller: widget.controller,
                            ),
                          ),
                        );
                        await _loadPayments();
                      },
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      itemCount: _payments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _PaymentTile(pm: _payments[index], onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaymentDetailReceiptScreen(
                                  paymentId: _payments[index].id,
                                  controller: widget.controller,
                                ),
                              ),
                            );
                            await _loadPayments();
                          }),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Method filter chip — styled toggle button
// ─────────────────────────────────────────────────────────────────────────────
class _MethodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MethodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment receipt tile — gradient avatar, three-line info, amount badge
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentTile extends StatelessWidget {
  final Payment pm;
  final VoidCallback onTap;

  const _PaymentTile({required this.pm, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = pm.payerName ?? 'Student';
    final gradColors = AppColors.avatarGradientFor(name);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppColors.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Gradient avatar
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                                  fontSize: 10,
                                  color: AppColors.unpaidAmber,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pm.chargeTitle ?? 'Fee Payment',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
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
                            '· #${pm.receiptNumber} · ${CurrencyFormatter.formatDisplayDate(pm.paidDate)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.formatPaise(pm.amountPaise),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.settledGreen,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.settledGreenBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Paid',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.settledGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String method;
  final bool hasStudents;
  final VoidCallback onRegisterStudent;

  const _EmptyState({
    required this.method,
    required this.hasStudents,
    required this.onRegisterStudent,
  });

  @override
  Widget build(BuildContext context) {
    final isFiltered = method != 'All';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.settledGreenBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 36,
                color: AppColors.settledGreen,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isFiltered
                  ? 'No $method Receipts'
                  : 'No Receipts Issued Yet',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Try selecting "All" to view all issued receipts.'
                  : 'Fee payments collected from the Monthly Fees Register or Student Profiles will appear here automatically with downloadable receipts.',
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textTertiary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (!hasStudents && !isFiltered) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRegisterStudent,
                icon: const Icon(Icons.person_add_rounded, size: 17),
                label: const Text('Register First Student'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
