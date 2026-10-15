import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/batch.dart';
import '../controllers/vault_controller.dart';
import '../widgets/app_card.dart';

/// Screen to create or edit an Academy Course / Batch.
class BatchFormScreen extends StatefulWidget {
  final VaultController controller;
  final Batch? batchToEdit;

  const BatchFormScreen({
    super.key,
    required this.controller,
    this.batchToEdit,
  });

  @override
  State<BatchFormScreen> createState() => _BatchFormScreenState();
}

class _BatchFormScreenState extends State<BatchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late String _selectedAcademicYear;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.batchToEdit;
    _nameController = TextEditingController(text: b?.name ?? '');
    _notesController = TextEditingController(text: b?.notes ?? '');

    final availableYears = widget.controller.academicYears.map((ay) => ay.name).toList();
    if (b != null && availableYears.contains(b.academicYear)) {
      _selectedAcademicYear = b.academicYear;
    } else if (widget.controller.selectedAcademicYearFilter != null &&
        availableYears.contains(widget.controller.selectedAcademicYearFilter)) {
      _selectedAcademicYear = widget.controller.selectedAcademicYearFilter!;
    } else if (availableYears.isNotEmpty) {
      _selectedAcademicYear = availableYears.first;
    } else {
      _selectedAcademicYear = '2026-2027';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final notes = _notesController.text.trim();

      if (widget.batchToEdit == null) {
        await widget.controller.createBatch(
          name: name,
          academicYear: _selectedAcademicYear,
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        final updated = widget.batchToEdit!.copyWith(
          name: name,
          academicYear: _selectedAcademicYear,
          notes: notes.isEmpty ? null : notes,
        );
        await widget.controller.updateBatch(updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.batchToEdit == null
                  ? 'Batch "$name" created successfully.'
                  : 'Batch updated.',
            ),
            backgroundColor: AppColors.settledGreen,
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
    final isEditing = widget.batchToEdit != null;
    final academicYears = widget.controller.academicYears;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Batch' : 'New Batch / Course'),
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
                        'Batch Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navyDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Batches group your students by class or course. You can set standard fees once and charge all students in this batch.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.slate,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Academic Year selector
                      const Text(
                        'Academic Year',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.navyDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedAcademicYear,
                        decoration: InputDecoration(
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
                        items: academicYears.map((ay) {
                          return DropdownMenuItem<String>(
                            value: ay.name,
                            child: Row(
                              children: [
                                Text(ay.name),
                                if (ay.isCurrent) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryTealLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Current',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryTealDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedAcademicYear = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      // Batch name
                      const Text(
                        'Batch / Course Name *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.navyDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'e.g. Class 10 - Science, NEET Morning',
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
                            return 'Please enter a batch name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Notes / Description
                      const Text(
                        'Notes / Timings (Optional)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.navyDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g. Mon-Fri 8:00 AM - 10:00 AM, Room 3',
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
                    backgroundColor: AppColors.primaryTealDark,
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
                          isEditing ? 'Save Changes' : 'Create Batch',
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
