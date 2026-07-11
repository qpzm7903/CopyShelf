import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/snippet_provider.dart';
import 'search_overlay.dart';
import 'settings_page.dart';

/// 首页
///
/// 在搜索模式（默认）和设置模式之间切换。
/// 搜索模式为小窗口覆盖层，设置模式为全尺寸窗口。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showSettings = false;

  void _openSettings() {
    setState(() {
      _showSettings = true;
    });
  }

  void _closeSettings() {
    setState(() {
      _showSettings = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSettings) {
      return SettingsPage(onBack: _closeSettings);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Consumer<SnippetProvider>(
        builder: (context, provider, _) {
          if (provider.error != null && provider.snippets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange[300]),
                    const SizedBox(height: 12),
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.init(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            children: [
              const SearchOverlay(),
              // 设置入口
              Positioned(
                bottom: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  color: const Color(0xFFCCCCCC),
                  onPressed: _openSettings,
                  tooltip: '设置',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
