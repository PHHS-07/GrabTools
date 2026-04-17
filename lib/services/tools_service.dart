import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tool_model.dart';
import 'location_service.dart';

class ToolsService {
  final CollectionReference tools = FirebaseFirestore.instance.collection('tools');

  Future<String> addTool(Tool tool) async {
    final doc = await tools.add(tool.toMap());
    return doc.id;
  }

  Future<void> updateTool(Tool tool) async {
    await tools.doc(tool.id).set(tool.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteTool(String id) async {
    await tools.doc(id).delete();
  }

  Future<Tool?> getTool(String id) async {
    final doc = await tools.doc(id).get();
    if (!doc.exists) return null;
    return Tool.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  /// Get all tools with optional category filter
  Stream<List<Tool>> streamTools({String? category}) {
    Query query = tools.orderBy('title');
    if (category != null) query = query.where('categories', arrayContains: category);
    return query.snapshots().map((s) => s.docs
        .map((d) => Tool.fromMap(d.id, d.data() as Map<String, dynamic>))
        .where((t) => t.visibility != 'hidden')
        .toList());
  }

  /// Get tools near a location (within radiusKm)
  Stream<List<Tool>> streamToolsNearby({
    required double userLat,
    required double userLng,
    double radiusKm = 50.0,
    String? category,
  }) {
    Query query = tools.orderBy('title');
    if (category != null) query = query.where('categories', arrayContains: category);
    
    return query.snapshots().map((s) {
      final allTools = s.docs
          .map((d) => Tool.fromMap(d.id, d.data() as Map<String, dynamic>))
          .where((t) => t.visibility != 'hidden')
          .toList();

      // Filter by distance
      final nearbyTools = allTools.where((tool) {
        if (tool.location == null) return false;
        final toolLat = tool.location!['lat'] as double?;
        final toolLng = tool.location!['lng'] as double?;
        if (toolLat == null || toolLng == null) return false;

        final distance = LocationService.calculateDistance(
          userLat,
          userLng,
          toolLat,
          toolLng,
        );

        return distance <= radiusKm;
      }).toList();

      // Sort by distance
      nearbyTools.sort((a, b) {
        final distA = LocationService.calculateDistance(
          userLat,
          userLng,
          a.location!['lat'] as double,
          a.location!['lng'] as double,
        );
        final distB = LocationService.calculateDistance(
          userLat,
          userLng,
          b.location!['lat'] as double,
          b.location!['lng'] as double,
        );
        return distA.compareTo(distB);
      });

      return nearbyTools;
    });
  }

  Stream<List<Tool>> streamToolsByOwner(String ownerId) {
    // Avoid requiring a composite index on (ownerId, title) for this common view.
    final query = tools.where('ownerId', isEqualTo: ownerId);
    return query.snapshots().map((s) {
      final list = s.docs.map((d) => Tool.fromMap(d.id, d.data() as Map<String, dynamic>)).toList();
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      return list;
    });
  }
}
