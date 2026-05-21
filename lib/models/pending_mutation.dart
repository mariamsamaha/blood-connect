import 'dart:math';

String _generateMutationId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final random = Random().nextInt(99999);
  return 'mut_${now}_$random';
}

class PendingMutation {
  final String id;
  final String endpoint;
  final String method;
  final Map<String, dynamic>? payload;
  final Map<String, String>? headers;
  final DateTime createdAt;
  int retryCount;
  String status;
  int priority;
  String? optimisticCacheKey;
  Map<String, dynamic>? optimisticData;

  PendingMutation({
    String? id,
    required this.endpoint,
    required this.method,
    this.payload,
    this.headers,
    DateTime? createdAt,
    this.retryCount = 0,
    this.status = 'pending',
    this.priority = 0,
    this.optimisticCacheKey,
    this.optimisticData,
  })  : id = id ?? _generateMutationId(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'endpoint': endpoint,
        'method': method,
        'payload': payload,
        'headers': headers,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
        'status': status,
        'priority': priority,
        'optimisticCacheKey': optimisticCacheKey,
        'optimisticData': optimisticData,
      };

  factory PendingMutation.fromJson(Map<String, dynamic> json) {
    return PendingMutation(
      id: json['id'] as String,
      endpoint: json['endpoint'] as String,
      method: json['method'] as String,
      payload: json['payload'] != null
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : null,
      headers: json['headers'] != null
          ? Map<String, String>.from(json['headers'] as Map)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      priority: json['priority'] as int? ?? 0,
      optimisticCacheKey: json['optimisticCacheKey'] as String?,
      optimisticData: json['optimisticData'] != null
          ? Map<String, dynamic>.from(json['optimisticData'] as Map)
          : null,
    );
  }
}
