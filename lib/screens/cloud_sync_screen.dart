import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/cloud_sync_service.dart';
import '../services/route_recorder.dart';
import '../models/gps_frame.dart';

/// 云端同步界面
class CloudSyncScreen extends ConsumerStatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  ConsumerState<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends ConsumerState<CloudSyncScreen> {
  List<CloudRoute> _cloudRoutes = [];
  List<RecordedRoute> _localRoutes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 加载本地路线
    final storage = RouteStorageService();
    final local = await storage.listRoutes();

    // 加载云端路线
    final sync = ref.read(cloudSyncServiceProvider);
    sync.init(authToken: 'YOUR_TOKEN'); // 实际使用时替换
    final cloud = await sync.getRoutes();

    setState(() {
      _localRoutes = local;
      _cloudRoutes = cloud;
      _isLoading = false;
    });
  }

  Future<void> _uploadRoute(RecordedRoute route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('上传路线'),
        content: Text('确定要上传 "${route.name}" 到云端吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('上传'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 显示上传对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UploadProgressDialog(route: route),
    );
  }

  Future<void> _downloadRoute(CloudRoute route) async {
    // 显示下载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DownloadProgressDialog(route: route),
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('云端同步'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '本地路线'),
              Tab(text: '云端路线'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // 本地路线
                  _buildLocalRoutesList(),
                  // 云端路线
                  _buildCloudRoutesList(),
                ],
              ),
      ),
    );
  }

  Widget _buildLocalRoutesList() {
    if (_localRoutes.isEmpty) {
      return const Center(child: Text('暂无本地路线'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _localRoutes.length,
      itemBuilder: (context, index) {
        final route = _localRoutes[index];
        return _buildRouteCard(
          route: route,
          isLocal: true,
          onUpload: () => _uploadRoute(route),
          onDelete: () async {
            final storage = RouteStorageService();
            await storage.deleteRoute(route.id);
            _loadData();
          },
        );
      },
    );
  }

  Widget _buildCloudRoutesList() {
    if (_cloudRoutes.isEmpty) {
      return const Center(child: Text('暂无云端路线'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cloudRoutes.length,
      itemBuilder: (context, index) {
        final route = _cloudRoutes[index];
        return _buildCloudRouteCard(
          route: route,
          onDownload: () => _downloadRoute(route),
          onDelete: () async {
            final sync = ref.read(cloudSyncServiceProvider);
            await sync.deleteRoute(route.id);
            _loadData();
          },
        );
      },
    );
  }

  Widget _buildRouteCard({
    required RecordedRoute route,
    required bool isLocal,
    required VoidCallback onUpload,
    required VoidCallback onDelete,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.videocam, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatDate(route.recordedAt),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildChip(Icons.timer, '${route.duration.inMinutes}分'),
                const SizedBox(width: 8),
                _buildChip(Icons.route, _formatDistance(route.gpsTrack)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isLocal)
                  TextButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('上传'),
                    onPressed: onUpload,
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('删除', style: TextStyle(color: Colors.red)),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudRouteCard({
    required CloudRoute route,
    required VoidCallback onDownload,
    required VoidCallback onDelete,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cloud, size: 32, color: Colors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatDate(route.recordedAt),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildChip(Icons.timer, '${route.duration.inMinutes}分'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('下载'),
                  onPressed: onDownload,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('删除', style: TextStyle(color: Colors.red)),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
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

  String _formatDistance(GpsTrack track) {
    double total = 0;
    for (var i = 1; i < track.frames.length; i++) {
      final prev = track.frames[i - 1].position;
      final curr = track.frames[i].position;
      final dLat = curr.latitude - prev.latitude;
      final dLng = curr.longitude - prev.longitude;
      total += (dLat * dLat + dLng * dLng).sqrt() * 111000;
    }
    if (total < 1000) return '${total.toStringAsFixed(0)} m';
    return '${(total / 1000).toStringAsFixed(1)} km';
  }
}

/// 上传进度对话框
class _UploadProgressDialog extends ConsumerWidget {
  final RecordedRoute route;

  const _UploadProgressDialog({required this.route});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);

    // 启动上传
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(syncProvider.notifier);
      final success = await notifier.uploadRoute(route);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '上传成功' : '上传失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    });

    return AlertDialog(
      title: const Text('上传中'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: syncState.progressPercent),
          const SizedBox(height: 16),
          Text(syncState.statusText),
        ],
      ),
    );
  }
}

/// 下载进度对话框
class _DownloadProgressDialog extends ConsumerWidget {
  final CloudRoute route;

  const _DownloadProgressDialog({required this.route});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);

    // 启动下载
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(syncProvider.notifier);
      final downloaded = await notifier.downloadRoute(route.id, '/data/user/.../video_routes');
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(downloaded != null ? '下载成功' : '下载失败'),
            backgroundColor: downloaded != null ? Colors.green : Colors.red,
          ),
        );
      }
    });

    return AlertDialog(
      title: const Text('下载中'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: syncState.progressPercent),
          const SizedBox(height: 16),
          Text(syncState.statusText),
        ],
      ),
    );
  }
}