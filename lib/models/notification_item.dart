class NotificationItem {
  final String id;
  final String? requestId;
  final String notificationType;
  final String title;
  final String body;
  final DateTime sentAt;
  final DateTime? readAt;
  final String? deliveryStatus;

  NotificationItem({
    required this.id,
    this.requestId,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.sentAt,
    this.readAt,
    this.deliveryStatus,
  });

  bool get isUnread => readAt == null;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      requestId: json['request_id'] as String?,
      notificationType: json['notification_type'] as String? ?? 'system_message',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      sentAt: DateTime.tryParse(json['sent_at'] as String? ?? '') ?? DateTime.now(),
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
      deliveryStatus: json['delivery_status'] as String?,
    );
  }
}
