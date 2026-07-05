import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/command_provider.dart';

/// 搜索主界面（类 Spotlight 搜索框）
///
/// 顶部是搜索输入框，下方是指令列表。
/// 使用键盘上下键选择，回车粘贴。
class SearchOverlay extends StatefulWidget {
  const SearchOverlay({super.key});

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  /// 处理键盘事件
  KeyEventResult _handleKeyEvent(KeyEvent event, CommandProvider provider) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % provider.filteredCommands.length;
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = _selectedIndex - 1;
        if (_selectedIndex < 0) {
          _selectedIndex = provider.filteredCommands.length - 1;
        }
      });
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

  @override
  Widget build(BuildContext context) {
    return Consumer<CommandProvider>(
      builder: (context, provider, _) {
        final commands = provider.filteredCommands;

        return Focus(
          autofocus: true,
          focusNode: _focusNode,
          onKeyEvent: (node, event) => _handleKeyEvent(event, provider),
          child: Column(
            children: [
              _buildSearchBar(context, provider),
              Expanded(
                child: commands.isEmpty
                    ? _buildEmptyState(provider)
                    : _buildCommandList(context, provider, commands),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context, CommandProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
        ),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '搜索指令…',
          prefixIcon: Icon(Icons.search, size: 20),
          isDense: true,
        ),
        onChanged: (value) {
          provider.setSearchQuery(value);
          setState(() {
            _selectedIndex = 0;
          });
        },
        onSubmitted: (_) => _pasteSelected(provider),
      ),
    );
  }

  Widget _buildCommandList(
    BuildContext context,
    CommandProvider provider,
    List<dynamic> commands,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: commands.length,
      separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final cmd = commands[index];
        final isSelected = index == _selectedIndex;

        return ListTile(
          selected: isSelected,
          selectedTileColor: const Color(0xFFF0F0FF),
          leading: const Icon(Icons.code, size: 20, color: Color(0xFF6366F1)),
          title: Text(
            cmd.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: cmd.description.isNotEmpty
              ? Text(
                  cmd.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cmd.tags.isNotEmpty)
                ...cmd.tags.take(2).map(
                      (tag) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _TagChip(label: tag),
                      ),
                    ),
              const SizedBox(width: 8),
              Text(
                '${cmd.frequency}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFCCCCCC),
                ),
              ),
            ],
          ),
          onTap: () {
            provider.useCommand(cmd.id);
            provider.hideSearch();
          },
        );
      },
    );
  }

  Widget _buildEmptyState(CommandProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.searchQuery.isEmpty && provider.commands.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              '还没有指令',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
            const SizedBox(height: 4),
            Text(
              '在设置中添加你的第一条指令',
              style: TextStyle(fontSize: 12, color: Colors.grey[350]),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Text(
        '未找到匹配的指令',
        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
      ),
    );
  }

  void _pasteSelected(CommandProvider provider) {
    if (provider.filteredCommands.isEmpty) return;
    final cmd = provider.filteredCommands[_selectedIndex];
    provider.useCommand(cmd.id);
    provider.hideSearch();
  }
}

/// 标签小芯片
class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0FF),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE0E0FF), width: 0.5),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Color(0xFF6366F1)),
      ),
    );
  }
}
