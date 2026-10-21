import 'package:flutter/material.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show ConflictAlgorithm;
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../data/models/academic_year.dart';
import '../../data/models/batch.dart';
import '../../data/models/batch_fee_template.dart';
import '../../data/models/charge.dart';
import '../../data/models/payer.dart';
import '../../data/models/payment.dart';
import '../../data/models/vault_summary.dart';
import '../../data/repositories/academic_year_repository.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/repositories/batch_repository.dart';
import '../../data/repositories/charge_repository.dart';
import '../../data/repositories/payer_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/settings_repository.dart';

/// Central state controller for FeesVault business data.
/// Enforces in-flight double-tap prevention, reactive screen refreshes,
/// and consistent error reporting across the Academy hierarchy:
/// Academic Year -> Batches -> Batch Fee Templates -> Students -> Charge Fees.
class VaultController extends ChangeNotifier {
  final PayerRepository payerRepo;
  final ChargeRepository chargeRepo;
  final PaymentRepository paymentRepo;
  final SettingsRepository settingsRepo;
  final AuditRepository auditRepo;
  final AcademicYearRepository academicYearRepo;
  final BatchRepository batchRepo;

  VaultSummary _summary = VaultSummary.empty();
  List<Payer> _payers = [];
  List<Payment> _recentPayments = [];
  List<Charge> _overdueCharges = [];

  // Academy hierarchy state
  List<AcademicYear> _academicYears = [];
  AcademicYear? _currentAcademicYear;
  List<Batch> _batches = [];
  String? _selectedAcademicYearFilter;

  String _businessName = AppConstants.appDisplayName;
  bool _onboardingDone = false;
  bool _isLoading = false;
  String? _errorMessage;

  // In-flight operation lock to prevent rapid tap duplicate submissions
  final Set<String> _inFlightOperations = {};

  VaultController({
    required this.payerRepo,
    required this.chargeRepo,
    required this.paymentRepo,
    required this.settingsRepo,
    required this.auditRepo,
    AcademicYearRepository? academicYearRepo,
    BatchRepository? batchRepo,
  }) : academicYearRepo =
           academicYearRepo ?? AcademicYearRepository(payerRepo.dbManager),
       batchRepo = batchRepo ?? BatchRepository(payerRepo.dbManager);

  VaultSummary get summary => _summary;
  List<Payer> get payers => _payers;
  List<Payment> get recentPayments => _recentPayments;
  List<Charge> get overdueCharges => _overdueCharges;
  List<AcademicYear> get academicYears => _academicYears;
  AcademicYear? get currentAcademicYear => _currentAcademicYear;
  List<Batch> get batches => _batches;
  String? get selectedAcademicYearFilter => _selectedAcademicYearFilter;
  String get businessName => _businessName;
  bool get onboardingDone => _onboardingDone;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isOperationInFlight(String key) => _inFlightOperations.contains(key);

  /// Loads initial state after unlock
  Future<void> loadVaultData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _businessName = await settingsRepo.getSetting(
        AppConstants.settingBusinessName,
        defaultValue: AppConstants.appDisplayName,
      );
      final onb = await settingsRepo.getSetting(
        AppConstants.settingOnboardingDone,
        defaultValue: 'false',
      );
      _onboardingDone = (onb == 'true');

      // Load Academic Years
      _academicYears = await academicYearRepo.getAcademicYears();
      _currentAcademicYear = await academicYearRepo.getCurrentAcademicYear();
      _selectedAcademicYearFilter =
          _currentAcademicYear?.name ??
          (_academicYears.isNotEmpty ? _academicYears.first.name : '2026-2027');

      await refreshAll();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes all summary metrics, overdue charges, recent payments, payers, and batches
  Future<void> refreshAll() async {
    try {
      _summary = await chargeRepo.getVaultSummary();
      _payers = await payerRepo.getPayers();
      _recentPayments = await paymentRepo.getPayments(limit: 10);
      _overdueCharges = await chargeRepo.getOverdueCharges(limit: 10);
      _academicYears = await academicYearRepo.getAcademicYears();
      _currentAcademicYear = await academicYearRepo.getCurrentAcademicYear();

      final yearFilter =
          _selectedAcademicYearFilter ?? _currentAcademicYear?.name;
      _batches = await batchRepo.getBatches(academicYear: yearFilter);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Filters batches by academic year
  Future<void> filterBatchesByAcademicYear(String? academicYear) async {
    _selectedAcademicYearFilter = academicYear;
    _batches = await batchRepo.getBatches(academicYear: academicYear);
    notifyListeners();
  }

  /// Acknowledges first-run privacy and local storage disclosure
  Future<void> acknowledgeOnboarding() async {
    await settingsRepo.setSetting(AppConstants.settingOnboardingDone, 'true');
    _onboardingDone = true;
    notifyListeners();
  }

  /// Updates business display name
  Future<void> updateBusinessName(String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) {
      throw const ValidationException('Business name cannot be empty');
    }
    await settingsRepo.setSetting(AppConstants.settingBusinessName, clean);
    _businessName = clean;
    notifyListeners();
  }

  // --- Academic Year Actions ---

  Future<AcademicYear> createAcademicYear(
    String name, {
    bool isCurrent = false,
  }) async {
    const opKey = 'create_academic_year';
    if (_inFlightOperations.contains(opKey)) {
      throw const BusinessRuleException(
        'A save operation is already in progress',
      );
    }
    _inFlightOperations.add(opKey);

    try {
      final ay = await academicYearRepo.createAcademicYear(
        name: name,
        isCurrent: isCurrent,
      );
      if (isCurrent) {
        _selectedAcademicYearFilter = ay.name;
      }
      await refreshAll();
      return ay;
    } finally {
      _inFlightOperations.remove(opKey);
    }
  }

  Future<void> setCurrentAcademicYear(String id) async {
    await academicYearRepo.setCurrentAcademicYear(id);
    _currentAcademicYear = await academicYearRepo.getCurrentAcademicYear();
    _selectedAcademicYearFilter = _currentAcademicYear?.name;
    await refreshAll();
  }

  Future<void> deleteAcademicYear(String id) async {
    await academicYearRepo.deleteAcademicYear(id);
    await refreshAll();
  }

  // --- Batch Actions ---

  Future<Batch> createBatch({
    required String name,
    required String academicYear,
    String? notes,
  }) async {
    const opKey = 'create_batch';
    if (_inFlightOperations.contains(opKey)) {
      throw const BusinessRuleException(
        'A save operation is already in progress',
      );
    }
    _inFlightOperations.add(opKey);

    try {
      final batch = await batchRepo.createBatch(
        name: name,
        academicYear: academicYear,
        notes: notes,
      );
      await refreshAll();
      return batch;
    } finally {
      _inFlightOperations.remove(opKey);
    }
  }

  Future<void> updateBatch(Batch batch) async {
    final opKey = 'update_batch_${batch.id}';
    if (_inFlightOperations.contains(opKey)) return;
    _inFlightOperations.add(opKey);

    try {
      await batchRepo.updateBatch(batch);
      await refreshAll();
    } finally {
      _inFlightOperations.remove(opKey);
    }
  }

  Future<void> deleteBatch(String batchId) async {
    final opKey = 'delete_batch_$batchId';
    if (_inFlightOperations.contains(opKey)) return;
    _inFlightOperations.add(opKey);

    try {
      await batchRepo.deleteBatch(batchId);
      await refreshAll();
    } finally {
      _inFlightOperations.remove(opKey);
    }
  }

  // --- Batch Fee Templates ---

  Future<BatchFeeTemplate> addBatchFeeTemplate({
    required String batchId,
    required String title,
    required int grossPaise,
    String? defaultDueDate,
  }) async {
    final template = await batchRepo.addFeeTemplate(
      batchId: batchId,
      title: title,
      grossPaise: grossPaise,
      defaultDueDate: defaultDueDate,
    );
    await refreshAll();
    return template;
  }

  Future<void> updateBatchFeeTemplate(BatchFeeTemplate template) async {
    await batchRepo.updateFeeTemplate(template);
    await refreshAll();
  }

  Future<void> deleteBatchFeeTemplate(String templateId) async {
    await batchRepo.deleteFeeTemplate(templateId);
    await refreshAll();
  }

  // --- Automated Batch Fee Charging ---

  /// Charges a batch's standard fee structure to a student
  Future<List<Charge>> chargeBatchFeesToStudent({
    required String payerId,
    required String batchId,
    int concessionPaise = 0,
  }) async {
    final opKey = 'charge_batch_${batchId}_student_$payerId';
    if (_inFlightOperations.contains(opKey)) {
      throw const BusinessRuleException('Fee charging is already in progress');
    }
    _inFlightOperations.add(opKey);

    try {
      final charges = await batchRepo.chargeBatchFeesToStudent(
        payerId: payerId,
        batchId: batchId,
        concessionPaise: concessionPaise,
      );
      await refreshAll();
      return charges;
    } finally {
      _inFlightOperations.remove(opKey);
    }
  }

  /// One-tap: Charges all students currently in a batch
  Future<int> chargeBatchFeesToAllStudents({required String batchId}) async {
    final opKey = 'charge_all_batch_$batchId';
    if (_inFlightOperations.contains(opKey)) {
      throw const BusinessRuleException('Fee charging is already in progress');
    }
    _inFlightOperations.add(opKey);

    try {
      final count = await batchRepo.chargeBatchFeesToAllStudents(
        batchId: batchId,
      );
      await refreshAll();
      return count;
    } finally {
      _inFlightOperations.remove(opKey);
    }
  }

  // --- Payer (Student) Actions ---

  Future<Payer> addPayer({
    required String name,
    String? phone,
    String? batch,
    String? batchId,
    String? notes,
    bool applyBatchFees = false,
    int concessionPaise = 0,
  }) async {
    const opKey = 'add_payer';
    if (_inFlightOperations.contains(opKey)) {
      throw const BusinessRuleException(
        'A save operation is already in progress',
      );
    }
    _inFlightOperations.add(opKey);

    try {
      final payer = await payerRepo.createPayer(
        name: name,
        phone: phone,
        batch: batch,
        batchId: batchId,
        notes: notes,
      );

      // If user selected to apply the batch fee structure immediately
      if (applyBatchFees && batchId != null && batchId.isNotEmpty) {
        try {
          await batchRepo.chargeBatchFeesToStudent(
            payerId: payer.id,
            batchId: batchId,
            concessionPaise: concessionPaise,
          );
        } catch (_) {
          // If batch had no templates configured yet, still allow student creation
        }
      }

      await refreshAll();
      return payer;
    } finally {
      _inFlightOperations.remove(opKey);
    }
  }

  Future<void> updatePayer(Payer payer) async {
    final opKey = 'update_payer_${payer.id}';
    if (_inFlightOperations.contains(opKey)) return;
    _inFlightOperations.add(opKey);

    try {
      await payerRepo.updatePayer(payer);
      await refreshAll();
    } finally {
      _inFlightOperations.remove(opKey);
    }
  }

  Future<void> archivePayer(String payerId, bool archived) async {
    await payerRepo.setPayerArchived(payerId, archived);
    await refreshAll();
  }

  Future<void> deletePayer(String payerId) async {
    await payerRepo.deletePayer(payerId);
    await refreshAll();
  }

  // --- Charge Actions ---

  Future<Charge> addCharge({
    required String payerId,
    required String title,
    String? period,
    required int grossPaise,
    int discountPaise = 0,
    required String dueDate,
    String? notes,
    String? batchId,
  }) async {
    const opKey = 'add_charge';
    if (_inFlightOperations.contains(opKey)) {
      throw const BusinessRuleException(
        'A save operation is already in progress',
      );
    }
    _inFlightOperations.add(opKey);

    try {
      final charge = await chargeRepo.createCharge(
        payerId: payerId,
        title: title,
        period: period,
        grossPaise: grossPaise,
        discountPaise: discountPaise,
        dueDate: dueDate,
        notes: notes,
        batchId: batchId,
      );
      await refreshAll();
      return charge;
    } finally {
      _inFlightOperations.remove(opKey);
    }
  }

  Future<void> updateCharge(Charge charge) async {
    final opKey = 'update_charge_${charge.id}';
    if (_inFlightOperations.contains(opKey)) return;
    _inFlightOperations.add(opKey);

    try {
      await chargeRepo.updateCharge(charge);
      await refreshAll();
    } finally {
      _inFlightOperations.remove(opKey);
    }
  }

  Future<void> deleteCharge(String chargeId) async {
    await chargeRepo.deleteCharge(chargeId);
    await refreshAll();
  }

  // --- Payment Actions ---

  Future<Payment> recordPayment({
    required String chargeId,
    required int amountPaise,
    required String paidDate,
    required String method,
    String? reference,
    String? notes,
  }) async {
    final opKey = 'record_payment_$chargeId';
    if (_inFlightOperations.contains(opKey)) {
      throw const BusinessRuleException(
        'A payment save is already in progress',
      );
    }
    _inFlightOperations.add(opKey);

    try {
      final payment = await paymentRepo.recordPayment(
        chargeId: chargeId,
        amountPaise: amountPaise,
        paidDate: paidDate,
        method: method,
        reference: reference,
        notes: notes,
      );
      await refreshAll();
      return payment;
    } finally {
      _inFlightOperations.remove(opKey);
    }
  }

  Future<void> updatePayment({
    required Payment payment,
    required String correctionReason,
  }) async {
    final opKey = 'update_payment_${payment.id}';
    if (_inFlightOperations.contains(opKey)) return;
    _inFlightOperations.add(opKey);

    try {
      await paymentRepo.updatePayment(
        payment: payment,
        correctionReason: correctionReason,
      );
      await refreshAll();
    } finally {
      _inFlightOperations.remove(opKey);
    }
  }

  Future<void> deletePayment({
    required String paymentId,
    required String correctionReason,
  }) async {
    final opKey = 'delete_payment_$paymentId';
    if (_inFlightOperations.contains(opKey)) return;
    _inFlightOperations.add(opKey);

    try {
      await paymentRepo.deletePayment(
        paymentId: paymentId,
        correctionReason: correctionReason,
      );
      await refreshAll();
    } finally {
      _inFlightOperations.remove(opKey);
    }
  }

  /// Safely wipes all student records, batches, charges, and payments in strict
  /// reverse-dependency order. Resets monotonic receipt counter to 1000.
  Future<void> clearAllVaultData() async {
    final db = payerRepo.dbManager.database;
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
    await refreshAll();
  }
}
