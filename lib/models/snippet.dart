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

  /// 是否作为模板：为 true 时粘贴前解析 {占位符}/内置变量并填表渲染；
  /// 为 false（默认）时逐字粘贴——含字面大括号的命令/JSON 不会被误当占位符。
  final bool isTemplate;

  Snippet({
    required this.id,
    required this.name,
    required this.content,
    this.description = '',
    List<String>? tags,
    DateTime? createdAt,
    this.isTemplate = false,
  })  : tags = List.unmodifiable(tags ?? const []),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'content': content,
        'description': description,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        if (isTemplate) 'isTemplate': true,
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
      isTemplate: json['isTemplate'] as bool? ?? false,
    );
  }

  Snippet copyWith({
    String? name,
    String? content,
    String? description,
    List<String>? tags,
    bool? isTemplate,
  }) {
    return Snippet(
      id: id,
      name: name ?? this.name,
      content: content ?? this.content,
      description: description ?? this.description,
      tags: tags ?? List.from(this.tags),
      createdAt: createdAt,
      isTemplate: isTemplate ?? this.isTemplate,
    );
  }
}
