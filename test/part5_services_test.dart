import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/features/auth_profile/models/user_profile.dart';
import 'package:heritage_walk/features/auth_profile/services/profile_service.dart';
import 'package:heritage_walk/features/discovery_planning/services/discovery_service.dart';
import 'package:heritage_walk/features/group_support/models/tour_group.dart';
import 'package:heritage_walk/features/group_support/services/group_tour_service.dart';

void main() {
  late ProfileService profile;
  late GroupTourService service;
  late DiscoveryService discovery;
  setUp(() {
    profile = ProfileService();
    service = GroupTourService(profile);
    discovery = DiscoveryService();
  });
  tearDown(() {
    service.dispose();
    profile.dispose();
    discovery.dispose();
  });
  test('Create/read use current profile and generate unique IDs and codes', () {
    final first = service.createGroup(' Friends ', discovery.places.first);
    final second = service.createGroup('Friends', discovery.places.first);
    expect(first.name, 'Friends');
    expect(first.leaderId, profile.profile.id);
    expect(first.leaderName, profile.profile.fullName);
    expect(first.members.single.isLeader, isTrue);
    expect(first.members.single.isSharingLocation, isFalse);
    expect(first.id, isNot(second.id));
    expect(first.inviteCode, isNot(second.inviteCode));
    expect(service.getGroups().length, 2);
  });
  test('Group/member updates and delete modify immutable shared records', () {
    final group = service.createGroup('Friends', discovery.places.first);
    service.renameGroup(group.id, 'New Name');
    service.updateDestination(group.id, discovery.places[2]);
    final member = service.addMember(group.id, 'Amal');
    expect(service.getGroupById(group.id)!.name, 'New Name');
    expect(service.getGroupById(group.id)!.destinationName, 'Galle Fort');
    expect(service.getGroupById(group.id)!.members.length, 2);
    expect(
      () => service.removeMember(group.id, group.leaderId),
      throwsStateError,
    );
    service.removeMember(group.id, member.id);
    expect(service.getGroupById(group.id)!.members.length, 1);
    expect(
      () => service.getGroupById(group.id)!.members.clear(),
      throwsUnsupportedError,
    );
    service.deleteGroup(group.id);
    expect(service.getGroupById(group.id), isNull);
  });
  test('Joining a local code adds current user exactly once', () {
    final group = service.createGroup(
      'Other Group',
      discovery.places.first,
      leader: const UserProfile(
        id: 'other',
        fullName: 'Demo Leader',
        email: 'demo@example.com',
      ),
    );
    expect(service.joinGroupByCode('missing'), isNull);
    final joined = service.joinGroupByCode(
      ' ${group.inviteCode.toLowerCase()} ',
    )!;
    expect(joined.members.length, 2);
    expect(joined.members.last.id, profile.profile.id);
    expect(service.joinGroupByCode(group.inviteCode)!.members.length, 2);
    expect(() => service.renameGroup(group.id, 'Blocked'), throwsStateError);
    expect(() => service.deleteGroup(group.id), throwsStateError);
    expect(() => service.addMember(group.id, 'Blocked'), throwsStateError);
    expect(
      () => service.updateDestination(group.id, discovery.places[2]),
      throwsStateError,
    );
  });
  test('Sharing controls only current user and refresh is deterministic', () {
    final group = service.createGroup('Friends', discovery.places.first);
    final member = service.addMember(group.id, 'Amal');
    expect(
      () => service.toggleMemberLocationSharing(group.id, member.id, false),
      throwsStateError,
    );
    service.toggleMemberLocationSharing(group.id, profile.profile.id, true);
    final before = service.getGroupById(group.id)!.members.first;
    service.refreshTracking(group.id);
    expect(
      service.getGroupById(group.id)!.members.first.relativeX,
      closeTo(before.relativeX! + .04, .00001),
    );
    service.toggleMemberLocationSharing(group.id, profile.profile.id, false);
    final frozen = service.getGroupById(group.id)!.members.first;
    service.refreshTracking(group.id);
    expect(
      service.getGroupById(group.id)!.members.first.relativeX,
      frozen.relativeX,
    );
  });
  test('Validation and map serialization preserve group/member data', () {
    expect(
      () => service.createGroup('', discovery.places.first),
      throwsArgumentError,
    );
    expect(
      () => service.createGroup('x' * 61, discovery.places.first),
      throwsArgumentError,
    );
    final group = service.createGroup('Friends', discovery.places.first);
    service.addMember(group.id, 'Amal');
    final stored = service.getGroupById(group.id)!;
    expect(TourGroup.fromMap(stored.toMap()).toMap(), stored.toMap());
    expect(() => service.addMember(group.id, ' '), throwsArgumentError);
    expect(() => service.renameGroup(group.id, ''), throwsArgumentError);
  });
  test('Profile edits keep group leader/member names synchronized', () async {
    final group = service.createGroup('Friends', discovery.places.first);
    await profile.update(
      profile.profile.copyWith(fullName: 'Updated Traveller'),
    );
    expect(service.getGroupById(group.id)!.leaderName, 'Updated Traveller');
    expect(
      service.getGroupById(group.id)!.members.single.name,
      'Updated Traveller',
    );
  });
  test('Clearing state invalidates old codes without reusing them', () {
    final group = service.createGroup('Friends', discovery.places.first);
    service.clear();
    expect(service.getGroups(), isEmpty);
    expect(service.joinGroupByCode(group.inviteCode), isNull);
    final next = service.createGroup(
      'New Session Group',
      discovery.places.first,
    );
    expect(next.inviteCode, isNot(group.inviteCode));
  });
}
