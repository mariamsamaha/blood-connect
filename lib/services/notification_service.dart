import 'package:flutter/foundation.dart';
import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/notification_item.dart';
import 'package:bloodconnect/services/api_client.dart';

class NotificationService {
  final ApiClient? _api;

  NotificationService([this._api]);

  Future<List<NotificationItem>> getNotifications() async {
    try {
      final result = await _api!.getJsonList(
        '/api/v1/notifications',
        forceRefresh: true,
      );
      return result.map((row) => NotificationItem.fromJson(row)).toList();
    } catch (e) {
      debugPrint('getNotifications error: $e');
      return [];
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final row = await _api!.getJson(
        '/api/v1/notifications/unread-count',
        forceRefresh: true,
      );
      if (row == null) {
        debugPrint('getUnreadCount: null response');
        return 0;
      }
      final count = (row['count'] as num?)?.toInt() ?? 0;
      debugPrint('getUnreadCount: $count');
      return count;
    } catch (e) {
      debugPrint('getUnreadCount error: $e');
      return 0;
    }
  }

  Future<void> markAsRead({String? notificationId}) async {
    try {
      await _api!.postEmpty(
        '/api/v1/notifications/read',
        body: notificationId != null ? {'notificationId': notificationId} : {},
      );
    } catch (e) {
      debugPrint('markAsRead error: $e');
    }
  }

  Future<void> sendNewRequestNotifications(BloodRequest request) async {
    debugPrint(
      'NotificationService: push handled by API for request ${request.shortId}',
    );
  }
}
