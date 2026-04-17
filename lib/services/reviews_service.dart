import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

class ReviewsService {
  final CollectionReference reviews = FirebaseFirestore.instance.collection('reviews');

  Future<String> addReview(Review review) async {
    final doc = await reviews.add(review.toMap());
    return doc.id;
  }

  Stream<List<Review>> streamReviewsForTool(String toolId) {
    return reviews.where('toolId', isEqualTo: toolId).snapshots().map((s) => s.docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return Review(
            id: d.id,
            toolId: data['toolId'] as String,
            userId: data['userId'] as String,
            rating: (data['rating'] as num).toInt(),
            comment: data['comment'] as String,
            createdAt: (data['createdAt'] as Timestamp).toDate(),
          );
        }).toList());
  }
}
