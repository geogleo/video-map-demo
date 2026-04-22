import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/recorder_screen.dart';
import 'screens/enhanced_recorder_screen.dart';
import 'screens/history_screen.dart';
import 'screens/cloud_sync_screen.dart';
import 'main.dart' show PlayerScreen;

void main() {
  runApp(const ProviderScope(child: VideoMapApp()));
}

class VideoMapApp extends StatelessWidget {
  const VideoMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '视频地图行车记录',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      routes: {
        '/record': (context) => const RecorderScreen(),
        '/record-enhanced': (context) => const EnhancedRecorderScreen(),
        '/history': (context) => const HistoryScreen(),
        '/play': (context) => const PlayerScreen(),
        '/cloud': (context) => const CloudSyncScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视频地图行车记录'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo区域
            const SizedBox(height: 40),
            Icon(
              Icons.videocam_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              '行车视频记录',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '录制视频 + GPS轨迹，地图联动回放',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),

            const Spacer(),

            // 功能入口
            _buildFeatureCard(
              context,
              icon: Icons.fiber_manual_record,
              title: '开始录制',
              subtitle: '真实GPS + 后台保活',
              color: Colors.red,
              onTap: () => Navigator.pushNamed(context, '/record-enhanced'),
              badge: '增强版',
            ),

            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              icon: Icons.history,
              title: '历史记录',
              subtitle: '查看和播放已录制的行程',
              color: Colors.blue,
              onTap: () => Navigator.pushNamed(context, '/history'),
            ),

            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              icon: Icons.cloud_sync,
              title: '云端同步',
              subtitle: '上传/下载路线数据',
              color: Colors.purple,
              onTap: () => Navigator.pushNamed(context, '/cloud'),
            ),

            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              icon: Icons.play_circle_outline,
              title: '播放演示',
              subtitle: '体验地图联动播放功能',
              color: Colors.green,
              onTap: () => Navigator.pushNamed(context, '/play'),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}