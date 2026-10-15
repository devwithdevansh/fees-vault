/// Audit event record tracking local corrections and modifications.
/// Stored strictly inside the encrypted SQLCipher database.
class AuditEvent {
  final String id;
  final String entityType; // 'payment', 'charge', 'payer'
  final String entityId;
  final String action;     // 'create', 'update', 'delete'
  final int timestamp;
  final String? reason;
  final String? detailsJson;

  const AuditEvent({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.timestamp,
    this.reason,
    this.detailsJson,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entityType': entityType,
      'entityId': entityId,
      'action': action,
      'timestamp': timestamp,
      'reason': reason,
      'detailsJson': detailsJson,
    };
  }

  factory AuditEvent.fromMap(Map<String, dynamic> map) {
    return AuditEvent(
      id: map['id'] as String,
      entityType: map['entityType'] as String,
      entityId: map['entityId'] as String,
      action: map['action'] as String,
      timestamp: map['timestamp'] as int,
      reason: map['reason'] as String?,
      detailsJson: map['detailsJson'] as String?,
    );
  }
}
