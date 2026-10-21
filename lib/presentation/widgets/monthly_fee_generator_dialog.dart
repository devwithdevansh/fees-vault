import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../controllers/vault_controller.dart';
import 'money_input_field.dart';

/// Modal dialog that generates a complete 12-month tuition fee schedule
/// with a single tap, eliminating the need to manually enter 12 installments.
class MonthlyFeeGeneratorDialog extends StatefulWidget {
  final VaultController controller;
  final String batchId;
  final String batchName;
  final String academicYear;

  const MonthlyFeeGeneratorDialog({
    super.key,
    required this.controller,
    required this.batchId,
    required this.batchName,
    required this.academicYear,
  });

  @override
  State<MonthlyFeeGeneratorDialog> createState() =>
      _MonthlyFeeGeneratorDialogState();
}

class _MonthlyFeeGeneratorDialogState extends State<MonthlyFeeGeneratorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _monthlyAmountController = TextEditingController(text: '2000');
  final _admissionAmountController = TextEditingController(text: '1000');

  int _dueDay = 10;
  bool _includeAdmissionFee = false;
  bool _isGenerating = false;

  late int _startYear;
  late int _endYear;

  // 12 Academic session months (April to March)
  final List<bool> _selectedMonths = List.generate(12, (_) => true);

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
    // Parse years from academicYear string e.g. "2026-2027" or "2026-27"
    final matches = RegExp(
      r'\d{4}',
    ).allMatches(widget.academicYear).map((m) => m.group(0)!).toList();
    if (matches.isNotEmpty) {
      _startYear = int.tryParse(matches[0]) ?? DateTime.now().year;
    } else {
      _startYear = DateTime.now().year;
    }
    _endYear = _startYear + 1;
  }

  @override
  void dispose() {
    _monthlyAmountController.dispose();
    _admissionAmountController.dispose();
    super.dispose();
  }

  String _getMonthCode(int index) {
    final year = index < 9 ? _startYear : _endYear;
    final monthNumber = index < 9 ? index + 4 : index - 8;
    final mStr = monthNumber.toString().padLeft(2, '0');
    return '$year-$mStr';
  }

  String _getMonthTitle(int index) {
    final year = index < 9 ? _startYear : _endYear;
    return '${_monthFullNames[index]} $year';
  }

  String _formatDayLabel(int day) {
    if (day == 1) return '1st of month';
    if (day == 2) return '2nd of month';
    if (day == 3) return '3rd of month';
    return '${day}th of month';
  }

  int _calculateTotalPaise() {
    final monthlyPaise = _parsePaise(_monthlyAmountController.text);
    final count = _selectedMonths.where((m) => m).length;
    var total = monthlyPaise * count;
    if (_includeAdmissionFee) {
      total += _parsePaise(_admissionAmountController.text);
    }
    return total;
  }

  int _parsePaise(String text) {
    try {
      return CurrencyFormatter.parseToPaise(text);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _generateSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    final selectedCount = _selectedMonths.where((m) => m).length;
    if (selectedCount == 0 && !_includeAdmissionFee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one month or include an admission fee.',
          ),
          backgroundColor: AppColors.overdueRed,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final monthlyPaise = CurrencyFormatter.parseToPaise(
        _monthlyAmountController.text,
      );

      int createdCount = 0;

      // 1. Create One-Time Admission Fee if checked
      if (_includeAdmissionFee) {
        final admPaise = CurrencyFormatter.parseToPaise(
          _admissionAmountController.text,
        );
        final firstMonthCode = _getMonthCode(0);
        final admDueDate = '$firstMonthCode-05';

        await widget.controller.batchRepo.addFeeTemplate(
          batchId: widget.batchId,
          title: 'Admission & Study Material Kit',
          grossPaise: admPaise,
          defaultDueDate: admDueDate,
        );
        createdCount++;
      }

      // 2. Create the selected Monthly Fee Templates
      final dayStr = _dueDay.toString().padLeft(2, '0');
      for (int i = 0; i < 12; i++) {
        if (!_selectedMonths[i]) continue;

        final title = '${_getMonthTitle(i)} Tuition Fee';
        final dueDate = '${_getMonthCode(i)}-$dayStr';

        await widget.controller.batchRepo.addFeeTemplate(
          batchId: widget.batchId,
          title: title,
          grossPaise: monthlyPaise,
          defaultDueDate: dueDate,
        );
        createdCount++;
      }

      await widget.controller.refreshAll();

      if (mounted) {
        Navigator.pop(context, createdCount);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate schedule: $e'),
            backgroundColor: AppColors.overdueRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedMonths.where((m) => m).length;
    final totalPaise = _calculateTotalPaise();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppColors.brandGlow,
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Generate Monthly Fee Schedule',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.batchName} · Session $_startYear-$_endYear',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                      color: AppColors.textMuted,
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 20),

                // Monthly Tuition Amount
                MoneyInputField(
                  controller: _monthlyAmountController,
                  label: 'Monthly Tuition Fee',
                  helperText: 'Standard monthly fee charged per student',
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 18),

                // Due Day Selector
                const Text(
                  'Payment Due Day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Day of every month when fees become due',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1, 5, 10, 15, 20].map((day) {
                    final isSelected = _dueDay == day;
                    return ChoiceChip(
                      label: Text(_formatDayLabel(day)),
                      selected: isSelected,
                      selectedColor: AppColors.brand,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                      onSelected: (_) => setState(() => _dueDay = day),
                      backgroundColor: AppColors.surfaceSubtle,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.brand
                              : AppColors.divider,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Academic Months Selection
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Session Months ($selectedCount of 12 selected)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          final allSelected = _selectedMonths.every((m) => m);
                          for (int i = 0; i < 12; i++) {
                            _selectedMonths[i] = !allSelected;
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.brand,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: Text(
                        _selectedMonths.every((m) => m)
                            ? 'Deselect All'
                            : 'Select All',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth =
                        ((constraints.maxWidth - (3 * 8)) / 4).floorToDouble();
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(12, (index) {
                        final isSelected = _selectedMonths[index];
                        return SizedBox(
                          width: itemWidth,
                          height: 38,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(9),
                            onTap: () {
                              setState(() =>
                                  _selectedMonths[index] = !_selectedMonths[index]);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.brandLight
                                    : AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.brand
                                      : AppColors.divider,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                _monthLabels[index],
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.brand
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Optional Admission Fee Checkbox
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _includeAdmissionFee,
                            activeColor: AppColors.brand,
                            onChanged: (val) {
                              setState(
                                () => _includeAdmissionFee = val ?? false,
                              );
                            },
                          ),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'One-time Admission / Kit Fee',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Initial registration, study material or kit fee',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_includeAdmissionFee) ...[
                        const SizedBox(height: 10),
                        MoneyInputField(
                          controller: _admissionAmountController,
                          label: 'One-Time Admission Fee',
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Summary Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.brandLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.brandMid),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ANNUAL BATCH FEE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandDark,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$selectedCount Monthly installments${_includeAdmissionFee ? " + 1 Admission fee" : ""}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CurrencyFormatter.formatPaise(totalPaise),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.brand,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: _isGenerating
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.divider),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppColors.brandGlow,
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isGenerating ? null : _generateSchedule,
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.bolt_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                          label: Text(
                            _isGenerating
                                ? 'Generating...'
                                : 'Generate ($selectedCount)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
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
