import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
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

  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios';
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // Unique ID on Android
    }
    return 'unknown_device';
  }

  Future<int> countUsersOnDevice(String deviceId) async {
    final snapshot = await users.where('deviceId', isEqualTo: deviceId).get();
    return snapshot.docs.length;
  }
}
