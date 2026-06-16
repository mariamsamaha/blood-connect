import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/services/ai_prediction_service.dart';

void main() {
  group('AiPredictionResult', () {
    test('fromJson parses full v3.0.0 response', () {
      final json = {
        'prediction': 'Normal',
        'eligible': true,
        'result': 'ELIGIBLE',
        'confidence': 97.33,
        'raw_probability': 0.0267,
        'threshold': 0.50,
        'abnormal_findings': [
          {
            'feature': 'neutrophils',
            'label': 'Neutrophils',
            'value': 75.1,
            'unit': '%',
            'value_type': 'percentage (%)',
            'status': 'HIGH',
            'range': [40.0, 75.0],
          },
          {
            'feature': 'lymphocytes',
            'label': 'Lymphocytes',
            'value': 0.4,
            'unit': '\u00d710\u2079/L',
            'value_type': 'absolute (\u00d710\u2079/L)',
            'status': 'LOW',
            'range': [1.0, 4.8],
          },
        ],
        'metrics': {
          'rbc_indices': {'haemoglobin': 13.5},
          'differential_pct': {'neutrophils': 75.1},
          'differential_abs': {'neutrophils': 5.2},
        },
        'regression_denormalized': {'hemoglobin': 13.5, 'neutrophils_pct': 75.1},
        'reasons': [],
        'evaluation': {
          'status': 'ELIGIBLE',
          'explanation_en': 'All parameters normal.',
          'explanation_ar': '\u0627\u0644\u0645\u0639\u0627\u064a\u064a\u0631 \u0637\u0628\u064a\u0639\u064a\u0629.',
          'gender': 'male',
          'thresholds_version': '3.0.0',
        },
      };
      final result = AiPredictionResult.fromJson(json);
      expect(result.prediction, 'Normal');
      expect(result.eligible, isTrue);
      expect(result.result, 'ELIGIBLE');
      expect(result.confidence, 97.33);
      expect(result.isNormal, isTrue);
      expect(result.isAbnormal, isFalse);
      expect(result.abnormalFindings.length, 2);
      expect(result.abnormalFindings[0].label, 'Neutrophils');
      expect(result.abnormalFindings[0].isHigh, isTrue);
      expect(result.abnormalFindings[1].isLow, isTrue);
      expect(result.metrics.rbcIndices['haemoglobin'], 13.5);
      expect(result.explanationEn, 'All parameters normal.');
      expect(result.explanationAr, isNotEmpty);
    });

    test('fromJson handles Abnormal response with findings', () {
      final json = {
        'prediction': 'Abnormal',
        'eligible': false,
        'result': 'DEFERRED',
        'confidence': 92.1,
        'raw_probability': 0.921,
        'threshold': 0.50,
        'abnormal_findings': [
          {
            'feature': 'TLC',
            'label': 'Total WBC Count',
            'value': 3.0,
            'unit': '\u00d710\u00b3/\u00b5L',
            'value_type': 'absolute',
            'status': 'LOW',
            'range': [4.0, 11.0],
          },
        ],
        'metrics': {
          'rbc_indices': {'TLC': 3.0},
          'differential_pct': {},
          'differential_abs': {},
        },
        'regression_denormalized': {'TLC': 3.0},
        'reasons': ['Total WBC Count is below normal'],
        'evaluation': {
          'status': 'DEFERRED',
          'explanation_en': 'Temporary deferral.',
          'explanation_ar': '\u062a\u0623\u062c\u064a\u0644 \u0645\u0648\u0642\u062a.',
          'gender': 'male',
        },
      };
      final result = AiPredictionResult.fromJson(json);
      expect(result.prediction, 'Abnormal');
      expect(result.eligible, isFalse);
      expect(result.result, 'DEFERRED');
      expect(result.isAbnormal, isTrue);
      expect(result.abnormalFindings.length, 1);
      expect(result.abnormalFindings[0].feature, 'TLC');
      expect(result.reasons.length, 1);
    });

    test('fromJson handles missing fields gracefully', () {
      final result = AiPredictionResult.fromJson({});
      expect(result.prediction, '');
      expect(result.eligible, isFalse);
      expect(result.confidence, 0.0);
      expect(result.abnormalFindings, isEmpty);
      expect(result.metrics.rbcIndices, isEmpty);
      expect(result.reasons, isEmpty);
      expect(result.explanationEn, isEmpty);
    });

    test('fromJson handles null fields', () {
      final json = {
        'prediction': null,
        'eligible': null,
        'confidence': null,
        'abnormal_findings': null,
        'metrics': null,
        'reasons': null,
        'evaluation': null,
      };
      final result = AiPredictionResult.fromJson(json);
      expect(result.eligible, isFalse);
      expect(result.confidence, 0.0);
      expect(result.prediction, '');
      expect(result.abnormalFindings, isEmpty);
    });

    test('AbnormalFinding range parsing', () {
      final finding = AbnormalFinding.fromJson({
        'feature': 'basophils',
        'label': 'Basophils',
        'value': 8.0,
        'unit': '%',
        'value_type': 'percentage (%)',
        'status': 'HIGH',
        'range': [0.0, 1.0],
      });
      expect(finding.isHigh, isTrue);
      expect(finding.isLow, isFalse);
      expect(finding.range[0], 0.0);
      expect(finding.range[1], 1.0);
    });
  });
}
