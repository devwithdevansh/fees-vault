/// Domain model representing a standard Fee Installment template defined for a Batch.
class BatchFeeTemplate {
  final String id;
  final String batchId;
  final String title;
  final int grossPaise;
  final String? defaultDueDate;
  final int createdAt;
  final int updatedAt;

  const BatchFeeTemplate({
    required this.id,
    required this.batchId,
    required this.title,
    required this.grossPaise,
    this.defaultDueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batchId': batchId,
      'title': title,
      'grossPaise': grossPaise,
      'defaultDueDate': defaultDueDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory BatchFeeTemplate.fromMap(Map<String, dynamic> map) {
    return BatchFeeTemplate(
      id: map['id'] as String,
      batchId: map['batchId'] as String,
      title: map['title'] as String,
      grossPaise: map['grossPaise'] as int,
      defaultDueDate: map['defaultDueDate'] as String?,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
    );
  }

  BatchFeeTemplate copyWith({
    String? id,
    String? batchId,
    String? title,
    int? grossPaise,
    String? defaultDueDate,
    int? createdAt,
    int? updatedAt,
  }) {
    return BatchFeeTemplate(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      title: title ?? this.title,
      grossPaise: grossPaise ?? this.grossPaise,
      defaultDueDate: defaultDueDate ?? this.defaultDueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
