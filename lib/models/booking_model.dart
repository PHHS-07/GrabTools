class Booking {
  final String id;
  final int? bookingNumber;
  final String toolId;
  final String toolName;
  final String renterId;
  final String lenderId;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // requested, approved, rejected, active, completed, cancelled
  final double totalPrice;
  final String paymentStatus; // unpaid, pending_verification
  final String? paymentMethod;
  final String? paymentReference;
  final String? pendingActionType; // extend, return
  final String? pendingActionStatus; // requested
  final String? pendingActionPaymentMode;
  final DateTime? requestedEndDate;
  final double? requestedTotalPrice;

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
    this.paymentStatus = 'unpaid',
    this.paymentMethod,
    this.paymentReference,
    this.pendingActionType,
    this.pendingActionStatus,
    this.pendingActionPaymentMode,
    this.requestedEndDate,
    this.requestedTotalPrice,
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
        paymentStatus: map['paymentStatus'] as String? ?? 'unpaid',
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
      );
}
