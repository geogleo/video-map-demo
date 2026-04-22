/// 路段 - 可以选择播放的片段
class RouteSegment {
  final String id;
  final String name;
  final String? description;
  final Duration startTime;
  final Duration endTime;
  final String? thumbnailUrl;

  const RouteSegment({
    required this.id,
    required this.name,
    this.description,
    required this.startTime,
    required this.endTime,
    this.thumbnailUrl,
  });

  Duration get duration => endTime - startTime;

  factory RouteSegment.fromJson(Map<String, dynamic> json) {
    return RouteSegment(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      startTime: Duration(milliseconds: json['startTime'] as int),
      endTime: Duration(milliseconds: json['endTime'] as int),
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }
}