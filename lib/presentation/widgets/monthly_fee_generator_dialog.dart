import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/fee_partition_presets.dart';
import '../../core/formatters/currency_formatter.dart';
import '../controllers/vault_controller.dart';
import 'money_input_field.dart';

/// Modal dialog that generates complete fee schedules and partitions matching school-erp.
/// Supports presets:
/// 1. DEFAULT_12_2 (14 parts: 12 monthly education + 2 term fees)
/// 2. MONTHLY_12 (12 equal monthly installments)
/// 3. QUARTERLY_4 (4 installments: Jun, Sep, Dec, Mar)
/// 4. HALF_YEARLY_2 (2 semester installments: Jun & Nov)
/// 5. ANNUAL_1 (100% full annual payment upfront)
/// 6. CUSTOM (arbitrary installment parts, names, due dates, & amounts)
/// Also supports Admission Fee, Bag & Kit Fee, and Term Fee overrides.
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

// Alias for semantic clarity
typedef FeeScheduleGeneratorDialog = MonthlyFeeGeneratorDialog;

class _MonthlyFeeGeneratorDialogState extends State<MonthlyFeeGeneratorDialog> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _annualFeeController = TextEditingController(text: '28000');
  final _admissionAmountController = TextEditingController(text: '0');
  final _bagKitAmountController = TextEditingController(text: '0');
  final _termFeeOverrideController = TextEditingController(text: '0');

  FeeScheduleType _selectedPreset = FeeScheduleType.default12_2;
  SessionStartMonth _sessionStart = SessionStartMonth.june;
  int _dueDay = 10;

  bool _includeAdmissionFee = false;
  bool _includeBagKitFee = false;
  bool _useTermFeeOverride = false;
  bool _replaceExistingTemplates = true;
  bool _isGenerating = false;
  bool _showAncillarySection = false;

  late int _startYear;
  late int _endYear;

  // Custom installment parts when in CUSTOM mode or fine-tuning
  List<InstallmentPartConfig> _customParts = [];

  @override
  void initState() {
    super.initState();
    final matches = RegExp(
      r'\d{4}',
    ).allMatches(widget.academicYear).map((m) => m.group(0)!).toList();
    if (matches.isNotEmpty) {
      _startYear = int.tryParse(matches[0]) ?? DateTime.now().year;
    } else {
      _startYear = DateTime.now().year;
    }
    _endYear = _startYear + 1;

    _regeneratePreview();
  }

  @override
  void dispose() {
    _annualFeeController.dispose();
    _admissionAmountController.dispose();
    _bagKitAmountController.dispose();
    _termFeeOverrideController.dispose();
    super.dispose();
  }

  int _parsePaise(String text) {
    try {
      return CurrencyFormatter.parseToPaise(text);
    } catch (_) {
      return 0;
    }
  }

  void _regeneratePreview() {
    final annualPaise = _parsePaise(_annualFeeController.text);
    final admissionPaise = _includeAdmissionFee
        ? _parsePaise(_admissionAmountController.text)
        : 0;
    final bagKitPaise = _includeBagKitFee
        ? _parsePaise(_bagKitAmountController.text)
        : 0;
    final termOverridePaise = _useTermFeeOverride
        ? _parsePaise(_termFeeOverrideController.text)
        : 0;

    _customParts = FeePartitionHelper.generatePresetParts(
      type: _selectedPreset,
      annualFeePaise: annualPaise,
      startYear: _startYear,
      sessionStart: _sessionStart,
      dueDay: _dueDay,
      termFeeOverridePaise: termOverridePaise,
      admissionFeePaise: admissionPaise,
      bagKitFeePaise: bagKitPaise,
    );
  }

  void _onPresetChanged(FeeScheduleType preset) {
    setState(() {
      _selectedPreset = preset;
      if (preset == FeeScheduleType.monthly12 && _annualFeeController.text == '28000') {
        _annualFeeController.text = '24000';
      } else if (preset == FeeScheduleType.default12_2 && _annualFeeController.text == '24000') {
        _annualFeeController.text = '28000';
      }
      _regeneratePreview();
    });
  }

  void _splitCustomEvenly() {
    final annualPaise = _parsePaise(_annualFeeController.text);
    if (_customParts.isEmpty || annualPaise <= 0) return;

    // Filter education and term parts
    final mainParts = _customParts
        .where((p) => p.feeType == 'EDUCATION' || p.feeType == 'TERM')
        .toList();
    if (mainParts.isEmpty) return;

    final base = annualPaise ~/ mainParts.length;
    final rem = annualPaise - (base * mainParts.length);

    setState(() {
      for (int i = 0; i < mainParts.length; i++) {
        mainParts[i].grossPaise = (i == 0) ? base + rem : base;
      }
    });
  }

  int _calculateTotalSchedulePaise() {
    return _customParts.fold<int>(0, (sum, part) => sum + part.grossPaise);
  }

  Future<void> _generateSchedule() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customParts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please configure at least one fee installment part.'),
          backgroundColor: AppColors.overdueRed,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // 1. Optionally clear existing templates
      if (_replaceExistingTemplates) {
        await widget.controller.clearBatchFeeTemplates(widget.batchId);
      }

      // 2. Add each installment part as a BatchFeeTemplate
      int createdCount = 0;
      for (final part in _customParts) {
        await widget.controller.batchRepo.addFeeTemplate(
          batchId: widget.batchId,
          title: part.title,
          grossPaise: part.grossPaise,
          defaultDueDate: part.dueDate,
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
            content: Text('Failed to generate fee schedule: $e'),
            backgroundColor: AppColors.overdueRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Color _getBadgeColor(String feeType) {
    switch (feeType) {
      case 'TERM':
        return Colors.purple;
      case 'ADMISSION':
        return Colors.orange;
      case 'BAG_KIT':
        return Colors.teal;
      default:
        return AppColors.brand;
    }
  }

  String _formatDayLabel(int day) {
    if (day == 1 || day == 21 || day == 31) return '${day}st';
    if (day == 2 || day == 22) return '${day}nd';
    if (day == 3 || day == 23) return '${day}rd';
    return '${day}th';
  }

  @override
  Widget build(BuildContext context) {
    final totalPaise = _calculateTotalSchedulePaise();
    final partsCount = _customParts.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 820),
        child: Column(
          children: [
            // ── Dialog Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 16, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppColors.brandGlow,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
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
                          'Fee Schedule & Partitions',
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
            ),
            const Divider(height: 1, color: AppColors.divider),

            // ── Scrollable Dialog Body ─────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preset Selector Header
                      const Text(
                        'Select Schedule Partition Preset',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Choose how annual school fees are partitioned into installments',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Presets Chips Grid
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: FeeScheduleType.values.map((preset) {
                          final isSelected = _selectedPreset == preset;
                          return ChoiceChip(
                            avatar: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                            label: Text(
                              preset.label +
                                  (preset.count > 0
                                      ? ' (${preset.count}p)'
                                      : ''),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.brand,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            onSelected: (_) => _onPresetChanged(preset),
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

                      // Preset Description Box
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandLight.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.brand.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: AppColors.brand,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedPreset.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.brand,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Annual Base Fee Input
                      MoneyInputField(
                        controller: _annualFeeController,
                        label: 'Total Annual Tuition Fee',
                        helperText: _selectedPreset == FeeScheduleType.default12_2
                            ? 'Divided into 14 parts (12 monthly tuition + 2 term fees)'
                            : _selectedPreset == FeeScheduleType.monthly12
                                ? 'Divided evenly into 12 monthly installments'
                                : _selectedPreset == FeeScheduleType.quarterly4
                                    ? 'Divided into 4 quarterly installments'
                                    : _selectedPreset == FeeScheduleType.halfYearly2
                                        ? 'Divided into 2 semester installments'
                                        : 'Full annual tuition amount',
                        onChanged: (_) {
                          setState(() {
                            _regeneratePreview();
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Academic Session Selector
                      const Text(
                        'Academic Session',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<SessionStartMonth>(
                        initialValue: _sessionStart,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceSubtle,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.divider,
                            ),
                          ),
                        ),
                        items: SessionStartMonth.values.map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(
                              s == SessionStartMonth.june
                                  ? 'June - May (State / Western Board)'
                                  : 'April - March (CBSE / Northern Board)',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _sessionStart = val;
                              _regeneratePreview();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Due Day of Month
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
                        'Day of each month when fees become due',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [1, 5, 10, 15, 20, 25].map((day) {
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
                            onSelected: (_) {
                              setState(() {
                                _dueDay = day;
                                _regeneratePreview();
                              });
                            },
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
                      const SizedBox(height: 16),

                      // Ancillary Components Accordion
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showAncillarySection = !_showAncillarySection;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.add_moderator_rounded,
                                size: 18,
                                color: AppColors.brand,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Additional Components (Admission, Bag & Kit, Term Override)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(
                                _showAncillarySection
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_showAncillarySection) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Admission Fee Checkbox & Input
                              CheckboxListTile(
                                value: _includeAdmissionFee,
                                title: const Text(
                                  'Include One-Time Admission Fee',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Added as a one-time charge at the start of the session',
                                  style: TextStyle(fontSize: 11.5),
                                ),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                activeColor: AppColors.brand,
                                onChanged: (val) {
                                  setState(() {
                                    _includeAdmissionFee = val ?? false;
                                    _regeneratePreview();
                                  });
                                },
                              ),
                              if (_includeAdmissionFee)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 32,
                                    bottom: 12,
                                  ),
                                  child: MoneyInputField(
                                    controller: _admissionAmountController,
                                    label: 'Admission Fee Amount',
                                    onChanged: (_) {
                                      setState(() => _regeneratePreview());
                                    },
                                  ),
                                ),

                              const Divider(
                                height: 16,
                                color: AppColors.divider,
                              ),

                              // 2. Bag & Kit Fee Checkbox & Input
                              CheckboxListTile(
                                value: _includeBagKitFee,
                                title: const Text(
                                  'Include Bag & Kit Fee',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Books, uniforms, and student kit material fee',
                                  style: TextStyle(fontSize: 11.5),
                                ),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                activeColor: AppColors.brand,
                                onChanged: (val) {
                                  setState(() {
                                    _includeBagKitFee = val ?? false;
                                    _regeneratePreview();
                                  });
                                },
                              ),
                              if (_includeBagKitFee)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 32,
                                    bottom: 12,
                                  ),
                                  child: MoneyInputField(
                                    controller: _bagKitAmountController,
                                    label: 'Bag & Kit Fee Amount',
                                    onChanged: (_) {
                                      setState(() => _regeneratePreview());
                                    },
                                  ),
                                ),

                              if (_selectedPreset ==
                                  FeeScheduleType.default12_2) ...[
                                const Divider(
                                  height: 16,
                                  color: AppColors.divider,
                                ),
                                // 3. Specific Term Fee Override
                                CheckboxListTile(
                                  value: _useTermFeeOverride,
                                  title: const Text(
                                    'Explicit Term Fee Override',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'By default, Term 1 & 2 are 1/14th of annual fee. Enable to set a custom amount.',
                                    style: TextStyle(fontSize: 11.5),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  activeColor: AppColors.brand,
                                  onChanged: (val) {
                                    setState(() {
                                      _useTermFeeOverride = val ?? false;
                                      _regeneratePreview();
                                    });
                                  },
                                ),
                                if (_useTermFeeOverride)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 32,
                                      bottom: 8,
                                    ),
                                    child: MoneyInputField(
                                      controller: _termFeeOverrideController,
                                      label: 'Fee per Term (Term 1 & Term 2)',
                                      onChanged: (_) {
                                        setState(() => _regeneratePreview());
                                      },
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Replace existing templates option
                      CheckboxListTile(
                        value: _replaceExistingTemplates,
                        title: const Text(
                          'Replace existing fee templates for this batch',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Clears previously configured installments so duplicates are avoided',
                          style: TextStyle(fontSize: 11.5),
                        ),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppColors.brand,
                        onChanged: (val) {
                          setState(() {
                            _replaceExistingTemplates = val ?? true;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── Schedule Preview Section ───────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Installment Partitions ($partsCount parts)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_selectedPreset == FeeScheduleType.custom) ...[
                            TextButton.icon(
                              icon: const Icon(Icons.bolt, size: 16),
                              label: const Text(
                                'Split Evenly',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: _splitCustomEvenly,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.brand,
                                visualDensity: VisualDensity.compact,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                'Add',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: () {
                                setState(() {
                                  final nextOrder = _customParts.length + 1;
                                  _customParts.add(
                                    InstallmentPartConfig(
                                      title: 'Installment $nextOrder',
                                      grossPaise: 0,
                                      dueDate: FeePartitionHelper.formatDate(
                                        _startYear,
                                        _sessionStart.monthNumber,
                                        _dueDay,
                                      ),
                                      dueMonth: 'Custom',
                                      feeType: 'EDUCATION',
                                      order: nextOrder,
                                    ),
                                  );
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.brand,
                                visualDensity: VisualDensity.compact,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Installments Preview Cards Container
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _customParts.length,
                          separatorBuilder: (ctx, idx) => const Divider(
                            height: 1,
                            color: AppColors.divider,
                          ),
                          itemBuilder: (ctx, idx) {
                            final part = _customParts[idx];
                            final badgeColor = _getBadgeColor(part.feeType);

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  // Part fee type badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      part.feeType == 'EDUCATION'
                                          ? 'EDU'
                                          : part.feeType == 'TERM'
                                              ? 'TERM'
                                              : part.feeType == 'ADMISSION'
                                                  ? 'ADM'
                                                  : 'KIT',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: badgeColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Title & Due date
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          part.title,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Due: ${CurrencyFormatter.formatDisplayDate(part.dueDate)}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Amount
                                  if (_selectedPreset ==
                                      FeeScheduleType.custom) ...[
                                    SizedBox(
                                      width: 90,
                                      child: TextFormField(
                                        initialValue: (part.grossPaise / 100)
                                            .toStringAsFixed(0),
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          prefixText: '₹',
                                          isDense: true,
                                          contentPadding:
                                              EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                        ),
                                        onChanged: (val) {
                                          final parsed =
                                              CurrencyFormatter.parseToPaise(
                                            val,
                                          );
                                          setState(() {
                                            part.grossPaise = parsed;
                                          });
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: AppColors.overdueRed,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _customParts.removeAt(idx);
                                        });
                                      },
                                    ),
                                  ] else
                                    Text(
                                      CurrencyFormatter.formatPaise(
                                        part.grossPaise,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Dialog Footer with Summary & Generate CTA ──────────────
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL ANNUAL SCHEDULE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatPaise(totalPaise),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: AppColors.divider),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isGenerating ? null : _generateSchedule,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isGenerating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Generate $partsCount Parts',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
