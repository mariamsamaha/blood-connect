import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // ← ADDED

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

  String _resolveBaseUrl() {
    final envUrl = dotenv.env['AI_SERVICE_URL']?.trim() ?? '';
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  // ← ADDED: detects image type from bytes
  String _detectMimeType(Uint8List bytes, String fileName) {
    if (bytes.length >= 2) {
      if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
    }
    final ext = fileName.split('.').last.toLowerCase();
    return ext == 'png' ? 'image/png' : 'image/jpeg';
  }

  Future<AiPredictionResult> predictImage({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final baseUrl = _resolveBaseUrl();
    final uri = Uri.parse('$baseUrl/predict');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
        contentType: MediaType.parse(_detectMimeType(imageBytes, fileName)), // ← ADDED
      ),
    );

    final response = await request.send().timeout(const Duration(seconds: 60));
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception(
        'AI request failed (${response.statusCode}): ${body.isEmpty ? 'No response body' : body}',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected AI response format.');
    }
    return AiPredictionResult.fromJson(decoded);
  }
}