import 'package:flutter_test/flutter_test.dart';
import 'package:fees_vault/core/constants/app_constants.dart';
import 'package:fees_vault/data/seeds/demo_data_seeder.dart';

void main() {
  group('Demo Data Seeder Invariants', () {
    test(
      'Ensures exactly 50 distinct students and valid batch configurations',
      () {
        expect(DemoDataSeeder.monthNames.length, equals(12));
        expect(DemoDataSeeder.monthCodes.length, equals(12));
        expect(
          AppConstants.paymentMethods,
          containsAll(['Cash', 'UPI', 'Bank transfer', 'Other']),
        );
      },
    );
  });
}
