import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/booking_model.dart';
import '../models/tool_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/bookings_service.dart';
import '../services/payments_service.dart';
import '../services/users_service.dart';
import '../widgets/app_alerts.dart';

class BookingRequestScreen extends StatefulWidget {
  final Tool tool;
  const BookingRequestScreen({super.key, required this.tool});

  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  final PaymentsService _paymentsService = PaymentsService();
  DateTime? _start;
  DateTime? _end;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  double _calculateRentalDays(DateTime start, DateTime end) {
    final minutes = end.difference(start).inMinutes;
    if (minutes <= 0) return 1.0;
    return (minutes / (24 * 60)).ceilToDouble();
  }

  bool _isDateAvailable(DateTime day) {
    final d = DateTime.utc(day.year, day.month, day.day);
    bool isBooked = widget.tool.bookedRanges.any((range) =>
        (d.isAfter(range.startDate) || d.isAtSameMomentAs(range.startDate)) &&
        (d.isBefore(range.endDate) || d.isAtSameMomentAs(range.endDate)));
    bool isBlocked = widget.tool.blockedRanges.any((range) =>
        (d.isAfter(range.startDate) || d.isAtSameMomentAs(range.startDate)) &&
        (d.isBefore(range.endDate) || d.isAtSameMomentAs(range.endDate)));
    return !isBooked && !isBlocked;
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      selectableDayPredicate: _isDateAvailable,
    );
    if (picked != null) {
      setState(() {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) {
          _end = picked;
        }
        if (_isSameDayBooking) {
          _startTime ??= const TimeOfDay(hour: 9, minute: 0);
          _endTime ??= _addMinutes(_startTime!, 30);
        } else {
          _startTime = null;
          _endTime = null;
        }
      });
    }
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start ?? now,
      firstDate: _start ?? now,
      lastDate: now.add(const Duration(days: 365)),
      selectableDayPredicate: _isDateAvailable,
    );
    if (picked != null) {
      setState(() {
        _end = picked;
        if (_isSameDayBooking) {
          _startTime ??= const TimeOfDay(hour: 9, minute: 0);
          _endTime ??= _addMinutes(_startTime!, 30);
        } else {
          _startTime = null;
          _endTime = null;
        }
      });
    }
  }

  bool get _isSameDayBooking =>
      _start != null &&
      _end != null &&
      _start!.year == _end!.year &&
      _start!.month == _end!.month &&
      _start!.day == _end!.day;

  TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
    final total = time.hour * 60 + time.minute + minutes;
    final safeTotal = total.clamp(0, (24 * 60) - 1);
    return TimeOfDay(hour: safeTotal ~/ 60, minute: safeTotal % 60);
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;

    setState(() {
      _startTime = picked;
      final minimumEnd = _addMinutes(picked, 30);
      if (_endTime == null) {
        _endTime = minimumEnd;
        return;
      }
      final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
      final minEndMinutes = minimumEnd.hour * 60 + minimumEnd.minute;
      if (endMinutes < minEndMinutes) {
        _endTime = minimumEnd;
      }
    });
  }

  Future<void> _pickEndTime() async {
    final baseline = _startTime != null ? _addMinutes(_startTime!, 30) : const TimeOfDay(hour: 9, minute: 30);
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? baseline,
    );
    if (picked == null) return;

    if (_startTime != null) {
      final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
      final endMinutes = picked.hour * 60 + picked.minute;
      if (endMinutes - startMinutes < 30) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Minimum same-day booking duration is 30 minutes')),
        );
        return;
      }
    }

    setState(() => _endTime = picked);
  }

  Future<void> _submit() async {
    if (!mounted) return;
    
    final auth = context.read<AuthProvider>();
    final profile = auth.profile;
    
    if (profile == null || profile.trustScore < 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your trust score is too low to create bookings.')),
      );
      return;
    }

    if (!widget.tool.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This tool is marked as unavailable by the lender')),
      );
      return;
    }

    if (_start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select dates')));
      return;
    }
    if (_end!.isBefore(_start!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date must be after start date')));
      return;
    }

    final bookingStart = _isSameDayBooking
        ? _combineDateAndTime(_start!, _startTime ?? const TimeOfDay(hour: 9, minute: 0))
        : _start!;
    final bookingEnd = _isSameDayBooking
        ? _combineDateAndTime(_end!, _endTime ?? const TimeOfDay(hour: 9, minute: 30))
        : _end!;

    if (_isSameDayBooking) {
      final minutes = bookingEnd.difference(bookingStart).inMinutes;
      if (minutes < 30) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose at least 30 minutes for same-day bookings')),
        );
        return;
      }
    }

    bool isCurrentlyUnavailable;
    try {
      isCurrentlyUnavailable = await BookingsService().isToolCurrentlyUnavailable(widget.tool.id, bookingStart, bookingEnd);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking availability: $e')),
      );
      return;
    }

    if (!mounted) return;
    if (isCurrentlyUnavailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This tool is already booked for the selected dates')),
      );
      return;
    }

    final billableDays = _calculateRentalDays(bookingStart, bookingEnd);
    final totalPrice = widget.tool.pricePerDay * billableDays;
    final renter = context.read<AuthProvider>().user!;
    AppUser? lenderProfile;
    try {
      lenderProfile = await UsersService().getUser(widget.tool.ownerId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching lender details: $e')),
      );
      return;
    }
    if (!mounted) return;
    final summaryText = '${billableDays.toStringAsFixed(0)} day(s) x ';

    final paymentChoice = await showDialog<_PaymentChoice>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirm Booking'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 2,
                  children: [
                    Text(summaryText),
                    const Icon(Icons.currency_rupee, size: 16),
                    Text('${widget.tool.pricePerDay.toStringAsFixed(0)}/day = '),
                    const Icon(Icons.currency_rupee, size: 16),
                    Text(totalPrice.toStringAsFixed(2)),
                  ],
                ),
                if (_canUseUpi(lenderProfile?.upiId)) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'You can launch any UPI app installed on this phone, including Google Pay.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Are you agree with terms and conditions and rental price ?',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, _PaymentChoice.cancel), child: const Text("No, I don't")),
              ElevatedButton(onPressed: () => Navigator.pop(dialogContext, _PaymentChoice.bookOnly), child: const Text("Yes. I Agree")),
              if (_canUseUpi(lenderProfile?.upiId))
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, _PaymentChoice.payWithUpi),
                  child: const Text('Yes, and Pay via UPI'),
                ),
            ],
          ),
        ) ??
        _PaymentChoice.cancel;
    if (paymentChoice == _PaymentChoice.cancel) return;

    final booking = Booking(
      id: '',
      bookingNumber: null,
      toolId: widget.tool.id,
      toolName: widget.tool.title,
      renterId: renter.uid,
      lenderId: widget.tool.ownerId,
      startDate: bookingStart,
      endDate: bookingEnd,
      status: 'requested',
      totalPrice: totalPrice,
      paymentStatus: paymentChoice == _PaymentChoice.payWithUpi ? 'pending_verification' : 'unpaid',
      paymentMethod: paymentChoice == _PaymentChoice.payWithUpi ? 'upi' : null,
    );

    try {
      final bookingId = await BookingsService().createBooking(booking);

      if (paymentChoice == _PaymentChoice.payWithUpi && lenderProfile != null) {
        final paymentReference = _paymentsService.buildPaymentReference(bookingId);
        await BookingsService().updateBookingPayment(
          id: bookingId,
          paymentStatus: 'pending_verification',
          paymentMethod: 'upi',
          paymentReference: paymentReference,
        );

        final launched = await _paymentsService.launchUpiPayment(
          upiId: lenderProfile.upiId!.trim(),
          payeeName: _paymentsService.payeeNameFromProfile(
            username: lenderProfile.username,
            displayName: lenderProfile.displayName,
            fallbackEmail: lenderProfile.email,
          ),
          amount: totalPrice,
          transactionRef: paymentReference,
          note: 'Booking for ${widget.tool.title}',
        );

        if (!mounted) return;
        Navigator.of(context).pop(
          launched
              ? 'UPI app opened. Payment will stay pending until manually verified.'
              : 'No UPI app found on this device. Booking created without launching payment.',
        );
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pop('Booking requested!');
    } catch (e) {
      if (!mounted) return;
      showErrorAlert(context, 'Unable to request booking. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    String fmtDate(DateTime d) => d.toLocal().toString().split(' ').first;
    String fmtTime(TimeOfDay? time) => time == null ? 'Select' : time.format(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Request Booking')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(title: const Text('Tool'), subtitle: Text(widget.tool.title)),
            ListTile(
              title: const Text('Start'),
              subtitle: Text(_start == null ? 'Select' : fmtDate(_start!)),
              trailing: TextButton(onPressed: _pickStart, child: const Text('Choose')),
            ),
            ListTile(
              title: const Text('End'),
              subtitle: Text(_end == null ? 'Select' : fmtDate(_end!)),
              trailing: TextButton(onPressed: _pickEnd, child: const Text('Choose')),
            ),
            if (_isSameDayBooking) ...[
              ListTile(
                title: const Text('Start Time'),
                subtitle: Text(fmtTime(_startTime)),
                trailing: TextButton(onPressed: _pickStartTime, child: const Text('Choose')),
              ),
              ListTile(
                title: const Text('End Time'),
                subtitle: Text(fmtTime(_endTime)),
                trailing: TextButton(onPressed: _pickEndTime, child: const Text('Choose')),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'For same-day bookings, minimum duration is 30 minutes.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _submit, child: const Text('Send Request')),
          ],
        ),
      ),
    );
  }

  bool _canUseUpi(String? upiId) => upiId != null && _paymentsService.isValidUpiId(upiId);
}

enum _PaymentChoice { cancel, bookOnly, payWithUpi }
