/// 标签过滤条件（搜索窗左侧标签栏）
///
/// 三种取值：全部 / 无标签 / 指定标签。
/// 与 `#tag` 搜索语法不同：侧栏点的是库中真实存在的标签，
/// 因此按「不区分大小写的精确匹配」，而非子串匹配。
class TagFilter {
  /// 指定标签时非 null；「全部」「无标签」时为 null
  final String? tag;
  final bool _isUntagged;

  const TagFilter.all()
      : tag = null,
        _isUntagged = false;

  const TagFilter.untagged()
      : tag = null,
        _isUntagged = true;

  const TagFilter.tag(String this.tag) : _isUntagged = false;

  bool get isAll => tag == null && !_isUntagged;
  bool get isUntagged => _isUntagged;

  /// 片段标签是否满足该过滤条件
  bool matches(List<String> snippetTags) {
    if (isAll) return true;
    if (_isUntagged) return snippetTags.isEmpty;
    final target = tag!.toLowerCase();
    return snippetTags.any((t) => t.toLowerCase() == target);
  }

  @override
  bool operator ==(Object other) =>
      other is TagFilter &&
      other.tag == tag &&
      other._isUntagged == _isUntagged;

  @override
  int get hashCode => Object.hash(tag, _isUntagged);
}
