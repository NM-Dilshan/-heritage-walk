import '../../../core/firebase/cloud_values.dart';

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.description,
    this.phoneNumber,
    this.category = 'other',
    this.isActive = false,
    this.isVerified = false,
    this.priority = 100,
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
  });
  final String id, name, description;
  final String? phoneNumber;
  final String category, createdBy, updatedBy;
  final bool isActive, isVerified;
  final int priority;
  final DateTime? createdAt, updatedAt;
  static const categories = [
    'police',
    'ambulance',
    'medical',
    'fire',
    'touristPolice',
    'disaster',
    'other',
  ];
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'phoneNumber': phoneNumber,
    'category': category,
    'isActive': isActive,
    'isVerified': isVerified,
    'priority': priority,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'createdBy': createdBy,
    'updatedBy': updatedBy,
  };
  factory EmergencyContact.fromMap(Map<String, Object?> data) {
    final number = CloudValues.number(data['priority']);
    return EmergencyContact(
      id: CloudValues.text(data['id']),
      name: CloudValues.text(data['name']),
      description: CloudValues.text(data['description']),
      phoneNumber: data['phoneNumber'] is String
          ? data['phoneNumber'] as String
          : null,
      category: categories.contains(data['category'])
          ? data['category'] as String
          : 'other',
      isActive: CloudValues.boolean(data['isActive'], false),
      isVerified: CloudValues.boolean(data['isVerified'], false),
      priority:
          number != null &&
              number.isFinite &&
              number == number.truncateToDouble() &&
              number >= 0 &&
              number <= 999
          ? number.toInt()
          : 100,
      createdAt: CloudValues.optionalDate(data['createdAt']),
      updatedAt: CloudValues.optionalDate(data['updatedAt']),
      createdBy: CloudValues.text(data['createdBy']),
      updatedBy: CloudValues.text(data['updatedBy']),
    );
  }
}

abstract final class EmergencyValidation {
  static String? requiredText(String? value) =>
      value == null || value.trim().isEmpty
      ? 'This field is required'
      : value.trim().length > 10000
      ? 'Use at most 10000 characters'
      : null;
  static String? normalizedPhone(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(text)) return null;
    final number = text.replaceAll(RegExp(r'[ ()-]'), '');
    return RegExp(r'^\+?[0-9]{2,15}$').hasMatch(number) ? number : null;
  }

  static String? phone(String? value) => normalizedPhone(value) == null
      ? 'Enter a valid phone number or short code'
      : null;
  static String? priority(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number < 0 || number > 999
        ? 'Enter a whole number from 0 to 999'
        : null;
  }
}
