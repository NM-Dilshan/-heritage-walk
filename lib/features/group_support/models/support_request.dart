import '../../../core/firebase/cloud_values.dart';

enum SupportCategory {
  general('General'),
  technical('Technical'),
  account('Account'),
  tourPlanning('Tour Planning'),
  navigation('Navigation'),
  other('Other');

  const SupportCategory(this.label);
  final String label;
}

enum SupportStatus { open, resolved }

class SupportRequest {
  const SupportRequest({
    required this.id,
    required this.subject,
    required this.message,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, subject, message;
  final SupportCategory category;
  final SupportStatus status;
  final DateTime createdAt, updatedAt;

  SupportRequest copyWith({
    String? subject,
    String? message,
    SupportCategory? category,
    SupportStatus? status,
    DateTime? updatedAt,
  }) => SupportRequest(
    id: id,
    subject: subject ?? this.subject,
    message: message ?? this.message,
    category: category ?? this.category,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'subject': subject,
    'message': message,
    'category': category.name,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
  factory SupportRequest.fromMap(Map<String, dynamic> map) => SupportRequest(
    id: CloudValues.text(map['id']),
    subject: CloudValues.text(map['subject']),
    message: CloudValues.text(map['message']),
    category: CloudValues.enumValue(
      SupportCategory.values,
      map['category'],
      SupportCategory.general,
    ),
    status: CloudValues.enumValue(
      SupportStatus.values,
      map['status'],
      SupportStatus.open,
    ),
    createdAt: CloudValues.date(map['createdAt']),
    updatedAt: CloudValues.date(map['updatedAt']),
  );
}
