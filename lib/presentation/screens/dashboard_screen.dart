import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/charge.dart';
import '../../data/models/payment.dart';
import '../controllers/vault_controller.dart';
import '../widgets/status_badge.dart';
import 'batch_form_screen.dart';
import 'charge_detail_screen.dart';
import 'charge_form_screen.dart';
import 'payer_form_screen.dart';
import 'payment_detail_receipt_screen.dart';
import 'payment_form_screen.dart';
import 'walkthrough_screen.dart';

/// FeesVault Dashboard — premium redesign with gradient header,
/// status metric cards, overdue alerts, and recent activity.
class DashboardScreen extends StatelessWidget {
  final VaultController controller;

  const DashboardScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = controller.summary;
    final hasStudents = controller.payers.isNotEmpty;
    final overdueCount = controller.overdueCharges.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => controller.refreshAll(),
        color: AppColors.brand,
        child: CustomScrollView(
          slivers: [
            // ── Premium Gradient Header ────────────────────────────────────
            SliverToBoxAdapter(
              child: _DashboardHeader(
                controller: controller,
                hasStudents: hasStudents,
                overdueCount: overdueCount,
              ),
            ),

            // ── Quick Actions ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _QuickActions(controller: controller, hasStudents: hasStudents),
              ),
            ),

            // ── Onboarding Card (first run) ────────────────────────────────
            if (!hasStudents)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _OnboardingCard(controller: controller),
                ),
              ),

            // ── Financial Metrics ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: _SectionTitle('FINANCIAL OVERVIEW'),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _MetricsGrid(s: s),
              ),
            ),

            // ── This Month ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: _MonthCard(s: s),
              ),
            ),

            // ── Overdue Installments ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
                child: Row(
                  children: [
                    _SectionTitle('OVERDUE INSTALLMENTS'),
                    if (overdueCount > 0) ...[
                      const Spacer(),
                      _OverdueBadge(count: overdueCount),
                    ],
                  ],
                ),
              ),
            ),

            if (controller.overdueCharges.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _EmptyStateCard(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: AppColors.settledGreen,
                    title: 'All Clear',
                    subtitle: 'No overdue fee installments.',
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: controller.overdueCharges.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _OverdueTile(
                    ch: controller.overdueCharges[i],
                    controller: controller,
                  ),
                ),
              ),

            // ── Recent Receipts ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
                child: Row(
                  children: [
                    _SectionTitle('RECENT RECEIPTS'),
                    const Spacer(),
                    Text(
                      '${controller.recentPayments.length} logged',
                      style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ),

            if (controller.recentPayments.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _EmptyStateCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Receipts Yet',
                    subtitle: 'Payments recorded will appear here.',
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: controller.recentPayments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ReceiptTile(
                    pm: controller.recentPayments[i],
                    controller: controller,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header with gradient background
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardHeader extends StatelessWidget {
  final VaultController controller;
  final bool hasStudents;
  final int overdueCount;

  const _DashboardHeader({
    required this.controller,
    required this.hasStudents,
    required this.overdueCount,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.businessName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'FeesVault • Offline & Encrypted',
                      style: TextStyle(
                        color: Color(0xFFB0B8FF),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // Help button
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AcademyWalkthroughScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.help_outline_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Hero outstanding amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Outstanding',
                    style: TextStyle(color: Color(0xFFB0B8FF), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: controller.summary.totalOutstandingPaise.toDouble(),
                    ),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => Text(
                      CurrencyFormatter.formatPaise(v.round()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (overdueCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.overdueRed.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$overdueCount overdue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Action buttons
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final VaultController controller;
  final bool hasStudents;

  const _QuickActions({required this.controller, required this.hasStudents});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionChip(
          icon: Icons.layers_rounded,
          label: 'New Batch',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BatchFormScreen(controller: controller)),
            );
          },
        ),
        const SizedBox(width: 8),
        _ActionChip(
          icon: Icons.person_add_rounded,
          label: 'Student',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PayerFormScreen(controller: controller)),
            );
          },
        ),
        const SizedBox(width: 8),
        _ActionChip(
          icon: Icons.receipt_rounded,
          label: 'Custom Fee',
          onTap: () async {
            if (!hasStudents) {
              _showNeedStudentSnack(context);
              return;
            }
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChargeFormScreen(controller: controller)),
            );
          },
        ),
        const SizedBox(width: 8),
        _ActionChip(
          icon: Icons.payments_rounded,
          label: 'Payment',
          isPrimary: true,
          onTap: () async {
            if (!hasStudents) {
              _showNeedStudentSnack(context);
              return;
            }
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PaymentFormScreen(controller: controller)),
            );
          },
        ),
      ],
    );
  }

  void _showNeedStudentSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add a student first before recording fees or payments.'),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isPrimary ? AppColors.brandGradient : null,
            color: isPrimary ? null : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPrimary ? Colors.transparent : AppColors.divider,
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isPrimary ? Colors.white : AppColors.brand,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? Colors.white : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding first-run card
// ─────────────────────────────────────────────────────────────────────────────
class _OnboardingCard extends StatelessWidget {
  final VaultController controller;
  const _OnboardingCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.brandMid),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to FeesVault',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Get started in 3 steps',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StepRow(number: '1', text: 'Create a Batch (e.g. Class 10) with fee structure'),
          const SizedBox(height: 8),
          _StepRow(number: '2', text: 'Enroll students with parent contact'),
          const SizedBox(height: 8),
          _StepRow(number: '3', text: 'Auto-charge fees & record receipts'),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PayerFormScreen(controller: controller)),
                    );
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Add First Student'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AcademyWalkthroughScreen()),
                  );
                },
                child: const Text('View Guide'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String text;
  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metrics grid
// ─────────────────────────────────────────────────────────────────────────────
class _MetricsGrid extends StatelessWidget {
  final dynamic s;
  const _MetricsGrid({required this.s});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Total Raised',
                amountPaise: s.totalNetFeesPaise,
                color: AppColors.textPrimary,
                iconColor: AppColors.brand,
                icon: Icons.trending_up_rounded,
                subtitle: '${s.totalChargesCount} installments',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Collected',
                amountPaise: s.totalCollectedPaise,
                color: AppColors.settledGreen,
                iconColor: AppColors.settledGreen,
                icon: Icons.check_circle_rounded,
                subtitle: 'Into vault',
                bgColor: AppColors.settledGreenBg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Outstanding',
                amountPaise: s.totalOutstandingPaise,
                color: s.totalOutstandingPaise > 0 ? AppColors.unpaidAmber : AppColors.textTertiary,
                iconColor: AppColors.unpaidAmber,
                icon: Icons.pending_actions_rounded,
                subtitle: 'Pending collection',
                bgColor: s.totalOutstandingPaise > 0 ? AppColors.unpaidAmberBg : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Overdue',
                amountPaise: s.totalOverduePaise,
                color: s.totalOverduePaise > 0 ? AppColors.overdueRed : AppColors.textTertiary,
                iconColor: AppColors.overdueRed,
                icon: Icons.warning_rounded,
                subtitle: '${s.overdueChargesCount} overdue',
                bgColor: s.totalOverduePaise > 0 ? AppColors.overdueRedBg : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final int amountPaise;
  final Color color;
  final Color iconColor;
  final IconData icon;
  final String subtitle;
  final Color? bgColor;

  const _MetricCard({
    required this.title,
    required this.amountPaise,
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.subtitle,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: amountPaise.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              CurrencyFormatter.formatPaise(v.round()),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// This Month card
// ─────────────────────────────────────────────────────────────────────────────
class _MonthCard extends StatelessWidget {
  final dynamic s;
  const _MonthCard({required this.s});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ][now.month - 1];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, size: 15, color: AppColors.brand),
              const SizedBox(width: 6),
              Text(
                'THIS MONTH  •  $month ${now.year}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MonthStat(
                  label: 'Dues This Month',
                  paise: s.monthNetFeesPaise,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(width: 1, height: 44, color: AppColors.divider),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _MonthStat(
                    label: 'Collected',
                    paise: s.monthCollectedPaise,
                    color: AppColors.settledGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthStat extends StatelessWidget {
  final String label;
  final int paise;
  final Color color;
  const _MonthStat({required this.label, required this.paise, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.formatPaise(paise),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.2),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section title
// ─────────────────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textTertiary,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overdue badge
// ─────────────────────────────────────────────────────────────────────────────
class _OverdueBadge extends StatelessWidget {
  final int count;
  const _OverdueBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.overdueRedBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count overdue',
        style: const TextStyle(fontSize: 11, color: AppColors.overdueRed, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overdue charge tile
// ─────────────────────────────────────────────────────────────────────────────
class _OverdueTile extends StatelessWidget {
  final Charge ch;
  final VaultController controller;
  const _OverdueTile({required this.ch, required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChargeDetailScreen(chargeId: ch.id, controller: controller),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.overdueRedBg),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.overdueRedBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.overdueRed, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ch.payerName ?? 'Student',
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${ch.title} • Due ${CurrencyFormatter.formatDisplayDate(ch.dueDate)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                    fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.overdueRed,
                  ),
                ),
                const SizedBox(height: 3),
                StatusBadge.fromChargeStatus(ch.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Receipt tile
// ─────────────────────────────────────────────────────────────────────────────
class _ReceiptTile extends StatelessWidget {
  final Payment pm;
  final VaultController controller;
  const _ReceiptTile({required this.pm, required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentDetailReceiptScreen(paymentId: pm.id, controller: controller),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.settledGreenBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.settledGreen, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pm.payerName ?? 'Student',
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '#${pm.receiptNumber} • ${pm.method} • ${CurrencyFormatter.formatDisplayDate(pm.paidDate)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.formatPaise(pm.amountPaise),
              style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.settledGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic empty state card
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: (iconColor ?? AppColors.textTertiary).withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
