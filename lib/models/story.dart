class Story {
  final String id;
  final String authorId;
  final String authorName;
  final String authorBloodType;
  final String role;
  final String title;
  final String body;
  final String? bloodType;
  final int likesCount;
  final bool isFeatured;
  final bool isLikedByMe;
  final DateTime createdAt;

  const Story({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorBloodType,
    required this.role,
    required this.title,
    required this.body,
    this.bloodType,
    required this.likesCount,
    required this.isFeatured,
    required this.isLikedByMe,
    required this.createdAt,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String? ?? 'Anonymous',
      authorBloodType: json['author_blood_type'] as String? ?? '',
      role: json['role'] as String? ?? 'donor',
      title: json['title'] as String,
      body: json['body'] as String,
      bloodType: json['blood_type'] as String?,
      likesCount: json['likes_count'] is int
          ? json['likes_count'] as int
          : int.tryParse(json['likes_count']?.toString() ?? '') ?? 0,
      isFeatured: json['is_featured'] as bool? ?? false,
      isLikedByMe: json['is_liked_by_me'] as bool? ?? false,
      createdAt: DateTime.tryParse(
            json['created_at'] as String? ?? '',
          ) ??
          DateTime.now(),
    );
  }

  Story copyWith({int? likesCount, bool? isLikedByMe}) {
    return Story(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorBloodType: authorBloodType,
      role: role,
      title: title,
      body: body,
      bloodType: bloodType,
      likesCount: likesCount ?? this.likesCount,
      isFeatured: isFeatured,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      createdAt: createdAt,
    );
  }
}
