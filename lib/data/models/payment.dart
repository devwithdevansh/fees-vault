/// Payment domain model representing an entry against a specific Charge.
class Payment {
  final String id;
  final String chargeId;
  final int amountPaise;
  final String paidDate; // YYYY-MM-DD
  final String method; // Cash, UPI, Bank transfer, Other
  final String? reference;
  final String? notes;
  final int receiptNumber; // Unique monotonic integer counter
  final int createdAt;
  final int updatedAt;

  // Hydrated presentation details
  final String? payerName;
  final String? chargeTitle;
  final int? remainingBalancePaise;
  final bool isEdited;

  const Payment({
    required this.id,
    required this.chargeId,
    required this.amountPaise,
    required this.paidDate,
    required this.method,
    this.reference,
    this.notes,
    required this.receiptNumber,
    required this.createdAt,
    required this.updatedAt,
    this.payerName,
    this.chargeTitle,
    this.remainingBalancePaise,
    this.isEdited = false,
  });

  // Education Academy Aliases
  String? get studentName => payerName;
  String? get feeTitle => chargeTitle;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chargeId': chargeId,
      'amountPaise': amountPaise,
      'paidDate': paidDate,
      'method': method,
      'reference': reference,
      'notes': notes,
      'receiptNumber': receiptNumber,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Payment.fromMap(
    Map<String, dynamic> map, {
    String? payerName,
    String? chargeTitle,
    int? remainingBalancePaise,
    bool isEdited = false,
  }) {
    return Payment(
      id: map['id'] as String,
      chargeId: map['chargeId'] as String,
      amountPaise: map['amountPaise'] as int,
      paidDate: map['paidDate'] as String,
      method: map['method'] as String,
      reference: map['reference'] as String?,
      notes: map['notes'] as String?,
      receiptNumber: map['receiptNumber'] as int,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
      payerName: payerName ?? map['payerName'] as String?,
      chargeTitle: chargeTitle ?? map['chargeTitle'] as String?,
      remainingBalancePaise:
          remainingBalancePaise ?? (map['remainingBalancePaise'] as int?),
      isEdited: isEdited,
    );
  }

  Payment copyWith({
    String? id,
    String? chargeId,
    int? amountPaise,
    String? paidDate,
    String? method,
    String? reference,
    String? notes,
    int? receiptNumber,
    int? createdAt,
    int? updatedAt,
    String? payerName,
    String? chargeTitle,
    int? remainingBalancePaise,
    bool? isEdited,
  }) {
    return Payment(
      id: id ?? this.id,
      chargeId: chargeId ?? this.chargeId,
      amountPaise: amountPaise ?? this.amountPaise,
      paidDate: paidDate ?? this.paidDate,
      method: method ?? this.method,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      payerName: payerName ?? this.payerName,
      chargeTitle: chargeTitle ?? this.chargeTitle,
      remainingBalancePaise:
          remainingBalancePaise ?? this.remainingBalancePaise,
      isEdited: isEdited ?? this.isEdited,
    );
  }
}
