/// Git 同步状态（供 UI 常驻指示）
enum SyncState {
  /// 未配置远端或尚未同步过
  idle,

  /// 正在同步
  syncing,

  /// 最近一次同步成功
  ok,

  /// 最近一次同步失败
  error,
}

/// 同步状态快照（不可变）
class SyncStatus {
  final SyncState state;

  /// 失败时的可读原因（state == error 时非空）
  final String? message;

  /// 最近一次成功同步的时间（从未成功为 null）
  final DateTime? lastSuccessAt;

  const SyncStatus({
    required this.state,
    this.message,
    this.lastSuccessAt,
  });

  static const SyncStatus initial = SyncStatus(state: SyncState.idle);

  SyncStatus copyWith({
    SyncState? state,
    String? message,
    DateTime? lastSuccessAt,
  }) =>
      SyncStatus(
        state: state ?? this.state,
        message: message,
        lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      );

  bool get isSyncing => state == SyncState.syncing;
  bool get hasError => state == SyncState.error;
}
