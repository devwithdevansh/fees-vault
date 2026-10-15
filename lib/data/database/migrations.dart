import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../core/constants/app_constants.dart';

/// Database schema initialization and versioned migrations.
class DatabaseMigrations {
  static const int currentVersion = 2;

  static Future<void> onCreate(Database db, int version) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON;');

    // 1. Payers (Students) table
    await db.execute('''
      CREATE TABLE payers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        batch TEXT,
        batchId TEXT,
        notes TEXT,
        archived INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX idx_payers_archived ON payers(archived);');
    await db.execute('CREATE INDEX idx_payers_name ON payers(name);');
    await db.execute('CREATE INDEX idx_payers_batchId ON payers(batchId);');

    // 2. Charges (Fee Installments) table
    await db.execute('''
      CREATE TABLE charges (
        id TEXT PRIMARY KEY,
        payerId TEXT NOT NULL REFERENCES payers(id) ON DELETE RESTRICT,
        title TEXT NOT NULL,
        period TEXT,
        grossPaise INTEGER NOT NULL CHECK (grossPaise > 0),
        discountPaise INTEGER NOT NULL DEFAULT 0 CHECK (discountPaise >= 0 AND discountPaise <= grossPaise),
        dueDate TEXT NOT NULL,
        notes TEXT,
        batchId TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX idx_charges_payerId ON charges(payerId);');
    await db.execute('CREATE INDEX idx_charges_dueDate ON charges(dueDate);');
    await db.execute('CREATE INDEX idx_charges_batchId ON charges(batchId);');

    // 3. Payments table with UNIQUE receiptNumber
    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        chargeId TEXT NOT NULL REFERENCES charges(id) ON DELETE RESTRICT,
        amountPaise INTEGER NOT NULL CHECK (amountPaise > 0),
        paidDate TEXT NOT NULL,
        method TEXT NOT NULL,
        reference TEXT,
        notes TEXT,
        receiptNumber INTEGER NOT NULL UNIQUE,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX idx_payments_chargeId ON payments(chargeId);',
    );
    await db.execute(
      'CREATE INDEX idx_payments_paidDate ON payments(paidDate);',
    );

    // 4. Audit events table (encrypted local correction history)
    await db.execute('''
      CREATE TABLE audit_events (
        id TEXT PRIMARY KEY,
        entityType TEXT NOT NULL,
        entityId TEXT NOT NULL,
        action TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        reason TEXT,
        detailsJson TEXT
      );
    ''');
    await db.execute(
      'CREATE INDEX idx_audit_entity ON audit_events(entityType, entityId);',
    );

    // 5. Settings table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    // 6. Academic Years table
    await db.execute('''
      CREATE TABLE academic_years (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        isCurrent INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL
      );
    ''');

    // 7. Batches table
    await db.execute('''
      CREATE TABLE batches (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        academicYear TEXT NOT NULL,
        notes TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX idx_batches_academicYear ON batches(academicYear);',
    );

    // 8. Batch Fee Templates table (standard fee structure per batch)
    await db.execute('''
      CREATE TABLE batch_fee_templates (
        id TEXT PRIMARY KEY,
        batchId TEXT NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        grossPaise INTEGER NOT NULL CHECK (grossPaise > 0),
        defaultDueDate TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX idx_bft_batchId ON batch_fee_templates(batchId);',
    );

    // Seed default settings inside the encrypted database
    await db.insert('settings', {
      'key': AppConstants.settingBusinessName,
      'value': AppConstants.appDisplayName,
    });
    await db.insert('settings', {
      'key': AppConstants.settingCurrency,
      'value': 'INR',
    });
    await db.insert('settings', {
      'key': AppConstants.settingOnboardingDone,
      'value': 'false',
    });
    await db.insert('settings', {
      'key': AppConstants.settingReceiptCounter,
      'value': '1000',
    });

    // Seed default Academic Year: 2026-2027
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('academic_years', {
      'id': 'ay_2026_27',
      'name': '2026-2027',
      'isCurrent': 1,
      'createdAt': now,
    });
  }

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // 1. Create academic_years table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS academic_years (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          isCurrent INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL
        );
      ''');

      // 2. Create batches table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS batches (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          academicYear TEXT NOT NULL,
          notes TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        );
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_batches_academicYear ON batches(academicYear);',
      );

      // 3. Create batch_fee_templates table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS batch_fee_templates (
          id TEXT PRIMARY KEY,
          batchId TEXT NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
          title TEXT NOT NULL,
          grossPaise INTEGER NOT NULL CHECK (grossPaise > 0),
          defaultDueDate TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        );
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bft_batchId ON batch_fee_templates(batchId);',
      );

      // 4. Safely add batchId column to payers if missing
      try {
        await db.execute('ALTER TABLE payers ADD COLUMN batchId TEXT;');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_payers_batchId ON payers(batchId);',
        );
      } catch (_) {}

      // 5. Safely add batchId column to charges if missing
      try {
        await db.execute('ALTER TABLE charges ADD COLUMN batchId TEXT;');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_charges_batchId ON charges(batchId);',
        );
      } catch (_) {}

      // 6. Seed default academic year if table is empty
      final ayCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM academic_years;'),
          ) ??
          0;
      if (ayCount == 0) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await db.insert('academic_years', {
          'id': 'ay_2026_27',
          'name': '2026-2027',
          'isCurrent': 1,
          'createdAt': now,
        });
      }
    }
  }

  static Future<void> onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }
}
