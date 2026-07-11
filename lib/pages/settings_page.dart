import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/snippet_provider.dart';
import '../services/storage_service.dart';
import '../services/git_service.dart';
import '../utils/constants.dart';

/// 设置页面
///
/// 管理数据目录、Git 远程地址、快捷键、片段 CRUD。
class SettingsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const SettingsPage({super.key, this.onBack});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameController = TextEditingController();
  final _contentController = TextEditingController();
  final _descController = TextEditingController();
  final _tagController = TextEditingController();
  final _gitRemoteController = TextEditingController();
  final _dataDirController = TextEditingController();

  bool _isEditing = false;
  String? _editingId;
  List<String> _tempTags = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _descController.dispose();
    _tagController.dispose();
    _gitRemoteController.dispose();
    _dataDirController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final storage = await StorageService.instance;
    final dataDir = await storage.getDataDirPath();
    _dataDirController.text = dataDir;
    _gitRemoteController.text = storage.gitRemote ?? '';
  }

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

  void _startAdd() {
    setState(() {
      _isEditing = true;
      _editingId = null;
      _nameController.clear();
      _contentController.clear();
      _descController.clear();
      _tagController.clear();
      _tempTags = [];
    });
  }

  void _startEdit(String id, String name, String content, String desc, List<String> tags) {
    setState(() {
      _isEditing = true;
      _editingId = id;
      _nameController.text = name;
      _contentController.text = content;
      _descController.text = desc;
      _tempTags = List.from(tags);
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _editingId = null;
    });
  }

  Future<void> _saveSnippet() async {
    final provider = context.read<SnippetProvider>();
    final name = _nameController.text.trim();
    final content = _contentController.text.trim();

    if (name.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名称和内容不能为空')),
      );
      return;
    }

    if (_editingId != null) {
      await provider.updateSnippet(
        id: _editingId!,
        name: name,
        content: content,
        description: _descController.text.trim(),
        tags: _tempTags,
      );
    } else {
      await provider.addSnippet(
        name: name,
        content: content,
        description: _descController.text.trim(),
        tags: _tempTags,
      );
    }

    _cancelEdit();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tempTags.contains(tag)) {
      setState(() {
        _tempTags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tempTags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('设置'),
        actions: [
          if (!_isEditing)
            TextButton.icon(
              onPressed: _startAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加片段'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- 片段编辑区 ----
          if (_isEditing) _buildSnippetEditor(),
          if (_isEditing) const SizedBox(height: 24),

          // ---- 片段列表 ----
          _buildSectionTitle('已有片段'),
          const SizedBox(height: 8),
          Consumer<SnippetProvider>(
            builder: (context, provider, _) {
              final snippets = provider.snippets;
              if (snippets.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        '还没有片段，点击右上角添加',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: snippets.map((snippet) => _buildSnippetCard(snippet)).toList(),
              );
            },
          ),

          const SizedBox(height: 32),

          // ---- 数据目录 ----
          _buildSectionTitle('数据目录'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _dataDirController,
                      decoration: const InputDecoration(
                        hintText: '如 C:\\Users\\你\\.copyshelf',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _saveDataDir,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '修改后需重启应用生效。片段数据存储在此目录的 snippets.json 中。',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),

          const SizedBox(height: 24),

          // ---- Git 远程地址 ----
          _buildSectionTitle('Git 远程仓库'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _gitRemoteController,
                      decoration: const InputDecoration(
                        hintText: '如 https://github.com/user/repo.git',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _saveGitRemote,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '设置后每次增删改片段自动 commit & push，启动时自动 pull。',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),

          const SizedBox(height: 32),

          // ---- 版本信息 ----
          Center(
            child: Text(
              'CopyShelf v${AppConstants.version}',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF999999),
      ),
    );
  }

  Widget _buildSnippetEditor() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editingId != null ? '编辑片段' : '添加片段',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '名称 *', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: '内容 *', isDense: true),
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: '描述（可选）', isDense: true),
            ),
            const SizedBox(height: 12),
            // 标签
            const Text('标签', style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ..._tempTags.map((t) => Chip(
                      label: Text(t, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => _removeTag(t),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    )),
                SizedBox(
                  width: 120,
                  height: 32,
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: '添加标签',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _cancelEdit,
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveSnippet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_editingId != null ? '保存' : '添加'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnippetCard(dynamic snippet) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        title: Text(snippet.name),
        subtitle: snippet.description.isNotEmpty
            ? Text(snippet.description, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _startEdit(
                snippet.id, snippet.name, snippet.content, snippet.description, snippet.tags,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: () => _confirmDelete(snippet.id, snippet.name),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除片段'),
        content: Text('确定删除 "$name" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      await context.read<SnippetProvider>().deleteSnippet(id);
    }
  }
}
