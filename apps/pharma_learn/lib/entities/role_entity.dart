/// Role entity for admin screens.
class Role {
  final String id;
  final String name;
  final String roleCode;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  Role({
    required this.id,
    required this.name,
    required this.roleCode,
    this.description,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });
  
  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'],
      name: json['name'],
      roleCode: json['role_code'],
      description: json['description'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role_code': roleCode,
    'description': description,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
