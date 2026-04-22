import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';

/// 视频录制服务
class VideoRecorderService {
  CameraController? _controller;
  bool _isRecording = false;
  String? _currentVideoPath;
  DateTime? _startTime;

  /// 初始化摄像头
  Future<void> initialize(CameraDescription camera) async {
    _controller = CameraController(
      camera,
      ResolutionPreset.veryHigh,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
  }

  /// 开始录制
  Future<String?> startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return null;
    }

    try {
      // 生成文件名
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final directory = await getApplicationDocumentsDirectory();
      final videoDir = Directory('${directory.path}/video_routes');
      if (!await videoDir.exists()) {
        await videoDir.create(recursive: true);
      }

      _currentVideoPath = '${videoDir.path}/route_$timestamp.mp4';
      _startTime = DateTime.now();

      await _controller!.startVideoRecording(_currentVideoPath!);
      _isRecording = true;

      return _currentVideoPath;
    } catch (e) {
      debugPrint('Start recording error: $e');
      return null;
    }
  }

  /// 停止录制
  Future<String?> stopRecording() async {
    if (_controller == null || !_isRecording) {
      return null;
    }

    try {
      final file = await _controller!.stopVideoRecording();
      _isRecording = false;
      return file.path;
    } catch (e) {
      debugPrint('Stop recording error: $e');
      return null;
    }
  }

  /// 获取摄像头预览
  CameraController? get controller => _controller;

  /// 是否正在录制
  bool get isRecording => _isRecording;

  /// 当前视频路径
  String? get currentVideoPath => _currentVideoPath;

  /// 录制时长
  Duration? get recordingDuration =>
    _startTime != null ? DateTime.now().difference(_startTime!) : null;

  /// 释放资源
  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}

/// 视频录制状态
class VideoRecorderState {
  final bool isInitialized;
  final bool isRecording;
  final Duration? duration;
  final String? videoPath;

  const VideoRecorderState({
    this.isInitialized = false,
    this.isRecording = false,
    this.duration,
    this.videoPath,
  });

  VideoRecorderState copyWith({
    bool? isInitialized,
    bool? isRecording,
    Duration? duration,
    String? videoPath,
  }) {
    return VideoRecorderState(
      isInitialized: isInitialized ?? this.isInitialized,
      isRecording: isRecording ?? this.isRecording,
      duration: duration ?? this.duration,
      videoPath: videoPath ?? this.videoPath,
    );
  }
}

/// 视频录制状态管理
class VideoRecorderNotifier extends StateNotifier<VideoRecorderState> {
  VideoRecorderService? _service;
  Timer? _durationTimer;
  List<CameraDescription>? _cameras;

  VideoRecorderNotifier() : super(const VideoRecorderState());

  /// 初始化
  Future<bool> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        return false;
      }

      // 使用后置摄像头
      final backCamera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _service = VideoRecorderService();
      await _service!.initialize(backCamera);

      state = state.copyWith(isInitialized: true);
      return true;
    } catch (e) {
      debugPrint('Initialize error: $e');
      return false;
    }
  }

  /// 开始录制
  Future<void> startRecording() async {
    final path = await _service?.startRecording();
    if (path == null) return;

    // 定时更新时长
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final duration = _service?.recordingDuration;
      state = state.copyWith(duration: duration);
    });

    state = state.copyWith(isRecording: true, videoPath: path);
  }

  /// 停止录制
  Future<String?> stopRecording() async {
    _durationTimer?.cancel();
    _durationTimer = null;

    final path = await _service?.stopRecording();
    state = state.copyWith(isRecording: false);
    return path;
  }

  /// 获取摄像头控制器（用于预览）
  CameraController? get cameraController => _service?.controller;

  /// 释放资源
  @override
  void dispose() {
    _durationTimer?.cancel();
    _service?.dispose();
    super.dispose();
  }
}

/// Provider
final videoRecorderProvider =
    StateNotifierProvider<VideoRecorderNotifier, VideoRecorderState>(
  (ref) => VideoRecorderNotifier(),
);