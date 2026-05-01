class Dispute {
  final String id;
  final String bookingId;
  final String raisedBy;
  final String reason;
  final String description;
  final List<String> evidenceUrls;
  final String status; // open, under_review, resolved
  final String resolution; // none, refund, partial, rejected
  final DateTime createdAt;

  Dispute({
    required this.id,
    required this.bookingId,
    required this.raisedBy,
    required this.reason,
    required this.description,
    this.evidenceUrls = const [],
    this.status = 'open',
    this.resolution = 'none',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'bookingId': bookingId,
        'raisedBy': raisedBy,
        'reason': reason,
        'description': description,
        'evidenceUrls': evidenceUrls,
        'status': status,
        'resolution': resolution,
        'createdAt': createdAt.toUtc(),
      };

  factory Dispute.fromMap(String id, Map<String, dynamic> map) => Dispute(
        id: id,
        bookingId: map['bookingId'] as String,
        raisedBy: map['raisedBy'] as String,
        reason: map['reason'] as String,
        description: map['description'] as String,
        evidenceUrls: List<String>.from(map['evidenceUrls'] ?? []),
        status: map['status'] as String? ?? 'open',
        resolution: map['resolution'] as String? ?? 'none',
        createdAt: map['createdAt'] is DateTime
            ? map['createdAt'] as DateTime
            : (map['createdAt'] as dynamic).toDate() as DateTime,
      );
}
