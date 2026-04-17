import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class VisionResult {
  final bool isValid;
  final String? reason; // shown to user if invalid
  final List<String> detectedLabels;

  const VisionResult({
    required this.isValid,
    this.reason,
    this.detectedLabels = const [],
  });
}

class VisionService {
  static const String _endpoint =
      'https://vision.googleapis.com/v1/images:annotate';

  // Tool-related keywords — image must contain at least one
  static const List<String> _toolKeywords = [
    'tool', 'tools', 'drill', 'hammer', 'wrench', 'screwdriver', 'saw',
    'grinder', 'sander', 'pliers', 'chisel', 'level', 'tape measure',
    'ladder', 'jack', 'clamp', 'vise', 'blowtorch', 'soldering', 'welder',
    'compressor', 'generator', 'pump', 'machine', 'equipment', 'device',
    'instrument', 'power tool', 'hand tool', 'hardware', 'machinery',
    'gardening', 'mower', 'trimmer', 'chainsaw', 'hedge trimmer',
    'pressure washer', 'vacuum', 'blower', 'sprayer', 'cultivator',
    'cleaning', 'painting', 'roller', 'brush', 'sprayer', 'plumbing',
    'pipe', 'fitting', 'valve', 'electrical', 'multimeter', 'tester',
    'cable', 'wire', 'conduit', 'socket', 'bolt', 'nut', 'screw',
    'nail', 'fastener', 'bracket', 'hinge', 'latch',
  ];

  // Blocked content — reject if detected
  static const List<String> _blockedKeywords = [
    'person', 'face', 'human', 'body', 'adult', 'nudity',
    'violence', 'weapon', 'gun', 'knife', 'blood',
    'food', 'drink', 'animal', 'pet', 'plant', 'flower',
    'car', 'vehicle', 'furniture', 'clothing',
  ];

  Future<VisionResult> verifyToolImage({
    required File imageFile,
    required String toolName,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('$_endpoint?key=${AppConfig.visionApiKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'LABEL_DETECTION', 'maxResults': 15},
                {'type': 'SAFE_SEARCH_DETECTION'},
              ],
            }
          ]
        }),
      );

      if (response.statusCode != 200) {
        // If Vision API fails, allow upload (don't block users on API errors)
        return const VisionResult(isValid: true, detectedLabels: []);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final responses = data['responses'] as List<dynamic>;
      if (responses.isEmpty) {
        return const VisionResult(isValid: true, detectedLabels: []);
      }

      final result = responses.first as Map<String, dynamic>;

      // Check safe search first
      final safeSearch = result['safeSearchAnnotation'] as Map<String, dynamic>?;
      if (safeSearch != null) {
        final adult = safeSearch['adult'] as String? ?? 'UNKNOWN';
        final violence = safeSearch['violence'] as String? ?? 'UNKNOWN';
        if (adult == 'LIKELY' || adult == 'VERY_LIKELY' ||
            violence == 'LIKELY' || violence == 'VERY_LIKELY') {
          return const VisionResult(
            isValid: false,
            reason: 'Image contains inappropriate content and cannot be uploaded.',
          );
        }
      }

      // Get labels
      final labelAnnotations = result['labelAnnotations'] as List<dynamic>? ?? [];
      final labels = labelAnnotations
          .map((l) => (l['description'] as String).toLowerCase())
          .toList();

      // Check for blocked content
      final hasBlockedContent = labels.any((label) =>
          _blockedKeywords.any((blocked) => label.contains(blocked)));
      if (hasBlockedContent) {
        return VisionResult(
          isValid: false,
          reason: 'The image does not appear to be a tool. Please upload a clear photo of "$toolName".',
          detectedLabels: labels,
        );
      }

      // Check if image contains tool-related content
      final hasToolContent = labels.any((label) =>
          _toolKeywords.any((keyword) => label.contains(keyword)));

      if (!hasToolContent) {
        return VisionResult(
          isValid: false,
          reason: 'The image does not appear to be a tool. Please upload a clear photo of "$toolName".',
          detectedLabels: labels,
        );
      }

      return VisionResult(isValid: true, detectedLabels: labels);
    } catch (e) {
      // On any error, allow the upload rather than blocking the user
      return const VisionResult(isValid: true, detectedLabels: []);
    }
  }
}