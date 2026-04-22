/// Trainer entity for admin screens.
class Trainer {
  final String id;
  final String organizationId;
  final String employeeId;
  final String employeeName;
  final String? employeeCode;
  final String? specialization;
  final String? qualifications;
  final bool isActive;
  final DateTime certifiedAt;
  final DateTime? certificationExpiresAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  Trainer({
    required this.id,
    required this.organizationId,
    required this.employeeId,
    required this.employeeName,
    this.employeeCode,
    this.specialization,
    this.qualifications,
    required this.isActive,
    required this.certifiedAt,
    this.certificationExpiresAt,
    required this.createdAt,
    this.updatedAt,
  });
  
  factory Trainer.fromJson(Map<String, dynamic> json) {
    return Trainer(
      id: json['id'],
      organizationId: json['organization_id'],
      employeeId: json['employee_id'],
      employeeName: json['employee_name'] ?? 
          '${json['employees']?['first_name'] ?? ''} ${json['employees']?['last_name'] ?? ''}',
      employeeCode: json['employee_code'] ?? json['employees']?['employee_code'],
      specialization: json['specialization'],
      qualifications: json['qualifications'],
      isActive: json['is_active'] ?? true,
      certifiedAt: DateTime.parse(json['certified_at']),
      certificationExpiresAt: json['certification_expires_at'] != null 
          ? DateTime.parse(json['certification_expires_at']) 
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'employee_id': employeeId,
    'specialization': specialization,
    'qualifications': qualifications,
    'is_active': isActive,
    'certified_at': certifiedAt.toIso8601String(),
    'certification_expires_at': certificationExpiresAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
