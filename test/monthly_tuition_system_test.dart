import 'package:flutter_test/flutter_test.dart';
import 'package:fees_vault/data/models/batch.dart';
import 'package:fees_vault/data/models/charge.dart';
import 'package:fees_vault/data/seeds/demo_data_seeder.dart';

void main() {
  group('Monthly Tuition Fee System Invariants', () {
    test('Session months accurately model 12 months from April to March', () {
      expect(DemoDataSeeder.monthNames.first, equals('April 2026'));
      expect(DemoDataSeeder.monthNames.last, equals('March 2027'));
      expect(DemoDataSeeder.monthCodes.first, equals('2026-04'));
      expect(DemoDataSeeder.monthCodes.last, equals('2027-03'));
    });

    test(
      'Charges created for monthly schedule have valid due dates and status',
      () {
        const charge = Charge(
          id: 'ch_oct_2026',
          payerId: 'payer_1',
          title: 'October 2026 Tuition Fee',
          period: 'October 2026',
          grossPaise: 200000, // ₹2,000
          discountPaise: 0,
          dueDate: '2026-10-10',
          paidPaise: 200000,
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
        );

        expect(charge.isSettled, isTrue);
        expect(charge.outstandingPaise, equals(0));
        expect(charge.dueDate, equals('2026-10-10'));
      },
    );

    test('Batch model aggregates monthly fee structure cleanly', () {
      final batch = Batch(
        id: 'batch_class_10',
        name: 'Class 10 - Board Master Batch',
        academicYear: '2026-2027',
        studentCount: 10,
        totalFeePaise: 25500000, // 10 * ₹25,500
        totalCollectedPaise: 15000000,
        totalOutstandingPaise: 10500000,
        feeTemplates: const [],
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
      );

      expect(batch.name, contains('Class 10'));
      expect(batch.totalOutstandingPaise, equals(10500000));
    });
  });
}
