import 'dart:ui';

import 'package:flutter/material.dart';
import '../services/tools_service.dart';
import '../models/tool_model.dart';
import '../widgets/contact_owner_sheet.dart';
import '../widgets/tool_availability_badge.dart';
import 'tool_details_screen.dart';

class ToolListScreen extends StatefulWidget {
  const ToolListScreen({super.key});

  @override
  State<ToolListScreen> createState() => _ToolListScreenState();
}

class _ToolListScreenState extends State<ToolListScreen> {
  String? _selectedCategory;
  final List<String> _categories = [
    'All',
    'Power Tools',
    'Hand Tools',
    'Gardening',
    'Cleaning',
    'Painting',
    'Plumbing',
    'Electrical',
    'Heavy Equipment',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse Tools')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isAll = cat == 'All';
                  final selected = isAll ? _selectedCategory == null : _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          if (isAll) {
                            _selectedCategory = null;
                          } else {
                            _selectedCategory = cat;
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Tool>>(
              stream: ToolsService().streamTools(category: _selectedCategory),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final tools = snap.data ?? [];
                if (tools.isEmpty) return const Center(child: Text('No tools available'));
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: tools.length,
                  itemBuilder: (ctx, i) {
                    final t = tools[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LiquidGlassCard(
                        child: ListTile(
                          leading: t.imageUrls.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(t.imageUrls.first, width: 56, height: 56, fit: BoxFit.cover),
                                )
                              : const Icon(Icons.build),
                          title: Text(t.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              ToolAvailabilityBadge(tool: t, compact: true),
                              const SizedBox(height: 6),
                              TextButton.icon(
                                onPressed: () => showContactOwnerSheet(context, t),
                                icon: const Icon(Icons.contact_phone, size: 16),
                                label: const Text('Contact Owner'),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.currency_rupee, size: 16),
                              Text('${t.pricePerDay.toStringAsFixed(0)}/day'),
                            ],
                          ),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ToolDetailsScreen(toolId: t.id))),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidGlassCard extends StatefulWidget {
  final Widget child;

  const _LiquidGlassCard({required this.child});

  @override
  State<_LiquidGlassCard> createState() => _LiquidGlassCardState();
}

class _LiquidGlassCardState extends State<_LiquidGlassCard> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(14);
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : const Color(0xFF1300FF)).withValues(alpha: _hovered ? 0.22 : 0.12),
              blurRadius: _hovered ? 24 : 14,
              spreadRadius: _hovered ? 0.6 : 0,
              offset: Offset(0, _hovered ? 12 : 8),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: _hovered ? 0.18 : 0.08),
              blurRadius: _hovered ? 18 : 10,
              offset: const Offset(-1, -1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.62),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.75),
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
