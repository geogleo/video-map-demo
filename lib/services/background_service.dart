import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 后台服务管理器
class BackgroundServiceManager {
  static const MethodChannel _channel = MethodChannel('video_map_demo/background');

  /// 启动前台服务（Android）
  static Future<bool> startForegroundService({
    required String title,
    required String content,
  }) async {
    try {
      final result = await _channel.invokeMethod('startForegroundService', {
        'title': title,
        'content': content,
      });
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('启动前台服务失败: ${e.message}');
      return false;
    }
  }

  /// 停止前台服务
  static Future<bool> stopForegroundService() async {
    try {
      final result = await _channel.invokeMethod('stopForegroundService');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('停止前台服务失败: ${e.message}');
      return false;
    }
  }

  /// 检查前台服务是否运行
  static Future<bool> isServiceRunning() async {
    try {
      final result = await _channel.invokeMethod('isServiceRunning');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('检查服务状态失败: ${e.message}');
      return false;
    }
  }

  /// 更新通知内容
  static Future<bool> updateNotification({
    required String title,
    required String content,
  }) async {
    try {
      final result = await _channel.invokeMethod('updateNotification', {
        'title': title,
        'content': content,
      });
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('更新通知失败: ${e.message}');
      return false;
    }
  }
}

/// 后台录制状态
class BackgroundRecordingState {
  final bool isRunning;
  final Duration duration;
  final String statusText;

  const BackgroundRecordingState({
    this.isRunning = false,
    this.duration = Duration.zero,
    this.statusText = '未运行',
  });

  BackgroundRecordingState copyWith({
    bool? isRunning,
    Duration? duration,
    String? statusText,
  }) {
    return BackgroundRecordingState(
      isRunning: isRunning ?? this.isRunning,
      duration: duration ?? this.duration,
      statusText: statusText ?? this.statusText,
    );
  }
}

/// 后台录制状态管理
class BackgroundRecordingNotifier extends StateNotifier<BackgroundRecordingState> {
  BackgroundRecordingNotifier() : super(const BackgroundRecordingState());

  /// 启动后台录制
  Future<void> startBackgroundRecording() async {
    final success = await BackgroundServiceManager.startForegroundService(
      title: '行车录制中',
      content: 'GPS轨迹记录中...',
    );

    if (success) {
      state = state.copyWith(
        isRunning: true,
        statusText: '后台录制中',
      );
    }
  }

  /// 停止后台录制
  Future<void> stopBackgroundRecording() async {
    await BackgroundServiceManager.stopForegroundService();
    state = const BackgroundRecordingState();
  }

  /// 更新录制状态
  void updateDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    state = state.copyWith(
      duration: duration,
      statusText: '录制中 ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
    );
  }
}

/// Provider
final backgroundRecordingProvider =
    StateNotifierProvider<BackgroundRecordingNotifier, BackgroundRecordingState>(
  (ref) => BackgroundRecordingNotifier(),
);