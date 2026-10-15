import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/charge.dart';
import '../../data/models/payment.dart';
import '../controllers/vault_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/status_badge.dart';
import 'batch_form_screen.dart';
import 'charge_detail_screen.dart';
import 'charge_form_screen.dart';
import 'payer_form_screen.dart';
import 'payment_detail_receipt_screen.dart';
import 'payment_form_screen.dart';
import 'walkthrough_screen.dart';

/// FeesVault Academy Dashboard displaying independently aggregated financial totals,
/// overdue installment alerts, recent receipts, and primary academy actions.
class DashboardScreen extends StatelessWidget {
  final VaultController controller;

  const DashboardScreen({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final s = controller.summary;
    final hasStudents = controller.payers.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.businessName,
              style: const TextStyle(
                color: AppColors.navyDark,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Text(
              'Academy Fee Vault • Offline & Encrypted',
              style: TextStyle(
                color: AppColors.slate,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppColors.primaryTealDark),
            tooltip: 'Academy Workflow Guide',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AcademyWalkthroughScreen(),
                ),
              );
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.refreshAll(),
        color: AppColors.primaryTealDark,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Quick Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: _quickActionButton(
                    icon: Icons.groups_outlined,
                    label: 'New Batch',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BatchFormScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _quickActionButton(
                    icon: Icons.person_add_alt_1_outlined,
                    label: 'Add Student',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PayerFormScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _quickActionButton(
                    icon: Icons.request_quote_outlined,
                    label: 'Custom Fee',
                    onTap: () async {
                      if (!hasStudents) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please register a student before creating a fee installment.'),
                            backgroundColor: AppColors.primaryTealDark,
                          ),
                        );
                        return;
                      }
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChargeFormScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _quickActionButton(
                    icon: Icons.payments_outlined,
                    label: 'Payment',
                    isPrimary: true,
                    onTap: () async {
                      if (!hasStudents) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Register a student and fee installment before recording payments.'),
                            backgroundColor: AppColors.primaryTealDark,
                          ),
                        );
                        return;
                      }
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentFormScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // First-run Academy Guidance Banner if no students exist
            if (!hasStudents) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryTealLight),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryTealDark.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTealLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.school_outlined,
                            color: AppColors.primaryTealDark,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome to FeesVault Academy',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navyDark,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Get started in 3 simple steps',
                                style: TextStyle(fontSize: 12, color: AppColors.slate),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '1. Create a Batch (e.g. Class 10) with standard fees.\n'
                      '2. Enroll students with parent contact and assign to batch.\n'
                      '3. Automatically charge fees and record receipts.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.navyDark,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PayerFormScreen(controller: controller),
                                ),
                              );
                            },
                            icon: const Icon(Icons.person_add_alt_1_outlined, size: 16, color: Colors.white),
                            label: const Text('Add First Student', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryTealDark,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AcademyWalkthroughScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.divider),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('View Guide', style: TextStyle(color: AppColors.navyDark, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Section: All-Time Financial Overview
            const Text(
              'ALL-TIME ACADEMY OVERVIEW',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.slate,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),

            // Metric Cards Grid
            Row(
              children: [
                Expanded(
                  child: _metricCard(
                    context: context,
                    title: 'Total Fees Raised',
                    amountPaise: s.totalNetFeesPaise,
                    color: AppColors.navyDark,
                    subtitle: '${s.totalChargesCount} installments assigned',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    context: context,
                    title: 'Total Collected',
                    amountPaise: s.totalCollectedPaise,
                    color: AppColors.settledGreen,
                    subtitle: 'Paid into academy vault',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _metricCard(
                    context: context,
                    title: 'Outstanding Dues',
                    amountPaise: s.totalOutstandingPaise,
                    color: s.totalOutstandingPaise > 0 ? AppColors.unpaidAmber : AppColors.slate,
                    subtitle: 'Pending collection',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    context: context,
                    title: 'Overdue Fees',
                    amountPaise: s.totalOverduePaise,
                    color: s.totalOverduePaise > 0 ? AppColors.overdueRed : AppColors.slate,
                    subtitle: '${s.overdueChargesCount} overdue installments',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section: Current Month Breakdown
            const Text(
              'THIS MONTH BREAKDOWN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.slate,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fees Due This Month', style: TextStyle(color: AppColors.slate, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.formatPaise(s.monthNetFeesPaise),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navyDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.divider),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Collected This Month', style: TextStyle(color: AppColors.slate, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.formatPaise(s.monthCollectedPaise),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.settledGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section: Overdue Installments
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'OVERDUE INSTALLMENTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate,
                    letterSpacing: 0.6,
                  ),
                ),
                if (controller.overdueCharges.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.overdueRedBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${controller.overdueCharges.length} overdue',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.overdueRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (controller.overdueCharges.isEmpty)
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppColors.settledGreen.withValues(alpha: 0.8), size: 36),
                      const SizedBox(height: 8),
                      const Text(
                        'No Overdue Installments',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'All student fees are up to date or upcoming.',
                        style: TextStyle(fontSize: 12, color: AppColors.slate),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...controller.overdueCharges.map((ch) => _overdueChargeTile(context, ch)),

            const SizedBox(height: 24),

            // Section: Recent Receipts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RECENT RECEIPTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.slate,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  '${controller.recentPayments.length} logged',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (controller.recentPayments.isEmpty)
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_outlined, color: AppColors.slate, size: 36),
                      const SizedBox(height: 8),
                      const Text(
                        'No Fee Receipts Yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Payments recorded against student fees will appear here.',
                        style: TextStyle(fontSize: 12, color: AppColors.slate),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...controller.recentPayments.map((pm) => _paymentTile(context, pm)),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primaryTealDark : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPrimary ? AppColors.primaryTealDark : AppColors.divider,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppColors.primaryTealDark.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isPrimary ? Colors.white : AppColors.navyDark,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : AppColors.navyDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard({
    required BuildContext context,
    required String title,
    required int amountPaise,
    required Color color,
    required String subtitle,
  }) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.slate,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          if (disableAnimations)
            Text(
              CurrencyFormatter.formatPaise(amountPaise),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            )
          else
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: amountPaise.toDouble()),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (ctx, value, _) {
                return Text(
                  CurrencyFormatter.formatPaise(value.round()),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                );
              },
            ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.slateLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overdueChargeTile(BuildContext context, Charge ch) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChargeDetailScreen(
                chargeId: ch.id,
                controller: controller,
              ),
            ),
          );
        },
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ch.payerName ?? 'Student',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${ch.title} • Due ${CurrencyFormatter.formatDisplayDate(ch.dueDate)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.slate),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatPaise(ch.outstandingPaise),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.overdueRed,
                  ),
                ),
                const SizedBox(height: 2),
                StatusBadge.fromChargeStatus(ch.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentTile(BuildContext context, Payment pm) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentDetailReceiptScreen(
                paymentId: pm.id,
                controller: controller,
              ),
            ),
          );
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
              child: const Icon(Icons.receipt_long, color: AppColors.settledGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pm.payerName ?? 'Student',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '#${pm.receiptNumber} • ${pm.method} • ${CurrencyFormatter.formatDisplayDate(pm.paidDate)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.slate),
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
