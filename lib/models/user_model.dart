class AppUser {
  final String id;
  final String email;
  final String role; // 'seeker' | 'lender' | 'admin'
  final DateTime? createdAt;
  final String? displayName;
  final String? photoUrl;
  final String? username;
  final String? phoneNumber;
  final String gender;
  final String? upiId;
  final String? paymentMode;
  final double earnings;
  final int trustScore;

  AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.createdAt,
    this.displayName,
    this.photoUrl,
    this.username,
    this.phoneNumber,
    this.gender = 'Rather Not Say',
    this.upiId,
    this.paymentMode,
    this.earnings = 0.0,
    this.trustScore = 50,
  });

  Map<String, dynamic> toMap() => {
        'uid': id,
        'email': email,
        'role': role,
        'createdAt': createdAt?.toUtc(),
        'displayName': displayName,
        'photoUrl': photoUrl,
        'username': username,
        'phoneNumber': phoneNumber,
        'gender': gender,
        'upiId': upiId,
        'paymentMode': paymentMode,
        'earnings': earnings,
        'trustScore': trustScore,
      };

  factory AppUser.fromMap(String id, Map<String, dynamic> map) => AppUser(
        id: id,
        email: map['email'] as String,
        role: map['role'] as String? ?? 'seeker',
        createdAt: map['createdAt'] == null
            ? null
            : (map['createdAt'] is DateTime
                ? map['createdAt'] as DateTime
                : (map['createdAt'] as dynamic).toDate() as DateTime),
        displayName: map['displayName'] as String?,
        photoUrl: map['photoUrl'] as String?,
        username: map['username'] as String?,
        phoneNumber: map['phoneNumber'] as String?,
        gender: map['gender'] as String? ?? 'Rather Not Say',
        upiId: map['upiId'] as String?,
        paymentMode: map['paymentMode'] as String?,
        earnings: (map['earnings'] as num?)?.toDouble() ?? 0.0,
        trustScore: (map['trustScore'] as num?)?.toInt() ?? 50,
      );
}
