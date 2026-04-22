import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/gps_frame.dart';

/// GPS录制服务 - 持续采集GPS数据
class GpsRecorderService {
  final void Function(GpsFrame)? onFrame;
  final Duration interval;

  Timer? _timer;
  LatLng? _lastPosition;
  double _lastHeading = 0;
  double _lastSpeed = 0;
  DateTime _startTime = DateTime.now();
  final List<GpsFrame> _frames = [];

  GpsRecorderService({
    this.onFrame,
    this.interval = const Duration(seconds: 1),
  });

  /// 开始录制
  void start() {
    _startTime = DateTime.now();
    _frames.clear();
    _lastPosition = null;

    // 模拟GPS数据流（实际应使用 geolocator 包）
    _timer = Timer.periodic(interval, (_) => _captureFrame());
  }

  /// 停止录制
  List<GpsFrame> stop() {
    _timer?.cancel();
    _timer = null;
    return List.from(_frames);
  }

  /// 捕获一帧GPS数据
  void _captureFrame() {
    final now = DateTime.now();
    final elapsed = now.difference(_startTime);

    // 实际项目中应该使用 geolocator 获取真实GPS
    // 这里模拟数据
    final frame = GpsFrame(
      timestamp: elapsed,
      position: _lastPosition ?? LatLng(37.7749, -122.4194),
      speed: _lastSpeed,
      heading: _lastHeading,
    );

    _frames.add(frame);
    onFrame?.call(frame);
  }

  /// 更新当前位置（由外部GPS服务调用）
  void updatePosition(LatLng position, {double? speed, double? heading}) {
    _lastPosition = position;
    if (speed != null) _lastSpeed = speed;
    if (heading != null) _lastHeading = heading;
  }

  /// 获取已录制帧数
  int get frameCount => _frames.length;

  /// 获取所有帧
  List<GpsFrame> get frames => List.unmodifiable(_frames);
}

/// GPS录制状态
class GpsRecorderState {
  final bool isRecording;
  final Duration elapsed;
  final int frameCount;
  final LatLng? currentPosition;
  final double currentSpeed;
  final double distance; // 累计距离（米）

  const GpsRecorderState({
    this.isRecording = false,
    this.elapsed = Duration.zero,
    this.frameCount = 0,
    this.currentPosition,
    this.currentSpeed = 0,
    this.distance = 0,
  });

  GpsRecorderState copyWith({
    bool? isRecording,
    Duration? elapsed,
    int? frameCount,
    LatLng? currentPosition,
    double? currentSpeed,
    double? distance,
  }) {
    return GpsRecorderState(
      isRecording: isRecording ?? this.isRecording,
      elapsed: elapsed ?? this.elapsed,
      frameCount: frameCount ?? this.frameCount,
      currentPosition: currentPosition ?? this.currentPosition,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      distance: distance ?? this.distance,
    );
  }
}

/// GPS录制状态管理
class GpsRecorderNotifier extends StateNotifier<GpsRecorderState> {
  GpsRecorderService? _service;
  DateTime? _startTime;
  Timer? _elapsedTimer;
  double _totalDistance = 0;
  LatLng? _prevPosition;

  GpsRecorderNotifier() : super(const GpsRecorderState());

  /// 开始录制
  void startRecording() {
    _service = GpsRecorderService(
      onFrame: _onFrame,
      interval: const Duration(seconds: 1),
    );
    _startTime = DateTime.now();
    _totalDistance = 0;
    _prevPosition = null;

    _service!.start();

    // 定时更新时长
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startTime != null) {
        state = state.copyWith(
          elapsed: DateTime.now().difference(_startTime!),
        );
      }
    });

    state = state.copyWith(isRecording: true);
  }

  /// 停止录制
  List<GpsFrame> stopRecording() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;

    final frames = _service?.stop() ?? [];
    _service = null;

    state = const GpsRecorderState();
    return frames;
  }

  /// GPS帧回调
  void _onFrame(GpsFrame frame) {
    // 计算累计距离
    if (_prevPosition != null) {
      _totalDistance += _calculateDistance(_prevPosition!, frame.position);
    }
    _prevPosition = frame.position;

    state = state.copyWith(
      frameCount: _service!.frameCount,
      currentPosition: frame.position,
      currentSpeed: frame.speed,
      distance: _totalDistance,
    );
  }

  /// 更新GPS位置（外部调用）
  void updatePosition(LatLng position, {double? speed, double? heading}) {
    _service?.updatePosition(position, speed: speed, heading: heading);
  }

  /// 计算两点距离（简化版，米）
  double _calculateDistance(LatLng a, LatLng b) {
    // 使用 Haversine 公式的简化版本
    const earthRadius = 6371000.0; // 地球半径（米）
    final lat1 = a.latitude * 3.14159 / 180;
    final lat2 = b.latitude * 3.14159 / 180;
    final dLat = (b.latitude - a.latitude) * 3.14159 / 180;
    final dLng = (b.longitude - a.longitude) * 3.14159 / 180;

    final x = dLat * dLat + dLng * dLng * (lat1.cos() * lat1.cos());
    return earthRadius * x.sqrt();
  }
}

/// Provider
final gpsRecorderProvider =
    StateNotifierProvider<GpsRecorderNotifier, GpsRecorderState>(
  (ref) => GpsRecorderNotifier(),
);