/// Domain model representing an Academic Year (e.g., 2026-2027).
class AcademicYear {
  final String id;
  final String name;
  final bool isCurrent;
  final int createdAt;

  const AcademicYear({
    required this.id,
    required this.name,
    this.isCurrent = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isCurrent': isCurrent ? 1 : 0,
      'createdAt': createdAt,
    };
  }

  factory AcademicYear.fromMap(Map<String, dynamic> map) {
    return AcademicYear(
      id: map['id'] as String,
      name: map['name'] as String,
      isCurrent: (map['isCurrent'] as int? ?? 0) == 1,
      createdAt: map['createdAt'] as int,
    );
  }

  AcademicYear copyWith({
    String? id,
    String? name,
    bool? isCurrent,
    int? createdAt,
  }) {
    return AcademicYear(
      id: id ?? this.id,
      name: name ?? this.name,
      isCurrent: isCurrent ?? this.isCurrent,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
