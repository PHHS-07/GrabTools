class DateRange {
  final DateTime startDate;
  final DateTime endDate;
  DateRange({required this.startDate, required this.endDate});
  Map<String, dynamic> toMap() => {
    'startDate': startDate.toUtc(),
    'endDate': endDate.toUtc(),
  };
  factory DateRange.fromMap(Map<String, dynamic> map) => DateRange(
    startDate: map['startDate'] is DateTime ? map['startDate'] : (map['startDate'] as dynamic).toDate() as DateTime,
    endDate: map['endDate'] is DateTime ? map['endDate'] : (map['endDate'] as dynamic).toDate() as DateTime,
  );
}

class Tool {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final double pricePerDay;
  final List<String> imageUrls;
  final List<String> imageStoragePaths;
  final List<String> categories;
  final String? address; // Human-readable address
  final Map<String, dynamic>? location; // {lat, lng}
  final String conditionStatus;
  final String? termsAndConditions;
  final bool available;

  final String? proofImageUrl;
  final String? proofStoragePath;
  final bool isSuspicious;
  final bool isVerified;
  final String visibility;
  final List<DateRange> bookedRanges;
  final List<DateRange> blockedRanges;
  final double ownerTrustScore;
  final int bookingCount;
  final double ratingScore;

  Tool({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.pricePerDay,
    this.imageUrls = const [],
    this.imageStoragePaths = const [],
    this.categories = const [],
    this.address,
    this.location,
    required this.conditionStatus,
    this.termsAndConditions,
    this.available = true,
    this.proofImageUrl,
    this.proofStoragePath,
    this.isSuspicious = false,
    this.isVerified = false,
    this.visibility = 'visible',
    this.bookedRanges = const [],
    this.blockedRanges = const [],
    this.ownerTrustScore = 0.0,
    this.bookingCount = 0,
    this.ratingScore = 0.0,
  });

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'title': title,
        'description': description,
        'pricePerDay': pricePerDay,
        'imageUrls': imageUrls,
        'imageStoragePaths': imageStoragePaths,
        'categories': categories,
        'address': address,
        'location': location,
        'conditionStatus': conditionStatus,
        'termsAndConditions': termsAndConditions,
        'available': available,
        'proofImageUrl': proofImageUrl,
        'proofStoragePath': proofStoragePath,
        'isSuspicious': isSuspicious,
        'isVerified': isVerified,
        'visibility': visibility,
        'bookedRanges': bookedRanges.map((r) => r.toMap()).toList(),
        'blockedRanges': blockedRanges.map((r) => r.toMap()).toList(),
        'ownerTrustScore': ownerTrustScore,
        'bookingCount': bookingCount,
        'ratingScore': ratingScore,
      };

  factory Tool.fromMap(String id, Map<String, dynamic> map) => Tool(
        id: id,
        ownerId: map['ownerId'] as String,
        title: map['title'] as String,
        description: map['description'] as String,
        pricePerDay: (map['pricePerDay'] as num).toDouble(),
        imageUrls: List<String>.from(map['imageUrls'] ?? []),
        imageStoragePaths: List<String>.from(map['imageStoragePaths'] ?? []),
        categories: List<String>.from(map['categories'] ?? []),
        address: map['address'] as String?,
        location: map['location'] as Map<String, dynamic>?,
        conditionStatus: map['conditionStatus'] as String? ?? '',
        termsAndConditions: map['termsAndConditions'] as String?,
        available: map['available'] as bool? ?? true,
        proofImageUrl: map['proofImageUrl'] as String?,
        proofStoragePath: map['proofStoragePath'] as String?,
        isSuspicious: map['isSuspicious'] as bool? ?? false,
        isVerified: map['isVerified'] as bool? ?? false,
        visibility: map['visibility'] as String? ?? 'visible',
        bookedRanges: (map['bookedRanges'] as List<dynamic>?)
                ?.map((r) => DateRange.fromMap(r as Map<String, dynamic>))
                .toList() ??
            const [],
        blockedRanges: (map['blockedRanges'] as List<dynamic>?)
                ?.map((r) => DateRange.fromMap(r as Map<String, dynamic>))
                .toList() ??
            const [],
        ownerTrustScore: (map['ownerTrustScore'] as num?)?.toDouble() ?? 0.0,
        bookingCount: (map['bookingCount'] as num?)?.toInt() ?? 0,
        ratingScore: (map['ratingScore'] as num?)?.toDouble() ?? 0.0,
      );
}
