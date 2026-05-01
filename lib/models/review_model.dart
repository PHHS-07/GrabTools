class Review {
  final String id;
  final String bookingId;
  final String reviewerId;
  final String targetUserId; // The user being reviewed (lender or renter)
  final int rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.bookingId,
    required this.reviewerId,
    required this.targetUserId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'bookingId': bookingId,
        'reviewerId': reviewerId,
        'targetUserId': targetUserId,
        'rating': rating,
        'comment': comment,
        'createdAt': createdAt.toUtc(),
      };

  factory Review.fromMap(String id, Map<String, dynamic> map) => Review(
        id: id,
        bookingId: map['bookingId'] as String? ?? '',
        reviewerId: map['reviewerId'] as String? ?? (map['userId'] as String? ?? ''),
        targetUserId: map['targetUserId'] as String? ?? '',
        rating: (map['rating'] as num?)?.toInt() ?? 0,
        comment: map['comment'] as String? ?? '',
        createdAt: map['createdAt'] == null
            ? DateTime.now()
            : (map['createdAt'] is DateTime
                ? map['createdAt'] as DateTime
                : (map['createdAt'] as dynamic).toDate() as DateTime),
      );
}
