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
  final List<DateTime> bookedDates;
  final List<DateTime> blockedDates;
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
    this.bookedDates = const [],
    this.blockedDates = const [],
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
        'bookedDates': bookedDates.map((d) => d.toUtc()).toList(),
        'blockedDates': blockedDates.map((d) => d.toUtc()).toList(),
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
        bookedDates: (map['bookedDates'] as List<dynamic>?)
                ?.map((d) => d is DateTime ? d : (d as dynamic).toDate() as DateTime)
                .toList() ??
            const [],
        blockedDates: (map['blockedDates'] as List<dynamic>?)
                ?.map((d) => d is DateTime ? d : (d as dynamic).toDate() as DateTime)
                .toList() ??
            const [],
        ownerTrustScore: (map['ownerTrustScore'] as num?)?.toDouble() ?? 0.0,
        bookingCount: (map['bookingCount'] as num?)?.toInt() ?? 0,
        ratingScore: (map['ratingScore'] as num?)?.toDouble() ?? 0.0,
      );
}
