import 'dart:math' as math;

/// frecency 半衰期：一次使用的权重每 7 天衰减一半
const int _halfLifeDays = 7;

/// 参与 frecency 计算的最近使用记录条数上限
const int _maxRecentUses = 10;

/// 片段使用统计
///
/// 本机维度的使用频率与最近使用时间，只用于排序（frecency）。
/// 存储在本地 stats.json，不参与 Git 同步（见 ADR-0001）。
class SnippetStats {
  /// 累计使用次数（不截断，仅展示/同分退避用）
  final int frequency;

  final DateTime lastUsedAt;

  /// 最近使用时间戳（升序，最多保留 [_maxRecentUses] 条），frecency 的输入
  final List<DateTime> recentUses;

  /// 是否置顶（本地状态，不同步；置顶项恒排最前）
  final bool pinned;

  const SnippetStats({
    required this.frequency,
    required this.lastUsedAt,
    this.recentUses = const [],
    this.pinned = false,
  });

  /// 从未使用过的片段的统计（频率 0、时间为 epoch，排序垫底）。
  static final SnippetStats zero = SnippetStats(
    frequency: 0,
    lastUsedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// 记录一次使用，返回新实例（不可变更新）。
  SnippetStats used(DateTime at) {
    final uses = [...recentUses, at];
    return SnippetStats(
      frequency: frequency + 1,
      lastUsedAt: at,
      recentUses: uses.length > _maxRecentUses
          ? uses.sublist(uses.length - _maxRecentUses)
          : uses,
      pinned: pinned,
    );
  }

  /// 切换置顶状态，返回新实例。
  SnippetStats withPinned(bool value) => SnippetStats(
        frequency: frequency,
        lastUsedAt: lastUsedAt,
        recentUses: recentUses,
        pinned: value,
      );

  /// frecency 得分：每条最近使用记录按年龄指数衰减后求和。
  ///
  /// 刚用过的一次贡献 1.0，7 天前的一次贡献 0.5，越久贡献越小；
  /// 因此「近期低频」会胜过「远古高频」。
  double frecencyScore(DateTime now) {
    var score = 0.0;
    for (final use in recentUses) {
      final ageDays = now.difference(use).inSeconds / Duration.secondsPerDay;
      // 时钟回拨产生的「未来」时间戳按刚用过计分（钳到 0），不丢分
      final clampedAge = ageDays < 0 ? 0.0 : ageDays;
      score += math.pow(0.5, clampedAge / _halfLifeDays).toDouble();
    }
    return score;
  }

  Map<String, dynamic> toJson() => {
        'frequency': frequency,
        'lastUsedAt': lastUsedAt.toIso8601String(),
        'recentUses': recentUses.map((t) => t.toIso8601String()).toList(),
        if (pinned) 'pinned': true,
      };

  factory SnippetStats.fromJson(Map<String, dynamic> json) {
    final frequency = json['frequency'] as int? ?? 0;
    final lastUsedAt = json['lastUsedAt'] != null
        ? DateTime.parse(json['lastUsedAt'] as String)
        : DateTime.fromMillisecondsSinceEpoch(0);

    final rawUses = json['recentUses'] as List<dynamic>?;
    List<DateTime> recentUses;
    if (rawUses != null) {
      recentUses = rawUses.map((e) => DateTime.parse(e as String)).toList();
    } else if (frequency > 0) {
      // 旧格式迁移：把 lastUsedAt 合成为一条使用记录，保留基本排序信号
      recentUses = [lastUsedAt];
    } else {
      recentUses = const [];
    }

    return SnippetStats(
      frequency: frequency,
      lastUsedAt: lastUsedAt,
      recentUses: recentUses,
      pinned: json['pinned'] as bool? ?? false,
    );
  }
}
