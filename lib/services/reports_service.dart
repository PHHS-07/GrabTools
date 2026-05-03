import 'package:cloud_firestore/cloud_firestore.dart';

class ToolReport {
  final String id;
  final String toolId;
  final String toolName;
  final String reporterId;
  final String reason;
  final String? details;
  final DateTime createdAt;

  ToolReport({
    required this.id,
    required this.toolId,
    required this.toolName,
    required this.reporterId,
    required this.reason,
    this.details,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'toolId': toolId,
        'toolName': toolName,
        'reporterId': reporterId,
        'reason': reason,
        'details': details,
        'createdAt': Timestamp.fromDate(createdAt),
        'status': 'pending', // pending, reviewed, dismissed
      };
}

class ReportsService {
  final CollectionReference _reports =
      FirebaseFirestore.instance.collection('reports');

  Future<void> submitReport(ToolReport report) async {
    await _reports.add(report.toMap());
  }

  /// Check if this user has already reported this tool
  Future<bool> hasReported({
    required String toolId,
    required String reporterId,
  }) async {
    try {
      final snap = await _reports
          .where('toolId', isEqualTo: toolId)
          .where('reporterId', isEqualTo: reporterId)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      // If rules deny read access, allow the report dialogue to show anyway
      return false;
    }
  }
}