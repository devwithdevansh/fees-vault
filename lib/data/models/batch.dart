import 'batch_fee_template.dart';

/// Domain model representing an Academy Course / Batch tied to an Academic Year.
class Batch {
  final String id;
  final String name;
  final String academicYear;
  final String? notes;
  final int createdAt;
  final int updatedAt;

  // Hydrated statistics and fee structure
  final int studentCount;
  final int totalFeePaise;
  final int totalCollectedPaise;
  final int totalOutstandingPaise;
  final List<BatchFeeTemplate> feeTemplates;

  const Batch({
    required this.id,
    required this.name,
    required this.academicYear,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.studentCount = 0,
    this.totalFeePaise = 0,
    this.totalCollectedPaise = 0,
    this.totalOutstandingPaise = 0,
    this.feeTemplates = const [],
  });

  /// Total standard fees configured for this batch across all fee templates
  int get standardBatchFeePaise =>
      feeTemplates.fold<int>(0, (sum, t) => sum + t.grossPaise);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'academicYear': academicYear,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Batch.fromMap(Map<String, dynamic> map, {
    int studentCount = 0,
    int totalFeePaise = 0,
    int totalCollectedPaise = 0,
    int totalOutstandingPaise = 0,
    List<BatchFeeTemplate> feeTemplates = const [],
  }) {
    return Batch(
      id: map['id'] as String,
      name: map['name'] as String,
      academicYear: map['academicYear'] as String,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
      studentCount: studentCount,
      totalFeePaise: totalFeePaise,
      totalCollectedPaise: totalCollectedPaise,
      totalOutstandingPaise: totalOutstandingPaise,
      feeTemplates: feeTemplates,
    );
  }

  Batch copyWith({
    String? id,
    String? name,
    String? academicYear,
    String? notes,
    int? createdAt,
    int? updatedAt,
    int? studentCount,
    int? totalFeePaise,
    int? totalCollectedPaise,
    int? totalOutstandingPaise,
    List<BatchFeeTemplate>? feeTemplates,
  }) {
    return Batch(
      id: id ?? this.id,
      name: name ?? this.name,
      academicYear: academicYear ?? this.academicYear,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      studentCount: studentCount ?? this.studentCount,
      totalFeePaise: totalFeePaise ?? this.totalFeePaise,
      totalCollectedPaise: totalCollectedPaise ?? this.totalCollectedPaise,
      totalOutstandingPaise: totalOutstandingPaise ?? this.totalOutstandingPaise,
      feeTemplates: feeTemplates ?? this.feeTemplates,
    );
  }
}
