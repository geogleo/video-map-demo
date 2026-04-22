import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../services/gps_recorder.dart';
import '../services/route_recorder.dart';
import '../models/gps_frame.dart';
import '../models/route_segment.dart';

/// 录制界面
class RecorderScreen extends ConsumerStatefulWidget {
  const RecorderScreen({super.key});

  @override
  ConsumerState<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends ConsumerState<RecorderScreen> {
  bool _isInitialized = false;
  bool _isRecording = false;
  CameraController? _cameraController;
  Timer? _durationTimer;
  Duration _recordingDuration = Duration.zero;

  // GPS数据
  final List<GpsFrame> _gpsFrames = [];
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showError('没有可用的摄像头');
        return;
      }

      // 使用后置摄像头
      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.veryHigh,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      setState(() => _isInitialized = true);
    } catch (e) {
      _showError('摄像头初始化失败: $e');
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      await _cameraController!.startVideoRecording();
      _startTime = DateTime.now();
      _gpsFrames.clear();
      _isRecording = true;

      // 启动GPS录制
      ref.read(gpsRecorderProvider.notifier).startRecording();

      // 定时更新录制时长
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_startTime != null) {
          setState(() {
            _recordingDuration = DateTime.now().difference(_startTime!);
          });
        }
      });

      setState(() {});
    } catch (e) {
      _showError('开始录制失败: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      // 停止视频录制
      final videoFile = await _cameraController!.stopVideoRecording();
      _durationTimer?.cancel();
      _durationTimer = null;

      // 停止GPS录制
      final gpsFrames = ref.read(gpsRecorderProvider.notifier).stopRecording();

      _isRecording = false;
      setState(() {});

      // 保存路线
      await _saveRoute(videoFile.path, gpsFrames);
    } catch (e) {
      _showError('停止录制失败: $e');
    }
  }

  Future<void> _saveRoute(String videoPath, List<GpsFrame> gpsFrames) async {
    if (gpsFrames.isEmpty) {
      _showError('没有GPS数据');
      return;
    }

    final now = DateTime.now();
    final route = RecordedRoute(
      id: 'route_${now.millisecondsSinceEpoch}',
      name: '行车记录 ${_formatDateTime(now)}',
      videoPath: videoPath,
      gpsTrack: GpsTrack(
        id: 'gps_${now.millisecondsSinceEpoch}',
        name: 'GPS轨迹',
        frames: gpsFrames,
        recordedAt: now,
      ),
      recordedAt: now,
      duration: _recordingDuration,
    );

    final storage = RouteStorageService();
    await storage.saveRoute(route);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('路线已保存')),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
             '${minutes.toString().padLeft(2, '0')}:'
             '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
           '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gpsState = ref.watch(gpsRecorderProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('行车录制'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 摄像头预览
          if (_isInitialized && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            ),

          // 未初始化提示
          if (!_isInitialized)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // 顶部信息栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildInfoBar(gpsState),
          ),

          // 底部控制区
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar(GpsRecorderState gpsState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 录制时长
            Row(
              children: [
                if (_isRecording)
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  _formatDuration(_recordingDuration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // 速度
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.speed, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${gpsState.currentSpeed.toStringAsFixed(0)} km/h',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 速度统计
            _buildStatColumn('距离', _formatDistance(ref.read(gpsRecorderProvider).distance)),
            // 录制按钮
            GestureDetector(
              onTap: _isRecording ? _stopRecording : _startRecording,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? Colors.red : Colors.white,
                  border: Border.all(
                    color: Colors.white,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.fiber_manual_record,
                  size: _isRecording ? 40 : 50,
                  color: _isRecording ? Colors.white : Colors.red,
                ),
              ),
            ),
            // GPS状态
            _buildStatColumn('GPS', _isRecording ? '已连接' : '待机'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}