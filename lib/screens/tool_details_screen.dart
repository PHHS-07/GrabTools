import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/review_model.dart';
import '../services/bookings_service.dart';
import '../services/ratings_service.dart';
import '../services/reports_service.dart';
import '../services/reviews_service.dart';
import '../services/tools_service.dart';
import '../models/tool_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/tool_availability_badge.dart';
import '../widgets/contact_owner_sheet.dart';
import 'booking_request_screen.dart';
import 'edit_tool_screen.dart';

class ToolDetailsScreen extends StatelessWidget {
  final String toolId;
  const ToolDetailsScreen({super.key, required this.toolId});

  static const List<String> _reportReasons = [
    'Fake listing',
    'Wrong images',
    'Scam',
    'Other',
  ];

  Future<void> _showReportDialog(
      BuildContext context, tool, String reporterId) async {
    if (reporterId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to report a tool')),
      );
      return;
    }

    final reportsService = ReportsService();
    final alreadyReported = await reportsService.hasReported(
      toolId: tool.id,
      reporterId: reporterId,
    );

    if (!context.mounted) return;

    if (alreadyReported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already reported this tool')),
      );
      return;
    }

    String? selectedReason;
    final detailsCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Report Tool'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Why are you reporting this listing?'),
              const SizedBox(height: 12),
              Column(
                children: _reportReasons.map((reason) => InkWell(
                  onTap: () => setDialogState(() => selectedReason = reason),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          selectedReason == reason
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: selectedReason == reason
                              ? Theme.of(ctx).colorScheme.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(reason, style: const TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: detailsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Additional details (optional)',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    ) ?? false;

    if (!confirmed || selectedReason == null) return;

    try {
      await reportsService.submitReport(ToolReport(
        id: '',
        toolId: tool.id,
        toolName: tool.title,
        reporterId: reporterId,
        reason: selectedReason!,
        details: detailsCtrl.text.trim().isEmpty ? null : detailsCtrl.text.trim(),
        createdAt: DateTime.now(),
      ));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Report submitted. We will review it shortly.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit report. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Tool Details')),
      body: FutureBuilder<Tool?>(
        future: ToolsService().getTool(toolId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final t = snap.data;
          if (t == null || (t.visibility == 'hidden' && profile?.id != t.ownerId && profile?.role != 'admin')) {
            return const Center(child: Text('Tool no longer available'));
          }
          return StreamBuilder<bool>(
            stream: BookingsService().streamToolCurrentlyUnavailable(t.id),
            builder: (context, bookingSnap) {
              final isCurrentlyUnavailable = bookingSnap.data ?? false;
              final effectiveAvailability = t.available && !isCurrentlyUnavailable;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (t.imageUrls.isNotEmpty) SizedBox(height: 200, child: PageView(children: t.imageUrls.map((u) => Image.network(u, fit: BoxFit.cover)).toList())),
                  const SizedBox(height: 12),
                  Text(t.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  if (t.isVerified) ...[
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.verified, color: Colors.blue, size: 16),
                        SizedBox(width: 4),
                        Text('Verified Listing', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Status: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ToolAvailabilityBadge(tool: t),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(t.description),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Condition: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Expanded(
                        child: Text(
                          t.conditionStatus,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  if (t.termsAndConditions?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    const Text('Terms and Conditions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(t.termsAndConditions!),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Price: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const Icon(Icons.currency_rupee, size: 16),
                      Text('${t.pricePerDay.toStringAsFixed(0)}/day', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (t.address != null) ...[
                    const Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Colors.red),
                        const SizedBox(width: 6),
                        Expanded(child: Text(t.address!)),
                      ],
                    ),
                    if (t.location != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final lat = t.location!['lat'];
                          final lng = t.location!['lng'];
                          final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open map.')));
                            }
                          }
                        },
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('View in Map'),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Ratings & Reviews',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  // All ratings for this tool
                  StreamBuilder<List<Rating>>(
                    stream: RatingsService().streamRatingsByTool(t.id),
                    builder: (context, ratingSnap) {
                      if (ratingSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final ratings = ratingSnap.data ?? [];
                      if (ratings.isEmpty) {
                        return const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 18),
                                SizedBox(width: 4),
                                Text(
                                  '0.0/5 (0)',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text('No ratings yet.', style: TextStyle(color: Colors.grey)),
                          ],
                        );
                      }
                      // Average uses toolRating when available, falls back to behavior
                      final avgScore = ratings.fold(0.0, (s, r) => s + (r.toolRating ?? r.behavior)) / ratings.length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                '${avgScore.toStringAsFixed(1)} / 5  (${ratings.length} rating${ratings.length == 1 ? '' : 's'})',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...ratings.map((r) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Show toolRating stars if available, else behavior stars
                                      Row(
                                        children: List.generate(5, (i) => Icon(
                                          i < (r.toolRating ?? r.behavior) ? Icons.star : Icons.star_border,
                                          color: Colors.amber,
                                          size: 16,
                                        )),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        r.toolRating != null ? 'Tool' : 'Behavior',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      const Spacer(),
                                      Text(
                                        r.createdAt.toLocal().toString().split(' ').first,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  if (r.comment != null && r.comment!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(r.comment!),
                                  ],
                                ],
                              ),
                            ),
                          )),
                        ],
                      );
                    },
                  ),
                  // Written reviews
                  StreamBuilder<List<Review>>(
                    stream: ReviewsService().streamReviewsForTool(t.id),
                    builder: (context, reviewSnap) {
                      final reviews = reviewSnap.data ?? [];
                      if (reviews.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          const Text('Reviews',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 6),
                          ...reviews.map((rv) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Row(
                                        children: List.generate(5, (i) => Icon(
                                          i < rv.rating ? Icons.star : Icons.star_border,
                                          color: Colors.amber,
                                          size: 16,
                                        )),
                                      ),
                                      const Spacer(),
                                      Text(
                                        rv.createdAt.toLocal().toString().split(' ').first,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(rv.comment),
                                ],
                              ),
                            ),
                          )),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  if (profile?.id == t.ownerId) ...[
                    if (profile?.role == 'lender')
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditToolScreen(toolId: t.id))),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Tool'),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.lock),
                          label: const Text('You own this tool'),
                        ),
                      ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: effectiveAvailability
                                ? () async {
                                    final message = await Navigator.of(context).push<String>(
                                      MaterialPageRoute(
                                        builder: (_) => BookingRequestScreen(tool: t),
                                      ),
                                    );
                                    if (!context.mounted || message == null || message.isEmpty) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(message)),
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.book_online),
                            label: Text(effectiveAvailability ? 'Request Booking' : 'Currently Unavailable'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => showContactOwnerSheet(context, t),
                            icon: const Icon(Icons.support_agent),
                            label: const Text('Contact Owner'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _showReportDialog(context, t, profile?.id ?? ''),
                        icon: const Icon(Icons.flag_outlined, color: Colors.red, size: 18),
                        label: const Text('Report this tool',
                            style: TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    ),
                  ]
                ]),
              );
            },
          );
        },
      ),
    );
  }
}