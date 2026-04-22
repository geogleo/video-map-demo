import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:background_locator_2/background_locator.dart' as locator;
import 'package:background_locator_2/location_settings.dart';
import '../models/gps_frame.dart';

/// 真实GPS服务 - 使用 geolocator
class RealGpsService {
  StreamSubscription<Position>? _positionStream;
  final void Function(GpsFrame)? onFrame;
  final Duration interval;
  DateTime? _startTime;

  RealGpsService({
    this.onFrame,
    this.interval = const Duration(seconds: 1),
  });

  /// 检查并请求权限
  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// 开始监听GPS
  Future<bool> startTracking() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      debugPrint('GPS权限未授予');
      return false;
    }

    _startTime = DateTime.now();

    // 配置GPS设置
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // 移动5米更新一次
      intervalDuration: Duration(seconds: 1),
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final elapsed = DateTime.now().difference(_startTime!);
      final frame = GpsFrame(
        timestamp: elapsed,
        position: LatLng(position.latitude, position.longitude),
        speed: position.speed * 3.6, // m/s → km/h
        heading: position.heading,
      );
      onFrame?.call(frame);
    });

    return true;
  }

  /// 停止监听
  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  /// 获取当前位置
  Future<LatLng?> getCurrentPosition() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('获取位置失败: $e');
      return null;
    }
  }
}

/// 后台GPS服务 - 使用 background_locator_2
class BackgroundGpsService {
  static const String _channelName = 'video_map_demo_location';
  static const int _interval = 1; // 秒

  final void Function(GpsFrame)? onFrame;
  DateTime? _startTime;

  BackgroundGpsService({this.onFrame});

  /// 初始化后台定位
  Future<void> initialize() async {
    await locator.BackgroundLocator.initialize();
  }

  /// 开始后台追踪
  Future<bool> startBackgroundTracking() async {
    if (await locator.BackgroundLocator.isServiceRunning()) {
      return true;
    }

    _startTime = DateTime.now();

    await locator.BackgroundLocator.registerLocationUpdate(
      _callback,
      initCallback: _initCallback,
      disposeCallback: _disposeCallback,
      iosSettings: const IOSSettings(
        accuracy: LocationAccuracy.NAVIGATION,
        distanceFilter: 5,
        stopWithTerminate: false,
      ),
      autoStop: false,
      androidSettings: const AndroidSettings(
        accuracy: LocationAccuracy.NAVIGATION,
        interval: _interval,
        distanceFilter: 5,
        client: LocationClient.googleMaps,
        androidNotificationSettings: AndroidNotificationSettings(
          notificationChannelName: '行车录制',
          notificationTitle: '正在录制行车视频',
          notificationMsg: 'GPS轨迹记录中...',
          notificationIcon: 'ic_launcher',
          wakeLock: true,
        ),
      ),
    );

    return true;
  }

  /// 停止后台追踪
  Future<void> stopBackgroundTracking() async {
    await locator.BackgroundLocator.unRegisterLocationUpdate();
  }

  /// 检查是否在运行
  Future<bool> isRunning() async {
    return await locator.BackgroundLocator.isServiceRunning();
  }

  // 回调函数
  static void _callback(LocationDto location) {
    // 通过 Isolate 通信，这里需要使用 SendPort
    debugPrint('Location: ${location.latitude}, ${location.longitude}');
  }

  static void _initCallback() {
    debugPrint('Background location initialized');
  }

  static void _disposeCallback() {
    debugPrint('Background location disposed');
  }
}

/// GPS状态Provider
final gpsServiceProvider = Provider<RealGpsService>((ref) {
  return RealGpsService();
});

/// GPS权限状态
final gpsPermissionProvider = StateProvider<bool>((ref) => false);

/// 当前位置Provider
final currentPositionProvider = StateProvider<LatLng?>((ref) => null);

/// 初始化GPS权限
Future<void> initGpsPermission(WidgetRef ref) async {
  final service = ref.read(gpsServiceProvider);
  final hasPermission = await service.checkPermission();
  ref.read(gpsPermissionProvider.notifier).state = hasPermission;

  if (hasPermission) {
    final position = await service.getCurrentPosition();
    ref.read(currentPositionProvider.notifier).state = position;
  }
}