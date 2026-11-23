import 'package:flutter_test/flutter_test.dart';
import 'package:fees_vault/core/constants/fee_partition_presets.dart';

void main() {
  group('FeePartitionPresets Tests', () {
    test('DEFAULT_12_2 generates 14 equal parts summing to annual fee', () {
      const annualFeePaise = 2800000; // ₹28,000.00
      final parts = FeePartitionHelper.generatePresetParts(
        type: FeeScheduleType.default12_2,
        annualFeePaise: annualFeePaise,
        startYear: 2026,
        sessionStart: SessionStartMonth.june,
        dueDay: 10,
      );

      expect(parts.length, 14);

      // Verify sequence: Term 1, June..Nov, Term 2, Dec..May
      expect(parts[0].title, 'Term 1 Fee');
      expect(parts[0].feeType, 'TERM');
      expect(parts[0].dueDate, '2026-06-15');

      expect(parts[1].title, 'June Tuition Fee');
      expect(parts[1].feeType, 'EDUCATION');

      expect(parts[7].title, 'Term 2 Fee');
      expect(parts[7].feeType, 'TERM');
      expect(parts[7].dueDate, '2026-11-15');

      expect(parts[8].title, 'December Tuition Fee');
      expect(parts[13].title, 'May Tuition Fee');

      // Verify sum equals exactly annual fee
      final sum = parts.fold<int>(0, (acc, p) => acc + p.grossPaise);
      expect(sum, annualFeePaise);

      // 28,000 / 14 = exactly 2,000 per part
      for (final p in parts) {
        expect(p.grossPaise, 200000);
      }
    });

    test('DEFAULT_12_2 with odd annual fee distributes remainder without loss', () {
      const annualFeePaise = 2800050; // ₹28,000.50
      final parts = FeePartitionHelper.generatePresetParts(
        type: FeeScheduleType.default12_2,
        annualFeePaise: annualFeePaise,
        startYear: 2026,
      );

      final sum = parts.fold<int>(0, (acc, p) => acc + p.grossPaise);
      expect(sum, annualFeePaise);
    });

    test('DEFAULT_12_2 with termFeeOverride allocates specific amount to terms', () {
      const annualFeePaise = 3000000; // ₹30,000
      const termOverridePaise = 300000; // ₹3,000 per term

      final parts = FeePartitionHelper.generatePresetParts(
        type: FeeScheduleType.default12_2,
        annualFeePaise: annualFeePaise,
        startYear: 2026,
        termFeeOverridePaise: termOverridePaise,
      );

      expect(parts.length, 14);
      final term1 = parts.firstWhere((p) => p.title == 'Term 1 Fee');
      final term2 = parts.firstWhere((p) => p.title == 'Term 2 Fee');
      expect(term1.grossPaise, termOverridePaise);
      expect(term2.grossPaise, termOverridePaise);

      // Remaining for 12 education parts = 30,000 - 6,000 = 24,000 -> 2,000/mo
      final eduParts = parts.where((p) => p.feeType == 'EDUCATION').toList();
      expect(eduParts.length, 12);
      for (final p in eduParts) {
        expect(p.grossPaise, 200000);
      }

      final sum = parts.fold<int>(0, (acc, p) => acc + p.grossPaise);
      expect(sum, annualFeePaise);
    });

    test('MONTHLY_12 generates 12 monthly installments', () {
      const annualFeePaise = 2400000; // ₹24,000.00
      final parts = FeePartitionHelper.generatePresetParts(
        type: FeeScheduleType.monthly12,
        annualFeePaise: annualFeePaise,
        startYear: 2026,
        sessionStart: SessionStartMonth.june,
      );

      expect(parts.length, 12);
      expect(parts.first.title, 'June Tuition Fee');
      expect(parts.last.title, 'May Tuition Fee');

      final sum = parts.fold<int>(0, (acc, p) => acc + p.grossPaise);
      expect(sum, annualFeePaise);
    });

    test('QUARTERLY_4 generates 4 quarters summing to annual fee', () {
      const annualFeePaise = 2400000; // ₹24,000.00
      final parts = FeePartitionHelper.generatePresetParts(
        type: FeeScheduleType.quarterly4,
        annualFeePaise: annualFeePaise,
        startYear: 2026,
        sessionStart: SessionStartMonth.june,
      );

      expect(parts.length, 4);
      expect(parts[0].title, '1st Quarter (Jun - Aug)');
      expect(parts[1].title, '2nd Quarter (Sep - Nov)');
      expect(parts[2].title, '3rd Quarter (Dec - Feb)');
      expect(parts[3].title, '4th Quarter (Mar - May)');

      final sum = parts.fold<int>(0, (acc, p) => acc + p.grossPaise);
      expect(sum, annualFeePaise);
    });

    test('HALF_YEARLY_2 generates 2 semester installments', () {
      const annualFeePaise = 2000000; // ₹20,000.00
      final parts = FeePartitionHelper.generatePresetParts(
        type: FeeScheduleType.halfYearly2,
        annualFeePaise: annualFeePaise,
        startYear: 2026,
        sessionStart: SessionStartMonth.june,
      );

      expect(parts.length, 2);
      expect(parts[0].title, 'Term 1 Installment (Jun - Nov)');
      expect(parts[1].title, 'Term 2 Installment (Dec - May)');

      final sum = parts.fold<int>(0, (acc, p) => acc + p.grossPaise);
      expect(sum, annualFeePaise);
    });

    test('ANNUAL_1 generates 1 upfront payment', () {
      const annualFeePaise = 2500000;
      final parts = FeePartitionHelper.generatePresetParts(
        type: FeeScheduleType.annual1,
        annualFeePaise: annualFeePaise,
        startYear: 2026,
      );

      expect(parts.length, 1);
      expect(parts[0].title, 'Full Annual Fee');
      expect(parts[0].grossPaise, annualFeePaise);
    });

    test('Includes Admission Fee and Bag & Kit Fee when specified', () {
      const annualFeePaise = 2800000;
      const admissionFeePaise = 150000; // ₹1,500
      const bagKitFeePaise = 80000; // ₹800

      final parts = FeePartitionHelper.generatePresetParts(
        type: FeeScheduleType.default12_2,
        annualFeePaise: annualFeePaise,
        startYear: 2026,
        admissionFeePaise: admissionFeePaise,
        bagKitFeePaise: bagKitFeePaise,
      );

      // 14 main parts + 1 admission + 1 bag & kit = 16 parts
      expect(parts.length, 16);
      expect(parts[0].title, 'Admission Fee');
      expect(parts[0].feeType, 'ADMISSION');
      expect(parts[0].grossPaise, admissionFeePaise);

      expect(parts[1].title, 'Bag & Kit Fee');
      expect(parts[1].feeType, 'BAG_KIT');
      expect(parts[1].grossPaise, bagKitFeePaise);

      final totalSum = parts.fold<int>(0, (acc, p) => acc + p.grossPaise);
      expect(totalSum, annualFeePaise + admissionFeePaise + bagKitFeePaise);
    });
  });
}
