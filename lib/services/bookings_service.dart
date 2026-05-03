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
    });
    
    // Sync bookedRanges to the tool document so the calendar updates correctly
    _syncToolBookedRanges(data['toolId'] as String?);

    // If booking completed, credit lender earnings and update stats
    if (status == 'completed') {
      final lenderId = data['lenderId'] as String?;
      final renterId = data['renterId'] as String?;
      final toolId = data['toolId'] as String?;
      final totalPrice = (data['totalPrice'] as num?)?.toDouble() ?? 0.0;
      if (lenderId != null && totalPrice > 0) {
        await FirebaseFirestore.instance.collection('users').doc(lenderId).set({
          'earnings': FieldValue.increment(totalPrice),
          'totalBookings': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
      if (renterId != null) {
        await FirebaseFirestore.instance.collection('users').doc(renterId).set({
          'totalBookings': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
      if (toolId != null) {
        await FirebaseFirestore.instance.collection('tools').doc(toolId).set({
          'totalBookings': FieldValue.increment(1),
          'lastRentedAt': DateTime.now().toUtc(),
        }, SetOptions(merge: true));
      }
    }

    if (status == 'cancelled') {
      final renterId = data['renterId'] as String?;
      if (renterId != null) {
        await FirebaseFirestore.instance.collection('users').doc(renterId).set({
          'totalCancellations': FieldValue.increment(1),
        }, SetOptions(merge: true));
        // Need to update cancellationRate asynchronously via cloud function or rule, 
        // or we do it carefully on the client. For now, incrementing cancellations.
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

  Future<void> processBookingPayment({
    required String id,
    required String method,
    String? reference,
    String? proofUrl,
  }) async {
    final data = <String, dynamic>{
      'paymentStatus': 'paid',
      'paymentMethod': method,
      'status': 'paid',
      'updatedAt': DateTime.now().toUtc(),
    };
    if (reference != null) data['paymentReference'] = reference;
    if (proofUrl != null) data['paymentProofUrl'] = proofUrl;
    await bookings.doc(id).update(data);
  }

  Future<void> submitPaymentProof(String id, String imageUrl) async {
    await bookings.doc(id).update({
      'paymentProofUrl': imageUrl,
      'paymentStatus': 'paid',
      'updatedAt': DateTime.now().toUtc(),
    });
  }

  Future<void> verifyPayment(String id) async {
    await bookings.doc(id).update({
      'paymentStatus': 'verified',
      'updatedAt': DateTime.now().toUtc(),
    });
  }

  Future<void> generateVerificationCode(String id) async {
    final code = 'GT-${(1000 + DateTime.now().millisecondsSinceEpoch % 9000).toString()}';
    await bookings.doc(id).update({
      'verificationCode': code,
      'verificationGeneratedAt': DateTime.now().toUtc(),
    });
  }

  Future<void> submitPickupProof({
    required String id,
    required String imageUrl,
    required Map<String, dynamic> location,
    required String type,
    required String expectedCode,
    required String actualCode,
    required bool isLiveCapture,
    required bool aiToolMatch,
    required bool gpsMatch,
  }) async {
    double score = 0;
    if (isLiveCapture) score += 40;
    if (gpsMatch) score += 20;
    if (aiToolMatch) score += 20;
    if (expectedCode.isNotEmpty && expectedCode == actualCode) score += 20;

    await bookings.doc(id).update({
      'proofUrl': imageUrl,
      'proofType': type,
      'proofSubmitted': true,
      'proofConfidenceScore': score,
      'pickupTimestamp': DateTime.now().toUtc(),
      'pickupLocation': location,
      'updatedAt': DateTime.now().toUtc(),
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
    final toolId = await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return null;
      final booking = _mapBooking(snapshot);
      final pendingType = booking.pendingActionType;
      final pendingStatus = booking.pendingActionStatus;
      if (pendingType == null || pendingStatus != 'requested') return null;

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
      return booking.toolId;
    });
    
    // Sync booked ranges after resolving action
    if (toolId != null) {
      _syncToolBookedRanges(toolId);
    }
  }

  Future<void> _syncToolBookedRanges(String? toolId) async {
    if (toolId == null) return;
    try {
      final snapshot = await bookings.where('toolId', isEqualTo: toolId).get();
      final active = snapshot.docs.map(_mapBooking).where((b) {
        final s = b.status.toLowerCase();
        return s == 'approved' || s == 'confirmed' || s == 'paid' || s == 'verified' || s == 'in_progress' || s == 'active';
      }).toList();
      
      final ranges = active.map((b) => {
        'startDate': b.startDate.toUtc(),
        'endDate': b.endDate.toUtc(),
      }).toList();

      await FirebaseFirestore.instance.collection('tools').doc(toolId).update({
        'bookedRanges': ranges,
      });
    } catch (e) {
      // Ignore
    }
  }

  Stream<List<Booking>> streamBookingsForLender(String lenderId) {
    return bookings.where('lenderId', isEqualTo: lenderId).snapshots().map(
          (s) => s.docs.map(_mapBooking).toList(),
        );
  }

  Stream<bool> streamToolCurrentlyUnavailable(String toolId) {
    try {
      return bookings.where('toolId', isEqualTo: toolId).snapshots().map((s) {
        final now = DateTime.now();
        return s.docs
            .map(_mapBooking)
            .any((booking) {
              final normalizedStatus = booking.status.toLowerCase();
              final isAccepted = normalizedStatus == 'approved' || normalizedStatus == 'confirmed' || normalizedStatus == 'in_progress';
              if (!isAccepted) return false;
              return booking.endDate.isAfter(now);
            });
      }).handleError((error) {
        // Fallback to false if rules deny access
        return false;
      });
    } catch (e) {
      return Stream.value(false);
    }
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
    try {
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
    } catch (e) {
      // Fallback to false if rules deny access
      return false;
    }
  }

  // --- New Dispute & Refund Features ---

  Future<void> createDispute({
    required String bookingId,
    required String raisedBy,
    required String reason,
    required String description,
    List<String> evidenceUrls = const [],
  }) async {
    final disputeRef = FirebaseFirestore.instance.collection('disputes').doc();
    final now = DateTime.now().toUtc();

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.set(disputeRef, {
        'bookingId': bookingId,
        'raisedBy': raisedBy,
        'reason': reason,
        'description': description,
        'evidenceUrls': evidenceUrls,
        'status': 'open',
        'resolution': 'none',
        'createdAt': now,
      });

      transaction.update(bookings.doc(bookingId), {
        'disputeId': disputeRef.id,
        'updatedAt': now,
      });
    });
  }

  Future<void> requestRefund(String bookingId, String reason) async {
    await bookings.doc(bookingId).update({
      'refundStatus': 'requested',
      'refundReason': reason,
      'updatedAt': DateTime.now().toUtc(),
    });
  }

  Future<void> resolveRefund(String bookingId, String status) async {
    final docRef = bookings.doc(bookingId);
    
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final booking = _mapBooking(snapshot);

      transaction.update(docRef, {
        'refundStatus': status,
        'updatedAt': DateTime.now().toUtc(),
      });

      if (status == 'approved') {
        // If approved, we need to deduct earnings from the lender
        final lenderId = booking.lenderId;
        final amountToRefund = booking.totalPrice;
        
        transaction.update(FirebaseFirestore.instance.collection('users').doc(lenderId), {
          'earnings': FieldValue.increment(-amountToRefund),
        });
        
        // Mark booking as cancelled or similar if needed? 
        // For now, just setting refundStatus is enough as per requirement.
      }
    });
  }
}