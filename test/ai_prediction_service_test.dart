import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/services/ai_prediction_service.dart';

void main() {
  group('AiPredictionResult', () {
    test('fromJson parses full response', () {
      final json = {
        'result': 'Eligible',
        'eligible': true,
        'confidence': 89.5,
        'raw_probability': 0.895,
        'threshold': 0.55,
        'regression_denormalized': {
          'hemoglobin': 13.5,
          'weight': 70.0,
        },
        'reasons': [],
      };
      final result = AiPredictionResult.fromJson(json);
      expect(result.eligible, isTrue);
      expect(result.confidence, 89.5);
      expect(result.rawProbability, 0.895);
      expect(result.regressionDenormalized['hemoglobin'], 13.5);
      expect(result.reasons, isEmpty);
    });

    test('fromJson handles missing fields', () {
      final result = AiPredictionResult.fromJson({});
      expect(result.eligible, isFalse);
      expect(result.confidence, 0.0);
      expect(result.regressionDenormalized, isEmpty);
      expect(result.reasons, isEmpty);
    });

    test('fromJson handles null fields', () {
      final json = {
        'result': null,
        'eligible': null,
        'confidence': null,
        'reasons': null,
        'regression_denormalized': null,
      };
      final result = AiPredictionResult.fromJson(json);
      expect(result.eligible, isFalse);
      expect(result.confidence, 0.0);
      expect(result.result, '');
    });

    test('fromJson parses deferral reasons', () {
      final json = {
        'result': 'Deferred',
        'eligible': false,
        'confidence': 45.0,
        'raw_probability': 0.45,
        'threshold': 0.55,
        'regression_denormalized': {'hemoglobin': 9.5},
        'reasons': [
          'Hemoglobin is below the safe range',
          'Weight is below the safe range',
        ],
      };
      final result = AiPredictionResult.fromJson(json);
      expect(result.eligible, isFalse);
      expect(result.reasons.length, 2);
      expect(result.reasons[0], contains('Hemoglobin'));
    });

    test('fromJson handles partial regression data', () {
      final json = {
        'result': 'Eligible',
        'eligible': true,
        'confidence': 95.0,
        'raw_probability': 0.95,
        'threshold': 0.55,
        'regression_denormalized': {'hemoglobin': 14.0},
        'reasons': [],
      };
      final result = AiPredictionResult.fromJson(json);
      expect(result.regressionDenormalized.length, 1);
    });
  });
}
