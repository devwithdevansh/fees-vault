import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../data/models/batch.dart';
import '../../data/models/payer.dart';
import '../controllers/vault_controller.dart';
import '../widgets/app_card.dart';
import 'batch_form_screen.dart';

/// Screen to register a new student or edit existing student details,
/// with batch enrollment and automated fee template application.
class PayerFormScreen extends StatefulWidget {
  final VaultController controller;
  final Payer? payerToEdit;
  final Batch? initialBatch;

  const PayerFormScreen({
    super.key,
    required this.controller,
    this.payerToEdit,
    this.initialBatch,
  });

  @override
  State<PayerFormScreen> createState() => _PayerFormScreenState();
}

class _PayerFormScreenState extends State<PayerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _notesController;
  late TextEditingController _concessionController;

  String? _selectedBatchId;
  String? _customBatchName;
  bool _applyBatchFees = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.payerToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _phoneController = TextEditingController(text: p?.phone ?? '');
    _notesController = TextEditingController(text: p?.notes ?? '');
    _concessionController = TextEditingController(text: '');

    if (p != null) {
      _selectedBatchId = p.batchId;
      _customBatchName = p.batch;
    } else if (widget.initialBatch != null) {
      _selectedBatchId = widget.initialBatch!.id;
    } else if (widget.controller.batches.isNotEmpty) {
      _selectedBatchId = widget.controller.batches.first.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _concessionController.dispose();
    super.dispose();
  }

  Batch? get _selectedBatch {
    if (_selectedBatchId == null) return null;
    try {
      return widget.controller.batches.firstWhere(
        (b) => b.id == _selectedBatchId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final studentName = _nameController.text.trim();
      final batch = _selectedBatch;
      final batchName = batch?.name ?? _customBatchName?.trim();

      int concessionPaise = 0;
      if (_concessionController.text.trim().isNotEmpty) {
        final rupees = double.tryParse(_concessionController.text.trim()) ?? 0;
        concessionPaise = (rupees * 100).round();
      }

      if (widget.payerToEdit == null) {
        await widget.controller.addPayer(
          name: studentName,
          phone: _phoneController.text.trim(),
          batch: batchName,
          batchId: batch?.id,
          notes: _notesController.text.trim(),
          applyBatchFees: _applyBatchFees,
          concessionPaise: concessionPaise,
        );
      } else {
        final updated = widget.payerToEdit!.copyWith(
          name: studentName,
          phone: _phoneController.text.trim(),
          batch: batchName,
          batchId: batch?.id,
          notes: _notesController.text.trim(),
        );
        await widget.controller.updatePayer(updated);
      }

      // Gentle haptic feedback on successful save
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
                    widget.payerToEdit == null
                        ? 'Student "$studentName" registered successfully.'
                        : 'Student details updated.',
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
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.payerToEdit != null;
    final batches = widget.controller.batches;
    final selectedBatch = _selectedBatch;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Student Details' : 'Register New Student',
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Section: Student Information
            const Row(
              children: [
                Text(
                  'STUDENT INFORMATION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _nameController,
              autofocus: !isEdit,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                label: 'Student Name *',
                hint: 'e.g. Aarav Sharma',
                icon: Icons.person_outline,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter the student\'s name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Batch selection
            if (batches.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedBatchId,
                      decoration: _inputDecoration(
                        label: 'Course / Batch *',
                        hint: 'Select a batch',
                        icon: Icons.school_outlined,
                      ),
                      items: batches.map((b) {
                        return DropdownMenuItem<String>(
                          value: b.id,
                          child: Text(
                            '${b.name} (${b.academicYear})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedBatchId = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: AppColors.brand,
                    ),
                    tooltip: 'Create New Batch',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BatchFormScreen(controller: widget.controller),
                        ),
                      );
                      setState(() {});
                    },
                  ),
                ],
              ),
            ] else ...[
              // If no batches exist yet, provide a quick link to create batch or enter text
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.brand),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No batches created yet. You can create a batch to configure standard fees.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BatchFormScreen(controller: widget.controller),
                          ),
                        );
                        setState(() {});
                      },
                      child: const Text('Create Batch'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // If a batch is selected and we are creating a new student: Auto-charge banner!
            if (!isEdit && selectedBatch != null) ...[
              AppCard(
                backgroundColor: AppColors.brandLight.withValues(alpha: 0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bolt,
                          color: AppColors.brand,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Batch Fee Structure: ${CurrencyFormatter.formatPaise(selectedBatch.standardBatchFeePaise)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedBatch.feeTemplates.isNotEmpty
                          ? '${selectedBatch.feeTemplates.length} standard installment(s) configured'
                          : 'No standard installments configured in this batch yet',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (selectedBatch.feeTemplates.isNotEmpty) ...[
                      const Divider(height: 16, color: AppColors.divider),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                          'Charge batch fee structure immediately',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: const Text(
                          'Creates standard fee obligations automatically for this student',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        value: _applyBatchFees,
                        activeThumbColor: AppColors.brand,
                        onChanged: (val) =>
                            setState(() => _applyBatchFees = val),
                      ),
                      if (_applyBatchFees) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _concessionController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Scholarship / Concession (Optional)',
                            hintText: 'e.g. 5000',
                            prefixText: '₹ ',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Section: Parent / Guardian Contact
            const Row(
              children: [
                Text(
                  'PARENT / GUARDIAN CONTACT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(
                label: 'Parent / Guardian Phone',
                hint: 'e.g. +91 98765 43210',
                icon: Icons.phone_outlined,
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: _inputDecoration(
                label: 'Student ID / Roll No / Remarks (Optional)',
                hint: 'e.g. Roll #104, Admission ID',
                icon: Icons.badge_outlined,
              ),
            ),
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
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
                      isEdit ? 'Update Student Details' : 'Register Student',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
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
