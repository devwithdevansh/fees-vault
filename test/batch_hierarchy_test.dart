import 'package:flutter_test/flutter_test.dart';
import 'package:fees_vault/data/models/academic_year.dart';
import 'package:fees_vault/data/models/batch.dart';
import 'package:fees_vault/data/models/batch_fee_template.dart';
import 'package:fees_vault/data/models/charge.dart';
import 'package:fees_vault/data/models/payer.dart';

void main() {
  group('Academy Hierarchy Domain Invariants', () {
    test('1. Academic Year model defines fiscal/academic cycle and current active status', () {
      final ay = AcademicYear(
        id: 'ay_2026_27',
        name: '2026-2027',
        isCurrent: true,
        createdAt: 1700000000000,
      );

      expect(ay.name, equals('2026-2027'));
      expect(ay.isCurrent, isTrue);

      final map = ay.toMap();
      expect(map['isCurrent'], equals(1));

      final restored = AcademicYear.fromMap(map);
      expect(restored.isCurrent, isTrue);
      expect(restored.name, equals('2026-2027'));
    });

    test('2. Batches tie to an Academic Year and aggregate fee templates', () {
      const template1 = BatchFeeTemplate(
        id: 't_1',
        batchId: 'b_class_10',
        title: 'Term 1 Tuition',
        grossPaise: 1500000, // ₹ 15,000.00
        defaultDueDate: '2026-06-30',
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
      );

      const template2 = BatchFeeTemplate(
        id: 't_2',
        batchId: 'b_class_10',
        title: 'Term 2 Tuition',
        grossPaise: 1500000, // ₹ 15,000.00
        defaultDueDate: '2026-10-31',
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
      );

      const template3 = BatchFeeTemplate(
        id: 't_3',
        batchId: 'b_class_10',
        title: 'Lab & Study Material',
        grossPaise: 500000, // ₹ 5,000.00
        defaultDueDate: '2026-07-15',
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
      );

      final batch = Batch(
        id: 'b_class_10',
        name: 'Class 10 - Science',
        academicYear: '2026-2027',
        notes: 'Room 4, Morning 8 AM',
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
        studentCount: 20,
        feeTemplates: const [template1, template2, template3],
      );

      // Total standard fee per student in this batch: 15k + 15k + 5k = 35k (3,500,000 paise)
      expect(batch.standardBatchFeePaise, equals(3500000));
      expect(batch.feeTemplates.length, equals(3));
      expect(batch.academicYear, equals('2026-2027'));
    });

    test('3. Enrolled students link to Batch and inherit batch fee structure', () {
      const student1 = Payer(
        id: 'st_1',
        name: 'Aarav Sharma',
        phone: '+91 98765 43210',
        batch: 'Class 10 - Science',
        batchId: 'b_class_10',
        notes: 'Roll #101',
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
      );

      expect(student1.batchId, equals('b_class_10'));
      expect(student1.courseBatch, equals('Class 10 - Science'));

      final map = student1.toMap();
      expect(map['batchId'], equals('b_class_10'));

      final restored = Payer.fromMap(map);
      expect(restored.batchId, equals('b_class_10'));
    });

    test('4. Charging batch fees applies installments with optional concession distribution', () {
      const templates = [
        BatchFeeTemplate(
          id: 't_1',
          batchId: 'b_class_10',
          title: 'Term 1 Tuition',
          grossPaise: 1500000, // ₹ 15,000
          defaultDueDate: '2026-06-30',
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
        ),
        BatchFeeTemplate(
          id: 't_2',
          batchId: 'b_class_10',
          title: 'Term 2 Tuition',
          grossPaise: 1500000, // ₹ 15,000
          defaultDueDate: '2026-10-31',
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
        ),
      ];

      // Student has ₹ 5,000 scholarship concession
      const concessionPaise = 500000;
      var remainingConcession = concessionPaise;

      final generatedCharges = <Charge>[];
      for (final t in templates) {
        int discountForThis = 0;
        if (remainingConcession > 0) {
          discountForThis = remainingConcession <= t.grossPaise ? remainingConcession : t.grossPaise;
          remainingConcession -= discountForThis;
        }

        generatedCharges.add(Charge(
          id: 'ch_${t.id}',
          payerId: 'st_1',
          batchId: t.batchId,
          title: t.title,
          grossPaise: t.grossPaise,
          discountPaise: discountForThis,
          dueDate: t.defaultDueDate ?? '2026-12-31',
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
        ));
      }

      expect(generatedCharges.length, equals(2));
      // First installment has ₹5,000 discount applied -> Net ₹10,000
      expect(generatedCharges[0].discountPaise, equals(500000));
      expect(generatedCharges[0].netChargePaise, equals(1000000));

      // Second installment has ₹0 discount -> Net ₹15,000
      expect(generatedCharges[1].discountPaise, equals(0));
      expect(generatedCharges[1].netChargePaise, equals(1500000));

      // Total net fee charged: ₹25,000
      final totalNet = generatedCharges.fold<int>(0, (sum, c) => sum + c.netChargePaise);
      expect(totalNet, equals(2500000));
    });

    test('5. Idempotent charging: fee templates already charged are not duplicated', () {
      final existingCharges = [
        const Charge(
          id: 'ch_existing',
          payerId: 'st_1',
          batchId: 'b_class_10',
          title: 'Term 1 Tuition',
          grossPaise: 1500000,
          dueDate: '2026-06-30',
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
        ),
      ];

      const batchTemplates = [
        BatchFeeTemplate(
          id: 't_1',
          batchId: 'b_class_10',
          title: 'Term 1 Tuition',
          grossPaise: 1500000,
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
        ),
        BatchFeeTemplate(
          id: 't_2',
          batchId: 'b_class_10',
          title: 'Term 2 Tuition',
          grossPaise: 1500000,
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
        ),
      ];

      final existingTitles = existingCharges.map((c) => c.title.toLowerCase()).toSet();
      final unchargedTemplates = batchTemplates
          .where((t) => !existingTitles.contains(t.title.toLowerCase()))
          .toList();

      // Only Term 2 Tuition needs to be charged
      expect(unchargedTemplates.length, equals(1));
      expect(unchargedTemplates.first.title, equals('Term 2 Tuition'));
    });
  });
}
