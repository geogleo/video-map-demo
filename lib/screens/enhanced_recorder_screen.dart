import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:latlong2/latlong.dart';
import '../services/gps_recorder.dart';
import '../services/real_gps_service.dart';
import '../services/background_service.dart';
import '../services/route_recorder.dart';
import '../models/gps_frame.dart';

/// 增强版录制界面 - 支持真实GPS和后台录制
class EnhancedRecorderScreen extends ConsumerStatefulWidget {
  const EnhancedRecorderScreen({super.key});

  @override
  ConsumerState<EnhancedRecorderScreen> createState() => _EnhancedRecorderScreenState();
}

class _EnhancedRecorderScreenState extends ConsumerState<EnhancedRecorderScreen>
    with WidgetsBindingObserver {
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isPaused = false;
  CameraController? _cameraController;
  Timer? _durationTimer;
  Duration _recordingDuration = Duration.zero;
  DateTime? _startTime;
  List<GpsFrame> _gpsFrames = [];

  // 真实GPS
  RealGpsService? _gpsService;
  LatLng? _currentPosition;
  double _currentSpeed = 0;
  double _currentHeading = 0;
  StreamSubscription<Position>? _gpsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    await Future.wait([
      _initializeCamera(),
      _initializeGps(),
    ]);
    setState(() => _isInitialized = true);
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

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
    } catch (e) {
      _showError('摄像头初始化失败: $e');
    }
  }

  Future<void> _initializeGps() async {
    _gpsService = RealGpsService(
      onFrame: (frame) {
        setState(() {
          _currentPosition = frame.position;
          _currentSpeed = frame.speed;
          _currentHeading = frame.heading;
        });

        if (_isRecording && !_isPaused) {
          _gpsFrames.add(frame);
        }
      },
    );

    final hasPermission = await _gpsService!.checkPermission();
    if (hasPermission) {
      await _gpsService!.startTracking();
      final pos = await _gpsService!.getCurrentPosition();
      setState(() => _currentPosition = pos);
    } else {
      _showError('需要GPS权限才能记录轨迹');
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
      _isPaused = false;

      // 启动后台服务
      await ref.read(backgroundRecordingProvider.notifier).startBackgroundRecording();

      // 更新录制时长
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_startTime != null && !_isPaused) {
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

  Future<void> _pauseRecording() async {
    if (!_isRecording) return;

    try {
      await _cameraController!.pauseVideoRecording();
      setState(() => _isPaused = true);
    } catch (e) {
      _showError('暂停录制失败: $e');
    }
  }

  Future<void> _resumeRecording() async {
    if (!_isRecording || !_isPaused) return;

    try {
      await _cameraController!.resumeVideoRecording();
      setState(() => _isPaused = false);
    } catch (e) {
      _showError('继续录制失败: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final videoFile = await _cameraController!.stopVideoRecording();
      _durationTimer?.cancel();
      _durationTimer = null;

      // 停止后台服务
      await ref.read(backgroundRecordingProvider.notifier).stopBackgroundRecording();

      _isRecording = false;
      _isPaused = false;
      setState(() {});

      // 保存路线
      await _saveRoute(videoFile.path);
    } catch (e) {
      _showError('停止录制失败: $e');
    }
  }

  Future<void> _saveRoute(String videoPath) async {
    if (_gpsFrames.isEmpty) {
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
        frames: _gpsFrames,
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

  String _formatDistance() {
    double total = 0;
    for (var i = 1; i < _gpsFrames.length; i++) {
      final prev = _gpsFrames[i - 1].position;
      final curr = _gpsFrames[i].position;
      final dLat = curr.latitude - prev.latitude;
      final dLng = curr.longitude - prev.longitude;
      total += (dLat * dLat + dLng * dLng).sqrt() * 111000;
    }
    if (total < 1000) {
      return '${total.toStringAsFixed(0)} m';
    }
    return '${(total / 1000).toStringAsFixed(1)} km';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isRecording) {
      // 应用进入后台，继续录制
      debugPrint('应用进入后台，录制继续');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _durationTimer?.cancel();
    _gpsSubscription?.cancel();
    _gpsService?.stopTracking();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundState = ref.watch(backgroundRecordingProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('行车录制'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          // GPS状态指示
          if (_currentPosition != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gps_fixed, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('GPS', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // 摄像头预览
          if (_isInitialized && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            ),

          // 加载提示
          if (!_isInitialized)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('正在初始化...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),

          // 顶部信息栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildInfoBar(),
          ),

          // 暂停遮罩
          if (_isPaused)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Text(
                    '已暂停',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
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

  Widget _buildInfoBar() {
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
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),

            // 速度显示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    '${_currentSpeed.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'km/h',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 统计信息
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('距离', _formatDistance()),
                _buildStatItem('GPS帧', '${_gpsFrames.length}'),
                _buildStatItem('方向', '${_currentHeading.toStringAsFixed(0)}°'),
              ],
            ),

            const SizedBox(height: 24),

            // 控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 暂停/继续按钮
                if (_isRecording)
                  GestureDetector(
                    onTap: _isPaused ? _resumeRecording : _pauseRecording,
                    child: _buildControlButton(
                      icon: _isPaused ? Icons.play_arrow : Icons.pause,
                      size: 60,
                      color: Colors.orange,
                    ),
                  ),

                // 录制/停止按钮
                GestureDetector(
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  child: _buildControlButton(
                    icon: _isRecording ? Icons.stop : Icons.fiber_manual_record,
                    size: 80,
                    color: _isRecording ? Colors.red : Colors.white,
                    backgroundColor: _isRecording ? Colors.white : Colors.red,
                  ),
                ),

                // 占位（保持居中）
                if (_isRecording)
                  const SizedBox(width: 60),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required double size,
    required Color color,
    Color? backgroundColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(color: color, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}