import 'package:flutter_test/flutter_test.dart';
import 'package:bloodconnect/services/audit_log_service.dart';

void main() {
  group('AuditLogService', () {
    test('log completes without error', () async {
      final service = AuditLogService();
      await service.log(requestId: 'r1', eventType: 'test');
    });

    test('log accepts optional params', () async {
      final service = AuditLogService();
      await service.log(
        requestId: 'r1',
        eventType: 'verified',
        detail: 'Donation verified',
        actorUserId: 'h1',
      );
    });
  });
}
