import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

class ReviewsService {
  final CollectionReference reviews = FirebaseFirestore.instance.collection('reviews');

  Future<String> addReview(Review review) async {
    final doc = await reviews.add(review.toMap());
    return doc.id;
  }

  Future<void> submitReview(Review review) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(review.targetUserId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // 1. Get current user data
      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists) return;

      final userData = userSnap.data() as Map<String, dynamic>;
      final double currentAvg = (userData['averageRating'] as num?)?.toDouble() ?? 0.0;
      final int currentTotal = (userData['totalReviews'] as num?)?.toInt() ?? 0;

      // 2. Calculate new rating
      final int nextTotal = currentTotal + 1;
      final double nextAvg = ((currentAvg * currentTotal) + review.rating) / nextTotal;

      // 3. Update User
      transaction.update(userRef, {
        'averageRating': nextAvg,
        'totalReviews': nextTotal,
      });

      // 4. Add Review
      final reviewRef = reviews.doc();
      transaction.set(reviewRef, review.toMap());

      // 5. Update Booking (mark as reviewed if we had a field, but for now we just link)
      // No specific 'isReviewed' field requested in model yet, but we can add it or just rely on reviews collection.
    });
  }

  Stream<List<Review>> fetchUserReviews(String userId) {
    return reviews
        .where('targetUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Review.fromMap(d.id, d.data() as Map<String, dynamic>)).toList());
  }

  Stream<List<Review>> streamReviewsForTool(String toolId) {
    // Note: Review model was updated to be booking/user centric. 
    // For tool reviews, we might need to filter by bookingId if bookings are linked to tools.
    // Or we keep toolId in Review. For now, I'll update this to a generic query if needed.
    return reviews.where('toolId', isEqualTo: toolId).snapshots().map((s) => s.docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return Review.fromMap(d.id, data);
        }).toList());
  }
}
