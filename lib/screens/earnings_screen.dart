import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/booking_model.dart';
import '../models/tool_model.dart';
import '../providers/auth_provider.dart';
import '../services/bookings_service.dart';
import '../services/tools_service.dart';
import 'bookings_screen.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  String _formatMoney(double value) => 'INR ${value.toStringAsFixed(2)}';

  String _formatDateTime(DateTime value) {
    final date = value.toLocal();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute $suffix';
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

  String _paymentStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'pending_verification':
        return 'Pending Verification';
      case 'unpaid':
        return 'Unpaid';
      default:
        return status;
    }
  }

  Widget _buildBookingTitle(Booking booking) {
    if (booking.toolName.trim().isNotEmpty) {
      return Text(
        booking.toolName,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      );
    }

    return FutureBuilder<Tool?>(
      future: ToolsService().getTool(booking.toolId),
      builder: (context, snapshot) {
        final resolvedTitle = snapshot.data?.title;
        return Text(
          resolvedTitle != null && resolvedTitle.trim().isNotEmpty ? resolvedTitle : 'Tool',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        );
      },
    );
  }

  bool _isCompletedBooking(Booking booking) {
    final status = booking.status.toLowerCase();
    return status == 'completed' || status == 'finished';
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: StreamBuilder<List<Booking>>(
        stream: BookingsService().streamBookingsForLender(profile.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final completedBookings = (snapshot.data ?? <Booking>[])
              .where(_isCompletedBooking)
              .toList()
            ..sort((a, b) => b.endDate.compareTo(a.endDate));

          final totalEarnings = completedBookings.fold(0.0, (sum, b) => sum + b.totalPrice);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Total earnings: ${_formatMoney(totalEarnings)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Completed Bookings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (completedBookings.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No completed bookings yet.'),
                  ),
                )
              else
                ...completedBookings.map(
                  (booking) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(
                        booking.displayBookingId,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Amount: ${_formatMoney(booking.totalPrice)}'),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BookingDetailsScreen(
                              booking: booking,
                              isLender: true,
                              toolNameBuilder: _buildBookingTitle,
                              formatDateTime: _formatDateTime,
                              formatMoney: _formatMoney,
                              formatDuration: _formatDuration,
                              paymentStatusLabel: _paymentStatusLabel,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
