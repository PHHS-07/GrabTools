import 'package:url_launcher/url_launcher.dart';

class PaymentsService {
  static final RegExp _upiIdPattern = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');

  bool isValidUpiId(String value) => _upiIdPattern.hasMatch(value.trim());

  Future<bool> launchUpiPayment({
    required String upiId,
    required String payeeName,
    required double amount,
    required String transactionRef,
    required String note,
  }) async {
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upiId.trim(),
        'pn': payeeName.trim(),
        'am': amount.toStringAsFixed(2),
        'cu': 'INR',
        'tr': transactionRef,
        'tn': note,
      },
    );

    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      // If no app can handle the UPI scheme (e.g. on an emulator or a phone without UPI apps),
      // url_launcher throws an exception instead of returning false on some platforms.
      return false;
    }
  }

  String buildPaymentReference(String bookingId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'GT-$bookingId-$timestamp';
  }

  String paymentStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Payment: paid';
      case 'pending_verification':
        return 'Payment: pending verification';
      case 'unpaid':
      default:
        return 'Payment: unpaid';
    }
  }

  String payeeNameFromProfile({
    String? username,
    String? displayName,
    required String fallbackEmail,
  }) {
    final raw = username ?? displayName ?? fallbackEmail;
    return raw.trim().isEmpty ? 'GrabTools Lender' : raw.trim();
  }
}