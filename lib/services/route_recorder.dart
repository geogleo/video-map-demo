import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/gps_frame.dart';
import '../models/route_segment.dart';

/// 录制数据 - 包含视频和GPS轨迹
class RecordedRoute {
  final String id;
  final String name;
  final String videoPath;
  final GpsTrack gpsTrack;
  final List<RouteSegment> segments;
  final DateTime recordedAt;
  final Duration duration;

  const RecordedRoute({
    required this.id,
    required this.name,
    required this.videoPath,
    required this.gpsTrack,
    this.segments = const [],
    required this.recordedAt,
    required this.duration,
  });

  /// 转换为JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'videoPath': videoPath,
    'gpsTrack': {
      'id': gpsTrack.id,
      'name': gpsTrack.name,
      'frames': gpsTrack.frames.map((f) => f.toJson()).toList(),
      'recordedAt': gpsTrack.recordedAt.toIso8601String(),
    },
    'segments': segments.map((s) => {
      'id': s.id,
      'name': s.name,
      'description': s.description,
      'startTime': s.startTime.inMilliseconds,
      'endTime': s.endTime.inMilliseconds,
    }).toList(),
    'recordedAt': recordedAt.toIso8601String(),
    'duration': duration.inSeconds,
  };

  /// 从JSON创建
  factory RecordedRoute.fromJson(Map<String, dynamic> json) {
    final gpsJson = json['gpsTrack'] as Map<String, dynamic>;
    final framesJson = gpsJson['frames'] as List;

    return RecordedRoute(
      id: json['id'] as String,
      name: json['name'] as String,
      videoPath: json['videoPath'] as String,
      gpsTrack: GpsTrack(
        id: gpsJson['id'] as String,
        name: gpsJson['name'] as String,
        frames: framesJson
          .map((f) => GpsFrame.fromJson(f as Map<String, dynamic>))
          .toList(),
        recordedAt: DateTime.parse(gpsJson['recordedAt'] as String),
      ),
      segments: (json['segments'] as List)
        .map((s) => RouteSegment.fromJson(s as Map<String, dynamic>))
        .toList(),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      duration: Duration(seconds: json['duration'] as int),
    );
  }
}

/// 路线存储服务
class RouteStorageService {
  /// 保存录制的路线
  Future<String> saveRoute(RecordedRoute route) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final routesDir = Directory('${directory.path}/video_routes');
      if (!await routesDir.exists()) {
        await routesDir.create(recursive: true);
      }

      // 保存元数据JSON
      final jsonPath = '${routesDir.path}/${route.id}.json';
      final jsonFile = File(jsonPath);
      await jsonFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(route.toJson()),
      );

      debugPrint('Route saved: $jsonPath');
      return jsonPath;
    } catch (e) {
      debugPrint('Save route error: $e');
      rethrow;
    }
  }

  /// 加载路线
  Future<RecordedRoute?> loadRoute(String id) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final jsonPath = '${directory.path}/video_routes/$id.json';
      final jsonFile = File(jsonPath);

      if (!await jsonFile.exists()) {
        return null;
      }

      final json = jsonDecode(await jsonFile.readAsString());
      return RecordedRoute.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Load route error: $e');
      return null;
    }
  }

  /// 列出所有路线
  Future<List<RecordedRoute>> listRoutes() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final routesDir = Directory('${directory.path}/video_routes');

      if (!await routesDir.exists()) {
        return [];
      }

      final files = await routesDir
        .list()
        .where((f) => f.path.endsWith('.json'))
        .toList();

      final routes = <RecordedRoute>[];
      for (final file in files) {
        final json = jsonDecode(await File(file.path).readAsString());
        routes.add(RecordedRoute.fromJson(json as Map<String, dynamic>));
      }

      // 按录制时间排序（最新在前）
      routes.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      return routes;
    } catch (e) {
      debugPrint('List routes error: $e');
      return [];
    }
  }

  /// 删除路线
  Future<bool> deleteRoute(String id) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final jsonPath = '${directory.path}/video_routes/$id.json';
      final jsonFile = File(jsonPath);

      if (await jsonFile.exists()) {
        await jsonFile.delete();
      }

      return true;
    } catch (e) {
      debugPrint('Delete route error: $e');
      return false;
    }
  }

  /// 导出为GPX格式
  Future<String?> exportGpx(RecordedRoute route) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
      buffer.writeln('<gpx version="1.1" creator="VideoMapDemo">');
      buffer.writeln('  <trk>');
      buffer.writeln('    <name>${route.name}</name>');
      buffer.writeln('    <trkseg>');

      for (final frame in route.gpsTrack.frames) {
        buffer.writeln('      <trkpt lat="${frame.position.latitude}" lon="${frame.position.longitude}">');
        buffer.writeln('        <time>${route.recordedAt.add(frame.timestamp).toIso8601String()}</time>');
        buffer.writeln('        <speed>${frame.speed}</speed>');
        buffer.writeln('      </trkpt>');
      }

      buffer.writeln('    </trkseg>');
      buffer.writeln('  </trk>');
      buffer.writeln('</gpx>');

      final gpxPath = '${route.videoPath.replaceAll('.mp4', '.gpx')}';
      await File(gpxPath).writeAsString(buffer.toString());
      return gpxPath;
    } catch (e) {
      debugPrint('Export GPX error: $e');
      return null;
    }
  }
}