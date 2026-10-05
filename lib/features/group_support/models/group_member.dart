import '../../../core/firebase/cloud_values.dart';

class GroupMember {
  const GroupMember({
    required this.id,
    required this.name,
    this.avatarPath,
    this.isLeader = false,
    this.isOnline = true,
    this.isSharingLocation = false,
    this.lastUpdated,
    this.relativeX,
    this.relativeY,
  });
  final String id, name;
  final String? avatarPath;
  final bool isLeader, isOnline, isSharingLocation;
  final DateTime? lastUpdated;

  /// Normalized UI positions only, never geographic coordinates.
  final double? relativeX, relativeY;
  GroupMember copyWith({
    String? name,
    bool? isSharingLocation,
    DateTime? lastUpdated,
    double? relativeX,
    double? relativeY,
  }) => GroupMember(
    id: id,
    name: name ?? this.name,
    avatarPath: avatarPath,
    isLeader: isLeader,
    isOnline: isOnline,
    isSharingLocation: isSharingLocation ?? this.isSharingLocation,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    relativeX: relativeX ?? this.relativeX,
    relativeY: relativeY ?? this.relativeY,
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'avatarPath': avatarPath,
    'isLeader': isLeader,
    'isOnline': isOnline,
    'isSharingLocation': isSharingLocation,
    'lastUpdated': lastUpdated?.toIso8601String(),
    'relativeX': relativeX,
    'relativeY': relativeY,
  };
  factory GroupMember.fromMap(Map<String, Object?> map) => GroupMember(
    id: CloudValues.text(map['id']),
    name: CloudValues.text(map['name']),
    avatarPath: (map['avatarPath'] is String
        ? CloudValues.text(map['avatarPath'])
        : null),
    isLeader: CloudValues.boolean(map['isLeader'], false),
    isOnline: CloudValues.boolean(map['isOnline'], true),
    isSharingLocation: CloudValues.boolean(map['isSharingLocation'], false),
    lastUpdated: map['lastUpdated'] == null
        ? null
        : CloudValues.optionalDate(map['lastUpdated']),
    relativeX: CloudValues.number(map['relativeX']),
    relativeY: CloudValues.number(map['relativeY']),
  );
}
