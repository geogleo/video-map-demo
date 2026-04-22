import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/route_recorder.dart';
import '../models/gps_frame.dart';

/// 历史记录界面
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<RecordedRoute> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final storage = RouteStorageService();
    final routes = await storage.listRoutes();
    setState(() {
      _routes = routes;
      _isLoading = false;
    });
  }

  Future<void> _deleteRoute(RecordedRoute route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除路线'),
        content: Text('确定要删除 "${route.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final storage = RouteStorageService();
      await storage.deleteRoute(route.id);
      await _loadRoutes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRoutes,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '暂无录制记录',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击录制按钮开始记录行程',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _routes.length,
      itemBuilder: (context, index) {
        final route = _routes[index];
        return _buildRouteCard(route);
      },
    );
  }

  Widget _buildRouteCard(RecordedRoute route) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // TODO: 跳转到播放界面
          Navigator.pushNamed(
            context,
            '/play',
            arguments: route,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 缩略图占位
                  Container(
                    width: 80,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.play_circle_outline, size: 32),
                  ),
                  const SizedBox(width: 16),

                  // 路线信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(route.recordedAt),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),

                  // 删除按钮
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    onPressed: () => _deleteRoute(route),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 统计信息
              Row(
                children: [
                  _buildStatChip(Icons.timer, _formatDuration(route.duration)),
                  const SizedBox(width: 8),
                  _buildStatChip(Icons.route, _formatDistance(route.gpsTrack)),
                  const SizedBox(width: 8),
                  _buildStatChip(Icons.speed, 'Avg speed'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '${minutes}分${seconds}秒';
  }

  String _formatDistance(GpsTrack track) {
    double total = 0;
    for (var i = 1; i < track.frames.length; i++) {
      final prev = track.frames[i - 1].position;
      final curr = track.frames[i].position;
      // 简化距离计算
      final dLat = curr.latitude - prev.latitude;
      final dLng = curr.longitude - prev.longitude;
      total += (dLat * dLat + dLng * dLng).sqrt() * 111000; // 近似米数
    }
    if (total < 1000) {
      return '${total.toStringAsFixed(0)} m';
    }
    return '${(total / 1000).toStringAsFixed(1)} km';
  }
}