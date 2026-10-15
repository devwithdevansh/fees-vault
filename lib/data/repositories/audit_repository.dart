import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database/app_database.dart';
import '../models/audit_event.dart';

/// Repository for persisting and querying encrypted audit trail events.
class AuditRepository {
  final AppDatabase _dbManager;

  AuditRepository(this._dbManager);

  /// Logs an audit event within an active transaction or on the main db
  Future<void> logEvent(DatabaseExecutor executor, AuditEvent event) async {
    await executor.insert('audit_events', event.toMap());
  }

  /// Retrieves audit records for a given entity (e.g. all corrections for a payment)
  Future<List<AuditEvent>> getAuditHistoryForEntity(String entityId) async {
    final results = await _dbManager.database.query(
      'audit_events',
      where: 'entityId = ?',
      whereArgs: [entityId],
      orderBy: 'timestamp DESC',
    );
    return results.map(AuditEvent.fromMap).toList();
  }

  /// Retrieves recent audit events
  Future<List<AuditEvent>> getRecentEvents({int limit = 100}) async {
    final results = await _dbManager.database.query(
      'audit_events',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return results.map(AuditEvent.fromMap).toList();
  }
}
