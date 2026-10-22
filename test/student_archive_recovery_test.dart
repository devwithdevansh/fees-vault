import 'package:flutter_test/flutter_test.dart';
import 'package:fees_vault/data/models/payer.dart';

void main() {
  group('Student Archive & Recovery Operations', () {
    test('Payer model accurately handles archived state and copyWith toggle', () {
      const activeStudent = Payer(
        id: 'payer_1',
        name: 'Aarav Sharma',
        phone: '9876543210',
        batch: 'Class 10 - Mathematics',
        batchId: 'b_1',
        archived: false,
        totalNetPaise: 2500000,
        totalPaidPaise: 1500000,
        totalOutstandingPaise: 1000000,
        chargeCount: 5,
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
      );

      expect(activeStudent.archived, isFalse);

      // Archive operation
      final archivedStudent = activeStudent.copyWith(archived: true);
      expect(archivedStudent.archived, isTrue);
      expect(archivedStudent.name, equals('Aarav Sharma'));
      expect(archivedStudent.totalOutstandingPaise, equals(1000000));
      expect(archivedStudent.chargeCount, equals(5));

      // Recovery operation
      final recoveredStudent = archivedStudent.copyWith(archived: false);
      expect(recoveredStudent.archived, isFalse);
      expect(recoveredStudent.name, equals('Aarav Sharma'));
    });

    test('Active vs Archived student lists correctly segregate archived students', () {
      final students = [
        const Payer(
          id: 'p_1',
          name: 'Aarav Sharma',
          archived: false,
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
        ),
        const Payer(
          id: 'p_2',
          name: 'Priya Patel',
          archived: true, // Archived student
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
        ),
        const Payer(
          id: 'p_3',
          name: 'Rohan Verma',
          archived: false,
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
        ),
      ];

      final active = students.where((p) => !p.archived).toList();
      final archived = students.where((p) => p.archived).toList();

      expect(active.length, equals(2));
      expect(active.map((p) => p.name), containsAll(['Aarav Sharma', 'Rohan Verma']));
      expect(archived.length, equals(1));
      expect(archived.first.name, equals('Priya Patel'));
    });

    test('Charge assignment filters out archived students while preserving assigned student', () {
      final allPayers = [
        const Payer(
          id: 'p_1',
          name: 'Active Student 1',
          archived: false,
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
        ),
        const Payer(
          id: 'p_2',
          name: 'Archived Student',
          archived: true,
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
        ),
      ];

      // When creating a new charge (_selectedPayerId is null or p_1)
      final forNewCharge = allPayers.where((p) => !p.archived || p.id == null).toList();
      expect(forNewCharge.length, equals(1));
      expect(forNewCharge.first.name, equals('Active Student 1'));

      // When editing existing charge belonging to archived student
      const selectedPayerId = 'p_2';
      final forEditCharge = allPayers.where((p) => !p.archived || p.id == selectedPayerId).toList();
      expect(forEditCharge.length, equals(2));
    });
  });
}
