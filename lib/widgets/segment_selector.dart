import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/route_segment.dart';

/// 路段选择器 - 横向滑动选择播放片段
class SegmentSelector extends ConsumerWidget {
  final List<RouteSegment> segments;
  final Function(RouteSegment) onSegmentSelected;
  final String? activeSegmentId;

  const SegmentSelector({
    super.key,
    required this.segments,
    required this.onSegmentSelected,
    this.activeSegmentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: segments.length,
        itemBuilder: (context, index) {
          final segment = segments[index];
          final isActive = segment.id == activeSegmentId;

          return GestureDetector(
            onTap: () => onSegmentSelected(segment),
            child: Container(
              width: 120,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? Colors.blue : Colors.grey.shade300,
                  width: isActive ? 3 : 1,
                ),
                color: isActive ? Colors.blue.shade50 : Colors.grey.shade100,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 缩略图占位
                  Container(
                    width: 80,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.play_circle_outline,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    segment.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? Colors.blue : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 路段播放控制按钮
class SegmentPlayButton extends ConsumerWidget {
  final RouteSegment segment;
  final bool isPlaying;
  final VoidCallback onTap;

  const SegmentPlayButton({
    super.key,
    required this.segment,
    this.isPlaying = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isPlaying ? Colors.blue : Colors.blue.shade600,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              segment.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}