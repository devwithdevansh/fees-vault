import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/charge.dart';
import '../../data/models/payment.dart';
import '../controllers/vault_controller.dart';
import '../widgets/money_input_field.dart';
import 'payment_detail_receipt_screen.dart';

/// Screen to record a payment or edit an existing entry with mandatory audit reasoning.
class PaymentFormScreen extends StatefulWidget {
  final VaultController controller;
  final String? targetChargeId;
  final int? suggestedAmountPaise;
  final Payment? paymentToEdit;

  const PaymentFormScreen({
    super.key,
    required this.controller,
    this.targetChargeId,
    this.suggestedAmountPaise,
    this.paymentToEdit,
  });

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  List<Charge> _availableCharges = [];
  String? _selectedChargeId;
  Charge? _selectedCharge;

  late TextEditingController _amountController;
  late TextEditingController _referenceController;
  late TextEditingController _notesController;
  late TextEditingController _reasonController;

  late DateTime _selectedPaidDate;
  String _selectedMethod = 'UPI';
  bool _isSaving = false;
  bool _isLoadingCharges = true;

  @override
  void initState() {
    super.initState();
    final pm = widget.paymentToEdit;

    _amountController = TextEditingController(
      text: pm != null
          ? CurrencyFormatter.paiseToEditableString(pm.amountPaise)
          : (widget.suggestedAmountPaise != null
                ? CurrencyFormatter.paiseToEditableString(
                    widget.suggestedAmountPaise!,
                  )
                : ''),
    );
    _referenceController = TextEditingController(text: pm?.reference ?? '');
    _notesController = TextEditingController(text: pm?.notes ?? '');
    _reasonController = TextEditingController();

    if (pm != null) {
      _selectedPaidDate = CurrencyFormatter.parseDate(pm.paidDate);
      _selectedMethod = pm.method;
      _selectedChargeId = pm.chargeId;
    } else {
      _selectedPaidDate = DateTime.now();
      _selectedChargeId = widget.targetChargeId;
    }

    _loadAvailableCharges();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableCharges() async {
    try {
      final all = await widget.controller.chargeRepo.getAllCharges();
      // If new payment, prefer charges with outstanding > 0 or the pre-selected one
      final filtered = widget.paymentToEdit != null
          ? all
          : all
                .where(
                  (c) =>
                      c.outstandingPaise > 0 || c.id == widget.targetChargeId,
                )
                .toList();

      Charge? current;
      if (_selectedChargeId != null) {
        current = all.firstWhere(
          (c) => c.id == _selectedChargeId,
          orElse: () => filtered.isNotEmpty ? filtered.first : all.first,
        );
      } else if (filtered.isNotEmpty) {
        current = filtered.first;
        _selectedChargeId = current.id;
        if (_amountController.text.isEmpty && current.outstandingPaise > 0) {
          _amountController.text = CurrencyFormatter.paiseToEditableString(
            current.outstandingPaise,
          );
        }
      }

      if (mounted) {
        setState(() {
          _availableCharges = filtered;
          _selectedCharge = current;
          _isLoadingCharges = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCharges = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedPaidDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedPaidDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (_selectedChargeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a fee installment.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final isEdit = widget.paymentToEdit != null;

    if (isEdit && _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Correction reason is strictly mandatory when editing a payment.',
          ),
          backgroundColor: AppColors.overdueRed,
        ),
      );
      return;
    }

    final amountPaise = CurrencyFormatter.parseToPaise(_amountController.text);
    if (amountPaise <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment amount must be greater than zero.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final ymdDate = CurrencyFormatter.toYmd(_selectedPaidDate);

      if (!isEdit) {
        final payment = await widget.controller.recordPayment(
          chargeId: _selectedChargeId!,
          amountPaise: amountPaise,
          paidDate: ymdDate,
          method: _selectedMethod,
          reference: _referenceController.text.trim(),
          notes: _notesController.text.trim(),
        );

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
                      'Payment of ${CurrencyFormatter.formatPaise(amountPaise)} recorded. Receipt #${payment.receiptNumber} issued.',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.settledGreen,
              duration: const Duration(seconds: 4),
            ),
          );

          // Direct receipt viewing workflow!
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentDetailReceiptScreen(
                paymentId: payment.id,
                controller: widget.controller,
              ),
            ),
          );
        }
      } else {
        final updated = widget.paymentToEdit!.copyWith(
          amountPaise: amountPaise,
          paidDate: ymdDate,
          method: _selectedMethod,
          reference: _referenceController.text.trim(),
          notes: _notesController.text.trim(),
        );
        await widget.controller.updatePayment(
          payment: updated,
          correctionReason: _reasonController.text.trim(),
        );

        HapticFeedback.lightImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Payment entry updated with correction audit trail.',
              ),
              backgroundColor: AppColors.settledGreen,
            ),
          );
          Navigator.pop(context);
        }
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
    final isEdit = widget.paymentToEdit != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Payment Entry' : 'Record Fee Payment',
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
      body: _isLoadingCharges
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Fee Installment selection (disabled if editing)
                  if (!isEdit && widget.targetChargeId == null) ...[
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedChargeId,
                      items: _availableCharges.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            '${c.payerName}: ${c.title} (Due: ${CurrencyFormatter.formatPaise(c.outstandingPaise)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedChargeId = val;
                          _selectedCharge = _availableCharges.firstWhere(
                            (c) => c.id == val,
                          );
                          if (_selectedCharge != null &&
                              _selectedCharge!.outstandingPaise > 0) {
                            _amountController.text =
                                CurrencyFormatter.paiseToEditableString(
                                  _selectedCharge!.outstandingPaise,
                                );
                          }
                        });
                      },
                      decoration: _inputDecoration(
                        'Select Fee Installment *',
                        Icons.receipt_long_outlined,
                      ),
                      validator: (v) =>
                          v == null ? 'Please select a fee installment' : null,
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
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
                                decoration: const BoxDecoration(
                                  gradient: AppColors.brandGradient,
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppColors.brandLight,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.school_rounded,
                                              size: 14,
                                              color: AppColors.brand,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _selectedCharge?.payerName ??
                                                  'Student',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14.5,
                                                color: AppColors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _selectedCharge?.title ??
                                            'Fee Installment',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (_selectedCharge != null) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.overdueRedBg,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Due: ${CurrencyFormatter.formatPaise(_selectedCharge!.outstandingPaise)}',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.overdueRed,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Amount Input Field
                  MoneyInputField(
                    controller: _amountController,
                    label: 'Payment Amount',
                    helperText: _selectedCharge != null
                        ? 'Max allowed headroom: ${CurrencyFormatter.formatPaise(_selectedCharge!.outstandingPaise)}'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Payment Method Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedMethod,
                    items: AppConstants.paymentMethods.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m));
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedMethod = val ?? 'UPI'),
                    decoration: _inputDecoration(
                      'Payment Method *',
                      Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Paid Date Picker
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: _inputDecoration(
                        'Date Paid *',
                        Icons.calendar_today_outlined,
                      ),
                      child: Text(
                        CurrencyFormatter.formatDisplayDate(
                          CurrencyFormatter.toYmd(_selectedPaidDate),
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _referenceController,
                    decoration: _inputDecoration(
                      'Reference / UPI UTR / Bank Ref (Optional)',
                      Icons.tag,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: _inputDecoration(
                      'Notes / Remarks (Optional)',
                      Icons.notes_outlined,
                    ),
                  ),

                  // Mandatory correction reason when editing!
                  if (isEdit) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.unpaidAmber.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.unpaidAmber.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.gavel_rounded,
                              size: 14,
                              color: AppColors.unpaidAmber,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Audit Trail Notice: Any edit to a committed payment is permanently recorded in the local correction history.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.unpaidAmber,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _reasonController,
                      decoration: _inputDecoration(
                        'Correction Reason * (Mandatory)',
                        Icons.history_edu_outlined,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter a correction reason'
                          : null,
                    ),
                  ],

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
                                  ? 'Save Correction'
                                  : 'Commit & View Receipt',
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
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
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
