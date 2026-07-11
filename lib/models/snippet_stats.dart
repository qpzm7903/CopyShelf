/// 片段使用统计
///
/// 本机维度的使用频率与最近使用时间，只用于排序。
/// 存储在本地 stats.json，不参与 Git 同步（见 ADR-0001）。
class SnippetStats {
  final int frequency;
  final DateTime lastUsedAt;

  const SnippetStats({
    required this.frequency,
    required this.lastUsedAt,
  });

  /// 从未使用过的片段的统计（频率 0、时间为 epoch，排序垫底）。
  static final SnippetStats zero = SnippetStats(
    frequency: 0,
    lastUsedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// 记录一次使用，返回新实例（不可变更新）。
  SnippetStats used(DateTime at) {
    return SnippetStats(frequency: frequency + 1, lastUsedAt: at);
  }

  Map<String, dynamic> toJson() => {
        'frequency': frequency,
        'lastUsedAt': lastUsedAt.toIso8601String(),
      };

  factory SnippetStats.fromJson(Map<String, dynamic> json) {
    return SnippetStats(
      frequency: json['frequency'] as int? ?? 0,
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
