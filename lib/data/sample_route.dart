import '../models/gps_frame.dart';
import '../models/route_segment.dart';

/// 示例路线数据 - 旧金山金门大桥附近
class SampleRoute {
  static GpsTrack createSampleTrack() {
    // 模拟一条路线：从渔人码头到金门大桥
    final frames = <GpsFrame>[];
    final baseTime = DateTime.now();

    // 路线点（简化版）
    final routePoints = [
      // 起点：渔人码头
      {'lat': 37.8080, 'lng': -122.4177, 'speed': 0},
      {'lat': 37.8090, 'lng': -122.4180, 'speed': 30},
      {'lat': 37.8100, 'lng': -122.4185, 'speed': 45},
      {'lat': 37.8110, 'lng': -122.4190, 'speed': 50},
      // 沿海岸北上
      {'lat': 37.8150, 'lng': -122.4200, 'speed': 55},
      {'lat': 37.8200, 'lng': -122.4220, 'speed': 60},
      {'lat': 37.8250, 'lng': -122.4240, 'speed': 60},
      // Presidio
      {'lat': 37.7900, 'lng': -122.4440, 'speed': 45},
      {'lat': 37.7950, 'lng': -122.4480, 'speed': 50},
      {'lat': 37.8000, 'lng': -122.4520, 'speed': 55},
      // 金门大桥入口
      {'lat': 37.8060, 'lng': -122.4650, 'speed': 40},
      {'lat': 37.8070, 'lng': -122.4700, 'speed': 35},
      // 金门大桥
      {'lat': 37.8120, 'lng': -122.4750, 'speed': 50},
      {'lat': 37.8150, 'lng': -122.4800, 'speed': 55},
      {'lat': 37.8200, 'lng': -122.4850, 'speed': 55},
      // 北端
      {'lat': 37.8250, 'lng': -122.4900, 'speed': 45},
      {'lat': 37.8300, 'lng': -122.4950, 'speed': 40},
      {'lat': 37.8350, 'lng': -122.5000, 'speed': 0},
    ];

    // 生成GPS帧（每5秒一个点）
    for (var i = 0; i < routePoints.length; i++) {
      final point = routePoints[i];
      frames.add(GpsFrame(
        timestamp: Duration(seconds: i * 5),
        position: LatLng(point['lat'] as double, point['lng'] as double),
        speed: (point['speed'] as num).toDouble(),
        heading: _calculateHeading(i, routePoints),
      ));
    }

    return GpsTrack(
      id: 'route_001',
      name: '渔人码头 → 金门大桥',
      frames: frames,
      recordedAt: baseTime,
    );
  }

  static double _calculateHeading(int index, List<Map<String, dynamic>> points) {
    if (index >= points.length - 1) return 0;
    final curr = points[index];
    final next = points[index + 1];
    final dLat = (next['lat'] as double) - (curr['lat'] as double);
    final dLng = (next['lng'] as double) - (curr['lng'] as double);
    // 简化的航向计算
    return (90 + (dLat * 10 + dLng * 5)) % 360;
  }

  static List<RouteSegment> createSampleSegments() {
    return [
      const RouteSegment(
        id: 'seg_001',
        name: '起点出发',
        description: '渔人码头起步',
        startTime: Duration(seconds: 0),
        endTime: Duration(seconds: 20),
      ),
      const RouteSegment(
        id: 'seg_002',
        name: '海岸公路',
        description: '沿太平洋海岸北上',
        startTime: Duration(seconds: 20),
        endTime: Duration(seconds: 40),
      ),
      const RouteSegment(
        id: 'seg_003',
        name: 'Presidio',
        description: '穿越军事公园',
        startTime: Duration(seconds: 40),
        endTime: Duration(seconds: 55),
      ),
      const RouteSegment(
        id: 'seg_004',
        name: '金门大桥',
        description: '跨海大桥风光',
        startTime: Duration(seconds: 55),
        endTime: Duration(seconds: 75),
      ),
      const RouteSegment(
        id: 'seg_005',
        name: '抵达终点',
        description: '马林县终点',
        startTime: Duration(seconds: 75),
        endTime: Duration(seconds: 90),
      ),
    ];
  }
}