import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/charge.dart';
import '../../data/models/payer.dart';
import '../../data/models/payment.dart';
import '../controllers/vault_controller.dart';
import '../widgets/quick_collect_sheet.dart';
import 'batch_detail_screen.dart';
import 'batch_form_screen.dart';
import 'charge_detail_screen.dart';
import 'payer_form_screen.dart';
import 'payment_detail_receipt_screen.dart';
import 'walkthrough_screen.dart';

/// FeesVault Dashboard — professional Notion/Linear-inspired design.
/// Bold typography hierarchy, multi-layered card depth, rich data display.
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
        displacement: 80,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Hero Header ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _HeroHeader(
                controller: controller,
                hasStudents: hasStudents,
                overdueCount: overdueCount,
                s: s,
              ),
            ),

            // ── Quick Actions ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _QuickActionsRow(
                  controller: controller,
                  hasStudents: hasStudents,
                ),
              ),
            ),

            // ── First-run onboarding ───────────────────────────────────────
            if (!hasStudents)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _OnboardingCard(controller: controller),
                ),
              ),

            // ── Financial Metrics ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _SectionHeader(
                  label: 'FINANCIAL OVERVIEW',
                  trailing: Text(
                    controller.selectedAcademicYearFilter ?? 'All Years',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _MetricsGrid(s: s),
              ),
            ),

            // ── This Month ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _MonthCard(s: s),
              ),
            ),

            // ── Overdue Installments ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: _SectionHeader(
                  label: 'OVERDUE INSTALLMENTS',
                  trailing: overdueCount > 0
                      ? _PillBadge(
                          label: '$overdueCount overdue',
                          color: AppColors.overdueRed,
                          bg: AppColors.overdueRedBg,
                        )
                      : null,
                ),
              ),
            ),

            if (controller.overdueCharges.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _EmptyState(
                    icon: Icons.check_circle_rounded,
                    iconColor: AppColors.settledGreen,
                    iconBg: AppColors.settledGreenBg,
                    title: 'All Clear',
                    subtitle: 'No overdue fee installments — great work!',
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: controller.overdueCharges.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _OverdueTile(
                    ch: controller.overdueCharges[i],
                    controller: controller,
                  ),
                ),
              ),

            // ── Recent Receipts ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: _SectionHeader(
                  label: 'RECENT RECEIPTS',
                  trailing: Text(
                    '${controller.recentPayments.length} recorded',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            if (controller.recentPayments.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _EmptyState(
                    icon: Icons.receipt_long_rounded,
                    iconColor: AppColors.textTertiary,
                    iconBg: AppColors.surfaceSubtle,
                    title: 'No Receipts Yet',
                    subtitle: 'Recorded payments will appear here.',
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: controller.recentPayments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ReceiptTile(
                    pm: controller.recentPayments[i],
                    controller: controller,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Header — deep gradient with big outstanding number + glassy chips
// ─────────────────────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final VaultController controller;
  final bool hasStudents;
  final int overdueCount;
  final dynamic s;

  const _HeroHeader({
    required this.controller,
    required this.hasStudents,
    required this.overdueCount,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
      ),
      child: Stack(
        children: [
          // Decorative circle pattern
          Positioned(
            right: -40,
            top: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 60,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar: academy name + help
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              fontSize: 20,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF34D399),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'Offline · Encrypted',
                                style: TextStyle(
                                  color: Color(0xFF93C5FD),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AcademyWalkthroughScreen(),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: const Icon(
                          Icons.help_outline_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Big outstanding number
                const Text(
                  'Total Outstanding',
                  style: TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: s.totalOutstandingPaise.toDouble(),
                  ),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Text(
                    CurrencyFormatter.formatPaise(v.round()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                      height: 1.0,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Stat chips row
                Row(
                  children: [
                    _StatChip(
                      label: 'Collected',
                      value: CurrencyFormatter.formatPaise(
                        s.totalCollectedPaise,
                      ),
                      dotColor: const Color(0xFF34D399),
                    ),
                    const SizedBox(width: 8),
                    if (overdueCount > 0)
                      _StatChip(
                        label: '$overdueCount Overdue',
                        value: CurrencyFormatter.formatPaise(
                          s.totalOverduePaise,
                        ),
                        dotColor: const Color(0xFFFCA5A5),
                        isDanger: true,
                      )
                    else
                      _StatChip(
                        label: 'Students',
                        value: '${controller.payers.where((p) => !p.archived).length} active',
                        dotColor: const Color(0xFF93C5FD),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color dotColor;
  final bool isDanger;

  const _StatChip({
    required this.label,
    required this.value,
    required this.dotColor,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDanger ? 0.10 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
// Quick Action row — 4 tall action buttons with icon + label
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionsRow extends StatelessWidget {
  final VaultController controller;
  final bool hasStudents;

  const _QuickActionsRow({
    required this.controller,
    required this.hasStudents,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(label: 'QUICK ACTIONS'),
        const SizedBox(height: 12),
        Row(
          children: [
            _QuickActionTile(
              icon: Icons.school_rounded,
              label: 'New\nClass',
              onTap: () async {
                HapticFeedback.lightImpact();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BatchFormScreen(controller: controller),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            _QuickActionTile(
              icon: Icons.person_add_rounded,
              label: 'Add\nStudent',
              onTap: () async {
                HapticFeedback.lightImpact();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PayerFormScreen(controller: controller),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            _QuickActionTile(
              icon: Icons.calendar_month_rounded,
              label: 'Fees\nRegister',
              onTap: () {
                HapticFeedback.lightImpact();
                _openFeesRegister(context);
              },
            ),
            const SizedBox(width: 10),
            _QuickActionTile(
              icon: Icons.bolt_rounded,
              label: 'Quick\nCollect',
              isPrimary: true,
              onTap: () {
                if (!hasStudents) {
                  _snack(
                    context,
                    'Add a student first before collecting fees.',
                  );
                  return;
                }
                HapticFeedback.lightImpact();
                _openQuickCollectPicker(context);
              },
            ),
          ],
        ),
      ],
    );
  }

  void _openFeesRegister(BuildContext context) {
    if (controller.batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create a class or batch first.')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BatchFormScreen(controller: controller),
        ),
      );
      return;
    }

    if (controller.batches.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BatchDetailScreen(
            batchId: controller.batches.first.id,
            controller: controller,
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const Text(
              'Select Class for Fees Register',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose a class to view 12-month tuition register and collect fees',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: controller.batches.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final b = controller.batches[i];
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.divider),
                    ),
                    tileColor: AppColors.surfaceSubtle,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.brandLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: AppColors.brand,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      b.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'AY ${b.academicYear}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BatchDetailScreen(
                            batchId: b.id,
                            controller: controller,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Future<void> _openQuickCollectPicker(BuildContext context) async {
    final activeStudents = controller.payers.where((p) => !p.archived).toList();
    if (activeStudents.isEmpty) {
      _snack(context, 'Please add a student first before collecting fees.');
      return;
    }

    final allCharges = await controller.chargeRepo.getAllCharges();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = activeStudents.where((p) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return p.name.toLowerCase().contains(q) ||
                  (p.phone?.toLowerCase().contains(q) ?? false) ||
                  (p.batch?.toLowerCase().contains(q) ?? false);
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brandLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: AppColors.brand,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Fee Collection',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Select student to record instant payment',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    onChanged: (val) => setSheetState(() => query = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search student by name, phone, or class...',
                      hintStyle: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.brand,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceSubtle,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching students found',
                              style: TextStyle(color: AppColors.textTertiary),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final student = filtered[i];
                              final studentCharges = allCharges
                                  .where((c) =>
                                      c.payerId == student.id &&
                                      c.outstandingPaise > 0)
                                  .toList();
                              // Sort oldest due date first (FIFO)
                              studentCharges
                                  .sort((a, b) => a.dueDate.compareTo(b.dueDate));

                              final totalDuePaise = studentCharges.fold<int>(
                                0,
                                (sum, c) => sum + c.outstandingPaise,
                              );

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    if (studentCharges.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '✓ All fees are settled for ${student.name}!',
                                          ),
                                          backgroundColor:
                                              AppColors.settledGreen,
                                        ),
                                      );
                                      return;
                                    }

                                    if (studentCharges.length == 1) {
                                      await QuickCollectSheet.show(
                                        context: context,
                                        controller: controller,
                                        charge: studentCharges.first,
                                        onPaymentRecorded: () =>
                                            controller.refreshAll(),
                                      );
                                    } else {
                                      _showStudentChargePicker(
                                        context,
                                        student,
                                        studentCharges,
                                      );
                                    }
                                  },
                                  child: Ink(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(14),
                                      border:
                                          Border.all(color: AppColors.divider),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors:
                                                  AppColors.avatarGradientFor(
                                                student.name,
                                              ),
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            student.name.isNotEmpty
                                                ? student.name
                                                    .substring(0, 1)
                                                    .toUpperCase()
                                                : 'S',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                student.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                student.batch != null &&
                                                        student.batch!.isNotEmpty
                                                    ? student.batch!
                                                    : (student.phone ??
                                                        'No phone'),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textTertiary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (totalDuePaise > 0)
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                CurrencyFormatter.formatPaise(
                                                  totalDuePaise,
                                                ),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                  color: AppColors.overdueRed,
                                                ),
                                              ),
                                              Text(
                                                '${studentCharges.length} due',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textTertiary,
                                                ),
                                              ),
                                            ],
                                          )
                                        else
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.settledGreenBg,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Settled',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.settledGreen,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showStudentChargePicker(
    BuildContext context,
    Payer student,
    List<Charge> charges,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text(
              'Select Fee / Month for ${student.name}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Oldest dues are listed first for authentic fee collection',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: charges.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final ch = charges[i];
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: ch.isOverdue
                            ? AppColors.overdueRedMid
                            : AppColors.divider,
                      ),
                    ),
                    tileColor: ch.isOverdue
                        ? AppColors.overdueRedBg
                        : AppColors.surfaceSubtle,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: ch.isOverdue
                            ? AppColors.overdueRedBg
                            : AppColors.brandLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        ch.isOverdue
                            ? Icons.warning_amber_rounded
                            : Icons.calendar_month_rounded,
                        color: ch.isOverdue
                            ? AppColors.overdueRed
                            : AppColors.brand,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      ch.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Due ${CurrencyFormatter.formatDisplayDate(ch.dueDate)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    trailing: Text(
                      CurrencyFormatter.formatPaise(ch.outstandingPaise),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: ch.isOverdue
                            ? AppColors.overdueRed
                            : AppColors.textPrimary,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await QuickCollectSheet.show(
                        context: context,
                        controller: controller,
                        charge: ch,
                        onPaymentRecorded: () => controller.refreshAll(),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: widget.isPrimary ? AppColors.brandGradient : null,
              color: widget.isPrimary ? null : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isPrimary
                    ? Colors.transparent
                    : AppColors.divider,
              ),
              boxShadow: widget.isPrimary
                  ? AppColors.brandGlow
                  : AppColors.cardShadow,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.isPrimary
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppColors.brandLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 18,
                    color: widget.isPrimary ? Colors.white : AppColors.brand,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.isPrimary ? Colors.white : AppColors.textPrimary,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
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
// Onboarding first-run card — premium stepped guide
// ─────────────────────────────────────────────────────────────────────────────
class _OnboardingCard extends StatelessWidget {
  final VaultController controller;
  const _OnboardingCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brandMid),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header band
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(19),
                topRight: Radius.circular(19),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to FeesVault',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Get started in 3 quick steps',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB0B8FF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Steps
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _OnboardStep(
                  number: 1,
                  title: 'Create a Batch',
                  subtitle: 'Set up your class or course with fee structure',
                ),
                const SizedBox(height: 14),
                _OnboardStep(
                  number: 2,
                  title: 'Enroll Students',
                  subtitle: 'Add students with their parent contact',
                ),
                const SizedBox(height: 14),
                _OnboardStep(
                  number: 3,
                  title: 'Track Fees & Payments',
                  subtitle: 'Auto-charge installments & log receipts',
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PayerFormScreen(controller: controller),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_add_rounded, size: 16),
                        label: const Text('Add First Student'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AcademyWalkthroughScreen(),
                        ),
                      ),
                      child: const Text('View Guide'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardStep extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  const _OnboardStep({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textTertiary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metrics grid — 2×2 financial stat cards
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
                accentColor: AppColors.brand,
                bgColor: AppColors.brandLight,
                icon: Icons.trending_up_rounded,
                subtitle: '${s.totalChargesCount} installments',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Collected',
                amountPaise: s.totalCollectedPaise,
                accentColor: AppColors.settledGreen,
                bgColor: AppColors.settledGreenBg,
                icon: Icons.check_circle_rounded,
                subtitle: 'Payments received',
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
                accentColor: s.totalOutstandingPaise > 0
                    ? AppColors.unpaidAmber
                    : AppColors.textTertiary,
                bgColor: s.totalOutstandingPaise > 0
                    ? AppColors.unpaidAmberBg
                    : AppColors.surfaceSubtle,
                icon: Icons.pending_actions_rounded,
                subtitle: 'Pending collection',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Overdue',
                amountPaise: s.totalOverduePaise,
                accentColor: s.totalOverduePaise > 0
                    ? AppColors.overdueRed
                    : AppColors.textTertiary,
                bgColor: s.totalOverduePaise > 0
                    ? AppColors.overdueRedBg
                    : AppColors.surfaceSubtle,
                icon: Icons.warning_rounded,
                subtitle: '${s.overdueChargesCount} overdue items',
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
  final Color accentColor;
  final Color bgColor;
  final IconData icon;
  final String subtitle;

  const _MetricCard({
    required this.title,
    required this.amountPaise,
    required this.accentColor,
    required this.bgColor,
    required this.icon,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: amountPaise.toDouble()),
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              CurrencyFormatter.formatPaise(v.round()),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: accentColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// This Month card — monthly snapshot
// ─────────────────────────────────────────────────────────────────────────────
class _MonthCard extends StatelessWidget {
  final dynamic s;
  const _MonthCard({required this.s});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final month = monthNames[now.month - 1];

    final collected = s.monthCollectedPaise as int;
    final total = s.monthNetFeesPaise as int;
    final ratio = total > 0 ? (collected / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.brandLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 15,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$month ${now.year}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'THIS MONTH',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MonthStat(
                  label: 'Dues',
                  paise: total,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: AppColors.divider,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _MonthStat(
                    label: 'Collected',
                    paise: collected,
                    color: AppColors.settledGreen,
                  ),
                ),
              ),
            ],
          ),
          // Collection progress bar
          if (total > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: ratio),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        backgroundColor: AppColors.divider,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ratio > 0.9
                              ? AppColors.settledGreen
                              : ratio > 0.5
                                  ? AppColors.brand
                                  : AppColors.unpaidAmber,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(ratio * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthStat extends StatelessWidget {
  final String label;
  final int paise;
  final Color color;
  const _MonthStat({
    required this.label,
    required this.paise,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.formatPaise(paise),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header — Notion-style label + optional trailing widget
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final Widget? trailing;
  const _SectionHeader({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.9,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing!,
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill Badge
// ─────────────────────────────────────────────────────────────────────────────
class _PillBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _PillBadge({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overdue charge tile — with left colored border accent
// ─────────────────────────────────────────────────────────────────────────────
class _OverdueTile extends StatelessWidget {
  final Charge ch;
  final VaultController controller;
  const _OverdueTile({required this.ch, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ChargeDetailScreen(chargeId: ch.id, controller: controller),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.overdueRedMid),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              // Red accent left bar
              Container(
                width: 4,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.overdueRed,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.avatarGradientFor(
                      ch.payerName ?? 'Student',
                    ),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  (ch.payerName ?? 'S').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ch.payerName ?? 'Student',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${ch.title} · Due ${CurrencyFormatter.formatDisplayDate(ch.dueDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      CurrencyFormatter.formatPaise(ch.outstandingPaise),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.overdueRed,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        await QuickCollectSheet.show(
                          context: context,
                          controller: controller,
                          charge: ch,
                          onPaymentRecorded: () => controller.refreshAll(),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: AppColors.brandGlow,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Collect',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Receipt tile — green accent
// ─────────────────────────────────────────────────────────────────────────────
class _ReceiptTile extends StatelessWidget {
  final Payment pm;
  final VaultController controller;
  const _ReceiptTile({required this.pm, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              // Green accent left bar
              Container(
                width: 4,
                height: 68,
                decoration: const BoxDecoration(
                  color: AppColors.settledGreen,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.avatarGradientFor(
                      pm.payerName ?? 'Student',
                    ),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  (pm.payerName ?? 'S').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pm.payerName ?? 'Student',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '#${pm.receiptNumber} · ${pm.method} · ${CurrencyFormatter.formatDisplayDate(pm.paidDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  CurrencyFormatter.formatPaise(pm.amountPaise),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.settledGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state — illustrated with centered icon in colored circle
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBg;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: iconColor),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
