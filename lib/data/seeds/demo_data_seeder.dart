import 'dart:math';
import 'package:sqflite_sqlcipher/sqflite.dart' hide Batch;
import '../../core/constants/app_constants.dart';
import '../models/batch.dart';
import '../models/payer.dart';
import '../../presentation/controllers/vault_controller.dart';

/// Seeds realistic, authentic Indian tuition fee data for 50 students across 5 classes.
/// Models a standard Indian academic year (April 2026 to March 2027) with:
/// - 12 monthly tuition installments (due on the 10th of every month)
/// - One-time admission/material fee
/// - Realistic timeline collections up to the current month (October):
///   past months (Apr-Sep) mostly paid, current month (Oct) mixed, future (Nov-Mar) pending.
class DemoDataSeeder {
  static const List<String> _studentNames = [
    'Aarav Sharma',
    'Ananya Patel',
    'Rohan Verma',
    'Priya Iyer',
    'Aditya Kumar',
    'Sneha Kulkarni',
    'Vikram Singh',
    'Divya Nair',
    'Rahul Gupta',
    'Ishaan Joshi',
    'Pooja Deshmukh',
    'Arjun Mehta',
    'Tanvi Reddy',
    'Siddharth Roy',
    'Meera Chatterjee',
    'Varun Nambiar',
    'Riya Sen',
    'Nikhil Choudhury',
    'Kavya Pillai',
    'Aryan Bhatt',
    'Shreya Aggarwal',
    'Harsh Vardhan',
    'Anika Rao',
    'Devansh Tiwari',
    'Neha Saxena',
    'Kunal Kapoor',
    'Aditi Mishra',
    'Pranav Hegde',
    'Simran Kaur',
    'Ayush Dubey',
    'Ritu Bansal',
    'Manan Dave',
    'Shruti Menon',
    'Yash Malhotra',
    'Kritika Pandey',
    'Chirag Trivedi',
    'Disha Shah',
    'Gaurav Das',
    'Swati Goswami',
    'Samarth Bhat',
    'Pallavi Sengupta',
    'Rishabh Jain',
    'Tarun Venkatesh',
    'Sonali Mukherjee',
    'Abhinav Rajput',
    'Bhavna Chawla',
    'Karthik Sundaram',
    'Rupal Vora',
    'Mohit Singhal',
    'Vandana Patil',
  ];

  static const List<_IndianClassSpec> _classes = [
    _IndianClassSpec(
      name: 'Class 9 - Foundation Science & Maths',
      monthlyFeePaise: 150000, // ₹1,500/mo
      admissionFeePaise: 100000, // ₹1,000 one-time
      notes: 'CBSE Foundation 2026-27',
    ),
    _IndianClassSpec(
      name: 'Class 10 - Board Master Batch',
      monthlyFeePaise: 200000, // ₹2,000/mo
      admissionFeePaise: 150000, // ₹1,500 one-time
      notes: '10th Board Target 95%+',
    ),
    _IndianClassSpec(
      name: 'Class 11 - PCM & Computer Science',
      monthlyFeePaise: 280000, // ₹2,800/mo
      admissionFeePaise: 200000, // ₹2,000 one-time
      notes: 'Engineering & CBSE 11th',
    ),
    _IndianClassSpec(
      name: 'Class 12 - Target NEET & JEE Prep',
      monthlyFeePaise: 350000, // ₹3,500/mo
      admissionFeePaise: 250000, // ₹2,500 one-time
      notes: 'Intensive Entrance Batch',
    ),
    _IndianClassSpec(
      name: 'Commerce - Accountancy & Economics',
      monthlyFeePaise: 220000, // ₹2,200/mo
      admissionFeePaise: 150000, // ₹1,500 one-time
      notes: 'Class 11-12 Commerce Stream',
    ),
  ];

  static const List<String> monthNames = [
    'April 2026',
    'May 2026',
    'June 2026',
    'July 2026',
    'August 2026',
    'September 2026',
    'October 2026',
    'November 2026',
    'December 2026',
    'January 2027',
    'February 2027',
    'March 2027',
  ];

  static const List<String> monthCodes = [
    '2026-04',
    '2026-05',
    '2026-06',
    '2026-07',
    '2026-08',
    '2026-09',
    '2026-10',
    '2026-11',
    '2026-12',
    '2027-01',
    '2027-02',
    '2027-03',
  ];

  /// Safely cleans all student records, batches, charges, and payments in strict
  /// reverse-dependency order to avoid SQLite foreign key constraint crashes.
  /// Resets monotonic receipt counter to 1000.
  static Future<void> clearVaultData(VaultController controller) async {
    final db = controller.payerRepo.dbManager.database;
    await db.transaction((txn) async {
      await txn.delete('payments');
      await txn.delete('audit_events');
      await txn.delete('charges');
      await txn.delete('batch_fee_templates');
      await txn.delete('payers');
      await txn.delete('batches');
      await txn.insert('settings', {
        'key': AppConstants.settingReceiptCounter,
        'value': '1000',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await controller.refreshAll();
  }

  /// Seeds 50 students across 5 classes with standard Indian 12-month tuition schedules.
  /// If [clearFirst] is true, safely wipes existing demo data before seeding.
  static Future<Map<String, int>> seed(
    VaultController controller, {
    bool clearFirst = false,
  }) async {
    if (clearFirst) {
      await clearVaultData(controller);
    }

    // 1. Ensure active Academic Year is 2026-2027
    var currentYear = controller.currentAcademicYear?.name;
    if (currentYear == null || currentYear.isEmpty) {
      final existingYears = await controller.academicYearRepo
          .getAcademicYears();
      if (existingYears.isNotEmpty) {
        currentYear = existingYears.first.name;
      } else {
        final newAy = await controller.academicYearRepo.createAcademicYear(
          name: '2026-2027',
          isCurrent: true,
        );
        currentYear = newAy.name;
      }
    }

    // 2. Create the 5 Indian tuition batches with 12 monthly templates
    final createdBatches = <Batch>[];
    for (final cls in _classes) {
      final batch = await controller.batchRepo.createBatch(
        name: cls.name,
        academicYear: currentYear,
        notes: cls.notes,
      );

      // Add Admission Fee template
      await controller.batchRepo.addFeeTemplate(
        batchId: batch.id,
        title: 'Admission & Study Material Kit',
        grossPaise: cls.admissionFeePaise,
        defaultDueDate: '2026-04-05',
      );

      // Add 12 Monthly Fee templates (due on the 10th of each month)
      for (int m = 0; m < monthNames.length; m++) {
        final dueDay = '${monthCodes[m]}-10';
        await controller.batchRepo.addFeeTemplate(
          batchId: batch.id,
          title: '${monthNames[m]} Tuition Fee',
          grossPaise: cls.monthlyFeePaise,
          defaultDueDate: dueDay,
        );
      }

      createdBatches.add(batch);
    }

    int studentsAdded = 0;
    int chargesAdded = 0;
    int paymentsAdded = 0;

    final random = Random(101);
    final paymentMethods =
        AppConstants.paymentMethods; // Cash, UPI, Bank transfer, Other

    // 3. Create 50 students (10 per class)
    for (int i = 0; i < _studentNames.length; i++) {
      final studentName = _studentNames[i];
      final batchIndex = i % createdBatches.length;
      final assignedBatch = createdBatches[batchIndex];
      final cls = _classes[batchIndex];

      final phone = '98${(12000000 + i * 194821) % 89000000}';
      final rollNo = 101 + (i ~/ createdBatches.length);

      final Payer payer = await controller.payerRepo.createPayer(
        name: studentName,
        phone: phone,
        batch: assignedBatch.name,
        batchId: assignedBatch.id,
        notes: 'Roll No: $rollNo · ${cls.notes}',
      );
      studentsAdded++;

      // Create Admission Charge
      final admissionCharge = await controller.chargeRepo.createCharge(
        payerId: payer.id,
        title: 'Admission & Study Material Kit',
        period: 'Session 2026-27',
        grossPaise: cls.admissionFeePaise,
        discountPaise: (i % 7 == 0) ? 50000 : 0, // ₹500 concession occasionally
        dueDate: '2026-04-05',
        batchId: assignedBatch.id,
      );
      chargesAdded++;

      // All students settled admission fee
      await controller.paymentRepo.recordPayment(
        chargeId: admissionCharge.id,
        amountPaise: admissionCharge.grossPaise - admissionCharge.discountPaise,
        paidDate: '2026-04-05',
        method: (i % 2 == 0) ? 'UPI' : 'Cash',
        reference: (i % 2 == 0) ? 'UPI/ADM/${2000 + i}' : 'CASH-REC',
        notes: 'Admission kit fee collected',
      );
      paymentsAdded++;

      // Create 12 Monthly Charges for this student
      // Month 0 (Apr) through 6 (Oct) are past/running.
      // Month 7 (Nov) through 11 (Mar) are future.
      for (int m = 0; m < monthNames.length; m++) {
        final mName = monthNames[m];
        final mDue = '${monthCodes[m]}-10';
        final monthlyCharge = await controller.chargeRepo.createCharge(
          payerId: payer.id,
          title: '$mName Tuition Fee',
          period: mName,
          grossPaise: cls.monthlyFeePaise,
          discountPaise: 0,
          dueDate: mDue,
          batchId: assignedBatch.id,
        );
        chargesAdded++;

        // Past months (Apr - Sep: m = 0..5): 90% paid
        if (m < 6) {
          final isDefaulter =
              (i % 10 == 0 && m >= 4); // Student misses Aug or Sep
          if (!isDefaulter) {
            final method =
                paymentMethods[random.nextInt(paymentMethods.length)];
            final payDay = (random.nextInt(8) + 2).toString().padLeft(2, '0');
            final pDate = '${monthCodes[m]}-$payDay';

            await controller.paymentRepo.recordPayment(
              chargeId: monthlyCharge.id,
              amountPaise: cls.monthlyFeePaise,
              paidDate: pDate,
              method: method,
              reference: method == 'UPI' ? 'UPI/${monthCodes[m]}/$i' : null,
              notes: '$mName Fee Paid',
            );
            paymentsAdded++;
          }
        }
        // Current month (October: m = 6): ~60% paid, ~40% pending/overdue
        else if (m == 6) {
          final hasPaidOctober = (i % 3 != 0); // 2 out of 3 paid
          if (hasPaidOctober) {
            final method = paymentMethods[random.nextInt(2)]; // UPI or Cash
            final payDay = (random.nextInt(9) + 1).toString().padLeft(2, '0');
            final pDate = '2026-10-$payDay';

            await controller.paymentRepo.recordPayment(
              chargeId: monthlyCharge.id,
              amountPaise: cls.monthlyFeePaise,
              paidDate: pDate,
              method: method,
              reference: method == 'UPI' ? 'UPI/OCT/$i' : null,
              notes: 'October Fee Cleared',
            );
            paymentsAdded++;
          }
        }
        // Future months (Nov - Mar: m >= 7): No payments yet (pending future dues)
      }
    }

    await controller.refreshAll();

    return {
      'students': studentsAdded,
      'batches': createdBatches.length,
      'charges': chargesAdded,
      'payments': paymentsAdded,
    };
  }
}

class _IndianClassSpec {
  final String name;
  final int monthlyFeePaise;
  final int admissionFeePaise;
  final String notes;

  const _IndianClassSpec({
    required this.name,
    required this.monthlyFeePaise,
    required this.admissionFeePaise,
    required this.notes,
  });
}
