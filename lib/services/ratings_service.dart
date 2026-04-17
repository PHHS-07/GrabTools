import 'package:cloud_firestore/cloud_firestore.dart';

class Rating {
  final String id;
  final String ownerId; // user who received the rating
  final String reviewerId;
  final String bookingId;
  final String? recipientRole;
  final String? toolId;
  final String? toolName;
  final String? toolCategory;
  final int behavior; // 1-5
  final int? toolRating; // 1-5
  final String? comment;
  final DateTime createdAt;

  Rating({
    required this.id,
    required this.ownerId,
    required this.reviewerId,
    required this.bookingId,
    this.recipientRole,
    this.toolId,
    this.toolName,
    this.toolCategory,
    required this.behavior,
    this.toolRating,
    this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'reviewerId': reviewerId,
        'bookingId': bookingId,
        'recipientRole': recipientRole,
        'toolId': toolId,
        'toolName': toolName,
        'toolCategory': toolCategory,
        'behavior': behavior,
        'toolRating': toolRating,
        'comment': comment,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Rating.fromDoc(DocumentSnapshot d) {
    final map = d.data() as Map<String, dynamic>;
    return Rating(
      id: d.id,
      ownerId: map['ownerId'] as String,
      reviewerId: map['reviewerId'] as String? ?? '',
      bookingId: map['bookingId'] as String? ?? '',
      recipientRole: map['recipientRole'] as String?,
      toolId: map['toolId'] as String?,
      toolName: map['toolName'] as String?,
      toolCategory: map['toolCategory'] as String?,
      behavior: (map['behavior'] as num).toInt(),
      toolRating: (map['toolRating'] as num?)?.toInt(),
      comment: map['comment'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class RatingsService {
  final CollectionReference ratings = FirebaseFirestore.instance.collection('ratings');

  Future<String> submitRating(Rating r) async {
    final doc = await ratings.add(r.toMap());
    return doc.id;
  }

  Future<bool> hasRatingForBooking({
    required String bookingId,
    required String reviewerId,
  }) async {
    final snap = await ratings
        .where('bookingId', isEqualTo: bookingId)
        .where('reviewerId', isEqualTo: reviewerId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Stream<List<Rating>> streamRatingsForOwner(String ownerId, {String? role}) {
    // No orderBy — avoids composite index requirement. Sorted client-side.
    var q = ratings.where('ownerId', isEqualTo: ownerId);
    if (role != null) {
      q = q.where('recipientRole', isEqualTo: role);
    }
    return q.snapshots().map((s) {
      final list = s.docs.map((d) => Rating.fromDoc(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<Rating>> streamRatingsByTool(String toolId) {
    // No orderBy to avoid composite index requirement — sorted client-side.
    return ratings.where('toolId', isEqualTo: toolId).snapshots().map((s) {
      final list = s.docs.map((d) => Rating.fromDoc(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<Rating>> streamRatingsForBooking(String bookingId) {
    // No orderBy — avoids composite index requirement. Sorted client-side.
    return ratings.where('bookingId', isEqualTo: bookingId).snapshots().map((s) {
      final list = s.docs.map((d) => Rating.fromDoc(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // Aggregate average behavior score
  Future<double> averageBehavior(String ownerId, {String? role}) async {
    var q = ratings.where('ownerId', isEqualTo: ownerId);
    if (role != null) {
      q = q.where('recipientRole', isEqualTo: role);
    }
    final snap = await q.get();
    final docs = snap.docs;
    if (docs.isEmpty) return 0.0;
    final sum = docs.fold<int>(0, (p, d) => p + ((d.data() as Map<String, dynamic>)['behavior'] as int));
    return sum / docs.length;
  }

  // Aggregate average tool rating grouped by category
  Future<Map<String, double>> averageToolRatingsByCategory(String ownerId, {String? role}) async {
    var q = ratings.where('ownerId', isEqualTo: ownerId);
    if (role != null) {
      q = q.where('recipientRole', isEqualTo: role);
    }
    final snap = await q.get();
    final docs = snap.docs;
    final Map<String, List<int>> groups = {};
    for (final d in docs) {
      final map = d.data() as Map<String, dynamic>;
      final cat = map['toolCategory'] as String? ?? 'Uncategorized';
      final r = (map['toolRating'] as num?)?.toInt();
      if (r == null) continue;
      groups.putIfAbsent(cat, () => []).add(r);
    }
    final result = <String, double>{};
    groups.forEach((k, list) {
      if (list.isNotEmpty) result[k] = list.reduce((a, b) => a + b) / list.length;
    });
    return result;
  }
}