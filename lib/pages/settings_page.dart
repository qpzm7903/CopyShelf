import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/snippet.dart';
import '../providers/snippet_provider.dart';
import '../providers/theme_controller.dart';
import '../services/storage_service.dart';
import '../services/git_service.dart';
import '../services/autostart_service.dart';
import '../services/hotkey_messages.dart';
import '../services/hotkey_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../services/importers/espanso_importer.dart';
import '../services/importers/importer.dart';
import '../services/importers/powershell_history_importer.dart';
import '../services/importers/vscode_snippets_importer.dart';
import '../services/update_checker.dart';
import '../utils/hotkey.dart';
import '../widgets/hotkey_recorder.dart';
import 'import_page.dart';
import 'snippet_editor_page.dart';

typedef HotkeyUpdater = Future<HotkeyRegistration> Function({
  required int mod,
  required int vk,
});

/// 设置页面
///
/// 三个分区：片段库（增删改）、快捷键（录制修改）、数据与同步。
class SettingsPage extends StatefulWidget {
  final VoidCallback? onBack;
  final HotkeyUpdater? hotkeyUpdater;
  final bool? isWindowsOverride;

  const SettingsPage({
    super.key,
    this.onBack,
    this.hotkeyUpdater,
    this.isWindowsOverride,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _gitRemoteController = TextEditingController();
  final _dataDirController = TextEditingController();

  Hotkey _hotkey = Hotkey.defaultHotkey;
  bool _isSyncing = false;
  bool _isAutostartEnabled = false;

  /// 仅 Windows 上创建；其他平台不展示自启开关
  final AutostartService? _autostart =
      Platform.isWindows ? AutostartService(WindowsRunKeyStore()) : null;

  bool get _isWindows => widget.isWindowsOverride ?? Platform.isWindows;

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
      _isAutostartEnabled = _readAutostartSafely();
    });
  }

  // ---------- 开机自启 ----------

  /// 读取自启状态，注册表异常一律降级为 false，绝不让设置页加载失败
  bool _readAutostartSafely() {
    try {
      return _autostart?.isEnabled ?? false;
    } catch (_) {
      return false;
    }
  }

  void _toggleAutostart(bool enabled) {
    final autostart = _autostart;
    if (autostart == null) return;
    try {
      if (enabled) {
        autostart.enable();
      } else {
        autostart.disable();
      }
      setState(() => _isAutostartEnabled = enabled);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('开机自启设置失败: $e')),
      );
    }
  }

  // ---------- 快捷键 ----------

  Future<HotkeyRegistration> _tryUpdateHotkey(
      HotkeyUpdater updater, Hotkey hotkey) async {
    try {
      return await updater(
        mod: hotkey.modifiers,
        vk: hotkey.virtualKey!,
      );
    } catch (e) {
      return HotkeyRegistration.failure('系统异常：$e');
    }
  }

  Future<void> _changeHotkey(Hotkey hotkey) async {
    if (hotkey.format() == _hotkey.format()) return;
    final storage = await StorageService.instance;
    final previous = _hotkey;

    String message = '快捷键已保存为 ${hotkey.format()}，重启后生效';
    if (_isWindows) {
      final updater = widget.hotkeyUpdater ?? HotkeyService.updateHotkey;
      final result = await _tryUpdateHotkey(updater, hotkey);
      if (!mounted) return;
      final provider = context.read<SnippetProvider>();
      if (result.ok) {
        storage.hotkey = hotkey.format();
        provider.setHotkeyError(null);
        message = '快捷键已更新为 ${hotkey.format()}';
      } else {
        final rollback = await _tryUpdateHotkey(updater, previous);
        if (!mounted) return;
        final recovery = rollback.ok
            ? '已恢复 ${previous.format()}'
            : '旧快捷键恢复也失败：${rollback.reason}；重启后仍使用 ${previous.format()}';
        provider.setHotkeyError(
          '快捷键 ${hotkey.format()} 注册失败：${result.reason}。$recovery。',
        );
        message = '快捷键 ${hotkey.format()} 注册失败，$recovery';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        return;
      }
    } else {
      storage.hotkey = hotkey.format();
    }

    if (!mounted) return;
    setState(() => _hotkey = hotkey);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

    String message = 'Git 远程地址已保存';
    if (remote.isNotEmpty) {
      final dataDir = await storage.getDataDirPath();
      final git = await GitService.instance;
      // 首次同步引导：scaffold 设备自动以远端为准（issue 07）
      final notice = await git.configureRemote(dataDir, remote);
      if (notice != null) {
        message = notice;
      } else {
        // 可能已采用远端数据，刷新片段列表
        if (mounted) {
          await context.read<SnippetProvider>().loadSnippets();
        }
        message = 'Git 远程地址已保存，片段列表已同步';
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

  /// 选择导入来源。VS Code 需要用户提供 snippets 文件路径。
  Future<void> _chooseImportSource() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (Platform.isWindows)
              ListTile(
                key: const Key('import-source-powershell'),
                leading: const Icon(Icons.terminal, size: 20),
                title: const Text('PowerShell 历史'),
                subtitle: const Text('从 PSReadLine 历史导入常用命令'),
                onTap: () => Navigator.pop(ctx, 'powershell'),
              ),
            ListTile(
              key: const Key('import-source-vscode'),
              leading: const Icon(Icons.code, size: 20),
              title: const Text('VS Code 片段'),
              subtitle: const Text('从 snippets JSON 文件导入'),
              onTap: () => Navigator.pop(ctx, 'vscode'),
            ),
            ListTile(
              key: const Key('import-source-espanso'),
              leading: const Icon(Icons.keyboard, size: 20),
              title: const Text('Espanso'),
              subtitle: const Text('从 Espanso match YAML 文件导入'),
              onTap: () => Navigator.pop(ctx, 'espanso'),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    if (source == 'powershell') {
      _pushImport(PowerShellHistoryImporter());
    } else if (source == 'vscode') {
      final path = await _askFilePath('VS Code snippets 文件',
          r'如 C:\Users\你\AppData\Roaming\Code\User\snippets\x.code-snippets');
      if (path != null) _pushImport(VsCodeSnippetsImporter(filePath: path));
    } else if (source == 'espanso') {
      final path = await _askFilePath('Espanso match 文件',
          r'如 C:\Users\你\AppData\Roaming\espanso\match\base.yml');
      if (path != null) _pushImport(EspansoImporter(filePath: path));
    }
  }

  /// 询问文件路径的通用对话框；取消或空返回 null。
  Future<String?> _askFilePath(String title, String hint) async {
    final controller = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint, isDense: true),
          style: const TextStyle(fontSize: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('打开'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (path == null || path.isEmpty) return null;
    return path;
  }

  void _pushImport(Importer importer) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ImportPage(importer: importer)),
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  key: const Key('import-button'),
                  onPressed: _chooseImportSource,
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('导入'),
                ),
                TextButton.icon(
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('新建片段'),
                ),
              ],
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
                  _buildHotkeyErrorBanner(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          _buildSectionHeader('常规'),
          Card(
            child: Column(
              children: [
                if (_autostart != null)
                  SwitchListTile(
                    key: const Key('autostart-switch'),
                    title:
                        const Text('开机自启', style: TextStyle(fontSize: 13.5)),
                    subtitle: const Text(
                      '登录 Windows 后自动在后台启动 CopyShelf',
                      style:
                          TextStyle(fontSize: 11.5, color: AppTheme.inkFaint),
                    ),
                    value: _isAutostartEnabled,
                    onChanged: _toggleAutostart,
                    dense: true,
                  ),
                if (_autostart != null) const Divider(height: 1),
                _buildThemeSelector(),
              ],
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
                  _buildSyncErrorPanel(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: TextButton(
              key: const Key('about-button'),
              onPressed: _showAbout,
              child: Text(
                'CopyShelf v${AppConstants.version} · 关于',
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.inkFaint),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAbout() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _AboutDialog(),
    );
  }

  /// 主题三态选择（跟随系统 / 亮 / 暗）
  Widget _buildThemeSelector() {
    return Consumer<ThemeController>(
      builder: (context, controller, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            const Expanded(
              child: Text('主题', style: TextStyle(fontSize: 13.5)),
            ),
            SegmentedButton<ThemeMode>(
              key: const Key('theme-selector'),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('跟随', style: TextStyle(fontSize: 12))),
                ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('亮', style: TextStyle(fontSize: 12))),
                ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('暗', style: TextStyle(fontSize: 12))),
              ],
              selected: {controller.mode},
              onSelectionChanged: (s) => controller.setMode(s.first),
            ),
          ],
        ),
      ),
    );
  }

  /// 最近一次同步失败的详情面板；无错误时不占空间
  Widget _buildSyncErrorPanel() {
    return Consumer<SnippetProvider>(
      builder: (context, provider, _) {
        final status = provider.syncStatus;
        if (!status.hasError) return const SizedBox.shrink();
        return Container(
          key: const Key('sync-error-panel'),
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFDECEA),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE8B4B0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline,
                  size: 16, color: Color(0xFFB3352C)),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  status.message ?? '同步失败',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFB3352C)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 热键注册失败时的错误横幅；注册正常时不占空间
  Widget _buildHotkeyErrorBanner() {
    return Consumer<SnippetProvider>(
      builder: (context, provider, _) {
        final error = provider.hotkeyError;
        if (error == null) return const SizedBox.shrink();
        return Container(
          key: const Key('hotkey-error-banner'),
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFDECEA),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE8B4B0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 16, color: Color(0xFFB3352C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error,
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFFB3352C)),
                ),
              ),
            ],
          ),
        );
      },
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

/// 关于对话框：版本号、开源地址、可用的「检查更新」按钮
class _AboutDialog extends StatefulWidget {
  const _AboutDialog();

  @override
  State<_AboutDialog> createState() => _AboutDialogState();
}

class _AboutDialogState extends State<_AboutDialog> {
  String? _status;
  bool _checking = false;

  Future<void> _checkUpdate() async {
    setState(() {
      _checking = true;
      _status = null;
    });
    final result = await UpdateChecker().check(AppConstants.version);
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (result.error != null) {
        _status = result.error;
      } else if (result.hasUpdate) {
        _status = '发现新版本 ${result.latestVersion}，可到 GitHub Releases 下载';
      } else {
        _status = '已是最新版本';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('about-dialog'),
      title: const Text('关于 CopyShelf'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('版本 v${AppConstants.version}',
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          const SelectableText(
            'https://github.com/qpzm7903/CopyShelf',
            style: TextStyle(fontSize: 12, color: AppTheme.inkSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                key: const Key('check-update-button'),
                onPressed: _checking ? null : _checkUpdate,
                icon: _checking
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.system_update_alt, size: 15),
                label: Text(_checking ? '检查中…' : '检查更新',
                    style: const TextStyle(fontSize: 12.5)),
              ),
              const SizedBox(width: 10),
              if (_status != null)
                Expanded(
                  child: Text(_status!,
                      key: const Key('update-status'),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.inkSecondary)),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
