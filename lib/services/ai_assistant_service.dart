import 'dart:convert';
import 'dart:io' show Platform, SocketException;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ChatMessage {
  const ChatMessage({required this.role, required this.content});
  final String role;
  final String content;
}

class AiAssistantService {
  const AiAssistantService();

  String _resolveBaseUrl() {
    final envUrl = dotenv.env['AI_SERVICE_URL']?.trim() ?? '';
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
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
    ).timeout(const Duration(seconds: 30));

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
