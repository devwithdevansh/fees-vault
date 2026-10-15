import 'package:intl/intl.dart';
import '../errors/app_exceptions.dart';

/// Accurate, integer-paise currency parsing and Indian English (en_IN) formatting.
/// Guarantees that financial records never lose precision from floating point errors.
class CurrencyFormatter {
  static final NumberFormat _inrWithDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _inrIntegerOnly = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// Parse a user decimal input string strictly into integer paise (1 Rupee = 100 paise).
  /// Rejects negative amounts, more than 2 fractional digits, and invalid characters.
  static int parseToPaise(String input) {
    final clean = input.replaceAll('₹', '').replaceAll(',', '').trim();
    if (clean.isEmpty) {
      throw const ValidationException('Amount cannot be empty');
    }

    // Strict regex matching: digits only or digits with 1 or 2 decimal digits
    final regex = RegExp(r'^\d+(\.\d{1,2})?$');
    if (!regex.hasMatch(clean)) {
      throw const ValidationException(
        'Invalid amount format. Enter a positive number with at most 2 decimal places (e.g. 500 or 500.50)',
      );
    }

    final parts = clean.split('.');
    final rupees = int.tryParse(parts[0]);
    if (rupees == null) {
      throw const ValidationException('Invalid rupees amount');
    }

    int paise = 0;
    if (parts.length > 1) {
      final decimalStr = parts[1].padRight(2, '0');
      paise = int.tryParse(decimalStr) ?? 0;
    }

    final totalPaise = rupees * 100 + paise;
    if (totalPaise <= 0 && clean != '0' && clean != '0.00' && clean != '0.0') {
      throw const ValidationException('Amount must be positive');
    }

    return totalPaise;
  }

  /// Formats paise integer to en_IN format.
  /// If showDecimalsIfZero is false and paise is an exact rupee, skips .00 for cleaner UI.
  static String formatPaise(int paise, {bool includeSymbol = true, bool showDecimalsIfZero = false}) {
    final isNegative = paise < 0;
    final absPaise = paise.abs();
    final rupeesValue = absPaise / 100.0;

    String formatted;
    if (absPaise % 100 == 0 && !showDecimalsIfZero) {
      formatted = _inrIntegerOnly.format(rupeesValue);
    } else {
      formatted = _inrWithDecimals.format(rupeesValue);
    }

    if (!includeSymbol) {
      formatted = formatted.replaceAll('₹', '').trim();
    }

    return isNegative ? '-$formatted' : formatted;
  }

  /// Converts paise to a decimal string suitable for form text fields (e.g. 10050 -> "100.50", 10000 -> "100").
  static String paiseToEditableString(int paise) {
    if (paise % 100 == 0) {
      return (paise ~/ 100).toString();
    } else {
      final rupees = paise ~/ 100;
      final remainder = (paise % 100).toString().padLeft(2, '0');
      return '$rupees.$remainder';
    }
  }

  /// Formats a date-only string YYYY-MM-DD to human readable "dd MMM yyyy"
  static String formatDisplayDate(String ymdDate) {
    try {
      final dt = parseDate(ymdDate);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return ymdDate;
    }
  }

  /// Parses date-only string YYYY-MM-DD
  static DateTime parseDate(String ymdDate) {
    final parts = ymdDate.split('-');
    if (parts.length != 3) {
      throw ValidationException('Invalid date format: $ymdDate. Expected YYYY-MM-DD');
    }
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Converts DateTime to date-only string YYYY-MM-DD
  static String toYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Checks if a due date is strictly before device's today calendar date.
  /// Note: Today's due date is NOT overdue.
  static bool isDateOverdue(String ymdDueDate) {
    try {
      final due = parseDate(ymdDueDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return due.isBefore(today);
    } catch (_) {
      return false;
    }
  }
}
