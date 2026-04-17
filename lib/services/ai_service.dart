import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  final String functionUrl;

  AiService({required this.functionUrl});

  /// Send a prompt (and optional imageUrl) to the cloud function proxy and
  /// return the parsed JSON response. Throws a detailed exception on failure.
  Future<Map<String, dynamic>> query(String prompt, {String? imageUrl}) async {
    final body = <String, dynamic>{'prompt': prompt};
    if (imageUrl != null) body['imageUrl'] = imageUrl;

    final uri = Uri.parse(functionUrl);
    http.Response res;
    try {
      // Debug log the outgoing payload
      // ignore: avoid_print
      print('AI request -> $uri');
      // ignore: avoid_print
      print('AI payload -> ${json.encode(body)}');

      res = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: json.encode(body))
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      // ignore: avoid_print
      print('AI request error: $e');
      throw Exception('AI request failed: $e');
    }

    if (res.statusCode != 200) {
      // ignore: avoid_print
      print('AI response status: ${res.statusCode}');
      // ignore: avoid_print
      print('AI response body: ${res.body}');

      String message = 'AI assistant is temporarily unavailable.';
      final rawBody = res.body.toLowerCase();
      if (rawBody.contains('api_key_invalid') || rawBody.contains('api key not valid')) {
        throw Exception('AI service API key is invalid. Please contact support.');
      }

      try {
        final parsed = json.decode(res.body) as Map<String, dynamic>;
        final code = (parsed['code'] ?? '').toString();
        if (code == 'AI_API_KEY_INVALID' || code == 'AI_API_KEY_MISSING') {
          message = 'AI service is not configured correctly. Please contact support.';
        } else if (parsed['message'] != null && parsed['message'].toString().trim().isNotEmpty) {
          message = parsed['message'].toString();
        }
      } catch (_) {
        // Keep generic message if body is not JSON.
      }
      throw Exception(message);
    }

    try {
      return json.decode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'raw': res.body};
    }
  }
}
