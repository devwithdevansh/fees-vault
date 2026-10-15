import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/batch_fee_template.dart';
import '../controllers/vault_controller.dart';
import '../widgets/app_card.dart';

/// Screen to add or edit a standard fee installment template for a batch.
class BatchFeeTemplateFormScreen extends StatefulWidget {
  final VaultController controller;
  final String batchId;
  final BatchFeeTemplate? templateToEdit;

  const BatchFeeTemplateFormScreen({
    super.key,
    required this.controller,
    required this.batchId,
    this.templateToEdit,
  });

  @override
  State<BatchFeeTemplateFormScreen> createState() => _BatchFeeTemplateFormScreenState();
}

class _BatchFeeTemplateFormScreenState extends State<BatchFeeTemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _dueDateController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.templateToEdit;
    _titleController = TextEditingController(text: t?.title ?? '');
    _amountController = TextEditingController(
      text: t != null ? (t.grossPaise / 100).toStringAsFixed(0) : '',
    );
    _dueDateController = TextEditingController(
      text: t?.defaultDueDate ?? CurrencyFormatter.toYmd(DateTime.now().add(const Duration(days: 30))),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    DateTime initial = DateTime.now().add(const Duration(days: 30));
    try {
      if (_dueDateController.text.isNotEmpty) {
        initial = CurrencyFormatter.parseDate(_dueDateController.text);
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        _dueDateController.text = CurrencyFormatter.toYmd(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final title = _titleController.text.trim();
      final rupees = double.parse(_amountController.text.trim());
      final grossPaise = (rupees * 100).round();
      final dueDate = _dueDateController.text.trim().isEmpty ? null : _dueDateController.text.trim();

      if (widget.templateToEdit == null) {
        await widget.controller.addBatchFeeTemplate(
          batchId: widget.batchId,
          title: title,
          grossPaise: grossPaise,
          defaultDueDate: dueDate,
        );
      } else {
        final updated = widget.templateToEdit!.copyWith(
          title: title,
          grossPaise: grossPaise,
          defaultDueDate: dueDate,
        );
        await widget.controller.updateBatchFeeTemplate(updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.templateToEdit == null
                  ? 'Fee installment "$title" added to batch.'
                  : 'Fee installment updated.',
            ),
            backgroundColor: AppColors.settledGreen,
          ),
        );
        Navigator.pop(context, true);
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
    final isEditing = widget.templateToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Fee Installment' : 'Add Fee Installment'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Standard Fee Installment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'This fee obligation will be applied to students enrolled in this batch.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      // Title
                      const Text(
                        'Installment Title *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'e.g. Term 1 Tuition, Lab & Study Material',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.divider),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter a fee title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Amount
                      const Text(
                        'Amount (₹) *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          prefixText: '₹ ',
                          hintText: 'e.g. 15000',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.divider),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter the fee amount';
                          }
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Amount must be greater than zero';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Default Due Date
                      const Text(
                        'Default Due Date',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _dueDateController,
                        readOnly: true,
                        onTap: _pickDueDate,
                        decoration: InputDecoration(
                          hintText: 'YYYY-MM-DD',
                          suffixIcon: const Icon(Icons.calendar_today, size: 20, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.divider),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          isEditing ? 'Save Installment' : 'Add Fee Installment',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
