import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/snippet_provider.dart';
import '../services/importers/importer.dart';
import '../theme/app_theme.dart';

/// 导入页：从某个来源解析候选 → 用户勾选 → 批量入库（重复内容已过滤）。
class ImportPage extends StatefulWidget {
  final Importer importer;

  const ImportPage({super.key, required this.importer});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  List<ImportCandidate>? _candidates;
  final Set<int> _selected = {};
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<SnippetProvider>();
    final raw = await widget.importer.discover();
    final deduped = dedupeCandidates(raw, provider.existingContents);
    if (!mounted) return;
    setState(() {
      _candidates = deduped;
      _selected
        ..clear()
        ..addAll(List.generate(deduped.length, (i) => i)); // 默认全选
      _loading = false;
    });
  }

  Future<void> _import() async {
    final candidates = _candidates;
    if (candidates == null) return;
    setState(() => _importing = true);
    final provider = context.read<SnippetProvider>();
    final incoming = [
      for (final i in _selected)
        provider.buildSnippet(
          name: candidates[i].name,
          content: candidateToSnippetContent(candidates[i]),
          isTemplate: candidates[i].isTemplate,
        ),
    ];
    final count = await provider.importSnippets(incoming);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导入 $count 条片段')),
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
        title: Text('导入 · ${widget.importer.displayName}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              key: const Key('import-confirm'),
              onPressed:
                  (_importing || _selected.isEmpty) ? null : _import,
              child: Text(_importing ? '导入中…' : '导入 ${_selected.length} 条'),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final candidates = _candidates ?? const [];
    if (candidates.isEmpty) {
      return const Center(
        child: Text('没有可导入的新条目（来源为空或都已存在）',
            key: Key('import-empty'),
            style: TextStyle(fontSize: 13, color: AppTheme.inkFaint)),
      );
    }
    return ListView.separated(
      itemCount: candidates.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = candidates[i];
        return CheckboxListTile(
          key: Key('import-item-$i'),
          value: _selected.contains(i),
          onChanged: (v) => setState(() {
            if (v ?? false) {
              _selected.add(i);
            } else {
              _selected.remove(i);
            }
          }),
          dense: true,
          title: Text(c.name,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            c.content.replaceAll('\n', ' ⏎ '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.mono(fontSize: 11),
          ),
          secondary: c.frequency > 1
              ? Text('×${c.frequency}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.inkFaint))
              : null,
        );
      },
    );
  }
}
