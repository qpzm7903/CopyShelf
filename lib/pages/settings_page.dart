import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/snippet.dart';
import '../providers/snippet_provider.dart';
import '../services/storage_service.dart';
import '../services/git_service.dart';
import '../services/hotkey_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/hotkey.dart';
import '../widgets/hotkey_recorder.dart';
import 'snippet_editor_page.dart';

/// 设置页面
///
/// 三个分区：片段库（增删改）、快捷键（录制修改）、数据与同步。
class SettingsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const SettingsPage({super.key, this.onBack});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _gitRemoteController = TextEditingController();
  final _dataDirController = TextEditingController();

  Hotkey _hotkey = Hotkey.defaultHotkey;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _gitRemoteController.dispose();
    _dataDirController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final storage = await StorageService.instance;
    final dataDir = await storage.getDataDirPath();
    if (!mounted) return;
    setState(() {
      _dataDirController.text = dataDir;
      _gitRemoteController.text = storage.gitRemote ?? '';
      _hotkey = Hotkey.parse(storage.hotkey) ?? Hotkey.defaultHotkey;
    });
  }

  // ---------- 快捷键 ----------

  Future<void> _changeHotkey(Hotkey hotkey) async {
    final storage = await StorageService.instance;
    storage.hotkey = hotkey.format();

    var applied = true;
    if (Platform.isWindows) {
      applied = await HotkeyService.updateHotkey(
        mod: hotkey.modifiers,
        vk: hotkey.virtualKey!,
      );
    }

    if (!mounted) return;
    setState(() => _hotkey = hotkey);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(applied
            ? '快捷键已更新为 ${hotkey.format()}'
            : '快捷键已保存为 ${hotkey.format()}，重启后生效'),
      ),
    );
  }

  // ---------- 数据与同步 ----------

  Future<void> _saveDataDir() async {
    final storage = await StorageService.instance;
    storage.dataDir = _dataDirController.text.trim();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('数据目录已更新，重启后生效')),
    );
  }

  Future<void> _saveGitRemote() async {
    final storage = await StorageService.instance;
    final remote = _gitRemoteController.text.trim();
    storage.gitRemote = remote.isEmpty ? null : remote;

    if (remote.isNotEmpty) {
      final dataDir = await storage.getDataDirPath();
      final git = await GitService.instance;
      await git.setRemote(dataDir, remote);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Git 远程地址已保存')),
    );
  }

  Future<void> _syncNow() async {
    final provider = context.read<SnippetProvider>();
    setState(() => _isSyncing = true);

    final success = await provider.syncNow();

    if (!mounted) return;
    setState(() => _isSyncing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('同步完成，片段列表已刷新')),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('同步失败'),
          content: Text(provider.error ?? '未知错误'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
  }

  // ---------- 片段库 ----------

  void _openEditor([Snippet? snippet]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SnippetEditorPage(snippet: snippet),
      ),
    );
  }

  Future<void> _confirmDelete(Snippet snippet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除片段'),
        content: Text('确定删除「${snippet.name}」吗？此操作会同步到其他设备。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<SnippetProvider>().deleteSnippet(snippet.id);
    }
  }

  // ---------- 布局 ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: widget.onBack,
        ),
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          _buildSectionHeader(
            '片段库',
            trailing: TextButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('新建片段'),
            ),
          ),
          _buildSnippetLibrary(),
          const SizedBox(height: 28),
          _buildSectionHeader('快捷键'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '在任意应用中按下此组合呼出搜索框',
                    style: TextStyle(
                        fontSize: 12.5, color: AppTheme.inkSecondary),
                  ),
                  const SizedBox(height: 10),
                  HotkeyRecorder(value: _hotkey, onChanged: _changeHotkey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          _buildSectionHeader('数据与同步'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldRow(
                    label: '数据目录',
                    hint: '如 C:\\Users\\你\\.copyshelf',
                    controller: _dataDirController,
                    onSave: _saveDataDir,
                    helper:
                        '片段存储在此目录的 ${AppConstants.snippetsFileName}，修改后重启生效',
                  ),
                  const SizedBox(height: 16),
                  _buildFieldRow(
                    label: 'Git 远程仓库',
                    hint: '如 https://github.com/user/repo.git',
                    controller: _gitRemoteController,
                    onSave: _saveGitRemote,
                    helper: '增删改片段自动 commit & push，启动时自动 pull',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isSyncing ? null : _syncNow,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, size: 15),
                    label: Text(_isSyncing ? '同步中…' : '立即同步',
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'CopyShelf v${AppConstants.version}',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.inkFaint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.inkSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildSnippetLibrary() {
    return Consumer<SnippetProvider>(
      builder: (context, provider, _) {
        final snippets = provider.snippets;
        if (snippets.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Center(
                child: Text(
                  '还没有片段，点击右上角「新建片段」',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.inkFaint),
                ),
              ),
            ),
          );
        }
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < snippets.length; i++) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                _buildSnippetRow(snippets[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSnippetRow(Snippet snippet) {
    final preview = snippet.content.replaceAll('\n', ' ⏎ ');
    return InkWell(
      onTap: () => _openEditor(snippet),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snippet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.mono(fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 16, color: AppTheme.inkSecondary),
              onPressed: () => _openEditor(snippet),
              tooltip: '编辑',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 16, color: Color(0xFFD05C5C)),
              onPressed: () => _confirmDelete(snippet),
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow({
    required String label,
    required String hint,
    required TextEditingController controller,
    required VoidCallback onSave,
    required String helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12.5, color: AppTheme.inkSecondary)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(hintText: hint, isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onSave,
              child: const Text('保存', style: TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(helper,
            style:
                const TextStyle(fontSize: 11.5, color: AppTheme.inkFaint)),
      ],
    );
  }
}
