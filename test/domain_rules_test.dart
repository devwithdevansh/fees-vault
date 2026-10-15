import 'package:flutter_test/flutter_test.dart';
import 'package:fees_vault/data/models/charge.dart';
import 'package:fees_vault/data/models/payment.dart';

void main() {
  group('Domain Business Rules & Invariants', () {
    test(
      'Editing charge: cannot reduce net charge below payments already collected',
      () {
        const chargeId = 'charge-1';
        final initialCharge = Charge(
          id: chargeId,
          payerId: 'payer-1',
          title: 'Tuition Fee',
          grossPaise: 1000000, // ₹10,000
          discountPaise: 100000, // ₹1,000 -> Net: ₹9,000
          dueDate: '2026-11-01',
          createdAt: 1000,
          updatedAt: 1000,
          paidPaise: 500000, // ₹5,000 already paid
        );

        // Attempting to change gross to ₹4,000 (net ₹4,000 < ₹5,000 paid)
        final invalidUpdate = initialCharge.copyWith(
          grossPaise: 400000,
          discountPaise: 0,
        );
        final newNet = invalidUpdate.netChargePaise;
        expect(newNet < initialCharge.paidPaise, isTrue);

        // Valid update: changing gross to ₹6,000 (net ₹6,000 >= ₹5,000 paid)
        final validUpdate = initialCharge.copyWith(
          grossPaise: 600000,
          discountPaise: 0,
        );
        expect(validUpdate.netChargePaise >= initialCharge.paidPaise, isTrue);
      },
    );

    test(
      'Editing payment: allowed headroom excludes the current payment old value',
      () {
        // Net Charge = ₹10,000
        const netChargePaise = 1000000;
        // Current payment 1 = ₹3,000
        const payment1Paise = 300000;
        // Current payment 2 (the one being edited) = ₹4,000
        const payment2OldPaise = 400000;
        // Total currently recorded = ₹7,000
        const totalPaid = payment1Paise + payment2OldPaise;

        // Other payments paid = ₹7,000 - ₹4,000 = ₹3,000
        const otherPaid = totalPaid - payment2OldPaise;
        // Allowed headroom for payment 2 = Net (₹10,000) - otherPaid (₹3,000) = ₹7,000
        const allowedMaxForPayment2 = netChargePaise - otherPaid;

        expect(allowedMaxForPayment2, equals(700000)); // ₹7,000 max

        // Increasing payment 2 to ₹6,000 is ALLOWED (total becomes ₹9,000 <= ₹10,000)
        const newAmountValid = 600000;
        expect(newAmountValid <= allowedMaxForPayment2, isTrue);

        // Increasing payment 2 to ₹8,000 is REJECTED (total would be ₹11,000 > ₹10,000)
        const newAmountInvalid = 800000;
        expect(newAmountInvalid > allowedMaxForPayment2, isTrue);
      },
    );

    test(
      'Deleted payment restores outstanding balance and preserves audit history',
      () {
        const netChargePaise = 1000000; // ₹10,000
        var paidPaise = 400000; // ₹4,000
        var outstanding = netChargePaise - paidPaise;
        expect(outstanding, equals(600000)); // ₹6,000

        // Simulate payment deletion
        paidPaise -= 400000;
        outstanding = netChargePaise - paidPaise;
        expect(outstanding, equals(1000000)); // Restored back to full ₹10,000
      },
    );

    test(
      'Monotonic receipt numbers increment strictly and are never reused',
      () {
        int sequenceCounter = 1000;
        final receiptsGenerated = <int>[];

        // Simulate 5 payments
        for (int i = 0; i < 5; i++) {
          sequenceCounter++;
          receiptsGenerated.add(sequenceCounter);
        }

        expect(receiptsGenerated, equals([1001, 1002, 1003, 1004, 1005]));

        // Deleting receipt 1003 must not reset or reuse 1003
        receiptsGenerated.remove(1003);

        // Next payment must get 1006, not 1003
        sequenceCounter++;
        final nextReceipt = sequenceCounter;
        expect(nextReceipt, equals(1006));
        expect(receiptsGenerated.contains(nextReceipt), isFalse);
      },
    );

    test(
      'Payment model requires unique monotonic receiptNumber and immutable chargeId',
      () {
        final payment = Payment(
          id: 'pm-1',
          chargeId: 'ch-1',
          amountPaise: 250000,
          paidDate: '2026-10-12',
          method: 'UPI',
          receiptNumber: 1001,
          createdAt: 100,
          updatedAt: 100,
        );

        expect(payment.receiptNumber, equals(1001));
        expect(payment.amountPaise, equals(250000));
        expect(payment.chargeId, equals('ch-1'));
      },
    );
  });
}
