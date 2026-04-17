import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/booking_model.dart';
import '../models/tool_model.dart';
import '../providers/auth_provider.dart';
import '../services/bookings_service.dart';
import '../services/payments_service.dart';
import '../services/ratings_service.dart';
import '../services/tools_service.dart';
import '../services/users_service.dart';
import '../widgets/app_alerts.dart';
import '../widgets/contact_owner_sheet.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

enum _BookingsTab { current, history }
enum _ReturnPaymentChoice { cancel, cash, makePayment }

class _BookingsScreenState extends State<BookingsScreen> {
  static final PaymentsService _paymentsService = PaymentsService();
  static const double _extensionFee = 5.0;
  final ToolsService _toolsService = ToolsService();
  final RatingsService _ratingsService = RatingsService();
  _BookingsTab _selectedTab = _BookingsTab.current;
  final Set<String> _ratingPromptInFlight = <String>{};
  final Set<String> _ratingPromptDismissed = <String>{};

  String _formatDateTime(DateTime value) {
    final date = value.toLocal();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute $suffix';
  }

  String _formatMoney(double value) => 'INR ${value.toStringAsFixed(2)}';

  double _calculateOverdueCharge({
    required DateTime dueDate,
    required double rentPerDay,
  }) {
    final now = DateTime.now();
    if (!now.isAfter(dueDate)) return 0.0;
    final overdueDuration = now.difference(dueDate);
    final overdueDays = overdueDuration.inDays;
    var charge = 5.0;
    if (overdueDays > 0) {
      charge += overdueDays * rentPerDay;
    }
    return charge;
  }

  String _formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    if (duration.inMinutes <= 0) return '0m';
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    return parts.join(' ');
  }

  double _calculateBillableDays(DateTime start, DateTime end) {
    final minutes = end.difference(start).inMinutes;
    if (minutes <= 0) return 1.0;
    return (minutes / (24 * 60)).ceilToDouble();
  }

  bool _hasVisibleToolName(String toolName) => toolName.trim().isNotEmpty;

  bool _isHistoryBooking(Booking booking) {
    final normalizedStatus = booking.status.toLowerCase();
    return normalizedStatus == 'completed' ||
        normalizedStatus == 'finished' ||
        normalizedStatus == 'cancelled' ||
        normalizedStatus == 'rejected' ||
        normalizedStatus == 'expired';
  }

  bool _canExtendBooking(Booking booking) {
    if (_isHistoryBooking(booking)) return false;
    final normalizedStatus = booking.status.toLowerCase();
    return (normalizedStatus == 'requested' ||
            normalizedStatus == 'approved' ||
            normalizedStatus == 'confirmed' ||
            normalizedStatus == 'in_progress' ||
            normalizedStatus == 'active') &&
        !_hasPendingActionRequest(booking);
  }

  bool _canReviewBooking(Booking booking) {
    return booking.status.toLowerCase() == 'requested';
  }

  bool _hasPendingActionRequest(Booking booking) {
    return booking.pendingActionStatus == 'requested' &&
        booking.pendingActionType != null;
  }

  bool _canReturnBooking(Booking booking) {
    if (_isHistoryBooking(booking)) return false;
    final normalizedStatus = booking.status.toLowerCase();
    return (normalizedStatus == 'in_progress' || normalizedStatus == 'active') &&
        !_hasPendingActionRequest(booking);
  }

  bool _isPendingReturnRequest(Booking booking) {
    return booking.pendingActionStatus == 'requested' &&
        booking.pendingActionType == 'return';
  }

  Widget _buildAnimatedHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: _selectedTab == _BookingsTab.current
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: width / 2,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _HeaderTabButton(
                      label: 'Current Bookings',
                      selected: _selectedTab == _BookingsTab.current,
                      onTap: () => setState(() => _selectedTab = _BookingsTab.current),
                    ),
                  ),
                  Expanded(
                    child: _HeaderTabButton(
                      label: 'Booking History',
                      selected: _selectedTab == _BookingsTab.history,
                      onTap: () => setState(() => _selectedTab = _BookingsTab.history),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookingTitle(Booking booking) {
    if (_hasVisibleToolName(booking.toolName)) {
      return Text(booking.toolName);
    }

    return FutureBuilder<Tool?>(
      future: _toolsService.getTool(booking.toolId),
      builder: (context, snapshot) {
        final resolvedTitle = snapshot.data?.title;
        if (resolvedTitle != null && resolvedTitle.trim().isNotEmpty) {
          return Text(resolvedTitle);
        }
        return const Text('Tool');
      },
    );
  }

  Future<void> _extendBooking(Booking booking) async {
    final tool = await _toolsService.getTool(booking.toolId);
    if (!mounted) return;

    final ratePerDay = tool?.pricePerDay ??
        (booking.totalPrice / _calculateBillableDays(booking.startDate, booking.endDate));
    final result = await showDialog<_ExtensionResult>(
      context: context,
      builder: (dialogContext) => _ExtendBookingDialog(
        initialStart: booking.startDate,
        initialEnd: booking.endDate,
        initialTotalPrice: booking.totalPrice,
        pricePerDay: ratePerDay,
        extensionFee: _extensionFee,
      ),
    );
    if (result == null) return;

    await BookingsService().requestBookingExtension(
      id: booking.id,
      requestedEndDate: result.endDate,
      requestedTotalPrice: result.totalPrice,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Extension request sent to lender')),
    );
  }

  Future<void> _returnBooking(Booking booking) async {
    final tool = await _toolsService.getTool(booking.toolId);
    if (!mounted) return;
    
    final billedDays = _calculateBillableDays(booking.startDate, booking.endDate);
    final rentPerDay = tool?.pricePerDay ?? (booking.totalPrice / billedDays);
    
    var accruedFees = booking.totalPrice - (billedDays * rentPerDay);
    if (accruedFees < 0.01) accruedFees = 0.0; // Handle precision issues

    final now = DateTime.now();
    double totalDue;
    double overdueCharge = 0.0;

    if (now.isBefore(booking.endDate)) {
      final actualDays = _calculateBillableDays(booking.startDate, now);
      totalDue = (actualDays * rentPerDay) + accruedFees;
    } else {
      overdueCharge = _calculateOverdueCharge(
        dueDate: booking.endDate,
        rentPerDay: rentPerDay,
      );
      totalDue = booking.totalPrice + overdueCharge;
    }

    final paymentChoice = await showDialog<_ReturnPaymentChoice>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Return Tool'),
            content: Text(
              overdueCharge > 0
                  ? 'Total due: ${_formatMoney(totalDue)}\nIncludes overdue charge of ${_formatMoney(overdueCharge)}.\nChoose a payment option before sending the return request.'
                  : (now.isBefore(booking.endDate) 
                      ? 'Returned early!\nTotal dynamically adjusted due: ${_formatMoney(totalDue)}\nChoose a payment option.'
                      : 'Total due: ${_formatMoney(totalDue)}\nChoose a payment option before sending the return request.'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, _ReturnPaymentChoice.cancel),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, _ReturnPaymentChoice.cash),
                child: const Text('By Cash'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, _ReturnPaymentChoice.makePayment),
                child: const Text('Make Payment'),
              ),
            ],
          ),
        ) ??
        _ReturnPaymentChoice.cancel;
    if (!mounted || paymentChoice == _ReturnPaymentChoice.cancel) return;

    var paymentMode = 'cash';
    if (paymentChoice == _ReturnPaymentChoice.makePayment) {
      final lenderProfile = await UsersService().getUser(booking.lenderId);
      if (!mounted) return;
      if (lenderProfile?.upiId == null ||
          !_paymentsService.isValidUpiId(lenderProfile!.upiId!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lender payment details are not available')),
        );
        return;
      }

      final paymentReference = _paymentsService.buildPaymentReference(booking.id);
      final launched = await _paymentsService.launchUpiPayment(
        upiId: lenderProfile.upiId!.trim(),
        payeeName: _paymentsService.payeeNameFromProfile(
          username: lenderProfile.username,
          displayName: lenderProfile.displayName,
          fallbackEmail: lenderProfile.email,
        ),
        amount: totalDue,
        transactionRef: paymentReference,
        note: 'Return payment for ${booking.toolName}',
      );
      if (!mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No payment app found on this device')),
        );
        return;
      }
      paymentMode = 'upi';
    }

    await BookingsService().requestBookingReturn(
      id: booking.id,
      paymentMode: paymentMode,
      requestedTotalPrice: totalDue,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Return request sent to lender')),
    );
  }

  Future<void> _showSeekerBookingActions(Booking booking) async {
    if (_selectedTab != _BookingsTab.current) return;
    if (!_canExtendBooking(booking) && !_canReturnBooking(booking)) return;
    if (_hasPendingActionRequest(booking)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This booking already has a pending approval request')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             if (_canExtendBooking(booking))
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Extend'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _extendBooking(booking);
                },
              ),
            if (booking.status.toLowerCase() == 'confirmed')
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Mark as Picked Up (In Progress)'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await BookingsService().updateBookingStatus(booking.id, 'in_progress');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking marked as in progress')));
                },
              ),
            if (_canReturnBooking(booking))
              ListTile(
                leading: const Icon(Icons.assignment_turned_in_outlined),
                title: const Text('Return'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _returnBooking(booking);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLenderBookingActions(Booking booking) async {
    if (_selectedTab != _BookingsTab.current) return;

    final tool = await _toolsService.getTool(booking.toolId);
    final seeker = await UsersService().getUser(booking.renterId);
    if (!mounted) return;

    if (tool == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tool details are not available')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.contact_phone_outlined),
              title: const Text('Contact Seeker'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await showContactUserSheet(
                  context: context,
                  tool: tool,
                  user: seeker,
                  heading: 'Contact Seeker',
                  personLabel: 'Seeker',
                  missingUserMessage: 'Seeker details are not available',
                  copiedNumberMessage: 'Seeker contact number copied',
                  callTitle: 'Call Seeker',
                  signInChatMessage: 'Please sign in to chat with the seeker',
                  missingPhoneMessage: 'Seeker mobile number is not available',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmReturnPaymentReceived(Booking booking) async {
    final amountLabel = booking.requestedTotalPrice == null
        ? ''
        : '\nAmount due: ${_formatMoney(booking.requestedTotalPrice!)}';
    final paymentModeLabel = booking.pendingActionPaymentMode == null
        ? ''
        : '\nMode: ${booking.pendingActionPaymentMode}';
    final received = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Payment Confirmation'),
            content: Text('Is payment received?$amountLabel$paymentModeLabel'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;
    return received;
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'approved' || s == 'confirmed') {
      return Colors.blue;
    }
    if (s == 'in_progress' || s == 'active' || s == 'finished' || s == 'completed') {
      return Colors.green;
    }
    if (s == 'pending' || s == 'waiting' || s == 'requested') {
      return Colors.orange;
    }
    if (s == 'rejected' || s == 'cancelled' || s == 'expired') {
      return Colors.red;
    }
    return Colors.grey;
  }

  Widget _buildBookingCard({
    required Booking booking,
    required bool isLender,
  }) {
    final statusColor = _getStatusColor(booking.status);
    final subtitleLines = [
      'Booking ID: ${booking.displayBookingId}',
      'From ${_formatDateTime(booking.startDate)} to ${_formatDateTime(booking.endDate)}',
      'Duration: ${_formatDuration(booking.startDate, booking.endDate)}',
      'Price: ${_formatMoney(booking.totalPrice)}',
      'Status: ${booking.status}',
      _paymentsService.paymentStatusLabel(booking.paymentStatus),
      if (_hasPendingActionRequest(booking))
        _pendingActionLabel(booking),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withValues(alpha: 0.6), width: 1.5),
      ),
      color: statusColor.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(8),
          child: ListTile(
          onLongPress: isLender
              ? () => _showLenderBookingActions(booking)
              : () => _showSeekerBookingActions(booking),
          title: _buildBookingTitle(booking),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(subtitleLines.join('\n')),
          ),
          trailing: Builder(
            builder: (context) {
              if (isLender && (_canReviewBooking(booking) || _hasPendingActionRequest(booking))) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () async {
                        if (_canReviewBooking(booking)) {
                          await BookingsService().updateBookingStatus(booking.id, 'approved');
                        } else {
                          if (_isPendingReturnRequest(booking)) {
                            final paymentReceived = await _confirmReturnPaymentReceived(booking);
                            if (!mounted || !paymentReceived) return;
                          }
                          await BookingsService().resolvePendingAction(
                            id: booking.id,
                            approve: true,
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () async {
                        if (_canReviewBooking(booking)) {
                          await BookingsService().updateBookingStatus(booking.id, 'rejected');
                        } else {
                          await BookingsService().resolvePendingAction(
                            id: booking.id,
                            approve: false,
                          );
                        }
                      },
                    ),
                  ],
                );
              } else if (!isLender && booking.status.toLowerCase() == 'approved') {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: () async {
                    await BookingsService().updateBookingStatus(booking.id, 'confirmed');
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Confirmed! Dates reserved in calendar.')));
                  },
                  child: const Text('Confirm Payment'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryBookingCard({
    required Booking booking,
    required bool isLender,
  }) {
    final statusColor = _getStatusColor(booking.status);
    final counterpartyId = isLender ? booking.renterId : booking.lenderId;
    final counterpartyLabel = isLender ? 'Seeker' : 'Owner';

    return FutureBuilder(
      future: UsersService().getUser(counterpartyId),
      builder: (context, snapshot) {
        final counterpartyName = snapshot.data?.username ??
            snapshot.data?.email ??
            counterpartyLabel;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: statusColor.withValues(alpha: 0.6), width: 1.5),
          ),
          color: statusColor.withValues(alpha: 0.08),
          child: ListTile(
            title: _buildBookingTitle(booking),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Booking ID: ${booking.displayBookingId}\n'
                '$counterpartyLabel: $counterpartyName\n'
                'Ended On: ${_formatDateTime(booking.endDate)}\n'
                'Status: ${booking.status}\n'
                '${_paymentsService.paymentStatusLabel(booking.paymentStatus)}\n'
                'Method: ${booking.paymentMethod ?? 'N/A'}',
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BookingDetailsScreen(
                    booking: booking,
                    isLender: isLender,
                    toolNameBuilder: _buildBookingTitle,
                    formatDateTime: _formatDateTime,
                    formatMoney: _formatMoney,
                    formatDuration: _formatDuration,
                    paymentStatusLabel: _paymentsService.paymentStatusLabel,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final profile = auth.profile;
    if (user == null) return const Scaffold(body: Center(child: Text('Not signed in')));

    final isLender = profile?.role == 'lender';
    final bookingsStream = isLender
        ? BookingsService().streamBookingsForLender(user.uid)
        : BookingsService().streamBookingsForUser(user.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: StreamBuilder<List<Booking>>(
        stream: bookingsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allBookings = snapshot.data ?? <Booking>[];
          _queueRatingPrompts(allBookings, isLender: isLender, currentUserId: user.uid);

          final bookings = (allBookings.where((booking) {
                if (_selectedTab == _BookingsTab.current) {
                  return !_isHistoryBooking(booking);
                }
                return _isHistoryBooking(booking);
              }).toList())
            ..sort((a, b) => b.startDate.compareTo(a.startDate));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildAnimatedHeader(),
              ),
              Expanded(
                child: bookings.isEmpty
                    ? Center(
                        child: Text(
                          _selectedTab == _BookingsTab.current
                              ? 'No current bookings'
                              : 'No booking history',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: bookings.length,
                        itemBuilder: (ctx, i) {
                          final booking = bookings[i];
                          return Column(
                            children: [
                              _selectedTab == _BookingsTab.history
                                  ? _buildHistoryBookingCard(
                                      booking: booking,
                                      isLender: isLender,
                                    )
                                  : _buildBookingCard(
                                      booking: booking,
                                      isLender: isLender,
                                    ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _pendingActionLabel(Booking booking) {
    if (booking.pendingActionType == 'extend') {
      final requestedEnd = booking.requestedEndDate == null
          ? ''
          : ' until ${_formatDateTime(booking.requestedEndDate!)}';
      return 'Pending lender approval: Extend$requestedEnd';
    }
    if (booking.pendingActionType == 'return') {
      final paymentMode = booking.pendingActionPaymentMode == null
          ? ''
          : ' via ${booking.pendingActionPaymentMode}';
      final totalDue = booking.requestedTotalPrice == null
          ? ''
          : ' (${_formatMoney(booking.requestedTotalPrice!)})';
      return 'Pending lender approval: Return$paymentMode$totalDue';
    }
    return 'Pending lender approval';
  }

  void _queueRatingPrompts(
    List<Booking> bookings, {
    required bool isLender,
    required String currentUserId,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final booking in bookings) {
        if (!_shouldPromptForRating(booking)) continue;
        if (_ratingPromptInFlight.contains(booking.id) ||
            _ratingPromptDismissed.contains(booking.id)) {
          continue;
        }

        _ratingPromptInFlight.add(booking.id);
        bool alreadySubmitted = false;
        try {
          alreadySubmitted = await _ratingsService.hasRatingForBooking(
            bookingId: booking.id,
            reviewerId: currentUserId,
          );
        } catch (e) {
          debugPrint('Error checking for existing rating: $e');
          alreadySubmitted = true; // Skip prompting if we can't verify
        }
        
        if (!mounted) return;
        if (alreadySubmitted) {
          _ratingPromptInFlight.remove(booking.id);
          _ratingPromptDismissed.add(booking.id);
          continue;
        }

        final rated = await _showRatingDialog(
          booking: booking,
          isLender: isLender,
          currentUserId: currentUserId,
        );
        if (!mounted) return;
        _ratingPromptInFlight.remove(booking.id);
        if (rated == null) {
          // Data fetch failed — don't dismiss, allow retry on next stream rebuild
          continue;
        }
        _ratingPromptDismissed.add(booking.id);
        if (rated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rating submitted')),
          );
        }
        break;
      }
    });
  }

  bool _shouldPromptForRating(Booking booking) {
    final normalizedStatus = booking.status.toLowerCase();
    return normalizedStatus == 'completed' || normalizedStatus == 'finished';
  }

  /// Returns true if rating was submitted, false if dismissed, null if data unavailable (retry later).
  Future<bool?> _showRatingDialog({
    required Booking booking,
    required bool isLender,
    required String currentUserId,
  }) async {
    final counterpartyId = isLender ? booking.renterId : booking.lenderId;
    final counterparty = await UsersService().getUser(counterpartyId);
    final tool = await _toolsService.getTool(booking.toolId);
    if (!mounted) return null;
    if (counterparty == null) return null; // Transient failure — retry on next rebuild

    final behavior = ValueNotifier<int>(5);
    final toolRating = ValueNotifier<int>(5);
    final commentCtrl = TextEditingController();
    final shouldRateTool = !isLender;

    final submitted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Rate This Booking'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rate ${counterparty.username ?? counterparty.email}'),
                  const SizedBox(height: 12),
                  const Text('Behavior'),
                  ValueListenableBuilder<int>(
                    valueListenable: behavior,
                    builder: (context, value, _) => _StarSelector(
                      value: value,
                      onChanged: (next) => behavior.value = next,
                    ),
                  ),
                  if (shouldRateTool) ...[
                    const SizedBox(height: 12),
                    const Text('Tool Quality'),
                    ValueListenableBuilder<int>(
                      valueListenable: toolRating,
                      builder: (context, value, _) => _StarSelector(
                        value: value,
                        onChanged: (next) => toolRating.value = next,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Comment',
                      hintText: 'Share your experience',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Submit'),
              ),
            ],
          ),
        ) ??
        false;

    if (!submitted) {
      commentCtrl.dispose();
      behavior.dispose();
      toolRating.dispose();
      return false;
    }

    await _ratingsService.submitRating(
      Rating(
        id: '',
        ownerId: counterparty.id,
        reviewerId: currentUserId,
        bookingId: booking.id,
        recipientRole: isLender ? 'seeker' : 'lender',
        toolId: booking.toolId,
        toolName: booking.toolName,
        toolCategory: tool?.categories.isNotEmpty == true ? tool!.categories.first : null,
        behavior: behavior.value,
        toolRating: shouldRateTool ? toolRating.value : null,
        comment: commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
        createdAt: DateTime.now(),
      ),
    );

    commentCtrl.dispose();
    behavior.dispose();
    toolRating.dispose();
    return true;
  }
}

class _StarSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _StarSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (index) => IconButton(
          onPressed: () => onChanged(index + 1),
          icon: Icon(
            index < value ? Icons.star : Icons.star_border,
            color: Colors.amber,
          ),
        ),
      ),
    );
  }
}

class BookingDetailsScreen extends StatelessWidget {
  final Booking booking;
  final bool isLender;
  final Widget Function(Booking booking) toolNameBuilder;
  final String Function(DateTime value) formatDateTime;
  final String Function(double value) formatMoney;
  final String Function(DateTime start, DateTime end) formatDuration;
  final String Function(String status) paymentStatusLabel;

  const BookingDetailsScreen({
    super.key,
    required this.booking,
    required this.isLender,
    required this.toolNameBuilder,
    required this.formatDateTime,
    required this.formatMoney,
    required this.formatDuration,
    required this.paymentStatusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final counterpartyId = isLender ? booking.renterId : booking.lenderId;
    final counterpartyLabel = isLender ? 'Seeker' : 'Owner';

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: FutureBuilder(
        future: UsersService().getUser(counterpartyId),
        builder: (context, snapshot) {
          final counterpartyName =
              snapshot.data?.username ?? snapshot.data?.email ?? counterpartyLabel;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyLarge ?? const TextStyle(),
                child: toolNameBuilder(booking),
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Booking ID', value: booking.displayBookingId),
              _DetailRow(label: counterpartyLabel, value: counterpartyName),
              _DetailRow(label: 'Start', value: formatDateTime(booking.startDate)),
              _DetailRow(label: 'End', value: formatDateTime(booking.endDate)),
              _DetailRow(
                label: 'Duration',
                value: formatDuration(booking.startDate, booking.endDate),
              ),
              _DetailRow(label: 'Price', value: formatMoney(booking.totalPrice)),
              _DetailRow(label: 'Status', value: booking.status),
              _DetailRow(
                label: 'Payment',
                value: paymentStatusLabel(booking.paymentStatus),
              ),
              if (booking.pendingActionType != null)
                _DetailRow(
                  label: 'Pending Action',
                  value: booking.pendingActionType!,
                ),
              if (booking.pendingActionPaymentMode != null)
                _DetailRow(
                  label: 'Pending Payment Mode',
                  value: booking.pendingActionPaymentMode!,
                ),
              if (booking.requestedEndDate != null)
                _DetailRow(
                  label: 'Requested End Date',
                  value: formatDateTime(booking.requestedEndDate!),
                ),
              if (booking.requestedTotalPrice != null)
                _DetailRow(
                  label: booking.pendingActionType == 'return'
                      ? 'Total Due on Return'
                      : 'Requested Total Price',
                  value: formatMoney(booking.requestedTotalPrice!),
                ),
              const SizedBox(height: 8),
              const Text(
                'Ratings',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<Rating>>(
                stream: RatingsService().streamRatingsForBooking(booking.id),
                builder: (context, ratingSnapshot) {
                  final ratings = ratingSnapshot.data ?? <Rating>[];
                  if (ratings.isEmpty) {
                    return const Text('No ratings submitted for this booking yet');
                  }

                  return Column(
                    children: ratings
                        .map(
                          (rating) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text('Behavior: ${rating.behavior}/5'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (rating.toolRating != null)
                                    Text('Tool: ${rating.toolRating}/5'),
                                  if (rating.recipientRole != null)
                                    Text('Recipient Role: ${rating.recipientRole}'),
                                  if (rating.comment?.isNotEmpty == true)
                                    Text(rating.comment!),
                                ],
                              ),
                              trailing: Text(
                                rating.createdAt.toLocal().toString().split(' ').first,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

class _HeaderTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HeaderTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _ExtensionResult {
  final DateTime endDate;
  final double totalPrice;

  const _ExtensionResult({
    required this.endDate,
    required this.totalPrice,
  });
}

class _ExtendBookingDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;
  final double initialTotalPrice;
  final double pricePerDay;
  final double extensionFee;

  const _ExtendBookingDialog({
    required this.initialStart,
    required this.initialEnd,
    required this.initialTotalPrice,
    required this.pricePerDay,
    required this.extensionFee,
  });

  @override
  State<_ExtendBookingDialog> createState() => _ExtendBookingDialogState();
}

class _ExtendBookingDialogState extends State<_ExtendBookingDialog> {
  late DateTime _endDate;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime(
      widget.initialEnd.year,
      widget.initialEnd.month,
      widget.initialEnd.day,
    );
    _endTime = TimeOfDay.fromDateTime(widget.initialEnd);
  }

  bool get _isSameDayBooking {
    final start = widget.initialStart;
    return start.year == _endDate.year &&
        start.month == _endDate.month &&
        start.day == _endDate.day;
  }

  DateTime get _combinedEndDate => DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _endTime.hour,
        _endTime.minute,
      );

  String _formatMoney(double value) => 'INR ${value.toStringAsFixed(2)}';

  double _calculateExtensionDays(DateTime oldEnd, DateTime newEnd) {
    // Count only the NEW calendar days beyond the old end's date.
    // e.g. oldEnd = 16/03 22:30, newEnd = 17/03 23:30 → 1 new day, not 2.
    // Stripping times ensures the time-of-day on oldEnd doesn't inflate the count.
    final oldDay = DateTime(oldEnd.year, oldEnd.month, oldEnd.day);
    final newDay = DateTime(newEnd.year, newEnd.month, newEnd.day);
    final extraDays = newDay.difference(oldDay).inDays;
    return extraDays <= 0 ? 0.0 : extraDays.toDouble();
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: widget.initialEnd,
      lastDate: widget.initialEnd.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _endDate = picked;
    });
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked == null) return;
    setState(() {
      _endTime = picked;
    });
  }

  void _submit() {
    final endDate = _combinedEndDate;
    if (!endDate.isAfter(widget.initialEnd)) {
      showErrorAlert(context, 'Choose an end time later than the current booking end');
      return;
    }

    if (_isSameDayBooking &&
        endDate.difference(widget.initialStart).inMinutes < 30) {
      showErrorAlert(context, 'Same-day bookings must be at least 30 minutes');
      return;
    }

    final additionalDays = _calculateExtensionDays(widget.initialEnd, endDate);
    final additionalPrice = (widget.pricePerDay * additionalDays) + widget.extensionFee;
    
    // Total price is the original booking total + extension days + extension fee
    final totalPrice = widget.initialTotalPrice + additionalPrice;
    Navigator.of(context).pop(
      _ExtensionResult(
        endDate: endDate,
        totalPrice: totalPrice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final additionalDays = _calculateExtensionDays(widget.initialEnd, _combinedEndDate);
    final additionalPrice = (widget.pricePerDay * additionalDays) + widget.extensionFee;
    final previewTotalPrice = widget.initialTotalPrice + additionalPrice;

    return AlertDialog(
      title: const Text('Extend Booking'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current end: ${widget.initialEnd.toLocal()}'),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('New End Date'),
            subtitle: Text('${_endDate.day.toString().padLeft(2, '0')}/${_endDate.month.toString().padLeft(2, '0')}/${_endDate.year}'),
            trailing: TextButton(
              onPressed: _pickEndDate,
              child: const Text('Choose'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('New End Time'),
            subtitle: Text(_endTime.format(context)),
            trailing: TextButton(
              onPressed: _pickEndTime,
              child: const Text('Choose'),
            ),
          ),
          const SizedBox(height: 8),
          Text('Updated price: ${_formatMoney(previewTotalPrice)}'),
          const SizedBox(height: 4),
          Text('Includes rent time extension fee: ${_formatMoney(widget.extensionFee)}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Update'),
        ),
      ],
    );
  }
}