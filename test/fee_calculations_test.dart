import 'package:flutter_test/flutter_test.dart';
import 'package:fees_vault/core/errors/app_exceptions.dart';
import 'package:fees_vault/core/formatters/currency_formatter.dart';
import 'package:fees_vault/data/models/charge.dart';

void main() {
  group('CurrencyFormatter & Decimal Input Tests', () {
    test('Strict integer paise parsing rejects >2 decimal places', () {
      expect(() => CurrencyFormatter.parseToPaise('100.123'), throwsA(isA<ValidationException>()));
      expect(() => CurrencyFormatter.parseToPaise('50.999'), throwsA(isA<ValidationException>()));
    });

    test('Strict integer paise parsing rejects negative or alphabetic input', () {
      expect(() => CurrencyFormatter.parseToPaise('-500'), throwsA(isA<ValidationException>()));
      expect(() => CurrencyFormatter.parseToPaise('abc'), throwsA(isA<ValidationException>()));
      expect(() => CurrencyFormatter.parseToPaise(''), throwsA(isA<ValidationException>()));
    });

    test('Parses exact rupees and paise correctly into integer paise without float errors', () {
      expect(CurrencyFormatter.parseToPaise('10000'), equals(1000000));
      expect(CurrencyFormatter.parseToPaise('10000.00'), equals(1000000));
      expect(CurrencyFormatter.parseToPaise('10000.50'), equals(1000050));
      expect(CurrencyFormatter.parseToPaise('0.05'), equals(5));
      expect(CurrencyFormatter.parseToPaise('0.5'), equals(50));
      expect(CurrencyFormatter.parseToPaise('0'), equals(0));
    });

    test('Formats paise into Indian English grouping (en_IN)', () {
      // 10,000 INR = 1000000 paise
      expect(CurrencyFormatter.formatPaise(1000000), equals('₹10,000'));
      // 1,23,456.50 INR = 12345650 paise
      expect(CurrencyFormatter.formatPaise(12345650), equals('₹1,23,456.50'));
    });

    test('Due date overdue check compares strictly against calendar date', () {
      final now = DateTime.now();
      final todayYmd = CurrencyFormatter.toYmd(now);
      final yesterdayYmd = CurrencyFormatter.toYmd(now.subtract(const Duration(days: 1)));
      final tomorrowYmd = CurrencyFormatter.toYmd(now.add(const Duration(days: 1)));

      // Yesterday is overdue
      expect(CurrencyFormatter.isDateOverdue(yesterdayYmd), isTrue);
      // Today is NOT overdue
      expect(CurrencyFormatter.isDateOverdue(todayYmd), isFalse);
      // Tomorrow is NOT overdue
      expect(CurrencyFormatter.isDateOverdue(tomorrowYmd), isFalse);
    });
  });

  group('Charge Math & Settlement Acceptance Checks', () {
    test('Payer + INR 10,000 charge - INR 1,000 discount + INR 4,000 payment = INR 5,000 outstanding', () {
      // 10,000 INR = 1,000,000 paise
      final grossPaise = CurrencyFormatter.parseToPaise('10000');
      // 1,000 INR = 100,000 paise
      final discountPaise = CurrencyFormatter.parseToPaise('1000');
      // 4,000 INR = 400,000 paise
      final paidPaise = CurrencyFormatter.parseToPaise('4000');

      final charge = Charge(
        id: 'c1',
        payerId: 'p1',
        title: 'Tuition Term 1',
        grossPaise: grossPaise,
        discountPaise: discountPaise,
        dueDate: '2026-12-31',
        createdAt: 1,
        updatedAt: 1,
        paidPaise: paidPaise,
      );

      expect(charge.netChargePaise, equals(900000)); // INR 9,000
      expect(charge.outstandingPaise, equals(500000)); // INR 5,000
      expect(charge.status, equals(ChargeStatus.partial));
      expect(charge.isSettled, isFalse);
    });

    test('Another INR 5,000 payment settles charge; extra payment exceeds headroom', () {
      final grossPaise = CurrencyFormatter.parseToPaise('10000');
      final discountPaise = CurrencyFormatter.parseToPaise('1000');
      final totalPaidPaise = CurrencyFormatter.parseToPaise('9000');

      final settledCharge = Charge(
        id: 'c1',
        payerId: 'p1',
        title: 'Tuition Term 1',
        grossPaise: grossPaise,
        discountPaise: discountPaise,
        dueDate: '2026-12-31',
        createdAt: 1,
        updatedAt: 1,
        paidPaise: totalPaidPaise,
      );

      expect(settledCharge.netChargePaise, equals(900000));
      expect(settledCharge.outstandingPaise, equals(0)); // INR 0
      expect(settledCharge.status, equals(ChargeStatus.settled));
      expect(settledCharge.isSettled, isTrue);

      // Any additional payment of e.g. 1 paisa violates headroom
      final extraPayment = 100;
      expect(extraPayment > settledCharge.outstandingPaise, isTrue);
    });

    test('Zero-net discounted charge is settled immediately', () {
      final grossPaise = CurrencyFormatter.parseToPaise('5000');
      final discountPaise = CurrencyFormatter.parseToPaise('5000');

      final charge = Charge(
        id: 'c2',
        payerId: 'p2',
        title: 'Scholarship Waiver',
        grossPaise: grossPaise,
        discountPaise: discountPaise,
        dueDate: '2026-12-31',
        createdAt: 1,
        updatedAt: 1,
        paidPaise: 0,
      );

      expect(charge.netChargePaise, equals(0));
      expect(charge.outstandingPaise, equals(0));
      expect(charge.status, equals(ChargeStatus.settled));
      expect(charge.isSettled, isTrue);
    });
  });
}
