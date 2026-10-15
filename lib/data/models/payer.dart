/// Payer domain model (can represent student, client, member).
class Payer {
  final String id;
  final String name;
  final String? phone;
  final String? batch;
  final String? batchId;
  final String? notes;
  final bool archived;
  final int createdAt;
  final int updatedAt;

  // Optional hydrated aggregated totals
  final int totalNetPaise;
  final int totalPaidPaise;
  final int totalOutstandingPaise;
  final int chargeCount;

  const Payer({
    required this.id,
    required this.name,
    this.phone,
    this.batch,
    this.batchId,
    this.notes,
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
    this.totalNetPaise = 0,
    this.totalPaidPaise = 0,
    this.totalOutstandingPaise = 0,
    this.chargeCount = 0,
  });

  // Education Academy Aliases
  String get studentName => name;
  String? get parentPhone => phone;
  String? get courseBatch => batch;
  String? get studentIdNotes => notes;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'batch': batch,
      'batchId': batchId,
      'notes': notes,
      'archived': archived ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Payer.fromMap(Map<String, dynamic> map, {
    int totalNetPaise = 0,
    int totalPaidPaise = 0,
    int totalOutstandingPaise = 0,
    int chargeCount = 0,
  }) {
    return Payer(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      batch: map['batch'] as String?,
      batchId: map['batchId'] as String?,
      notes: map['notes'] as String?,
      archived: (map['archived'] as int? ?? 0) == 1,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
      totalNetPaise: totalNetPaise,
      totalPaidPaise: totalPaidPaise,
      totalOutstandingPaise: totalOutstandingPaise,
      chargeCount: chargeCount,
    );
  }

  Payer copyWith({
    String? id,
    String? name,
    String? phone,
    String? batch,
    String? batchId,
    String? notes,
    bool? archived,
    int? createdAt,
    int? updatedAt,
    int? totalNetPaise,
    int? totalPaidPaise,
    int? totalOutstandingPaise,
    int? chargeCount,
  }) {
    return Payer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      batch: batch ?? this.batch,
      batchId: batchId ?? this.batchId,
      notes: notes ?? this.notes,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalNetPaise: totalNetPaise ?? this.totalNetPaise,
      totalPaidPaise: totalPaidPaise ?? this.totalPaidPaise,
      totalOutstandingPaise: totalOutstandingPaise ?? this.totalOutstandingPaise,
      chargeCount: chargeCount ?? this.chargeCount,
    );
  }
}
