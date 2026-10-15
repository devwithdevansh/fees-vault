import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';

/// Form input field specialized for currency (rupees & paise) entry.
class MoneyInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? helperText;
  final bool isRequired;
  final String? Function(String?)? customValidator;
  final ValueChanged<String>? onChanged;

  const MoneyInputField({
    super.key,
    required this.controller,
    required this.label,
    this.helperText,
    this.isRequired = true,
    this.customValidator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        helperText: helperText,
        prefixText: '₹ ',
        prefixStyle: const TextStyle(
          color: AppColors.navyDark,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
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
          borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
        ),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) {
          return 'Please enter an amount';
        }
        if (value != null && value.trim().isNotEmpty) {
          try {
            final paise = CurrencyFormatter.parseToPaise(value);
            if (isRequired && paise <= 0) {
              return 'Amount must be greater than zero';
            }
          } catch (e) {
            return e.toString();
          }
        }
        if (customValidator != null) {
          return customValidator!(value);
        }
        return null;
      },
    );
  }
}
