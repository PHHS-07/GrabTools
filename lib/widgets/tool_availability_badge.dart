import 'package:flutter/material.dart';

import '../models/tool_model.dart';


class ToolAvailabilityBadge extends StatelessWidget {
  final Tool tool;
  final bool compact;

  const ToolAvailabilityBadge({
    super.key,
    required this.tool,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    
    // Check if current date falls within any booked or blocked ranges
    final isBooked = tool.bookedRanges.any((r) =>
        (today.isAfter(r.startDate) || today.isAtSameMomentAs(r.startDate)) &&
        (today.isBefore(r.endDate) || today.isAtSameMomentAs(r.endDate)));
    
    final isBlocked = tool.blockedRanges.any((r) =>
        (today.isAfter(r.startDate) || today.isAtSameMomentAs(r.startDate)) &&
        (today.isBefore(r.endDate) || today.isAtSameMomentAs(r.endDate)));

    final isAvailable = tool.available && !isBooked && !isBlocked;
    
    final label = isAvailable ? 'Available' : 'Currently Unavailable';
    final foreground = isAvailable ? Colors.green.shade800 : Colors.red.shade800;
    final background = isAvailable ? Colors.green.shade50 : Colors.red.shade50;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: foreground.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
