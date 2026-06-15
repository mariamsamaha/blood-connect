import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:bloodconnect/config/app_config.dart';
import 'package:http/http.dart' as http;

class AiPredictionResult {
  const AiPredictionResult({
    required this.result,
    required this.eligible,
    required this.confidence,
    required this.rawProbability,
    required this.threshold,
    required this.regressionDenormalized,
    required this.reasons,
  });

  final String result;
  final bool eligible;
  final double confidence;
  final double rawProbability;
  final double threshold;
  final Map<String, dynamic> regressionDenormalized;
  final List<String> reasons;

  factory AiPredictionResult.fromJson(Map<String, dynamic> json) {
    return AiPredictionResult(
      result: (json['result'] ?? '').toString(),
      eligible: json['eligible'] == true,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      rawProbability: (json['raw_probability'] as num?)?.toDouble() ?? 0.0,
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.55,
      regressionDenormalized:
          (json['regression_denormalized'] as Map?)?.cast<String, dynamic>() ??
          const {},
      reasons:
          (json['reasons'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
    );
  }
}

class AiPredictionService {
  const AiPredictionService();

  String resolveBaseUrlForDebug() => _resolveBaseUrl();

  String _resolveBaseUrl() {
    final envUrl = AppConfig.aiServiceUrl;
    if (envUrl.isNotEmpty) return envUrl;
    return AppConfig.defaultLocalAiServiceUrl();
  }

  Future<void> _verifyService(String baseUrl) async {
    try {
      final healthUri = Uri.parse('$baseUrl/health');
      final response = await http.get(healthUri).timeout(const Duration(seconds: 300));
      if (response.statusCode != 200) {
        throw Exception('AI service is not responding correctly (status: ${response.statusCode}). Make sure the Python server is running.');
      }
      final health = jsonDecode(response.body);
      if (health['model_loaded'] != true) {
        throw Exception('AI model is not loaded. Check the Python server logs.');
      }
    } on SocketException {
      throw Exception('Cannot connect to AI service at $baseUrl. Ensure the Python server is running and reachable.');
    } on FormatException {
      throw Exception('AI service returned invalid response. Wrong server running at $baseUrl?');
    }
  }

  Future<AiPredictionResult> predictImage({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final baseUrl = _resolveBaseUrl();

    debugPrint('[AI] Resolved base URL: $baseUrl');
    await _verifyService(baseUrl);

    final uri = Uri.parse('$baseUrl/predict');
    debugPrint('[AI] Sending image: $fileName (${imageBytes.length} bytes)');

    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
        contentType: http.MediaType('image', 'jpeg'),
      ),
    );

    final response = await request.send().timeout(const Duration(seconds: 300));
    final body = await response.stream.bytesToString();

    debugPrint('[AI] Response status: ${response.statusCode}');
    debugPrint('[AI] Response body: $body');

    if (response.statusCode != 200) {
      String errorMsg;
      try {
        final errorJson = jsonDecode(body);
        errorMsg = errorJson['detail'] ?? body;
      } catch (_) {
        errorMsg = body.isEmpty ? 'No response body' : body;
      }
      throw Exception('AI analysis failed: $errorMsg');
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected AI response format.');
    }

    return AiPredictionResult.fromJson(decoded);
  }
}
