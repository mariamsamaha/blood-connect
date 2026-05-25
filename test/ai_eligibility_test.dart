import 'package:bloodconnect/models/ai_eligibility_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiEligibilityResult', () {
    test('fromJson parses eligible state correctly', () {
      final json = {
        'status': 'eligible',
        'score': 0.85,
        'warnings': ['Minor risk'],
        'tips': ['Drink water'],
        'message': 'Looks healthy',
      };

      final result = AiEligibilityResult.fromJson(json);

      expect(result.status, EligibilityStatus.eligible);
      expect(result.score, 0.85);
      expect(result.warnings, ['Minor risk']);
      expect(result.tips, ['Drink water']);
      expect(result.message, 'Looks healthy');
      expect(result.canProceed, isTrue);
    });

    test('fromJson infers eligible status when score >= 0.75 even if status string is empty', () {
      final json = {
        'status': '',
        'score': 0.80,
        'warnings': [],
        'tips': [],
        'message': '',
      };

      final result = AiEligibilityResult.fromJson(json);

      expect(result.status, EligibilityStatus.eligible);
      expect(result.canProceed, isTrue);
    });

    test('fromJson parses uncertain state correctly', () {
      final json = {
        'status': 'uncertain',
        'score': 0.60,
        'warnings': ['Low hemoglobin'],
        'tips': ['Consult doctor'],
        'message': 'Slightly low levels',
      };

      final result = AiEligibilityResult.fromJson(json);

      expect(result.status, EligibilityStatus.uncertain);
      expect(result.score, 0.60);
      expect(result.canProceed, isTrue); // Proceed with caution (canProceed is true)
    });

    test('fromJson infers uncertain status when score >= 0.5 and < 0.75', () {
      final json = {
        'status': '',
        'score': 0.55,
        'warnings': [],
        'tips': [],
        'message': '',
      };

      final result = AiEligibilityResult.fromJson(json);

      expect(result.status, EligibilityStatus.uncertain);
      expect(result.canProceed, isTrue);
    });

    test('fromJson parses notEligible state correctly', () {
      final json = {
        'status': 'notEligible',
        'score': 0.35,
        'warnings': ['Recent fever'],
        'tips': ['Rest for a week'],
        'message': 'Cannot donate today',
      };

      final result = AiEligibilityResult.fromJson(json);

      expect(result.status, EligibilityStatus.notEligible);
      expect(result.score, 0.35);
      expect(result.canProceed, isFalse);
    });

    test('fromJson handles null values and missing keys defensively', () {
      final result = AiEligibilityResult.fromJson({});

      expect(result.status, EligibilityStatus.uncertain); // default score is 0.5 -> uncertain
      expect(result.score, 0.5);
      expect(result.warnings, isEmpty);
      expect(result.tips, isEmpty);
      expect(result.message, isEmpty);
      expect(result.canProceed, isTrue);
    });

    test('serviceError creates a safe fallback object', () {
      final result = AiEligibilityResult.serviceError();

      expect(result.status, EligibilityStatus.error);
      expect(result.score, 0.5);
      expect(result.warnings, isEmpty);
      expect(result.tips, isNotEmpty);
      expect(result.canProceed, isTrue); // Fail open: must allow proceeding on infrastructure error
    });
  });
}
