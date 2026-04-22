import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../providers/playback_state.dart';
import '../models/gps_frame.dart';

/// 视频播放器组件
class VideoPlayerWidget extends ConsumerStatefulWidget {
  final String? videoUrl;
  final Function(VideoPlayerController)? onControllerCreated;

  const VideoPlayerWidget({
    super.key,
    this.videoUrl,
    this.onControllerCreated,
  });

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // 这里使用网络视频作为示例
    // 实际项目中应该使用录制的视频文件
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(
        widget.videoUrl ??
        'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4'
      ),
    );

    try {
      await _controller!.initialize();
      setState(() => _isInitialized = true);

      // 通知外部控制器已创建
      widget.onControllerCreated?.call(_controller!);

      // 监听播放位置变化
      _controller!.addListener(_onVideoUpdate);

      // 更新总时长
      ref.read(playbackProvider.notifier).updateDuration(
        _controller!.value.duration,
      );

    } catch (e) {
      debugPrint('Video init error: $e');
    }
  }

  void _onVideoUpdate() {
    if (_controller == null) return;

    final position = _controller!.value.position;
    final isPlaying = _controller!.value.isPlaying;

    // 更新播放状态
    final notifier = ref.read(playbackProvider.notifier);
    notifier.updatePlaying(isPlaying);
    notifier.updatePosition(position);

    // 触发GPS更新（由外部根据GPS数据同步）
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 视频画面
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),

          // 渐变遮罩
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),

          // 控制条
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final state = ref.watch(playbackProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 进度条
        Row(
          children: [
            Text(
              _formatDuration(state.currentPosition),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Expanded(
              child: SliderTheme(
                data: const SliderThemeData(
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: state.currentPosition.inMilliseconds.toDouble(),
                  max: state.totalDuration.inMilliseconds.toDouble(),
                  onChanged: (value) {
                    _seekTo(Duration(milliseconds: value.toInt()));
                  },
                ),
              ),
            ),
            Text(
              _formatDuration(state.totalDuration),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _seekTo(Duration position) {
    _controller?.seekTo(position);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// 简化版视频播放器（用于画中画模式）
class PipVideoWidget extends ConsumerWidget {
  final VideoPlayerController? controller;
  final VoidCallback? onTap;

  const PipVideoWidget({
    super.key,
    this.controller,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (controller == null || !controller!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: controller!.value.aspectRatio,
            child: VideoPlayer(controller!),
          ),
        ),
      ),
    );
  }
}