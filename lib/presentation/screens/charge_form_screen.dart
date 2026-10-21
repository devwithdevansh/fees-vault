import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/charge.dart';
import '../controllers/vault_controller.dart';
import '../widgets/contextual_help_button.dart';
import '../widgets/money_input_field.dart';

/// Screen to create or edit an academy Fee Installment.
class ChargeFormScreen extends StatefulWidget {
  final VaultController controller;
  final Charge? chargeToEdit;
  final String? initialPayerId;

  const ChargeFormScreen({
    super.key,
    required this.controller,
    this.chargeToEdit,
    this.initialPayerId,
  });

  @override
  State<ChargeFormScreen> createState() => _ChargeFormScreenState();
}

class _ChargeFormScreenState extends State<ChargeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late String? _selectedPayerId;
  late TextEditingController _titleController;
  late TextEditingController _periodController;
  late TextEditingController _grossController;
  late TextEditingController _discountController;
  late TextEditingController _notesController;
  late DateTime _selectedDueDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final ch = widget.chargeToEdit;
    _selectedPayerId =
        ch?.payerId ??
        widget.initialPayerId ??
        (widget.controller.payers.isNotEmpty
            ? widget.controller.payers.first.id
            : null);
    _titleController = TextEditingController(text: ch?.title ?? '');
    _periodController = TextEditingController(text: ch?.period ?? '');
    _grossController = TextEditingController(
      text: ch != null
          ? CurrencyFormatter.paiseToEditableString(ch.grossPaise)
          : '',
    );
    _discountController = TextEditingController(
      text: ch != null && ch.discountPaise > 0
          ? CurrencyFormatter.paiseToEditableString(ch.discountPaise)
          : '',
    );
    _notesController = TextEditingController(text: ch?.notes ?? '');

    if (ch != null) {
      _selectedDueDate = CurrencyFormatter.parseDate(ch.dueDate);
    } else {
      // Default due date: today
      _selectedDueDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _periodController.dispose();
    _grossController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() => _selectedDueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (_selectedPayerId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a student.')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    int grossPaise = 0;
    int discountPaise = 0;
    try {
      grossPaise = CurrencyFormatter.parseToPaise(_grossController.text);
      if (_discountController.text.trim().isNotEmpty) {
        discountPaise = CurrencyFormatter.parseToPaise(
          _discountController.text,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid amount format: $e'),
          backgroundColor: AppColors.overdueRed,
        ),
      );
      return;
    }

    if (discountPaise > grossPaise) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Concession cannot exceed the gross course fee.'),
          backgroundColor: AppColors.overdueRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final ymdDueDate = CurrencyFormatter.toYmd(_selectedDueDate);
      final feeTitle = _titleController.text.trim();

      if (widget.chargeToEdit == null) {
        await widget.controller.addCharge(
          payerId: _selectedPayerId!,
          title: feeTitle,
          period: _periodController.text.trim(),
          grossPaise: grossPaise,
          discountPaise: discountPaise,
          dueDate: ymdDueDate,
          notes: _notesController.text.trim(),
        );
      } else {
        final updated = widget.chargeToEdit!.copyWith(
          title: feeTitle,
          period: _periodController.text.trim(),
          grossPaise: grossPaise,
          discountPaise: discountPaise,
          dueDate: ymdDueDate,
          notes: _notesController.text.trim(),
        );
        await widget.controller.updateCharge(updated);
      }

      // Gentle haptic feedback
      HapticFeedback.lightImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.chargeToEdit == null
                        ? 'Fee installment "$feeTitle" created.'
                        : 'Fee installment updated.',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.settledGreen,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.overdueRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.chargeToEdit != null;
    final payers = widget.controller.payers;

    // Calculate live net fee — safe: returns 0 for empty or invalid input
    int safePaise(String text) {
      if (text.trim().isEmpty) return 0;
      try {
        return CurrencyFormatter.parseToPaise(text);
      } catch (_) {
        return 0;
      }
    }

    final gross = safePaise(_grossController.text);
    final disc = safePaise(_discountController.text);
    final net = (gross - disc).clamp(0, gross);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Fee Installment' : 'New Fee Installment',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _submit,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: AppColors.brand,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
            // Section 1: Student Selection
            _SectionHeader(icon: Icons.person_rounded, label: 'STUDENT ASSIGNMENT'),
            const SizedBox(height: 10),

            if (!isEdit && widget.initialPayerId == null) ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedPayerId,
                items: payers.map((p) {
                  return DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      '${p.name}${p.batch != null ? " (${p.batch})" : ""}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedPayerId = val),
                decoration: _inputDecoration(
                  'Assign to Student *',
                  Icons.person_outline,
                ),
                validator: (v) => v == null ? 'Please select a student' : null,
              ),
              const SizedBox(height: 20),
            ] else ...[
              TextFormField(
                initialValue:
                    widget.chargeToEdit?.payerName ??
                    (payers.any((p) => p.id == widget.initialPayerId)
                        ? payers
                              .firstWhere((p) => p.id == widget.initialPayerId)
                              .name
                        : 'Selected Student'),
                enabled: false,
                decoration: _inputDecoration('Student', Icons.school_outlined),
              ),
              const SizedBox(height: 20),
            ],

            // Section 2: Fee Details
            _SectionHeader(icon: Icons.school_rounded, label: 'FEE & ACADEMIC SESSION'),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration(
                      'Fee / Installment Title *',
                      Icons.label_outline,
                      hint: 'e.g. Term 1 Tuition, Q2 Installment',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Please enter a fee title'
                        : null,
                  ),
                ),
                const ContextualHelpButton(
                  title: 'Fee / Installment Title',
                  explanation:
                      'Name of this fee obligation. You can enter a single full course fee or split into multiple installments with separate due dates.',
                  example:
                      'Term 1 Tuition Fee, Annual Course Fee, Installment 2 (Jan)',
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _periodController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration(
                      'Academic Year / Session (Optional)',
                      Icons.calendar_view_month_outlined,
                      hint: 'e.g. 2026-27, Semester 1',
                    ),
                  ),
                ),
                const ContextualHelpButton(
                  title: 'Academic Year / Session',
                  explanation:
                      'The academic session or year for which this fee applies. Helps distinguish recurring annual sessions.',
                  example: '2026-27, 2026 Term 1, Class 10 Session',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 3: Financials
            _SectionHeader(icon: Icons.payments_rounded, label: 'FEE FINANCIALS'),
            const SizedBox(height: 10),

            MoneyInputField(
              controller: _grossController,
              label: 'Gross Course Fee Amount',
              helperText: 'Standard fee amount before any concession',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MoneyInputField(
                    controller: _discountController,
                    label: 'Concession / Scholarship (Optional)',
                    isRequired: false,
                    helperText: 'Deduction for merit, sibling, or scholarship',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: ContextualHelpButton(
                    title: 'Fee Concession',
                    explanation:
                        'Any scholarship, sibling discount, or fee reduction granted to the student. The net payable fee updates automatically.',
                    example:
                        '₹ 2,000.00 sibling discount, ₹ 5,000.00 merit scholarship',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Live Net Fee Preview Card ──────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
                boxShadow: AppColors.cardShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Net Fee Payable',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.formatPaise(net),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brand,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Section 4: Due Date
            _SectionHeader(icon: Icons.event_rounded, label: 'PAYMENT SCHEDULE'),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDueDate,
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: _inputDecoration(
                        'Due Date *',
                        Icons.calendar_today_outlined,
                      ),
                      child: Text(
                        CurrencyFormatter.formatDisplayDate(
                          CurrencyFormatter.toYmd(_selectedDueDate),
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const ContextualHelpButton(
                  title: 'Due Date',
                  explanation:
                      'The deadline by which this fee installment must be paid. If unpaid past this date, it is flagged as Overdue on your Academy Dashboard.',
                  example: '15th of the month, or term commencement date',
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: _inputDecoration(
                'Notes / Remarks (Optional)',
                Icons.notes_outlined,
                hint: 'e.g. Includes lab and exam charges',
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  shadowColor: AppColors.brand.withValues(alpha: 0.45),
                  elevation: 8,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isEdit
                            ? 'Update Fee Installment'
                            : 'Save Fee Installment',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
      prefixIcon: Icon(icon, color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.brand, width: 2),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Section header widget
// ────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.brandLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 13, color: AppColors.brand),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
