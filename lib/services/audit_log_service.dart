import 'package:flutter/foundation.dart';

/// Audit events are written by the API BFF when mutations occur.
class AuditLogService {
  Future<void> log({
    required String requestId,
    required String eventType,
    String? detail,
    String? actorUserId,
  }) async {
    debugPrint('Audit [$eventType] request=$requestId (server-side)');
  }
}
