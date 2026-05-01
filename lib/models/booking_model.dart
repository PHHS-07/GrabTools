class Booking {
  final String id;
  final int? bookingNumber;
  final String toolId;
  final String toolName;
  final String renterId;
  final String lenderId;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // requested, approved, paid, verified, completed, cancelled, expired
  final double totalPrice;
  final String paymentStatus; // pending, paid, verified
  final String? paymentMethod;
  final String? paymentReference;
  final String? pendingActionType; // extend, return
  final String? pendingActionStatus; // requested
  final String? pendingActionPaymentMode;
  final DateTime? requestedEndDate;
  final double? requestedTotalPrice;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // New Trust & Stabilization Fields
  final String? paymentProofUrl;
  final String? proofType; // none, selfie, selfie_code, video
  final String? proofUrl;
  final bool proofSubmitted;
  final String? verificationCode;
  final DateTime? verificationGeneratedAt;
  final double proofConfidenceScore;
  final DateTime? pickupTimestamp;
  final Map<String, dynamic>? pickupLocation; // {lat, lng}
  final String? disputeId;
  final String refundStatus; // none, requested, approved, rejected
  final String? refundReason;

  Booking({
    required this.id,
    this.bookingNumber,
    required this.toolId,
    required this.toolName,
    required this.renterId,
    required this.lenderId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.totalPrice,
    this.paymentStatus = 'pending',
    this.paymentMethod,
    this.paymentReference,
    this.pendingActionType,
    this.pendingActionStatus,
    this.pendingActionPaymentMode,
    this.requestedEndDate,
    this.requestedTotalPrice,
    this.createdAt,
    this.updatedAt,
    this.paymentProofUrl,
    this.proofType,
    this.proofUrl,
    this.proofSubmitted = false,
    this.verificationCode,
    this.verificationGeneratedAt,
    this.proofConfidenceScore = 0.0,
    this.pickupTimestamp,
    this.pickupLocation,
    this.disputeId,
    this.refundStatus = 'none',
    this.refundReason,
  });

  String get displayBookingId =>
      bookingNumber == null ? id : 'BK-${bookingNumber!.toString().padLeft(6, '0')}';

  Map<String, dynamic> toMap() => {
        'bookingNumber': bookingNumber,
        'toolId': toolId,
        'toolName': toolName,
        'renterId': renterId,
        'lenderId': lenderId,
        'startDate': startDate.toUtc(),
        'endDate': endDate.toUtc(),
        'status': status,
        'totalPrice': totalPrice,
        'paymentStatus': paymentStatus,
        'paymentMethod': paymentMethod,
        'paymentReference': paymentReference,
        'pendingActionType': pendingActionType,
        'pendingActionStatus': pendingActionStatus,
        'pendingActionPaymentMode': pendingActionPaymentMode,
        'requestedEndDate': requestedEndDate?.toUtc(),
        'requestedTotalPrice': requestedTotalPrice,
        'createdAt': createdAt?.toUtc(),
        'updatedAt': updatedAt?.toUtc(),
        'paymentProofUrl': paymentProofUrl,
        'proofType': proofType,
        'proofUrl': proofUrl,
        'proofSubmitted': proofSubmitted,
        'verificationCode': verificationCode,
        'verificationGeneratedAt': verificationGeneratedAt?.toUtc(),
        'proofConfidenceScore': proofConfidenceScore,
        'pickupTimestamp': pickupTimestamp?.toUtc(),
        'pickupLocation': pickupLocation,
        'disputeId': disputeId,
        'refundStatus': refundStatus,
        'refundReason': refundReason,
      };

  factory Booking.fromMap(String id, Map<String, dynamic> map) => Booking(
        id: id,
        bookingNumber: map['bookingNumber'] as int?,
        toolId: map['toolId'] as String,
        toolName: map['toolName'] as String? ?? '',
        renterId: map['renterId'] as String,
        lenderId: map['lenderId'] as String,
        startDate: map['startDate'] is DateTime
            ? map['startDate'] as DateTime
            : (map['startDate'] as dynamic).toDate() as DateTime,
        endDate: map['endDate'] is DateTime
            ? map['endDate'] as DateTime
            : (map['endDate'] as dynamic).toDate() as DateTime,
        status: map['status'] as String,
        totalPrice: (map['totalPrice'] as num).toDouble(),
        paymentStatus: map['paymentStatus'] as String? ?? 'pending',
        paymentMethod: map['paymentMethod'] as String?,
        paymentReference: map['paymentReference'] as String?,
        pendingActionType: map['pendingActionType'] as String?,
        pendingActionStatus: map['pendingActionStatus'] as String?,
        pendingActionPaymentMode: map['pendingActionPaymentMode'] as String?,
        requestedEndDate: map['requestedEndDate'] == null
            ? null
            : (map['requestedEndDate'] is DateTime
                ? map['requestedEndDate'] as DateTime
                : (map['requestedEndDate'] as dynamic).toDate() as DateTime),
        requestedTotalPrice: (map['requestedTotalPrice'] as num?)?.toDouble(),
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] is DateTime ? map['createdAt'] as DateTime : (map['createdAt'] as dynamic).toDate() as DateTime)
            : null,
        updatedAt: map['updatedAt'] != null
            ? (map['updatedAt'] is DateTime ? map['updatedAt'] as DateTime : (map['updatedAt'] as dynamic).toDate() as DateTime)
            : null,
        paymentProofUrl: map['paymentProofUrl'] as String?,
        proofType: map['proofType'] as String?,
        proofUrl: map['proofUrl'] as String?,
        proofSubmitted: map['proofSubmitted'] as bool? ?? false,
        verificationCode: map['verificationCode'] as String?,
        verificationGeneratedAt: map['verificationGeneratedAt'] != null
            ? (map['verificationGeneratedAt'] is DateTime ? map['verificationGeneratedAt'] as DateTime : (map['verificationGeneratedAt'] as dynamic).toDate() as DateTime)
            : null,
        proofConfidenceScore: (map['proofConfidenceScore'] as num?)?.toDouble() ?? 0.0,
        pickupTimestamp: map['pickupTimestamp'] != null
            ? (map['pickupTimestamp'] is DateTime ? map['pickupTimestamp'] as DateTime : (map['pickupTimestamp'] as dynamic).toDate() as DateTime)
            : null,
        pickupLocation: map['pickupLocation'] as Map<String, dynamic>?,
        disputeId: map['disputeId'] as String?,
        refundStatus: map['refundStatus'] as String? ?? 'none',
        refundReason: map['refundReason'] as String?,
      );
}
