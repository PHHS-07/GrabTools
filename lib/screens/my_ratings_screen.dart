import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/ratings_service.dart';

class MyRatingsScreen extends StatelessWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    if (profile == null) return const Scaffold(body: Center(child: Text('Not signed in')));

    final ownerId = profile.id;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Ratings'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'As Lender'),
              Tab(text: 'As Seeker'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
          ),
        ),
        body: TabBarView(
          children: [
            _RatingsRoleView(ownerId: ownerId, role: 'lender'),
            _RatingsRoleView(ownerId: ownerId, role: 'seeker'),
          ],
        ),
      ),
    );
  }
}

class _RatingsRoleView extends StatefulWidget {
  final String ownerId;
  final String role;

  const _RatingsRoleView({required this.ownerId, required this.role});

  @override
  State<_RatingsRoleView> createState() => _RatingsRoleViewState();
}

class _RatingsRoleViewState extends State<_RatingsRoleView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final RatingsService _ratingsService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ratingsService = RatingsService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<double>(
                future: _ratingsService.averageBehavior(widget.ownerId, role: widget.role),
                builder: (ctx, snap) {
                  final avg = snap.data ?? 0.0;
                  return _HoverMorphCard(
                    child: ListTile(
                      title: const Text('Behavior Rating'),
                      subtitle: Text('Average: ${avg.toStringAsFixed(2)} / 5'),
                    ),
                  );
                },
              ),
              if (widget.role == 'lender') ...[
                const SizedBox(height: 12),
                const Text('Tool Ratings by Category',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                FutureBuilder<Map<String, double>>(
                  future: _ratingsService.averageToolRatingsByCategory(widget.ownerId,
                      role: widget.role),
                  builder: (ctx, snap) {
                    final map = snap.data ?? <String, double>{};
                    if (map.isEmpty) return const Text('No tool ratings yet');
                    return Column(
                      children: map.entries.map((e) {
                        return _HoverMorphCard(
                          child: ListTile(
                            title: Text(e.key),
                            trailing: Text('${e.value.toStringAsFixed(2)} / 5'),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Recent Ratings'),
            Tab(text: 'Ratings History'),
          ],
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).unselectedWidgetColor,
        ),
        Expanded(
          child: StreamBuilder<List<Rating>>(
            stream: _ratingsService.streamRatingsForOwner(widget.ownerId, role: widget.role),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return const Center(child: Text('Unable to load ratings'));
              }
              final list = snap.data ?? <Rating>[];
              final recent = list.take(5).toList();
              final history = list.skip(5).toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _RatingList(ratings: recent),
                  _RatingList(ratings: history),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RatingList extends StatelessWidget {
  final List<Rating> ratings;
  const _RatingList({required this.ratings});

  @override
  Widget build(BuildContext context) {
    if (ratings.isEmpty) return const Center(child: Text('No ratings to display.'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: ratings.length,
      itemBuilder: (c, i) {
        final r = ratings[i];
        return _HoverMorphCard(
          child: ListTile(
            title: Text(r.toolName ?? r.toolCategory ?? 'Tool'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.toolCategory != null) Text(r.toolCategory!),
                Text('Behavior: ${r.behavior}/5'),
                if (r.toolRating != null) Text('Tool Quality: ${r.toolRating}/5'),
                if (r.comment != null) Text(r.comment!),
              ],
            ),
            trailing: Text(r.createdAt.toLocal().toString().split(' ')[0]),
          ),
        );
      },
    );
  }
}

class _HoverMorphCard extends StatefulWidget {
  final Widget child;

  const _HoverMorphCard({required this.child});

  @override
  State<_HoverMorphCard> createState() => _HoverMorphCardState();
}

class _HoverMorphCardState extends State<_HoverMorphCard> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(12);
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: radius,
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : const Color(0xFF1300FF))
                  .withValues(alpha: _hovered ? 0.22 : 0.1),
              blurRadius: _hovered ? 20 : 10,
              spreadRadius: _hovered ? 0.5 : 0,
              offset: Offset(0, _hovered ? 10 : 5),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: _hovered ? 0.12 : 0.05),
              blurRadius: _hovered ? 14 : 8,
              offset: const Offset(-1, -1),
            ),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: radius),
          child: widget.child,
        ),
      ),
    );
  }
}