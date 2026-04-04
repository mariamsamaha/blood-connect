import 'package:bloodconnect/services/database_service.dart';

/// Minimal audit trail for MVP (requires `request_audit_log` from SQL migration).
class AuditLogService {
  final DatabaseService _db;

  AuditLogService(this._db);

  Future<void> log({
    required String requestId,
    required String eventType,
    String? detail,
    String? actorUserId,
  }) async {
    try {
      await _db.query(
        '''
        INSERT INTO request_audit_log (request_id, event_type, detail, actor_user_id)
        VALUES (@requestId, @eventType, @detail, @actorUserId)
      ''',
        params: {
          'requestId': requestId,
          'eventType': eventType,
          'detail': detail,
          'actorUserId': actorUserId,
        },
      );
    } catch (_) {}
  }
}
