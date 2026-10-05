import 'package:flutter/material.dart';

import '../../auth_profile/models/user_profile.dart';
import '../../auth_profile/services/profile_service.dart';
import '../../discovery_planning/models/heritage_place.dart';
import '../models/group_member.dart';
import '../models/tour_group.dart';

class GroupTourService extends ChangeNotifier {
  GroupTourService(this.profileService) {
    profileService.addListener(_syncProfile);
  }
  final ProfileService profileService;
  final Map<String, TourGroup> _groups = {};
  int _groupSequence = 0, _memberSequence = 0;
  String Function()? idFactory;
  String Function()? inviteFactory;
  Future<TourGroup?> Function(String, UserProfile)? cloudJoin;
  bool get isCloud => cloudJoin != null;
  void restore(Iterable<TourGroup> groups) {
    _groups.clear();
    for (final group in groups) {
      _groups[group.id] = group;
    }
    notifyListeners();
  }

  Future<TourGroup?> join(String code) async {
    if (cloudJoin == null) return joinGroupByCode(code);
    final existing = _groups.values
        .where(
          (group) =>
              group.inviteCode == code.trim().toUpperCase() && isMember(group),
        )
        .firstOrNull;
    if (existing != null) return existing;
    return cloudJoin!(code, profileService.profile);
  }

  String get currentUserId => profileService.profile.id;
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter a name';
    return value.trim().length > 60 ? 'Use no more than 60 characters' : null;
  }

  String _name(UserProfile profile) => profile.fullName.trim().isEmpty
      ? 'Group Leader'
      : profile.fullName.trim();
  List<TourGroup> getGroups() => List.unmodifiable(_groups.values);
  TourGroup? getGroupById(String id) => _groups[id];
  bool isLeader(TourGroup group) => group.leaderId == currentUserId;
  bool isMember(TourGroup group) =>
      group.members.any((member) => member.id == currentUserId);
  TourGroup createGroup(
    String name,
    HeritagePlace destination, {
    UserProfile? leader,
  }) {
    if (validateName(name) != null) {
      throw ArgumentError('A valid group name is required.');
    }
    final profile = leader ?? profileService.profile;
    if (isCloud && profile.id != currentUserId) {
      throw StateError('Create groups only for the signed-in user.');
    }
    final sequence = ++_groupSequence;
    final now = DateTime.now();
    final group = TourGroup(
      id: idFactory?.call() ?? 'group-$sequence',
      name: name.trim(),
      inviteCode:
          inviteFactory?.call() ?? 'HW-${sequence.toString().padLeft(4, '0')}',
      leaderId: profile.id,
      leaderName: _name(profile),
      members: [
        GroupMember(
          id: profile.id,
          name: _name(profile),
          avatarPath: profile.photoPath,
          isLeader: true,
          lastUpdated: now,
          relativeX: .25,
          relativeY: .6,
        ),
      ],
      createdAt: now,
      destinationPlaceId: destination.id,
      destinationName: destination.name,
    );
    _groups[group.id] = group;
    notifyListeners();
    return group;
  }

  TourGroup _leaderGroup(String id) {
    final group = _groups[id];
    if (group == null || !isLeader(group)) {
      throw StateError('Only the group leader can manage this group.');
    }
    return group;
  }

  void renameGroup(String id, String name) {
    final group = _leaderGroup(id);
    if (validateName(name) != null) {
      throw ArgumentError('A valid name is required.');
    }
    _groups[id] = group.copyWith(name: name.trim());
    notifyListeners();
  }

  void updateDestination(String id, HeritagePlace destination) {
    _groups[id] = _leaderGroup(id).copyWith(
      destinationPlaceId: destination.id,
      destinationName: destination.name,
    );
    notifyListeners();
  }

  GroupMember addMember(String id, String name) {
    final group = _leaderGroup(id);
    if (isCloud && group.members.length >= 50) {
      throw StateError('This group has reached its 50-member limit.');
    }
    if (validateName(name) != null) throw ArgumentError('Enter a member name.');
    final sequence = ++_memberSequence;
    final member = GroupMember(
      id: 'demo-member-${idFactory?.call() ?? sequence}',
      name: name.trim(),
      isSharingLocation: true,
      lastUpdated: DateTime.now(),
      relativeX: .35 + (sequence % 3) * .12,
      relativeY: .35 + (sequence % 2) * .15,
    );
    _groups[id] = group.copyWith(members: [...group.members, member]);
    notifyListeners();
    return member;
  }

  void removeMember(String id, String memberId) {
    final group = _leaderGroup(id);
    if (memberId == group.leaderId) {
      throw StateError('The leader cannot be removed.');
    }
    _groups[id] = group.copyWith(
      members: group.members.where((member) => member.id != memberId).toList(),
    );
    notifyListeners();
  }

  TourGroup? joinGroupByCode(String code) {
    final matches = _groups.values.where(
      (group) => group.inviteCode == code.trim().toUpperCase(),
    );
    if (matches.isEmpty) return null;
    final group = matches.first;
    if (isMember(group)) return group;
    final profile = profileService.profile;
    final updated = group.copyWith(
      members: [
        ...group.members,
        GroupMember(
          id: profile.id,
          name: _name(profile),
          avatarPath: profile.photoPath,
          lastUpdated: DateTime.now(),
          relativeX: .3,
          relativeY: .65,
        ),
      ],
    );
    _groups[group.id] = updated;
    notifyListeners();
    return updated;
  }

  void toggleMemberLocationSharing(String id, String memberId, bool enabled) {
    final group = _groups[id];
    if (group == null || !isMember(group) || memberId != currentUserId) {
      throw StateError('You can change only your own sharing state.');
    }
    _groups[id] = group.copyWith(
      members: group.members
          .map(
            (member) => member.id == memberId
                ? member.copyWith(
                    isSharingLocation: enabled,
                    lastUpdated: DateTime.now(),
                  )
                : member,
          )
          .toList(),
    );
    notifyListeners();
  }

  void refreshTracking(String id) {
    final group = _groups[id];
    if (group == null || !isMember(group)) {
      throw StateError('Join the group before viewing tracking.');
    }
    final now = DateTime.now();
    _groups[id] = group.copyWith(
      members: group.members
          .map(
            (member) => !member.isSharingLocation
                ? member
                : member.copyWith(
                    relativeX: ((member.relativeX ?? .3) + .04) > .8
                        ? .2
                        : (member.relativeX ?? .3) + .04,
                    relativeY: ((member.relativeY ?? .4) + .03) > .8
                        ? .2
                        : (member.relativeY ?? .4) + .03,
                    lastUpdated: now,
                  ),
          )
          .toList(),
    );
    notifyListeners();
  }

  void deleteGroup(String id) {
    _leaderGroup(id);
    _groups.remove(id);
    notifyListeners();
  }

  void clear() {
    _groups.clear();
    notifyListeners();
  }

  void _syncProfile() {
    final profile = profileService.profile;
    var changed = false;
    for (final group in _groups.values.toList()) {
      if (!group.members.any((member) => member.id == profile.id)) continue;
      _groups[group.id] = group.copyWith(
        leaderName: group.leaderId == profile.id ? _name(profile) : null,
        members: group.members
            .map(
              (member) => member.id == profile.id
                  ? member.copyWith(name: _name(profile))
                  : member,
            )
            .toList(),
      );
      changed = true;
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    profileService.removeListener(_syncProfile);
    super.dispose();
  }
}

class GroupTourScope extends InheritedNotifier<GroupTourService> {
  const GroupTourScope({
    super.key,
    required GroupTourService service,
    required super.child,
  }) : super(notifier: service);
  static GroupTourService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GroupTourScope>()!.notifier!;
}
