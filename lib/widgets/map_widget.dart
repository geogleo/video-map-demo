import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/playback_state.dart';

/// 地图组件 - 显示GPS轨迹和当前位置
class MapWidget extends ConsumerWidget {
  final List<LatLng> pathPoints;
  final LatLng? currentPosition;
  final double currentHeading;
  final VoidCallback? onTap;
  final Function(LatLng)? onPositionTap;

  const MapWidget({
    super.key,
    required this.pathPoints,
    this.currentPosition,
    this.currentHeading = 0,
    this.onTap,
    this.onPositionTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapController = MapController();

    // 计算地图中心
    final center = currentPosition ??
      (pathPoints.isNotEmpty ? pathPoints.first : LatLng(37.7749, -122.4194));

    return GestureDetector(
      onTap: onTap,
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 13,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
          onPositionChanged: (position, hasGesture) {
            // 地图移动时不处理
          },
        ),
        children: [
          // 底图图层 - OpenStreetMap
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.video_map_demo',
          ),

          // 轨迹线
          if (pathPoints.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: pathPoints,
                  color: Colors.blue.withOpacity(0.8),
                  strokeWidth: 4,
                ),
              ],
            ),

          // 当前位置标记
          if (currentPosition != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: currentPosition!,
                  width: 30,
                  height: 30,
                  child: Transform.rotate(
                    angle: currentHeading * 3.14159 / 180,
                    child: const Icon(
                      Icons.navigation,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),

          // 点击地图选择位置
          if (onPositionTap != null)
            GestureDetector(
              onTapUp: (details) {
                // 转换屏幕坐标到地图坐标
                // 这里简化处理，实际需要使用MapController
              },
              child: Container(color: Colors.transparent),
            ),
        ],
      ),
    );
  }
}

/// 可点击的地图 - 点击跳转到对应视频位置
class InteractiveMapWidget extends ConsumerStatefulWidget {
  final List<LatLng> pathPoints;
  final Function(LatLng) onPathTap;

  const InteractiveMapWidget({
    super.key,
    required this.pathPoints,
    required this.onPathTap,
  });

  @override
  ConsumerState<InteractiveMapWidget> createState() => _InteractiveMapWidgetState();
}

class _InteractiveMapWidgetState extends ConsumerState<InteractiveMapWidget> {
  final MapController _mapController = MapController();
  StreamSubscription<PlaybackState>? _subscription;

  @override
  void initState() {
    super.initState();
    // 延迟订阅，避免在 initState 中访问 ref
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscription = ref.read(playbackProvider.notifier).stream.listen((state) {
        // 移动地图跟随当前位置
        if (state.currentPositionGps != null) {
          _mapController.move(state.currentPositionGps!, _mapController.camera.zoom);
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(playbackProvider);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.pathPoints.first,
        initialZoom: 12,
        onTap: (tapPosition, point) {
          // 点击地图时，找到最近的路径点
          _handleMapTap(point);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.video_map_demo',
        ),

        // 轨迹线
        if (widget.pathPoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.pathPoints,
                color: Colors.blue.withOpacity(0.8),
                strokeWidth: 5,
                borderColor: Colors.blue.withOpacity(0.3),
                borderStrokeWidth: 8,
              ),
            ],
          ),

        // 当前位置标记
        if (playbackState.currentPositionGps != null)
          MarkerLayer(
            markers: [
              Marker(
                point: playbackState.currentPositionGps!,
                width: 40,
                height: 40,
                child: Transform.rotate(
                  angle: playbackState.currentHeading * 3.14159 / 180,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_upward,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),

        // 已播放部分高亮
        if (playbackState.currentPositionGps != null && widget.pathPoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _getPlayedPoints(playbackState),
                color: Colors.green.withOpacity(0.9),
                strokeWidth: 5,
              ),
            ],
          ),
      ],
    );
  }

  List<LatLng> _getPlayedPoints(PlaybackState state) {
    // 返回已播放的路径点
    // 这里简化处理，实际应该根据时间戳过滤
    return widget.pathPoints;
  }

  void _handleMapTap(LatLng point) {
    // 找到最近的路径点
    LatLng? nearestPoint;
    double minDistance = double.infinity;

    for (final pathPoint in widget.pathPoints) {
      final distance = _distance(pathPoint, point);
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = pathPoint;
      }
    }

    if (nearestPoint != null && minDistance < 0.005) {
      // 在路径附近，触发回调
      widget.onPathTap(nearestPoint);
    }
  }

  double _distance(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLng = a.longitude - b.longitude;
    return (dLat * dLat + dLng * dLng);
  }
}