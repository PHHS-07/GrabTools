class Review {
  final String id;
  final String toolId;
  final String userId;
  final int rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.toolId,
    required this.userId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'toolId': toolId,
        'userId': userId,
        'rating': rating,
        'comment': comment,
        'createdAt': createdAt.toUtc(),
      };

  factory Review.fromMap(String id, Map<String, dynamic> map) => Review(
        id: id,
        toolId: map['toolId'] as String,
        userId: map['userId'] as String,
        rating: map['rating'] as int,
        comment: map['comment'] as String,
        createdAt: (map['createdAt'] as DateTime),
      );
}
