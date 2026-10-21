import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/batch.dart';
import '../../data/models/charge.dart';
import '../../data/models/payer.dart';
import '../controllers/vault_controller.dart';
import '../screens/charge_detail_screen.dart';
import 'quick_collect_sheet.dart';

/// Month-Wise Fees Register & Quick-Collection View.
/// Provides:
/// 1. Horizontal Month Carousel (April to March) with current month detection
/// 2. Monthly Collection Health Card (Target vs Collected vs Pending)
/// 3. Student Roster with 1-Tap "⚡ Collect ₹..." instant payment flow
/// 4. Classic Monthly Ledger Matrix view toggle (Student rows x 12 Month columns)
class MonthlyFeesRegisterView extends StatefulWidget {
  final VaultController controller;
  final Batch batch;
  final List<Payer> students;
  final VoidCallback onDataChanged;

  const MonthlyFeesRegisterView({
    super.key,
    required this.controller,
    required this.batch,
    required this.students,
    required this.onDataChanged,
  });

  @override
  State<MonthlyFeesRegisterView> createState() =>
      _MonthlyFeesRegisterViewState();
}

class _MonthlyFeesRegisterViewState extends State<MonthlyFeesRegisterView> {
  bool _isLoading = true;
  List<Charge> _allCharges = [];
  int _selectedMonthIndex = 0;
  bool _isLedgerMatrixView = false;
  String _filterState = 'all'; // 'all', 'pending', 'paid'

  late int _startYear;
  late int _endYear;

  static const List<String> _monthLabels = [
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
    'Jan',
    'Feb',
    'Mar',
  ];

  static const List<String> _monthFullNames = [
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
    'January',
    'February',
    'March',
  ];

  @override
  void initState() {
    super.initState();
    _initAcademicYears();
    _loadCharges();
  }

  void _initAcademicYears() {
    final matches = RegExp(
      r'\d{4}',
    ).allMatches(widget.batch.academicYear).map((m) => m.group(0)!).toList();
    if (matches.isNotEmpty) {
      _startYear = int.tryParse(matches[0]) ?? DateTime.now().year;
    } else {
      _startYear = DateTime.now().year;
    }
    _endYear = _startYear + 1;

    // Detect current calendar month index (April = 0, ..., March = 11)
    final now = DateTime.now();
    if (now.month >= 4) {
      _selectedMonthIndex = now.month - 4; // Apr(4) -> 0, Dec(12) -> 8
    } else {
      _selectedMonthIndex = now.month + 8; // Jan(1) -> 9, Mar(3) -> 11
    }
    if (_selectedMonthIndex < 0 || _selectedMonthIndex > 11) {
      _selectedMonthIndex = 0;
    }
  }

  String _getMonthCode(int index) {
    final year = index < 9 ? _startYear : _endYear;
    final monthNumber = index < 9 ? index + 4 : index - 8;
    return '$year-${monthNumber.toString().padLeft(2, '0')}';
  }

  String _getMonthTitle(int index) {
    final year = index < 9 ? _startYear : _endYear;
    return '${_monthFullNames[index]} $year';
  }

  Future<void> _loadCharges() async {
    setState(() => _isLoading = true);
    try {
      final charges = await widget.controller.chargeRepo.getChargesForBatch(
        widget.batch.id,
      );
      if (mounted) {
        setState(() {
          _allCharges = charges;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Charge> _getChargesForMonth(int monthIdx) {
    final monthCode = _getMonthCode(monthIdx);
    final monthName = _monthFullNames[monthIdx].toLowerCase();

    return _allCharges.where((c) {
      if (c.dueDate.startsWith(monthCode)) return true;
      if (c.period != null && c.period!.toLowerCase().contains(monthName)) {
        return true;
      }
      if (c.title.toLowerCase().contains(monthName)) return true;
      return false;
    }).toList();
  }

  Future<void> _quickCollectFee(Charge charge) async {
    final recorded = await QuickCollectSheet.show(
      context: context,
      controller: widget.controller,
      charge: charge,
      onPaymentRecorded: () async {
        await _loadCharges();
        widget.onDataChanged();
      },
    );

    if (recorded == true) {
      await _loadCharges();
      widget.onDataChanged();
      if (mounted) {
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }

    if (_allCharges.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: AppColors.brandLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.brand,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Fees Registered Yet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Generate a 12-month tuition schedule in the "Fee Structure" tab, then tap "Charge All Students" to activate this register.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Top Toolbar: Month Carousel + Ledger Matrix View Toggle
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              // Header row with view toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ACADEMIC SESSION $_startYear-$_endYear',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isLedgerMatrixView
                                ? Icons.view_agenda_outlined
                                : Icons.grid_view_rounded,
                            size: 20,
                            color: AppColors.brand,
                          ),
                          tooltip: _isLedgerMatrixView
                              ? 'Switch to Monthly Roster'
                              : 'Switch to Full Ledger Matrix',
                          onPressed: () {
                            setState(() {
                              _isLedgerMatrixView = !_isLedgerMatrixView;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Month Carousel (if in roster mode)
              if (!_isLedgerMatrixView)
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: 12,
                    itemBuilder: (ctx, idx) {
                      final isSelected = _selectedMonthIndex == idx;
                      final monthCharges = _getChargesForMonth(idx);
                      final totalPaid = monthCharges.fold<int>(
                        0,
                        (sum, c) => sum + c.paidPaise,
                      );
                      final totalNet = monthCharges.fold<int>(
                        0,
                        (sum, c) => sum + c.netChargePaise,
                      );

                      // Dot color indicator
                      Color dotColor = Colors.transparent;
                      if (monthCharges.isNotEmpty) {
                        if (totalPaid >= totalNet) {
                          dotColor = AppColors.settledGreen;
                        } else if (totalPaid > 0) {
                          dotColor = AppColors.partialBlue;
                        } else {
                          dotColor = AppColors.overdueRed;
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          avatar: dotColor != Colors.transparent
                              ? Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                          label: Text(_monthLabels[idx]),
                          selected: isSelected,
                          selectedColor: AppColors.brand,
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedMonthIndex = idx),
                          backgroundColor: AppColors.surfaceSubtle,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.brand
                                  : AppColors.divider,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),

        const Divider(height: 1, color: AppColors.divider),

        // Body: either Ledger Matrix View or Monthly Roster View
        Expanded(
          child: _isLedgerMatrixView
              ? _buildLedgerMatrix()
              : _buildMonthlyRoster(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // View A: Monthly Roster with Quick-Collection Buttons
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMonthlyRoster() {
    final monthCharges = _getChargesForMonth(_selectedMonthIndex);
    final monthTitle = _getMonthTitle(_selectedMonthIndex);

    final totalTarget = monthCharges.fold<int>(
      0,
      (sum, c) => sum + c.netChargePaise,
    );
    final totalCollected = monthCharges.fold<int>(
      0,
      (sum, c) => sum + c.paidPaise,
    );
    final totalPending = totalTarget - totalCollected;

    final settledCount = monthCharges.where((c) => c.isSettled).length;
    final pendingCount = monthCharges.where((c) => !c.isSettled).length;

    final filteredCharges = monthCharges.where((c) {
      if (_filterState == 'paid') return c.isSettled;
      if (_filterState == 'pending') return !c.isSettled;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        // Monthly Collection Health Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.elevatedShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    monthTitle.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      totalTarget > 0
                          ? '${((totalCollected / totalTarget) * 100).toInt()}% Collected'
                          : 'No Dues',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    CurrencyFormatter.formatPaise(totalCollected),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '/ ${CurrencyFormatter.formatPaise(totalTarget)} target',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: totalTarget > 0
                      ? (totalCollected / totalTarget).clamp(0.0, 1.0)
                      : 0.0,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.greenAccent,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 14),
              // Stats row
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '✓ $settledCount Paid',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '! $pendingCount Pending (${CurrencyFormatter.formatPaise(totalPending)})',
                      style: TextStyle(
                        color: pendingCount > 0
                            ? Colors.red.shade100
                            : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Filter chips (All / Pending / Paid)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('all', 'All (${monthCharges.length})'),
              const SizedBox(width: 8),
              _filterChip('pending', 'Pending ($pendingCount)'),
              const SizedBox(width: 8),
              _filterChip('paid', 'Paid ($settledCount)'),
            ],
          ),
        ),

        const SizedBox(height: 12),

        if (filteredCharges.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                _filterState == 'pending'
                    ? '🎉 All students have settled this month!'
                    : 'No records found for this filter.',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ...filteredCharges.map((charge) {
            final isSettled = charge.isSettled;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSettled
                      ? AppColors.settledGreenMid
                      : (charge.isOverdue
                            ? AppColors.overdueRedMid
                            : AppColors.divider),
                ),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: isSettled
                          ? null
                          : LinearGradient(
                              colors: AppColors.avatarGradientFor(
                                charge.payerName ?? '',
                              ),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: isSettled ? AppColors.settledGreenBg : null,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isSettled
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppColors.settledGreen,
                              size: 22,
                            )
                          : Text(
                              (charge.payerName ?? 'S')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Student Details & Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          charge.payerName ?? 'Student',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        if (isSettled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.settledGreenBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'PAID ${CurrencyFormatter.formatPaise(charge.paidPaise)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.settledGreenDark,
                              ),
                            ),
                          )
                        else
                          Text.rich(
                            TextSpan(
                              text:
                                  '${CurrencyFormatter.formatPaise(charge.outstandingPaise)} due',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: charge.isOverdue
                                    ? AppColors.overdueRed
                                    : AppColors.textSecondary,
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      ' · Due ${CurrencyFormatter.formatDisplayDate(charge.dueDate)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.normal,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Action: 1-Tap Quick Collect or View Receipt
                  if (!isSettled)
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: AppColors.brandGlow,
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _quickCollectFee(charge),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Collect ${CurrencyFormatter.formatPaise(charge.outstandingPaise)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.brand,
                        size: 20,
                      ),
                      tooltip: 'View Fee Details',
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChargeDetailScreen(
                              controller: widget.controller,
                              chargeId: charge.id,
                            ),
                          ),
                        );
                        await _loadCharges();
                        widget.onDataChanged();
                      },
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _filterChip(String key, String label) {
    final isSel = _filterState == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      selectedColor: AppColors.brand,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isSel ? Colors.white : AppColors.textSecondary,
      ),
      onSelected: (_) => setState(() => _filterState = key),
      backgroundColor: AppColors.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: isSel ? AppColors.brand : AppColors.divider),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // View B: Classic Monthly Tuition Ledger Matrix (Students x 12 Months)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLedgerMatrix() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppColors.cardShadow,
          ),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.surfaceSubtle),
            columnSpacing: 18,
            horizontalMargin: 16,
            columns: [
              const DataColumn(
                label: Text(
                  'Student Name',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              ..._monthLabels.map(
                (m) => DataColumn(
                  label: Text(
                    m,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
            rows: widget.students.map((student) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  ...List.generate(12, (mIdx) {
                    final monthCharges = _getChargesForMonth(mIdx);
                    final studentCharge = monthCharges
                        .where((c) => c.payerId == student.id)
                        .firstOrNull;

                    if (studentCharge == null) {
                      return const DataCell(
                        Text('-', style: TextStyle(color: AppColors.textMuted)),
                      );
                    }

                    if (studentCharge.isSettled) {
                      return DataCell(
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.settledGreen,
                          size: 18,
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChargeDetailScreen(
                                controller: widget.controller,
                                chargeId: studentCharge.id,
                              ),
                            ),
                          );
                          await _loadCharges();
                          widget.onDataChanged();
                        },
                      );
                    } else if (studentCharge.isOverdue) {
                      return DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.overdueRedBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Due',
                            style: TextStyle(
                              color: AppColors.overdueRed,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        onTap: () => _quickCollectFee(studentCharge),
                      );
                    } else {
                      return DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Pending',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        onTap: () => _quickCollectFee(studentCharge),
                      );
                    }
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
