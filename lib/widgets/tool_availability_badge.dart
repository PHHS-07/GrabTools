import 'package:flutter/material.dart';

import '../models/tool_model.dart';
import '../services/bookings_service.dart';

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
    return StreamBuilder<bool>(
      stream: BookingsService().streamToolEffectivelyAvailable(
        toolId: tool.id,
        toolMarkedAvailable: tool.available,
      ),
      builder: (context, snapshot) {
        final isAvailable = snapshot.data ?? tool.available;
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
      },
    );
  }
}
