import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import '../models/gps_frame.dart';
import '../models/route_segment.dart';
import 'route_recorder.dart';

/// 云端同步服务
class CloudSyncService {
  final Dio _dio;
  final String baseUrl;

  CloudSyncService({
    required this.baseUrl,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  /// 初始化
  void init({String? authToken}) {
    _dio.options.baseUrl = baseUrl;
    if (authToken != null) {
      _dio.options.headers['Authorization'] = 'Bearer $authToken';
    }
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  /// 上传路线
  Future<UploadResult> uploadRoute(RecordedRoute route, {
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      // 1. 上传视频文件
      final videoFile = File(route.videoPath);
      final videoName = p.basename(route.videoPath);
      
      final formData = FormData.fromMap({
        'video': await MultipartFile.fromFile(
          route.videoPath,
          filename: videoName,
        ),
        'metadata': {
          'id': route.id,
          'name': route.name,
          'gpsTrack': {
            'id': route.gpsTrack.id,
            'name': route.gpsTrack.name,
            'frames': route.gpsTrack.frames.map((f) => f.toJson()).toList(),
            'recordedAt': route.gpsTrack.recordedAt.toIso8601String(),
          },
          'duration': route.duration.inSeconds,
          'recordedAt': route.recordedAt.toIso8601String(),
        },
      });

      final response = await _dio.post(
        '/api/routes/upload',
        data: formData,
        onSendProgress: onProgress,
      );

      if (response.statusCode == 200) {
        return UploadResult.success(
          routeId: response.data['routeId'],
          videoUrl: response.data['videoUrl'],
        );
      }

      return UploadResult.failure(response.data['error'] ?? '上传失败');
    } on DioException catch (e) {
      return UploadResult.failure(_handleDioError(e));
    } catch (e) {
      return UploadResult.failure('上传失败: $e');
    }
  }

  /// 获取云端路线列表
  Future<List<CloudRoute>> getRoutes({int page = 1, int limit = 20}) async {
    try {
      final response = await _dio.get('/api/routes', queryParameters: {
        'page': page,
        'limit': limit,
      });

      final routes = (response.data['routes'] as List)
          .map((json) => CloudRoute.fromJson(json))
          .toList();

      return routes;
    } on DioException catch (e) {
      debugPrint('获取路线失败: ${e.message}');
      return [];
    }
  }

  /// 下载路线
  Future<RecordedRoute?> downloadRoute(String routeId, {
    required String savePath,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      // 获取路线信息
      final infoResponse = await _dio.get('/api/routes/$routeId');
      final metadata = infoResponse.data;

      // 下载视频
      final videoUrl = metadata['videoUrl'];
      final videoPath = '$savePath/${routeId}.mp4';

      await _dio.download(
        videoUrl,
        videoPath,
        onReceiveProgress: onProgress,
      );

      // 构建本地路线对象
      final gpsJson = metadata['gpsTrack'];
      return RecordedRoute(
        id: routeId,
        name: metadata['name'],
        videoPath: videoPath,
        gpsTrack: GpsTrack(
          id: gpsJson['id'],
          name: gpsJson['name'],
          frames: (gpsJson['frames'] as List)
              .map((f) => GpsFrame.fromJson(f))
              .toList(),
          recordedAt: DateTime.parse(gpsJson['recordedAt']),
        ),
        segments: (metadata['segments'] as List?)
            ?.map((s) => RouteSegment.fromJson(s))
            .toList() ?? [],
        recordedAt: DateTime.parse(metadata['recordedAt']),
        duration: Duration(seconds: metadata['duration']),
      );
    } catch (e) {
      debugPrint('下载路线失败: $e');
      return null;
    }
  }

  /// 删除云端路线
  Future<bool> deleteRoute(String routeId) async {
    try {
      final response = await _dio.delete('/api/routes/$routeId');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('删除路线失败: $e');
      return false;
    }
  }

  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时';
      case DioExceptionType.sendTimeout:
        return '发送超时';
      case DioExceptionType.receiveTimeout:
        return '接收超时';
      case DioExceptionType.badResponse:
        return '服务器错误: ${e.response?.statusCode}';
      default:
        return '网络错误: ${e.message}';
    }
  }
}

/// 上传结果
class UploadResult {
  final bool success;
  final String? error;
  final String? routeId;
  final String? videoUrl;

  const UploadResult._({
    required this.success,
    this.error,
    this.routeId,
    this.videoUrl,
  });

  factory UploadResult.success({required String routeId, required String videoUrl}) {
    return UploadResult._(success: true, routeId: routeId, videoUrl: videoUrl);
  }

  factory UploadResult.failure(String error) {
    return UploadResult._(success: false, error: error);
  }
}

/// 云端路线模型
class CloudRoute {
  final String id;
  final String name;
  final String videoUrl;
  final String? thumbnailUrl;
  final Duration duration;
  final DateTime recordedAt;
  final String userId;

  const CloudRoute({
    required this.id,
    required this.name,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.duration,
    required this.recordedAt,
    required this.userId,
  });

  factory CloudRoute.fromJson(Map<String, dynamic> json) {
    return CloudRoute(
      id: json['id'],
      name: json['name'],
      videoUrl: json['videoUrl'],
      thumbnailUrl: json['thumbnailUrl'],
      duration: Duration(seconds: json['duration']),
      recordedAt: DateTime.parse(json['recordedAt']),
      userId: json['userId'],
    );
  }
}

/// 同步状态
class SyncState {
  final bool isUploading;
  final bool isDownloading;
  final int progress;
  final int total;
  final String statusText;
  final String? error;

  const SyncState({
    this.isUploading = false,
    this.isDownloading = false,
    this.progress = 0,
    this.total = 0,
    this.statusText = '',
    this.error,
  });

  double get progressPercent => total > 0 ? progress / total : 0;

  SyncState copyWith({
    bool? isUploading,
    bool? isDownloading,
    int? progress,
    int? total,
    String? statusText,
    String? error,
    bool clearError = false,
  }) {
    return SyncState(
      isUploading: isUploading ?? this.isUploading,
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      total: total ?? this.total,
      statusText: statusText ?? this.statusText,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 同步状态管理
class SyncNotifier extends StateNotifier<SyncState> {
  final CloudSyncService _service;
  SyncNotifier(this._service) : super(const SyncState());

  /// 上传路线
  Future<bool> uploadRoute(RecordedRoute route) async {
    state = state.copyWith(isUploading: true, clearError: true);

    final result = await _service.uploadRoute(
      route,
      onProgress: (sent, total) {
        state = state.copyWith(
          progress: sent,
          total: total,
          statusText: '上传中 ${(sent / 1024 / 1024).toStringAsFixed(1)}MB / ${(total / 1024 / 1024).toStringAsFixed(1)}MB',
        );
      },
    );

    state = state.copyWith(
      isUploading: false,
      clearError: !result.success,
      error: result.success ? null : result.error,
    );

    return result.success;
  }

  /// 下载路线
  Future<RecordedRoute?> downloadRoute(String routeId, String savePath) async {
    state = state.copyWith(isDownloading: true, clearError: true);

    final route = await _service.downloadRoute(
      routeId,
      savePath: savePath,
      onProgress: (received, total) {
        state = state.copyWith(
          progress: received,
          total: total,
          statusText: '下载中 ${(received / 1024 / 1024).toStringAsFixed(1)}MB / ${(total / 1024 / 1024).toStringAsFixed(1)}MB',
        );
      },
    );

    state = state.copyWith(
      isDownloading: false,
      clearError: true,
    );

    return route;
  }

  /// 获取云端路线列表
  Future<List<CloudRoute>> getCloudRoutes() async {
    return await _service.getRoutes();
  }
}

/// Provider
final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  return CloudSyncService(
    baseUrl: 'https://api.example.com', // 替换为实际API地址
  );
});

final syncProvider =
    StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref.read(cloudSyncServiceProvider));
});