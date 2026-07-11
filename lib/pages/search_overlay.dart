import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/snippet.dart';
import '../providers/snippet_provider.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/hotkey.dart';
import '../widgets/key_caps.dart';

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

  void _pasteAt(SnippetProvider provider, int index) {
    final snippets = provider.filteredSnippets;
    if (index < 0 || index >= snippets.length) return;
    provider.useSnippet(snippets[index].id);
    provider.hideSearch();
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
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.hairline, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: AppTheme.inkFaint),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _inputFocusNode,
              autofocus: true,
              style: const TextStyle(fontSize: 16, color: AppTheme.ink),
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
      color: AppTheme.surface,
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
            onTap: () {
              provider.useSnippet(snippet.id);
              provider.hideSearch();
            },
            onHover: () => setState(() => _selectedIndex = index),
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
  final VoidCallback onTap;
  final VoidCallback onHover;

  const _SnippetRow({
    required this.snippet,
    required this.frequency,
    this.shortcutNumber,
    required this.isSelected,
    required this.onTap,
    required this.onHover,
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
                    child: Text(
                      snippet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.ink,
                      ),
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
