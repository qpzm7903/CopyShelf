import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/snippet_provider.dart';
import 'search_overlay.dart';
import 'settings_page.dart';

/// 首页
///
/// 在搜索模式（默认）和设置模式之间切换，并承担窗口生命周期行为：
/// - 搜索模式下失焦即自动隐藏窗口（启动器惯例）
/// - 主窗口点 X 隐藏到托盘，不退出进程（退出只在托盘菜单）
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener {
  SnippetProvider? _provider;
  int _lastSearchInvocation = 0;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // 监听「呼出」信号：每次呼出把残留的编辑器等 push 路由出栈，落回搜索界面。
    // 设置页是视图切换（isSettingsOpen），由下方 build 复位，无需在此处理。
    _provider = context.read<SnippetProvider>();
    _lastSearchInvocation = _provider!.searchInvocation;
    _provider!.addListener(_onProviderChanged);
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    windowManager.removeListener(this);
    super.dispose();
  }

  /// 呼出计数变化即说明用户重新呼出窗口：把盖在搜索界面之上的路由（如编辑器）出栈。
  void _onProviderChanged() {
    final provider = _provider;
    if (provider == null) return;
    if (provider.searchInvocation == _lastSearchInvocation) return;
    _lastSearchInvocation = provider.searchInvocation;

    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    // 在帧回调里出栈，避免在 notifyListeners 触发的回调中同步操作导航栈。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      navigator.popUntil((route) => route.isFirst);
    });
  }

  /// 失焦即隐藏：仅搜索模式生效——设置页可能需要切去别处复制 Git 地址
  @override
  void onWindowBlur() {
    final provider = context.read<SnippetProvider>();
    if (provider.isSettingsOpen || provider.isSnippetEditorOpen) return;
    windowManager.hide();
    provider.hideSearch();
  }

  /// 关闭即托盘：点 X 只隐藏窗口，进程常驻
  @override
  void onWindowClose() {
    windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SnippetProvider>(
      builder: (context, provider, _) {
        if (provider.isSettingsOpen) {
          return SettingsPage(onBack: provider.closeSettings);
        }

        if (provider.error != null && provider.snippets.isEmpty) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 48, color: Colors.orange[300]),
                    const SizedBox(height: 12),
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF999999)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.init(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              const SearchOverlay(),
              // 设置入口
              Positioned(
                bottom: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  color: const Color(0xFFCCCCCC),
                  onPressed: provider.openSettings,
                  tooltip: '设置',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
