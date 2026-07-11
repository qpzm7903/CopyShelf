/// 片段定义数据模型
///
/// 只包含跨设备同步的定义部分（见 ADR-0001）。
/// 使用统计（frequency/lastUsedAt）在 SnippetStats 中，本地存储、不同步。
class Snippet {
  final String id;
  final String name;
  final String content;
  final String description;
  final List<String> tags;
  final DateTime createdAt;

  Snippet({
    required this.id,
    required this.name,
    required this.content,
    this.description = '',
    List<String>? tags,
    DateTime? createdAt,
  })  : tags = List.unmodifiable(tags ?? const []),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'content': content,
        'description': description,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
      };

  /// 旧版数据文件中的 frequency/lastUsedAt 字段直接忽略。
  factory Snippet.fromJson(Map<String, dynamic> json) {
    return Snippet(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      content: json['content'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Snippet copyWith({
    String? name,
    String? content,
    String? description,
    List<String>? tags,
  }) {
    return Snippet(
      id: id,
      name: name ?? this.name,
      content: content ?? this.content,
      description: description ?? this.description,
      tags: tags ?? List.from(this.tags),
      createdAt: createdAt,
    );
  }
}
