import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';

class BookingsService {
  final CollectionReference bookings = FirebaseFirestore.instance.collection('bookings');
  final DocumentReference counters = FirebaseFirestore.instance.collection('app_meta').doc('counters');

  Future<String> createBooking(Booking booking) async {
    final docRef = bookings.doc();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final counterSnapshot = await transaction.get(counters);
      final currentCounter = counterSnapshot.exists
          ? ((counterSnapshot.data() as Map<String, dynamic>)['bookingCounter'] as num? ?? 0).toInt()
          : 0;
      final nextCounter = currentCounter + 1;

      transaction.set(counters, {'bookingCounter': nextCounter}, SetOptions(merge: true));
      final now = DateTime.now().toUtc();
      transaction.set(
        docRef,
        Booking(
          id: docRef.id,
          bookingNumber: nextCounter,
          toolId: booking.toolId,
          toolName: booking.toolName,
          renterId: booking.renterId,
          lenderId: booking.lenderId,
          startDate: booking.startDate,
          endDate: booking.endDate,
          status: booking.status,
          totalPrice: booking.totalPrice,
          paymentStatus: booking.paymentStatus,
          paymentMethod: booking.paymentMethod,
          paymentReference: booking.paymentReference,
          pendingActionType: booking.pendingActionType,
          pendingActionStatus: booking.pendingActionStatus,
          pendingActionPaymentMode: booking.pendingActionPaymentMode,
          requestedEndDate: booking.requestedEndDate,
          requestedTotalPrice: booking.requestedTotalPrice,
          createdAt: now,
          updatedAt: now,
        ).toMap(),
      );
    });
    return docRef.id;
  }

  Booking _mapBooking(DocumentSnapshot<Object?> d) {
    final data = d.data() as Map<String, dynamic>;
    return Booking.fromMap(d.id, data);
  }

  Future<void> updateBookingStatus(String id, String status) async {
    final docRef = bookings.doc(id);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;
    final data = snapshot.data() as Map<String, dynamic>;
    
    await FirebaseFirestore.instance.runTransaction((transaction) async {
       transaction.update(docRef, {
         'status': status,
         'updatedAt': DateTime.now().toUtc(),
       });

       // Update tool bookedDates upon confirmation
       if (status == 'confirmed') {
         final toolId = data['toolId'] as String?;
         if (toolId != null) {
           final toolRef = FirebaseFirestore.instance.collection('tools').doc(toolId);
           final start = (data['startDate'] as dynamic).toDate() as DateTime;
           final end = (data['endDate'] as dynamic).toDate() as DateTime;
           transaction.update(toolRef, {
             'bookedRanges': FieldValue.arrayUnion([{
               'startDate': start.toUtc(),
               'endDate': end.toUtc()
             }])
           });
         }
       }
    });

    // If booking completed, credit lender earnings
    if (status == 'completed') {
      final lenderId = data['lenderId'] as String?;
      final totalPrice = (data['totalPrice'] as num?)?.toDouble() ?? 0.0;
      if (lenderId != null && totalPrice > 0) {
        await FirebaseFirestore.instance.collection('users').doc(lenderId).set({'earnings': FieldValue.increment(totalPrice)}, SetOptions(merge: true));
      }
    }
  }

  Stream<List<Booking>> streamBookingsForUser(String userId) {
    return bookings.where('renterId', isEqualTo: userId).snapshots().map(
          (s) => s.docs.map(_mapBooking).toList(),
        );
  }

  Future<void> updateBookingPayment({
    required String id,
    required String paymentStatus,
    required String paymentMethod,
    required String paymentReference,
  }) async {
    await bookings.doc(id).update({
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'paymentReference': paymentReference,
    });
  }

  Future<void> updateBookingSchedule({
    required String id,
    required DateTime endDate,
    required double totalPrice,
  }) async {
    await bookings.doc(id).update({
      'endDate': endDate.toUtc(),
      'totalPrice': totalPrice,
    });
  }

  Future<void> requestBookingExtension({
    required String id,
    required DateTime requestedEndDate,
    required double requestedTotalPrice,
  }) async {
    await bookings.doc(id).update({
      'pendingActionType': 'extend',
      'pendingActionStatus': 'requested',
      'requestedEndDate': requestedEndDate.toUtc(),
      'requestedTotalPrice': requestedTotalPrice,
    });
  }

  Future<void> requestBookingReturn({
    required String id,
    required String paymentMode,
    required double requestedTotalPrice,
  }) async {
    await bookings.doc(id).update({
      'pendingActionType': 'return',
      'pendingActionStatus': 'requested',
      'pendingActionPaymentMode': paymentMode,
      'requestedTotalPrice': requestedTotalPrice,
    });
  }

  Future<void> resolvePendingAction({
    required String id,
    required bool approve,
  }) async {
    final docRef = bookings.doc(id);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final booking = _mapBooking(snapshot);
      final pendingType = booking.pendingActionType;
      final pendingStatus = booking.pendingActionStatus;
      if (pendingType == null || pendingStatus != 'requested') return;

      final updates = <String, dynamic>{
        'pendingActionType': FieldValue.delete(),
        'pendingActionStatus': FieldValue.delete(),
        'pendingActionPaymentMode': FieldValue.delete(),
        'requestedEndDate': FieldValue.delete(),
        'requestedTotalPrice': FieldValue.delete(),
        'updatedAt': DateTime.now().toUtc(),
      };

      if (approve) {
        if (pendingType == 'extend') {
          updates['endDate'] = booking.requestedEndDate?.toUtc();
          updates['totalPrice'] = booking.requestedTotalPrice;
        } else if (pendingType == 'return') {
          updates['status'] = 'completed';
          updates['paymentStatus'] = 'paid';
          if (booking.pendingActionPaymentMode != null) {
            updates['paymentMethod'] = booking.pendingActionPaymentMode;
          }
          if (booking.requestedTotalPrice != null) {
            updates['totalPrice'] = booking.requestedTotalPrice;
          }
        }
      }

      transaction.update(docRef, updates);

      if (approve && pendingType == 'return') {
        final lenderId = booking.lenderId;
        final totalPrice = booking.requestedTotalPrice ?? booking.totalPrice;
        transaction.set(
          FirebaseFirestore.instance.collection('users').doc(lenderId),
          {'earnings': FieldValue.increment(totalPrice)},
          SetOptions(merge: true),
        );
      }
    });
  }

  Stream<List<Booking>> streamBookingsForLender(String lenderId) {
    return bookings.where('lenderId', isEqualTo: lenderId).snapshots().map(
          (s) => s.docs.map(_mapBooking).toList(),
        );
  }

  Stream<bool> streamToolCurrentlyUnavailable(String toolId) {
    return bookings.where('toolId', isEqualTo: toolId).snapshots().map((s) {
      final now = DateTime.now();
      return s.docs
          .map(_mapBooking)
          .any((booking) {
            final normalizedStatus = booking.status.toLowerCase();
            final isAccepted = normalizedStatus == 'approved' || normalizedStatus == 'confirmed' || normalizedStatus == 'in_progress';
            if (!isAccepted) return false;
            // Unavailable as soon as approved — covers both upcoming and ongoing bookings.
            // Only clears once the booking end date has passed.
            return booking.endDate.isAfter(now);
          });
    });
  }

  Stream<bool> streamToolEffectivelyAvailable({
    required String toolId,
    required bool toolMarkedAvailable,
  }) {
    return streamToolCurrentlyUnavailable(toolId).map(
      (isUnavailable) => toolMarkedAvailable && !isUnavailable,
    );
  }

  Future<bool> isToolCurrentlyUnavailable(String toolId, DateTime requestedStart, DateTime requestedEnd) async {
    final snapshot = await bookings.where('toolId', isEqualTo: toolId).get();
    return snapshot.docs
        .map(_mapBooking)
        .any((booking) {
          final normalizedStatus = booking.status.toLowerCase();
          final isAccepted = normalizedStatus == 'approved' || normalizedStatus == 'confirmed' || normalizedStatus == 'in_progress';
          if (!isAccepted) return false;

          // Check for date overlap: (StartA <= EndB) and (EndA >= StartB)
          final overlap = requestedStart.isBefore(booking.endDate) && requestedEnd.isAfter(booking.startDate);
          return overlap;
        });
  }
}