import '../../core/formatters/currency_formatter.dart';

enum ChargeStatus {
  settled,
  overdue,
  partial,
  unpaid,
}

/// Charge domain model representing a fee obligation.
class Charge {
  final String id;
  final String payerId;
  final String title;
  final String? period;
  final int grossPaise;
  final int discountPaise;
  final String dueDate; // YYYY-MM-DD
  final String? notes;
  final int createdAt;
  final int updatedAt;

  // Hydrated payer & payment info
  final String? payerName;
  final int paidPaise;

  const Charge({
    required this.id,
    required this.payerId,
    required this.title,
    this.period,
    required this.grossPaise,
    this.discountPaise = 0,
    required this.dueDate,
    this.notes,
    this.batchId,
    required this.createdAt,
    required this.updatedAt,
    this.payerName,
    this.paidPaise = 0,
  });

  final String? batchId;

  int get netChargePaise => grossPaise - discountPaise;
  int get outstandingPaise => netChargePaise - paidPaise;

  // Education Academy Aliases
  String get feeTitle => title;
  String? get academicYear => period;
  int get concessionPaise => discountPaise;
  int get netFeePaise => netChargePaise;

  bool get isSettled => outstandingPaise == 0;
  bool get isOverdue => outstandingPaise > 0 && CurrencyFormatter.isDateOverdue(dueDate);
  bool get isPartial => paidPaise > 0 && outstandingPaise > 0;
  bool get isUnpaid => paidPaise == 0 && outstandingPaise > 0;

  ChargeStatus get status {
    if (isSettled) return ChargeStatus.settled;
    if (isOverdue) return ChargeStatus.overdue;
    if (isPartial) return ChargeStatus.partial;
    return ChargeStatus.unpaid;
  }

  String get statusLabel {
    switch (status) {
      case ChargeStatus.settled:
        return 'Settled';
      case ChargeStatus.overdue:
        return 'Overdue';
      case ChargeStatus.partial:
        return 'Partial';
      case ChargeStatus.unpaid:
        return 'Unpaid';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'payerId': payerId,
      'title': title,
      'period': period,
      'grossPaise': grossPaise,
      'discountPaise': discountPaise,
      'dueDate': dueDate,
      'notes': notes,
      'batchId': batchId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Charge.fromMap(Map<String, dynamic> map, {
    String? payerName,
    int paidPaise = 0,
  }) {
    return Charge(
      id: map['id'] as String,
      payerId: map['payerId'] as String,
      title: map['title'] as String,
      period: map['period'] as String?,
      grossPaise: map['grossPaise'] as int,
      discountPaise: (map['discountPaise'] as int?) ?? 0,
      dueDate: map['dueDate'] as String,
      notes: map['notes'] as String?,
      batchId: map['batchId'] as String?,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
      payerName: payerName ?? map['payerName'] as String?,
      paidPaise: paidPaise,
    );
  }

  Charge copyWith({
    String? id,
    String? payerId,
    String? title,
    String? period,
    int? grossPaise,
    int? discountPaise,
    String? dueDate,
    String? notes,
    String? batchId,
    int? createdAt,
    int? updatedAt,
    String? payerName,
    int? paidPaise,
  }) {
    return Charge(
      id: id ?? this.id,
      payerId: payerId ?? this.payerId,
      title: title ?? this.title,
      period: period ?? this.period,
      grossPaise: grossPaise ?? this.grossPaise,
      discountPaise: discountPaise ?? this.discountPaise,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      batchId: batchId ?? this.batchId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      payerName: payerName ?? this.payerName,
      paidPaise: paidPaise ?? this.paidPaise,
    );
  }
}
