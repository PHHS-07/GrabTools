import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tool_model.dart';
import '../providers/auth_provider.dart';
import '../services/ratings_service.dart';
import '../services/storage_service.dart';
import '../services/tools_service.dart';
import '../widgets/app_alerts.dart';
import '../widgets/tool_availability_badge.dart';
import 'add_tool_screen.dart';
import 'edit_tool_screen.dart';

class ToolManagementScreen extends StatefulWidget {
  const ToolManagementScreen({super.key});

  @override
  State<ToolManagementScreen> createState() => _ToolManagementScreenState();
}

class _ToolManagementScreenState extends State<ToolManagementScreen> {
  Object? _lastLoadError;

  Future<void> _showToolActions(Tool tool) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Tool'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => EditToolScreen(toolId: tool.id)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove Tool', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                await _removeTool(tool);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeTool(Tool tool) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove Tool'),
            content: Text('Delete "${tool.title}" permanently?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remove', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      for (final path in tool.imageStoragePaths) {
        await StorageService().deleteFile(path);
      }
      await ToolsService().deleteTool(tool.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tool removed')),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorAlert(context, 'Unable to remove tool. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your Tools')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddToolScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Tool>>(
        stream: ToolsService().streamToolsByOwner(profile.id),
        builder: (context, snap) {
          if (snap.hasError) {
            if (_lastLoadError != snap.error) {
              _lastLoadError = snap.error;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                showErrorAlert(context, 'Unable to load tools. Please try again.');
              });
            }
            return Center(
              child: ElevatedButton(
                onPressed: () => setState(() => _lastLoadError = null),
                child: const Text('Retry'),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final tools = snap.data ?? [];
          if (tools.isEmpty) return const Center(child: Text('No tools yet'));

          final anySuspicious = tools.any((t) => t.isSuspicious);

          return Column(
            children: [
              if (anySuspicious)
                Container(
                  width: double.infinity,
                  color: Colors.orange.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Some of your tools are under review. They may be hidden from search results until verified by an admin.',
                          style: TextStyle(color: Colors.orange.shade900, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: tools.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final t = tools[i];
                    return GestureDetector(
                      onLongPress: () => _showToolActions(t),
                      child: _LiquidGlassCard(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: t.imageUrls.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    t.imageUrls.first,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.handyman, size: 28),
                          title: Text(
                            t.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              StreamBuilder(
                                stream: RatingsService().streamRatingsByTool(t.id),
                                builder: (context, ratingSnap) {
                                  if (!ratingSnap.hasData || ratingSnap.data!.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 14),
                                          const SizedBox(width: 4),
                                          const Text(
                                            '0.0/5 (0)',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  final ratings = ratingSnap.data!;
                                  final avgScore = ratings.fold(0.0, (s, r) => s + (r.toolRating ?? r.behavior)) / ratings.length;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${avgScore.toStringAsFixed(1)}/5 (${ratings.length})',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              ToolAvailabilityBadge(tool: t, compact: true),
                              if (t.isSuspicious)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.orange),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.warning, color: Colors.orange, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'Flagged: Under Review',
                                          style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (t.visibility == 'hidden')
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.red),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.visibility_off, color: Colors.red, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'Hidden by Admin',
                                          style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.currency_rupee, size: 16),
                              Text('${t.pricePerDay.toStringAsFixed(0)}/day'),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      ),
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
    final radius = BorderRadius.circular(16);
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
            filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.62),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.78),
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
