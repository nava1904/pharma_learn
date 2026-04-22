/// Question bank entity for admin screens.
class QuestionBank {
  final String id;
  final String organizationId;
  final String name;
  final String? description;
  final String? courseId;
  final String? courseName;
  final int questionCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  QuestionBank({
    required this.id,
    required this.organizationId,
    required this.name,
    this.description,
    this.courseId,
    this.courseName,
    required this.questionCount,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });
  
  factory QuestionBank.fromJson(Map<String, dynamic> json) {
    return QuestionBank(
      id: json['id'],
      organizationId: json['organization_id'],
      name: json['name'],
      description: json['description'],
      courseId: json['course_id'],
      courseName: json['course_name'] ?? json['courses']?['title'],
      questionCount: json['question_count'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'name': name,
    'description': description,
    'course_id': courseId,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
