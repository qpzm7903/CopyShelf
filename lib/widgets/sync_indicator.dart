import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sync_status.dart';
import '../providers/snippet_provider.dart';
import '../theme/app_theme.dart';

/// 主窗常驻的 Git 同步状态指示（图标 + 文案）。
///
/// idle 不显示；syncing 转圈；ok 绿点 + 相对时间；error 红色可点开详情。
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SnippetProvider>(
      builder: (context, provider, _) {
        final status = provider.syncStatus;
        switch (status.state) {
          case SyncState.idle:
            return const SizedBox.shrink();
          case SyncState.syncing:
            return _row(
              key: 'sync-indicator-syncing',
              icon: const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
              label: '同步中…',
              color: AppTheme.inkSecondary,
            );
          case SyncState.ok:
            return _row(
              key: 'sync-indicator-ok',
              icon: const Icon(Icons.check_circle,
                  size: 11, color: Color(0xFF3E9E58)),
              label: '已同步${_relativeTime(status.lastSuccessAt)}',
              color: AppTheme.inkSecondary,
            );
          case SyncState.error:
            return Tooltip(
              message: status.message ?? '同步失败',
              child: _row(
                key: 'sync-indicator-error',
                icon: const Icon(Icons.error_outline,
                    size: 11, color: Color(0xFFB3352C)),
                label: '同步失败',
                color: const Color(0xFFB3352C),
              ),
            );
        }
      },
    );
  }

  Widget _row({
    required String key,
    required Widget icon,
    required String label,
    required Color color,
  }) {
    return Row(
      key: Key(key),
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  String _relativeTime(DateTime? at) {
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 60) return '（刚刚）';
    if (diff.inMinutes < 60) return '（${diff.inMinutes} 分钟前）';
    if (diff.inHours < 24) return '（${diff.inHours} 小时前）';
    return '（${diff.inDays} 天前）';
  }
}
