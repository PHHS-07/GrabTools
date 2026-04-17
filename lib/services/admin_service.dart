import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/tool_model.dart';
import 'reports_service.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ToolReport>> streamPendingReports() {
    return _db
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return ToolReport(
                id: doc.id,
                toolId: data['toolId'] ?? '',
                toolName: data['toolName'] ?? 'Unknown Tool',
                reporterId: data['reporterId'] ?? '',
                reason: data['reason'] ?? '',
                details: data['details'],
                createdAt: (data['createdAt'] as Timestamp).toDate(),
              );
            }).toList());
  }

  Stream<List<Tool>> streamSuspiciousTools() {
    return _db
        .collection('tools')
        .where('isSuspicious', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Tool.fromMap(doc.id, doc.data())).toList());
  }

  Stream<List<AppUser>> streamSuspiciousUsers() {
    // Users with trust score strictly below 30
    return _db
        .collection('users')
        .where('trustScore', isLessThan: 30)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AppUser.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> dismissReport(String reportId) async {
    await _db.collection('reports').doc(reportId).update({'status': 'dismissed'});
  }

  Future<void> deleteTool(String toolId) async {
    await _db.collection('tools').doc(toolId).delete();
  }

  Future<void> verifyTool(String toolId) async {
    await _db.collection('tools').doc(toolId).update({
      'isSuspicious': false,
      'isVerified': true,
      'visibility': 'public',
    });
  }

  Future<void> resetTrustScore(String userId) async {
    await _db.collection('users').doc(userId).update({'trustScore': 50});
  }
}
