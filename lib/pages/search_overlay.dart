import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/snippet.dart';
import '../providers/snippet_provider.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/hotkey.dart';
import '../utils/search_query.dart';
import '../utils/template.dart';
import '../widgets/key_caps.dart';
import '../widgets/sync_indicator.dart';

/// 搜索主界面（类 Spotlight 搜索框）
///
/// 大号搜索输入 + 片段列表（名称 + 等宽内容预览）+ 底部快捷键提示栏。
/// 键盘上下键选择，回车粘贴，Esc 隐藏。
class SearchOverlay extends StatefulWidget {
  const SearchOverlay({super.key});

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _inputFocusNode = FocusNode();
  int _selectedIndex = 0;
  Hotkey _hotkey = Hotkey.defaultHotkey;

  SnippetProvider? _provider;
  bool _wasSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _loadHotkey();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 监听唤醒事件：每次呼出都要回到「立即可打字」状态
    final provider = Provider.of<SnippetProvider>(context, listen: false);
    if (!identical(provider, _provider)) {
      _provider?.removeListener(_onProviderChanged);
      _provider = provider;
      _wasSearchVisible = provider.isSearchVisible;
      provider.addListener(_onProviderChanged);
    }
  }

  /// 呼出瞬间重置：清空上次的搜索词、选中第一条、焦点回到输入框。
  /// 典型路径「唤醒 → 打关键词 → 回车」不需要任何额外按键。
  void _onProviderChanged() {
    final provider = _provider;
    if (provider == null || !mounted) return;
    final visible = provider.isSearchVisible;
    if (visible && !_wasSearchVisible) {
      _searchController.clear();
      setState(() => _selectedIndex = 0);
      _inputFocusNode.requestFocus();
    }
    _wasSearchVisible = visible;
  }

  Future<void> _loadHotkey() async {
    final storage = await StorageService.instance;
    final hotkey = Hotkey.parse(storage.hotkey);
    if (hotkey != null && mounted) {
      setState(() => _hotkey = hotkey);
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  /// Alt+1..9 对应的数字键 → 列表序号（1 起）
  static final Map<LogicalKeyboardKey, int> _digitKeys = {
    for (var i = 1; i <= 9; i++)
      LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i - 1): i,
  };

  KeyEventResult _handleKeyEvent(KeyEvent event, SnippetProvider provider) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final count = provider.filteredSnippets.length;

    // Alt+1..9：直达粘贴列表第 N 项
    if (HardwareKeyboard.instance.isAltPressed) {
      final number = _digitKeys[event.logicalKey];
      if (number != null) {
        if (number <= count) {
          _pasteAt(provider, number - 1);
        }
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && count > 0) {
      setState(() => _selectedIndex = (_selectedIndex + 1) % count);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && count > 0) {
      setState(() => _selectedIndex = (_selectedIndex - 1 + count) % count);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      provider.hideSearch();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _pasteSelected(provider);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _pasteSelected(SnippetProvider provider) {
    _pasteAt(provider, _selectedIndex);
  }

  Future<void> _pasteAt(SnippetProvider provider, int index) async {
    final snippets = provider.filteredSnippets;
    if (index < 0 || index >= snippets.length) return;
    final snippet = snippets[index];

    // 只有显式标记为模板的片段才解析占位符；普通片段逐字粘贴，
    // 避免含字面大括号的命令/JSON（如 kubectl jsonpath='{...}'）被误当模板。
    String content = snippet.content;
    if (snippet.isTemplate) {
      var values = <String, String>{};
      final fields = userInputPlaceholders(snippet.content);
      if (fields.isNotEmpty) {
        final defaults = {
          for (final name in fields)
            name: defaultValueFor(snippet.content, name),
        };
        final filled =
            await _promptPlaceholders(snippet.name, fields, defaults);
        if (filled == null) return; // 用户取消
        values = filled;
      }

      String clipboard = '';
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        clipboard = data?.text ?? '';
      } catch (_) {
        // 读剪贴板失败不阻断粘贴，{clipboard} 退化为空串
      }
      content = renderTemplateAdvanced(
        snippet.content,
        userValues: values,
        now: DateTime.now(),
        clipboard: clipboard,
      );
    }

    // 终端多行护栏：以最终粘贴内容判定，多行片段粘进终端会被逐行执行
    if (provider.needsTerminalPasteConfirm(snippet.id,
        contentOverride: content)) {
      final confirmed = await _confirmTerminalPaste(provider, content);
      if (confirmed != true) return;
    }

    provider.useSnippet(snippet.id, contentOverride: content);
    provider.hideSearch();
  }

  /// 占位符填表对话框；返回 null 表示用户取消。[defaults] 预填每项默认值。
  Future<Map<String, String>?> _promptPlaceholders(String snippetName,
      List<String> placeholders, Map<String, String> defaults) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _PlaceholderForm(
        snippetName: snippetName,
        placeholders: placeholders,
        defaults: defaults,
      ),
    );
  }

  Future<bool?> _confirmTerminalPaste(
      SnippetProvider provider, String content) {
    var suppressChecked = false;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          key: const Key('terminal-paste-confirm'),
          title: const Text('粘贴多行内容到终端？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '目标窗口是终端，多行内容会被逐行执行。',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.maxFinite,
                constraints: const BoxConstraints(maxHeight: 160),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.canvas,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: Text(content, style: AppTheme.mono()),
                ),
              ),
              CheckboxListTile(
                key: const Key('terminal-paste-suppress'),
                value: suppressChecked,
                onChanged: (v) =>
                    setDialogState(() => suppressChecked = v ?? false),
                title: const Text('不再提醒', style: TextStyle(fontSize: 12.5)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              key: const Key('terminal-paste-proceed'),
              onPressed: () {
                if (suppressChecked) {
                  provider.suppressTerminalPasteWarning();
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('仍然粘贴'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SnippetProvider>(
      builder: (context, provider, _) {
        final snippets = provider.filteredSnippets;
        if (_selectedIndex >= snippets.length) {
          _selectedIndex = 0;
        }

        return Focus(
          autofocus: true,
          focusNode: _focusNode,
          onKeyEvent: (node, event) => _handleKeyEvent(event, provider),
          child: Column(
            children: [
              _buildSearchBar(provider),
              if (provider.notice != null)
                _NoticeBanner(notice: provider.notice!),
              Expanded(
                child: snippets.isEmpty
                    ? _buildEmptyState(provider)
                    : _buildSnippetList(provider, snippets),
              ),
              _buildFooter(snippets.length),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(SnippetProvider provider) {
    return Container(
      key: const Key('search-bar-container'),
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.hairlineOf(context), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: AppTheme.inkFaintOf(context)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _inputFocusNode,
              autofocus: true,
              style: TextStyle(fontSize: 16, color: AppTheme.inkOf(context)),
              decoration: const InputDecoration(
                hintText: '搜索名称、内容、标签，支持拼音',
                hintStyle:
                    TextStyle(fontSize: 16, color: AppTheme.inkFaint),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                provider.setSearchQuery(value);
                setState(() => _selectedIndex = 0);
              },
              onSubmitted: (_) => _pasteSelected(provider),
            ),
          ),
          const SizedBox(width: 12),
          KeyCaps(_hotkey.parts),
        ],
      ),
    );
  }

  Widget _buildSnippetList(SnippetProvider provider, List<Snippet> snippets) {
    return Container(
      key: const Key('snippet-list-container'),
      color: AppTheme.surfaceOf(context),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: snippets.length,
        itemBuilder: (context, index) {
          final snippet = snippets[index];
          return _SnippetRow(
            snippet: snippet,
            frequency: provider.statsFor(snippet.id).frequency,
            shortcutNumber: index < 9 ? index + 1 : null,
            isSelected: index == _selectedIndex,
            isPinned: provider.isPinned(snippet.id),
            highlight: provider.searchText,
            // 收敛到 _pasteAt：占位符填表与终端多行护栏对鼠标点击同样生效
            onTap: () => _pasteAt(provider, index),
            onHover: () => setState(() => _selectedIndex = index),
            onTogglePin: () => provider.togglePin(snippet.id),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(SnippetProvider provider) {
    if (provider.isLoading) {
      return Container(
        color: AppTheme.surface,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final isLibraryEmpty =
        provider.searchQuery.isEmpty && provider.snippets.isEmpty;

    return Container(
      color: AppTheme.surface,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isLibraryEmpty ? Icons.inbox_outlined : Icons.search_off,
            size: 40,
            color: AppTheme.inkFaint,
          ),
          const SizedBox(height: 12),
          Text(
            isLibraryEmpty ? '片段库还是空的' : '没有匹配的片段',
            style: const TextStyle(fontSize: 14, color: AppTheme.inkSecondary),
          ),
          const SizedBox(height: 6),
          if (isLibraryEmpty)
            Text(
              '点击右下角设置添加第一条片段，之后按快捷键随时呼出',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.inkFaint),
            )
          else
            Text(
              '换个关键词试试，名称、描述、标签、拼音都能搜',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.inkFaint),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: const BoxDecoration(
        color: AppTheme.canvas,
        border: Border(
          top: BorderSide(color: AppTheme.hairline, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const KeyCaps(['↑', '↓'], fontSize: 10),
          const SizedBox(width: 4),
          const _FooterLabel('选择'),
          const SizedBox(width: 14),
          const KeyCaps(['Enter'], fontSize: 10),
          const SizedBox(width: 4),
          const _FooterLabel('粘贴'),
          const SizedBox(width: 14),
          const KeyCaps(['Esc'], fontSize: 10),
          const SizedBox(width: 4),
          const _FooterLabel('隐藏'),
          const Spacer(),
          const SyncIndicator(),
          const SizedBox(width: 12),
          _FooterLabel(count > 0 ? '$count 条片段' : ''),
        ],
      ),
    );
  }
}

class _FooterLabel extends StatelessWidget {
  final String text;
  const _FooterLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, color: AppTheme.inkSecondary),
    );
  }
}

/// 列表行：名称 + 标签 + 使用次数，下方一行等宽内容预览
class _SnippetRow extends StatelessWidget {
  final Snippet snippet;
  final int frequency;

  /// Alt+N 直达序号（1..9）；列表第 10 项起为 null 不显示角标
  final int? shortcutNumber;
  final bool isSelected;
  final bool isPinned;

  /// 名称中要高亮的自由关键词（去掉 #tag）
  final String highlight;
  final VoidCallback onTap;
  final VoidCallback onHover;
  final VoidCallback onTogglePin;

  const _SnippetRow({
    required this.snippet,
    required this.frequency,
    this.shortcutNumber,
    required this.isSelected,
    required this.isPinned,
    required this.highlight,
    required this.onTap,
    required this.onHover,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final preview = snippet.content.replaceAll('\n', ' ⏎ ');

    return MouseRegion(
      onEnter: (_) => onHover(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentTint : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected ? AppTheme.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(18, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (shortcutNumber != null) ...[
                    Container(
                      key: Key('shortcut-badge-$shortcutNumber'),
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.accent : AppTheme.canvas,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                            color: isSelected
                                ? AppTheme.accent
                                : AppTheme.hairline,
                            width: 0.5),
                      ),
                      child: Text(
                        '$shortcutNumber',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color:
                              isSelected ? Colors.white : AppTheme.inkFaint,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: _HighlightedName(
                      name: snippet.name,
                      query: highlight,
                    ),
                  ),
                  ...snippet.tags.take(2).map(
                        (tag) => Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _TagChip(label: tag),
                        ),
                      ),
                  if (frequency > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '×$frequency',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.inkFaint,
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  InkWell(
                    key: Key('pin-toggle-${snippet.id}'),
                    onTap: onTogglePin,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(
                        isPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        size: 13,
                        color: isPinned
                            ? AppTheme.accent
                            : AppTheme.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.mono(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 片段名称，命中的自由关键词字符高亮
class _HighlightedName extends StatelessWidget {
  final String name;
  final String query;

  const _HighlightedName({required this.name, required this.query});

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppTheme.ink,
    );
    final ranges = highlightRanges(name, query);
    if (ranges.isEmpty) {
      return Text(name,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
    }
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final (start, end) in ranges) {
      if (start > cursor) {
        spans.add(TextSpan(text: name.substring(cursor, start)));
      }
      spans.add(TextSpan(
        text: name.substring(start, end),
        style: const TextStyle(
          color: AppTheme.accent,
          fontWeight: FontWeight.w700,
          backgroundColor: AppTheme.accentTint,
        ),
      ));
      cursor = end;
    }
    if (cursor < name.length) {
      spans.add(TextSpan(text: name.substring(cursor)));
    }
    return RichText(
      key: const Key('highlighted-name'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: base, children: spans),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.hairline, width: 0.5),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10.5, color: AppTheme.inkSecondary),
      ),
    );
  }
}

/// 占位符填表对话框：自管理 controller，退出动画期间不会用到已释放的控制器
class _PlaceholderForm extends StatefulWidget {
  final String snippetName;
  final List<String> placeholders;
  final Map<String, String> defaults;

  const _PlaceholderForm({
    required this.snippetName,
    required this.placeholders,
    this.defaults = const {},
  });

  @override
  State<_PlaceholderForm> createState() => _PlaceholderFormState();
}

class _PlaceholderFormState extends State<_PlaceholderForm> {
  late final Map<String, TextEditingController> _controllers = {
    for (final name in widget.placeholders)
      name: TextEditingController(text: widget.defaults[name] ?? ''),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _collect() =>
      _controllers.map((name, c) => MapEntry(name, c.text));

  @override
  Widget build(BuildContext context) {
    final placeholders = widget.placeholders;
    return AlertDialog(
      key: const Key('placeholder-form'),
      title: Text('填写「${widget.snippetName}」的占位符'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < placeholders.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  key: Key('placeholder-field-${placeholders[i]}'),
                  controller: _controllers[placeholders[i]],
                  autofocus: i == 0,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    labelText: placeholders[i],
                    isDense: true,
                  ),
                  onSubmitted: i == placeholders.length - 1
                      ? (_) => Navigator.pop(context, _collect())
                      : null,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          key: const Key('placeholder-submit'),
          onPressed: () => Navigator.pop(context, _collect()),
          child: const Text('粘贴'),
        ),
      ],
    );
  }
}

/// 粘贴降级提示（如目标窗口已关闭、内容仅复制到剪贴板）
class _NoticeBanner extends StatelessWidget {
  final String notice;
  const _NoticeBanner({required this.notice});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      color: const Color(0xFFFFF8E1),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: Color(0xFFBF8F00)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              notice,
              style: const TextStyle(fontSize: 12, color: Color(0xFFBF8F00)),
            ),
          ),
        ],
      ),
    );
  }
}
