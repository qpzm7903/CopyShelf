/// 片段数据模型

class Snippet {
  final String id;
  String name;
  String content;
  String description;
  List<String> tags;
  int frequency;
  DateTime lastUsedAt;
  final DateTime createdAt;

  Snippet({
    required this.id,
    required this.name,
    required this.content,
    this.description = '',
    List<String>? tags,
    this.frequency = 0,
    DateTime? lastUsedAt,
    DateTime? createdAt,
  })  : tags = tags ?? [],
        lastUsedAt = lastUsedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'content': content,
        'description': description,
        'tags': tags,
        'frequency': frequency,
        'lastUsedAt': lastUsedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

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
      frequency: json['frequency'] as int? ?? 0,
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : null,
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
      frequency: frequency,
      lastUsedAt: lastUsedAt,
      createdAt: createdAt,
    );
  }
}
