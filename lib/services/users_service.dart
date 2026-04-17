import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UsersService {
  final CollectionReference users = FirebaseFirestore.instance.collection('users');

  Future<void> createOrUpdateUser(AppUser user) async {
    await users.doc(user.id).set(user.toMap(), SetOptions(merge: true));
  }

  Future<AppUser?> getUser(String id) async {
    final doc = await users.doc(id).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  Stream<AppUser?> streamUser(String id) => users.doc(id).snapshots().map((s) =>
      s.exists ? AppUser.fromMap(s.id, s.data() as Map<String, dynamic>) : null);

  Future<void> deleteUser(String id) async => await users.doc(id).delete();
}
