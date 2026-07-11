import 'package:lpinyin/lpinyin.dart';
import '../models/snippet.dart';

/// 关键词匹配的检索索引（见 CONTEXT.md「关键词匹配」）
///
/// 把片段的名称/描述/标签拼成一个小写检索串；含中文的字段额外追加
/// 全拼与首字母拼音，使 `huifu` / `hf` 能命中「回复话术」。
/// 索引在片段加载/变更时预计算，搜索按键时只做子串比较。

final _chinesePattern = RegExp(r'[一-鿿]');

bool _hasChinese(String s) => _chinesePattern.hasMatch(s);

/// 为一条片段构建检索串。字段之间用换行分隔，避免跨字段的误命中。
String buildSearchIndex(Snippet snippet) {
  final parts = <String>[snippet.name, snippet.description, ...snippet.tags];
  final buffer = StringBuffer();
  for (final part in parts) {
    if (part.isEmpty) continue;
    buffer.writeln(part.toLowerCase());
    // 纯英文/数字字段不做拼音转换，避免 hf 之类的缩写误命中英文名
    if (_hasChinese(part)) {
      buffer.writeln(PinyinHelper.getPinyinE(
        part,
        separator: '',
        format: PinyinFormat.WITHOUT_TONE,
      ).toLowerCase());
      buffer.writeln(PinyinHelper.getShortPinyin(part).toLowerCase());
    }
  }
  return buffer.toString();
}
