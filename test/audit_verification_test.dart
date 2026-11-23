import 'package:flutter_test/flutter_test.dart';
import 'package:fees_vault/core/formatters/currency_formatter.dart';
import 'package:fees_vault/data/models/payer.dart';
import 'package:fees_vault/presentation/screens/developer_key_screen.dart';


void main() {
  group('Comprehensive Audit Regression & Verification Tests', () {
    test('C2/C3/M2: CurrencyFormatter integer-paise strictness and 0-allowance', () {
      expect(CurrencyFormatter.parseToPaise('0'), equals(0));
      expect(CurrencyFormatter.parseToPaise('0.00'), equals(0));
      expect(CurrencyFormatter.parseToPaise('500'), equals(50000));
      expect(CurrencyFormatter.parseToPaise('2999.99'), equals(299999));
      expect(CurrencyFormatter.parseToPaise('1234.56'), equals(123456));

      // Rejects negative numbers
      expect(() => CurrencyFormatter.parseToPaise('-100'), throwsException);
      expect(() => CurrencyFormatter.parseToPaise('-0.50'), throwsException);
      // Rejects more than 2 decimal places
      expect(() => CurrencyFormatter.parseToPaise('10.999'), throwsException);
    });

    test('C6: DeveloperKeyScreen validates via SHA-256 hashes without plaintext keys in memory', () {
      // Valid keys:
      expect(DeveloperKeyScreen.isValidKey('FEESVAULTDEVKEY'), isTrue);
      expect(DeveloperKeyScreen.isValidKey('fees-vault-dev-key'), isTrue);
      expect(DeveloperKeyScreen.isValidKey('VAULTDEV2026'), isTrue);
      expect(DeveloperKeyScreen.isValidKey('vault-dev-2026'), isTrue);
      expect(DeveloperKeyScreen.isValidKey('DEVKEY2026'), isTrue);
      expect(DeveloperKeyScreen.isValidKey('dev_key_2026'), isTrue);

      // Invalid keys:
      expect(DeveloperKeyScreen.isValidKey('WRONGKEY'), isFalse);
      expect(DeveloperKeyScreen.isValidKey(''), isFalse);
      expect(DeveloperKeyScreen.isValidKey('   '), isFalse);
      expect(DeveloperKeyScreen.isValidKey('123456'), isFalse);
    });

    test('M7: Payer.copyWith allows explicitly setting nullable fields to null via sentinel', () {
      final initial = Payer(
        id: 'p_100',
        name: 'Rahul Sharma',
        phone: '9876543210',
        batch: 'Class 10',
        batchId: 'b_10',
        notes: 'Some notes',
        archived: false,
        createdAt: 1000,
        updatedAt: 1000,
      );

      // Verify normal copyWith updates
      final updatedName = initial.copyWith(name: 'Rahul V. Sharma');
      expect(updatedName.name, equals('Rahul V. Sharma'));
      expect(updatedName.phone, equals('9876543210'));

      // Verify setting phone, batch, batchId, notes to null explicitly
      final cleared = initial.copyWith(
        phone: null,
        batch: null,
        batchId: null,
        notes: null,
      );

      expect(cleared.phone, isNull);
      expect(cleared.batch, isNull);
      expect(cleared.batchId, isNull);
      expect(cleared.notes, isNull);
      expect(cleared.name, equals('Rahul Sharma'));
      expect(cleared.id, equals('p_100'));
    });
  });
}
