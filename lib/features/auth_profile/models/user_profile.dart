import '../../../core/firebase/cloud_values.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.bio = '',
    this.photoPath,
    this.role = 'user',
  });
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String bio;
  final String? photoPath;
  final String role;
  bool get isAdmin => role == 'admin';

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? bio,
    bool removePhoto = false,
  }) => UserProfile(
    id: id,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    bio: bio ?? this.bio,
    photoPath: removePhoto ? null : photoPath,
    role: role,
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'bio': bio,
    'photoPath': photoPath,
    'role': role,
  };
  factory UserProfile.fromMap(Map<String, Object?> map) => UserProfile(
    id: CloudValues.text(map['id']),
    role: map['role'] == 'admin' ? 'admin' : 'user',
    fullName: CloudValues.text(map['fullName']),
    email: CloudValues.text(map['email']),
    phone: CloudValues.text(map['phone']),
    bio: CloudValues.text(map['bio']),
    photoPath: (map['photoPath'] is String
        ? CloudValues.text(map['photoPath'])
        : null),
  );
}
