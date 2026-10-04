class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.bio = '',
    this.photoPath,
  });
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String bio;
  final String? photoPath;

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
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'bio': bio,
    'photoPath': photoPath,
  };
  factory UserProfile.fromMap(Map<String, Object?> map) => UserProfile(
    id: map['id'] as String? ?? '',
    fullName: map['fullName'] as String? ?? '',
    email: map['email'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
    bio: map['bio'] as String? ?? '',
    photoPath: map['photoPath'] as String?,
  );
}
