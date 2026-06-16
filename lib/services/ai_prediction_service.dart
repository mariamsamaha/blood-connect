import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:bloodconnect/config/app_config.dart';
import 'package:http/http.dart' as http;

// ── Abnormal finding from OCR rule engine ────────────────────────────────────
class AbnormalFinding {
  const AbnormalFinding({
    required this.feature,
    required this.label,
    required this.value,
    required this.unit,
    required this.valueType,
    required this.status,
    required this.range,
  });

  final String feature;
  final String label;
  final double value;
  final String unit;
  final String valueType;
  final String status; // "LOW" | "HIGH"
  final List<double> range;

  factory AbnormalFinding.fromJson(Map<String, dynamic> json) {
    return AbnormalFinding(
      feature: (json['feature'] ?? '').toString(),
      label: (json['label'] ?? json['feature'] ?? '').toString(),
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      unit: (json['unit'] ?? '').toString(),
      valueType: (json['value_type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      range: [
        if (json['range'] is List && (json['range'] as List).isNotEmpty)
          (json['range'][0] as num?)?.toDouble() ?? 0.0,
        if (json['range'] is List && (json['range'] as List).length > 1)
          (json['range'][1] as num?)?.toDouble() ?? 0.0,
      ],
    );
  }

  bool get isLow => status.toUpperCase() == 'LOW';
  bool get isHigh => status.toUpperCase() == 'HIGH';
}

// ── CBC metrics from OCR parsing ─────────────────────────────────────────────
class CbcMetrics {
  const CbcMetrics({
    required this.rbcIndices,
    required this.differentialPct,
    required this.differentialAbs,
  });

  final Map<String, dynamic> rbcIndices;
  final Map<String, dynamic> differentialPct;
  final Map<String, dynamic> differentialAbs;

  factory CbcMetrics.fromJson(Map<String, dynamic> json) {
    return CbcMetrics(
      rbcIndices: (json['rbc_indices'] as Map?)?.cast<String, dynamic>() ?? const {},
      differentialPct: (json['differential_pct'] as Map?)?.cast<String, dynamic>() ?? const {},
      differentialAbs: (json['differential_abs'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

// ── Full prediction result ───────────────────────────────────────────────────
class AiPredictionResult {
  const AiPredictionResult({
    required this.prediction,
    required this.eligible,
    required this.result,
    required this.confidence,
    required this.rawProbability,
    required this.threshold,
    required this.abnormalFindings,
    required this.metrics,
    required this.regressionDenormalized,
    required this.reasons,
    required this.explanationEn,
    required this.explanationAr,
  });

  /// "Normal" | "Abnormal" — ViT classifier output
  final String prediction;

  /// Whether the donor is eligible
  final bool eligible;

  /// "ELIGIBLE" | "DEFERRED"
  final String result;

  /// Confidence percentage (0–100)
  final double confidence;

  /// Raw P(Abnormal) probability (0–1)
  final double rawProbability;

  /// Classification threshold
  final double threshold;

  /// OCR-extracted abnormal findings (only when Abnormal)
  final List<AbnormalFinding> abnormalFindings;

  /// Parsed CBC metrics from OCR
  final CbcMetrics metrics;

  /// Flat map for regression display
  final Map<String, dynamic> regressionDenormalized;

  /// Eligibility reasons (English)
  final List<String> reasons;

  /// Explanation from donor eligibility engine
  final String explanationEn;

  /// Arabic explanation
  final String explanationAr;

  bool get isNormal => prediction == 'Normal';
  bool get isAbnormal => prediction == 'Abnormal';

  factory AiPredictionResult.fromJson(Map<String, dynamic> json) {
    final findings = (json['abnormal_findings'] as List?)
            ?.map((e) => AbnormalFinding.fromJson(e as Map<String, dynamic>))
            .toList(growable: false) ??
        const [];

    final metricsRaw = json['metrics'] as Map<String, dynamic>?;
    final metrics = metricsRaw != null
        ? CbcMetrics.fromJson(metricsRaw)
        : const CbcMetrics(rbcIndices: {}, differentialPct: {}, differentialAbs: {});

    final evaluation = json['evaluation'] as Map<String, dynamic>?;

    return AiPredictionResult(
      prediction: (json['prediction'] ?? '').toString(),
      eligible: json['eligible'] == true,
      result: (json['result'] ?? '').toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      rawProbability: (json['raw_probability'] as num?)?.toDouble() ?? 0.0,
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.50,
      abnormalFindings: findings,
      metrics: metrics,
      regressionDenormalized:
          (json['regression_denormalized'] as Map?)?.cast<String, dynamic>() ?? const {},
      reasons: (json['reasons'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
      explanationEn: (evaluation?['explanation_en'] ?? '').toString(),
      explanationAr: (evaluation?['explanation_ar'] ?? '').toString(),
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
        throw Exception('AI service is not responding correctly (status: ${response.statusCode}).');
      }
      final health = jsonDecode(response.body);
      if (health['vit_model_loaded'] != true && health['model_loaded'] != true) {
        throw Exception('AI model is not loaded. Check the Python server logs.');
      }
    } on SocketException {
      throw Exception('Cannot connect to AI service at $baseUrl. Ensure the Python server is running.');
    } on FormatException {
      throw Exception('AI service returned invalid response. Wrong server running at $baseUrl?');
    }
  }

  Future<AiPredictionResult> predictImage({
    required Uint8List imageBytes,
    required String fileName,
    String gender = 'male',
  }) async {
    final baseUrl = _resolveBaseUrl();

    debugPrint('[AI] Resolved base URL: $baseUrl');
    await _verifyService(baseUrl);

    final uri = Uri.parse('$baseUrl/predict');
    debugPrint('[AI] Sending image: $fileName (${imageBytes.length} bytes)');

    final request = http.MultipartRequest('POST', uri);
    request.fields['gender'] = gender;
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
