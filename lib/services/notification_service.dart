import 'package:flutter/foundation.dart';

import 'package:bloodconnect/models/blood_request.dart';

/// Push notifications are triggered server-side when a request is created.
class NotificationService {
  Future<void> sendNewRequestNotifications(BloodRequest request) async {
    debugPrint(
      'NotificationService: push handled by API for request ${request.shortId}',
    );
  }
}
