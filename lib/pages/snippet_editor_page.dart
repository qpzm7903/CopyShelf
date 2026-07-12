import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/snippet.dart';
import '../providers/snippet_provider.dart';
import '../theme/app_theme.dart';

/// 片段编辑页（全页）
///
/// 内容区占满剩余高度的等宽编辑器——命令、代码、长 prompt 都放得下。
/// [snippet] 为 null 时是新建。
class SnippetEditorPage extends StatefulWidget {
  final Snippet? snippet;

  const SnippetEditorPage({super.key, this.snippet});

  @override
  State<SnippetEditorPage> createState() => _SnippetEditorPageState();
}

class _SnippetEditorPageState extends State<SnippetEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _contentController;
  late final TextEditingController _descController;
  final _tagController = TextEditingController();
  late List<String> _tags;
  bool _isSaving = false;
  late bool _isTemplate;

  bool get _isEditing => widget.snippet != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.snippet?.name ?? '');
    _contentController =
        TextEditingController(text: widget.snippet?.content ?? '');
    _descController =
        TextEditingController(text: widget.snippet?.description ?? '');
    _tags = List.from(widget.snippet?.tags ?? const []);
    _isTemplate = widget.snippet?.isTemplate ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _descController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags = [..._tags, tag];
        _tagController.clear();
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final content = _contentController.text;

    if (name.isEmpty || content.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名称和内容不能为空')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<SnippetProvider>();
    if (_isEditing) {
      await provider.updateSnippet(
        id: widget.snippet!.id,
        name: name,
        content: content,
        description: _descController.text.trim(),
        tags: _tags,
        isTemplate: _isTemplate,
      );
    } else {
      await provider.addSnippet(
        name: name,
        content: content,
        description: _descController.text.trim(),
        tags: _tags,
        isTemplate: _isTemplate,
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// 打开历史版本对话框；选中一条把内容填回编辑器（不立即保存，用户可再改）
  Future<void> _openHistory() async {
    final provider = context.read<SnippetProvider>();
    final id = widget.snippet!.id;
    final selected = await showDialog<SnippetVersion>(
      context: context,
      builder: (ctx) => _HistoryDialog(
        loader: () => provider.snippetHistory(id),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _nameController.text = selected.snippet.name;
      _contentController.text = selected.snippet.content;
      _descController.text = selected.snippet.description;
      _tags = List.from(selected.snippet.tags);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已载入历史版本，点「保存」确认恢复')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEditing ? '编辑片段' : '添加片段'),
        actions: [
          if (_isEditing)
            IconButton(
              key: const Key('snippet-history-button'),
              icon: const Icon(Icons.history, size: 20),
              tooltip: '历史版本',
              onPressed: _openHistory,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: Text(_isSaving ? '保存中…' : '保存'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _nameController,
                    autofocus: !_isEditing,
                    decoration: const InputDecoration(
                      labelText: '名称 *',
                      hintText: '如 git amend、回复话术-催发货',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: '描述（可选，参与搜索）',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTagEditor(),
            const SizedBox(height: 8),
            _buildTemplateToggle(),
            const SizedBox(height: 16),
            const Text('内容 *',
                style:
                    TextStyle(fontSize: 13, color: AppTheme.inkSecondary)),
            const SizedBox(height: 6),
            Expanded(
              child: TextField(
                controller: _contentController,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: AppTheme.mono(fontSize: 13, color: AppTheme.ink),
                decoration: const InputDecoration(
                  hintText: '命令、代码片段、prompt……支持多行，粘贴时原样输出',
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateToggle() {
    return InkWell(
      key: const Key('template-toggle'),
      onTap: () => setState(() => _isTemplate = !_isTemplate),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _isTemplate,
                onChanged: (v) => setState(() => _isTemplate = v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '作为模板：粘贴前把 {占位符} 填表、内置变量（date/time/clipboard）求值',
                style: TextStyle(fontSize: 12, color: AppTheme.inkSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagEditor() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ..._tags.map(
          (tag) => Chip(
            label: Text(tag, style: const TextStyle(fontSize: 12)),
            deleteIcon: const Icon(Icons.close, size: 13),
            onDeleted: () => setState(() {
              _tags = _tags.where((t) => t != tag).toList();
            }),
            backgroundColor: AppTheme.canvas,
            side: const BorderSide(color: AppTheme.hairline, width: 0.5),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        SizedBox(
          width: 140,
          child: TextField(
            controller: _tagController,
            decoration: const InputDecoration(
              hintText: '标签，回车添加',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            style: const TextStyle(fontSize: 12.5),
            onSubmitted: (_) => _addTag(),
          ),
        ),
      ],
    );
  }
}

/// 片段历史版本列表对话框：异步加载 git 历史，选中一条返回给编辑器
class _HistoryDialog extends StatelessWidget {
  final Future<List<SnippetVersion>> Function() loader;

  const _HistoryDialog({required this.loader});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('snippet-history-dialog'),
      title: const Text('历史版本'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: FutureBuilder<List<SnippetVersion>>(
          future: loader(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final versions = snap.data ?? const [];
            if (versions.isEmpty) {
              return const Center(
                child: Text('暂无历史版本（需已配置 Git 且有多次提交）',
                    style: TextStyle(fontSize: 13, color: AppTheme.inkFaint)),
              );
            }
            return ListView.separated(
              itemCount: versions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final v = versions[i];
                final preview = v.snippet.content.replaceAll('\n', ' ⏎ ');
                return ListTile(
                  key: Key('history-item-$i'),
                  dense: true,
                  title: Text(v.snippet.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.mono(fontSize: 11)),
                  trailing: Text(v.commit.hash,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.inkFaint)),
                  onTap: () => Navigator.pop(context, v),
                );
              },
            );
          },
        ),
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
