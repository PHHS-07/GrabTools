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
      );
}
