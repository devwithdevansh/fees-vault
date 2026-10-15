import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fees_vault/data/models/charge.dart';
import 'package:fees_vault/data/models/payer.dart';
import 'package:fees_vault/data/models/payment.dart';
import 'package:fees_vault/presentation/screens/walkthrough_screen.dart';
import 'package:fees_vault/presentation/widgets/contextual_help_button.dart';

void main() {
  group('Education Academy Domain Aliases & Model Compatibility', () {
    test('Payer model exposes studentName, parentPhone, and courseBatch aliases', () {
      const student = Payer(
        id: 'st_1',
        name: 'Aarav Sharma',
        phone: '+91 98765 43210',
        batch: 'Class 10 Science',
        notes: 'Roll #102',
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
      );

      expect(student.studentName, equals('Aarav Sharma'));
      expect(student.parentPhone, equals('+91 98765 43210'));
      expect(student.courseBatch, equals('Class 10 Science'));
      expect(student.studentIdNotes, equals('Roll #102'));
    });

    test('Charge model exposes feeTitle, academicYear, concessionPaise, and netFeePaise aliases', () {
      const charge = Charge(
        id: 'ch_1',
        payerId: 'st_1',
        title: 'Term 1 Tuition Fee',
        period: '2026-27',
        grossPaise: 2500000,     // ₹ 25,000.00
        discountPaise: 500000,   // ₹ 5,000.00 concession
        dueDate: '2026-11-15',
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
      );

      expect(charge.feeTitle, equals('Term 1 Tuition Fee'));
      expect(charge.academicYear, equals('2026-27'));
      expect(charge.concessionPaise, equals(500000));
      expect(charge.netFeePaise, equals(2000000));
      expect(charge.outstandingPaise, equals(2000000));
    });

    test('Payment model exposes studentName and feeTitle aliases', () {
      const payment = Payment(
        id: 'pm_1',
        chargeId: 'ch_1',
        amountPaise: 1000000, // ₹ 10,000.00
        paidDate: '2026-10-15',
        method: 'UPI',
        receiptNumber: 1001,
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
        payerName: 'Aarav Sharma',
        chargeTitle: 'Term 1 Tuition Fee',
      );

      expect(payment.studentName, equals('Aarav Sharma'));
      expect(payment.feeTitle, equals('Term 1 Tuition Fee'));
      expect(payment.receiptNumber, equals(1001));
    });
  });

  group('Academy Walkthrough & In-App Guidance Widgets', () {
    testWidgets('AcademyWalkthroughScreen renders 4 steps and allows navigation', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AcademyWalkthroughScreen(
            onComplete: () => completed = true,
          ),
        ),
      );

      // Verify Step 1 is visible
      expect(find.text('Register Students & Contacts'), findsOneWidget);
      expect(find.text('STEP 1 OF 4'), findsOneWidget);

      // Tap Next Step
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Verify Step 2 is visible
      expect(find.text('Set Up Course Fees & Installments'), findsOneWidget);
      expect(find.text('STEP 2 OF 4'), findsOneWidget);

      // Tap Skip in header to finish
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });

    testWidgets('ContextualHelpButton displays explanation dialog on tap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ContextualHelpButton(
                title: 'Concession / Scholarship',
                explanation: 'Deduction from the gross fee amount.',
                example: '₹ 1,000 sibling discount',
              ),
            ),
          ),
        ),
      );

      // Tap the info button
      await tester.tap(find.byType(ContextualHelpButton));
      await tester.pumpAndSettle();

      // Bottom sheet should open with explanation and example
      expect(find.text('Concession / Scholarship'), findsOneWidget);
      expect(find.text('Deduction from the gross fee amount.'), findsOneWidget);
      expect(find.text('₹ 1,000 sibling discount'), findsOneWidget);

      // Tap Got it to close
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.text('Deduction from the gross fee amount.'), findsNothing);
    });
  });
}
