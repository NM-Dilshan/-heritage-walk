import '../../../core/firebase/cloud_values.dart';

import 'group_member.dart';

class TourGroup {
  TourGroup({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.leaderId,
    required this.leaderName,
    required List<GroupMember> members,
    required this.createdAt,
    this.destinationPlaceId,
    this.destinationName,
    this.trackingEnabled = true,
  }) : members = List.unmodifiable(members);
  final String id, name, inviteCode, leaderId, leaderName;
  final List<GroupMember> members;
  final DateTime createdAt;
  final String? destinationPlaceId, destinationName;
  final bool trackingEnabled;
  TourGroup copyWith({
    String? name,
    String? leaderName,
    List<GroupMember>? members,
    String? destinationPlaceId,
    String? destinationName,
  }) => TourGroup(
    id: id,
    name: name ?? this.name,
    inviteCode: inviteCode,
    leaderId: leaderId,
    leaderName: leaderName ?? this.leaderName,
    members: members ?? this.members,
    createdAt: createdAt,
    destinationPlaceId: destinationPlaceId ?? this.destinationPlaceId,
    destinationName: destinationName ?? this.destinationName,
    trackingEnabled: trackingEnabled,
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'inviteCode': inviteCode,
    'leaderId': leaderId,
    'leaderName': leaderName,
    'members': members.map((member) => member.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'destinationPlaceId': destinationPlaceId,
    'destinationName': destinationName,
    'trackingEnabled': trackingEnabled,
  };
  factory TourGroup.fromMap(Map<String, Object?> map) => TourGroup(
    id: CloudValues.text(map['id']),
    name: CloudValues.text(map['name']),
    inviteCode: CloudValues.text(map['inviteCode']),
    leaderId: CloudValues.text(map['leaderId']),
    leaderName: CloudValues.text(map['leaderName']),
    members: CloudValues.list(map['members'])
        .map((member) => GroupMember.fromMap(CloudValues.map(member)))
        .toList(),
    createdAt: CloudValues.date(map['createdAt']),
    destinationPlaceId: (map['destinationPlaceId'] is String
        ? CloudValues.text(map['destinationPlaceId'])
        : null),
    destinationName: (map['destinationName'] is String
        ? CloudValues.text(map['destinationName'])
        : null),
    trackingEnabled: CloudValues.boolean(map['trackingEnabled'], true),
  );
}
