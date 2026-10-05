import '../../features/auth_profile/models/user_profile.dart';
import '../../features/group_support/models/tour_group.dart';

typedef CloudDocuments = Map<String, Map<String, Object?>>;

abstract interface class DataRepository {
  Future<CloudDocuments> load(String uid, String collection);
  Stream<CloudDocuments> watch(String uid, String collection);
  Future<void> write(
    String uid,
    String collection,
    CloudDocuments before,
    CloudDocuments after,
  );
  Future<TourGroup?> join(String code, UserProfile profile);
  String newId();
}
