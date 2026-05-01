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

  Future<void> calculateAndUpdateTrustScore(String userId) async {
    final userSnap = await users.doc(userId).get();
    if (!userSnap.exists) return;

    final user = AppUser.fromMap(userSnap.id, userSnap.data() as Map<String, dynamic>);

    int totalAttempts = user.totalBookings + user.totalCancellations;
    
    // 1. Success Rate (0-100)
    double successRate = 100.0;
    if (totalAttempts > 0) {
      successRate = (user.totalBookings / totalAttempts) * 100.0;
    }

    // 2. Proof Quality (0-100)
    double proofQuality = user.verificationLevel >= 2 ? 100.0 : 70.0;

    // 3. Average Rating (0-100)
    double ratingFactor = user.averageRating * 20.0;

    // 4. Penalty Factor (0-100)
    double calcCancellationRate = totalAttempts == 0 ? 0 : user.totalCancellations / totalAttempts;
    double penaltyFactor = 100.0 - (calcCancellationRate * 100.0);
    if (user.isSuspicious) penaltyFactor -= 30.0;
    if (penaltyFactor < 0) penaltyFactor = 0;

    // Final Formula:
    // trustScore = (successRate * 0.4) + (proofQuality * 0.2) + (averageRating * 0.2) + (penaltyFactor * 0.2)
    double finalScore = (successRate * 0.4) +
                        (proofQuality * 0.2) +
                        (ratingFactor * 0.2) +
                        (penaltyFactor * 0.2);

    await users.doc(userId).update({
      'trustScore': finalScore.clamp(0, 100).toInt(),
      'cancellationRate': calcCancellationRate,
    });
  }
}
