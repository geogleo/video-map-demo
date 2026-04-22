import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:latlong2/latlong.dart';

import 'providers/playback_state.dart';
import 'models/gps_frame.dart' show GpsFrame, GpsTrack;
import 'models/route_segment.dart';
import 'data/sample_route.dart';
import 'widgets/map_widget.dart';
import 'widgets/video_player_widget.dart';
import 'widgets/segment_selector.dart';

void main() {
  runApp(const ProviderScope(child: VideoMapDemoApp()));
}

class VideoMapDemoApp extends StatelessWidget {
  const VideoMapDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Map Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PlayerScreen(),
    );
  }
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  VideoPlayerController? _videoController;
  GpsTrack? _gpsTrack;
  List<RouteSegment> _segments = [];
  bool _isSeekingByMap = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // 加载示例数据
    _gpsTrack = SampleRoute.createSampleTrack();
    _segments = SampleRoute.createSampleSegments();

    // 注入GPS轨迹
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gpsTrackProvider.notifier).state = _gpsTrack;
    });
  }

  void _onVideoControllerCreated(VideoPlayerController controller) {
    _videoController = controller;

    // 监听视频播放位置，同步GPS
    controller.addListener(() {
      if (_isSeekingByMap) return;

      final position = controller.value.position;
      final gpsFrame = _gpsTrack?.findFrameAtTime(position);

      ref.read(playbackProvider.notifier).updatePosition(
        position,
        gpsFrame: gpsFrame,
      );
    });
  }

  /// 地图点击 → 视频跳转
  void _onMapPositionTap(LatLng position) {
    if (_gpsTrack == null || _videoController == null) return;

    final time = _gpsTrack!.findTimeAtPosition(position);
    if (time != null) {
      setState(() => _isSeekingByMap = true);

      _videoController!.seekTo(time);
      _videoController!.play();

      // 延迟重置标记
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isSeekingByMap = false);
      });
    }
  }

  /// 选择路段播放
  void _onSegmentSelected(RouteSegment segment) {
    if (_videoController == null) return;

    ref.read(playbackProvider.notifier).selectSegment(segment.id);

    // 跳转到路段开始位置
    _videoController!.seekTo(segment.startTime);
    _videoController!.play();

    // 设置路段结束暂停
    _setupSegmentEndPause(segment);
  }

  void _setupSegmentEndPause(RouteSegment segment) {
    if (_videoController == null) return;

    // 监听播放位置，到达路段结束时暂停
    void listener() {
      if (_videoController!.value.position >= segment.endTime) {
        _videoController!.pause();
        _videoController!.removeListener(listener);
        ref.read(playbackProvider.notifier).clearSegment();
      }
    }

    _videoController!.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(playbackProvider);
    final gpsTrack = ref.watch(gpsTrackProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('视频地图联动播放器'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 视图切换按钮
          IconButton(
            icon: Icon(_getViewModeIcon(playbackState.viewMode)),
            onPressed: () => ref.read(playbackProvider.notifier).toggleViewMode(),
            tooltip: '切换视图',
          ),
        ],
      ),
      body: Column(
        children: [
          // 主内容区
          Expanded(
            child: _buildMainContent(playbackState, gpsTrack),
          ),

          // 底部控制区
          _buildBottomControls(playbackState),
        ],
      ),
    );
  }

  Widget _buildMainContent(PlaybackState state, GpsTrack? track) {
    switch (state.viewMode) {
      case ViewMode.video:
        return VideoPlayerWidget(
          onControllerCreated: _onVideoControllerCreated,
        );

      case ViewMode.map:
        if (track == null) {
          return const Center(child: Text('没有GPS数据'));
        }
        return InteractiveMapWidget(
          pathPoints: track.pathPoints,
          onPathTap: _onMapPositionTap,
        );

      case ViewMode.pip:
        return _buildPipView(state, track);
    }
  }

  Widget _buildPipView(PlaybackState state, GpsTrack? track) {
    return Stack(
      children: [
        // 地图（底层）
        if (track != null)
          Positioned.fill(
            child: InteractiveMapWidget(
              pathPoints: track.pathPoints,
              onPathTap: _onMapPositionTap,
            ),
          ),

        // 视频（右上角画中画）
        Positioned(
          top: 16,
          right: 16,
          width: 180,
          child: PipVideoWidget(
            controller: _videoController,
            onTap: () => ref.read(playbackProvider.notifier).setViewMode(ViewMode.video),
          ),
        ),

        // 当前位置信息
        if (state.currentPositionGps != null)
          Positioned(
            bottom: 16,
            left: 16,
            child: _buildInfoCard(state),
          ),
      ],
    );
  }

  Widget _buildInfoCard(PlaybackState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '速度: ${state.currentSpeed.toStringAsFixed(1)} km/h',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '方向: ${state.currentHeading.toStringAsFixed(0)}°',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(PlaybackState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 路段选择器
          SegmentSelector(
            segments: _segments,
            activeSegmentId: state.activeSegmentId,
            onSegmentSelected: _onSegmentSelected,
          ),

          // 视图模式切换
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildViewModeButton('视频', ViewMode.video, state.viewMode),
              const SizedBox(width: 12),
              _buildViewModeButton('画中画', ViewMode.pip, state.viewMode),
              const SizedBox(width: 12),
              _buildViewModeButton('地图', ViewMode.map, state.viewMode),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(String label, ViewMode mode, ViewMode currentMode) {
    final isActive = mode == currentMode;

    return GestureDetector(
      onTap: () => ref.read(playbackProvider.notifier).setViewMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.blue : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  IconData _getViewModeIcon(ViewMode mode) {
    switch (mode) {
      case ViewMode.video:
        return Icons.videocam;
      case ViewMode.map:
        return Icons.map;
      case ViewMode.pip:
        return Icons.picture_in_picture;
    }
  }
}