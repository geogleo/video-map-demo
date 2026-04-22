import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/gps_frame.dart';

/// 播放模式
enum ViewMode {
  video,       // 全屏视频
  map,         // 全屏地图
  pip,         // 画中画（视频+小地图）
}

/// 播放状态
class PlaybackState {
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final ViewMode viewMode;
  final LatLng? currentPositionGps;
  final double currentSpeed;
  final double currentHeading;
  final String? activeSegmentId;

  const PlaybackState({
    this.isPlaying = false,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.viewMode = ViewMode.pip,
    this.currentPositionGps,
    this.currentSpeed = 0,
    this.currentHeading = 0,
    this.activeSegmentId,
  });

  PlaybackState copyWith({
    bool? isPlaying,
    Duration? currentPosition,
    Duration? totalDuration,
    ViewMode? viewMode,
    LatLng? currentPositionGps,
    double? currentSpeed,
    double? currentHeading,
    String? activeSegmentId,
    bool clearActiveSegment = false,
    bool clearGps = false,
  }) {
    return PlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      viewMode: viewMode ?? this.viewMode,
      currentPositionGps: clearGps ? null : (currentPositionGps ?? this.currentPositionGps),
      currentSpeed: currentSpeed ?? this.currentSpeed,
      currentHeading: currentHeading ?? this.currentHeading,
      activeSegmentId: clearActiveSegment ? null : (activeSegmentId ?? this.activeSegmentId),
    );
  }
}

/// 播放状态控制器
class PlaybackNotifier extends StateNotifier<PlaybackState> {
  final _streamController = StreamController<PlaybackState>.broadcast();

  PlaybackNotifier() : super(const PlaybackState());

  /// 获取状态变更流
  Stream<PlaybackState> get stream => _streamController.stream;

  @override
  set state(PlaybackState value) {
    super.state = value;
    _streamController.add(value);
  }

  /// 更新播放状态
  void updatePlaying(bool isPlaying) {
    state = state.copyWith(isPlaying: isPlaying);
  }

  /// 更新当前播放位置
  void updatePosition(Duration position, {GpsFrame? gpsFrame}) {
    state = state.copyWith(
      currentPosition: position,
      currentPositionGps: gpsFrame?.position,
      currentSpeed: gpsFrame?.speed ?? 0,
      currentHeading: gpsFrame?.heading ?? 0,
      clearGps: gpsFrame == null,
    );
  }

  /// 更新总时长
  void updateDuration(Duration duration) {
    state = state.copyWith(totalDuration: duration);
  }

  /// 切换视图模式
  void toggleViewMode() {
    final modes = ViewMode.values;
    final currentIndex = modes.indexOf(state.viewMode);
    final nextIndex = (currentIndex + 1) % modes.length;
    state = state.copyWith(viewMode: modes[nextIndex]);
  }

  /// 设置视图模式
  void setViewMode(ViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  /// 选择路段
  void selectSegment(String segmentId) {
    state = state.copyWith(activeSegmentId: segmentId);
  }

  /// 取消路段选择
  void clearSegment() {
    state = state.copyWith(clearActiveSegment: true);
  }
}

/// 全局播放状态 Provider
final playbackProvider = StateNotifierProvider<PlaybackNotifier, PlaybackState>(
  (ref) => PlaybackNotifier(),
);

/// GPS轨迹 Provider（由外部注入）
final gpsTrackProvider = StateProvider<GpsTrack?>((ref) => null);