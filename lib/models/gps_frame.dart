import 'package:latlong2/latlong.dart';

/// GPS帧数据 - 每一秒的GPS信息
class GpsFrame {
  final Duration timestamp;
  final LatLng position;
  final double speed;      // km/h
  final double heading;    // 度数 0-360

  const GpsFrame({
    required this.timestamp,
    required this.position,
    required this.speed,
    required this.heading,
  });

  /// 从JSON创建
  factory GpsFrame.fromJson(Map<String, dynamic> json) {
    return GpsFrame(
      timestamp: Duration(milliseconds: json['t'] as int),
      position: LatLng(
        json['lat'] as double,
        json['lng'] as double,
      ),
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    't': timestamp.inMilliseconds,
    'lat': position.latitude,
    'lng': position.longitude,
    'speed': speed,
    'heading': heading,
  };
}

/// GPS轨迹 - 完整的一条路线
class GpsTrack {
  final String id;
  final String name;
  final List<GpsFrame> frames;
  final DateTime recordedAt;

  const GpsTrack({
    required this.id,
    required this.name,
    required this.frames,
    required this.recordedAt,
  });

  /// 总时长
  Duration get duration =>
    frames.isEmpty ? Duration.zero : frames.last.timestamp;

  /// 起点
  LatLng get start => frames.first.position;

  /// 终点
  LatLng get end => frames.last.position;

  /// 获取所有轨迹点
  List<LatLng> get pathPoints =>
    frames.map((f) => f.position).toList();

  /// 根据视频时间查找对应的GPS帧（二分查找）
  GpsFrame? findFrameAtTime(Duration time) {
    if (frames.isEmpty) return null;

    int left = 0;
    int right = frames.length - 1;

    while (left < right) {
      final mid = (left + right) ~/ 2;
      if (frames[mid].timestamp < time) {
        left = mid + 1;
      } else {
        right = mid;
      }
    }

    // 返回最接近的帧
    if (left > 0) {
      final prev = frames[left - 1];
      final curr = frames[left];
      // 选择更接近的那个
      if ((time - prev.timestamp).abs() < (time - curr.timestamp).abs()) {
        return prev;
      }
    }
    return frames[left];
  }

  /// 根据GPS位置查找最近的时间戳
  Duration? findTimeAtPosition(LatLng target) {
    if (frames.isEmpty) return null;

    Duration? nearestTime;
    double minDistance = double.infinity;

    for (final frame in frames) {
      // 简单的距离计算（欧几里得近似）
      final dist = _distance(frame.position, target);
      if (dist < minDistance) {
        minDistance = dist;
        nearestTime = frame.timestamp;
      }
    }

    return nearestTime;
  }

  double _distance(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLng = a.longitude - b.longitude;
    return dLat * dLat + dLng * dLng;
  }
}