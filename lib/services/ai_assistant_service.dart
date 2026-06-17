import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:bloodconnect/config/app_config.dart';
import 'package:http/http.dart' as http;

class ChatMessage {
  const ChatMessage({required this.role, required this.content});
  final String role;
  final String content;
}

/// Service for the AI medical assistant chat (OpenRouter / Gemini backend).
///
/// Expects `donorData` to contain:
/// ```json
/// {
///   "status": "ELIGIBLE" | "DEFERRED",
///   "gender": "male" | "female",
///   "explanation_en": "...",
///   "abnormal_findings": [
///     { "label": "...", "value": 75.1, "unit": "%", "status": "HIGH", "range": [40.0, 75.0] }
///   ],
///   "reasons": ["..."],
///   "confidence": 97.33
/// }
/// ```
class AiAssistantService {
  const AiAssistantService();

  String _resolveBaseUrl() {
    final envUrl = AppConfig.aiServiceUrl;
    if (envUrl.isNotEmpty) return envUrl;
    return AppConfig.defaultLocalAiServiceUrl();
  }

  Future<String> sendChat({
    required List<ChatMessage> messages,
    required Map<String, dynamic> donorData,
  }) async {
    final baseUrl = _resolveBaseUrl();
    final uri = Uri.parse('$baseUrl/assistant/chat');

    debugPrint('[AI Assistant] Sending chat to $uri');

    final body = jsonEncode({
      'messages': messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
      'donor_data': donorData,
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 300));

    debugPrint('[AI Assistant] Response: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['reply'] as String;
    }

    String errorMsg;
    try {
      final err = jsonDecode(response.body);
      errorMsg = err['detail'] ?? response.body;
    } catch (_) {
      errorMsg = response.body.isEmpty ? 'Unknown error' : response.body;
    }

    throw Exception('AI Assistant failed: $errorMsg');
  }
}
