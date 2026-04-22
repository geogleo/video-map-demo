# 视频地图联动播放器 - 完整技术架构

## 系统架构

```
┌─────────────────────────────────────────────────────────────────┐
│                      视频地图行车记录 App                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │  录制端    │    │  存储层     │    │  播放端     │         │
│  │            │    │            │    │            │         │
│  │ 📹 摄像头  │───→│ 📁 本地JSON │───→│ 🎬 视频播放 │         │
│  │ 📍 GPS定位 │───→│ 🎥 视频文件 │───→│ 🗺️ 地图联动 │         │
│  │ ⏱️ 时间同步│    │ 📊 元数据  │    │ 🖱️ 点击跳转│         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 录制端架构

### 服务层

| 服务 | 文件 | 职责 |
|------|------|------|
| **VideoRecorderService** | `video_recorder.dart` | 摄像头初始化、视频录制控制 |
| **GpsRecorderService** | `gps_recorder.dart` | GPS采集、帧数据生成 |
| **RouteStorageService** | `route_recorder.dart` | 路线保存/加载/删除/导出 |

### 录制流程

```
[RecorderScreen]
    │
    ├── 初始化摄像头 ──→ CameraController.initialize()
    │
    ├── 点击录制按钮
    │       │
    │       ├── 视频流 ──→ startVideoRecording()
    │       │
    │       ├── GPS流 ──→ GpsRecorderService.start()
    │       │                  │
    │       │                  └── 每秒采集位置
    │       │
    │       └── 定时器 ──→ 更新录制时长UI
    │
    └── 停止录制
            │
            ├── 视频保存 ──→ stopVideoRecording() → MP4文件
            │
            ├── GPS导出 ──→ List<GpsFrame>
            │
            └── 元数据保存 ──→ RecordedRoute.toJson() → JSON文件
```

### GPS帧结构

```dart
class GpsFrame {
  Duration timestamp;  // 相对录制开始的时间偏移
  LatLng position;      // 经纬度
  double speed;         // km/h
  double heading;       // 方向角 0-360°
}
```

---

## 播放端架构

### 核心组件

| 组件 | 文件 | 职责 |
|------|------|------|
| **PlayerScreen** | `main.dart` | 主界面，协调视频和地图 |
| **VideoPlayerWidget** | `video_player_widget.dart` | 视频播放控制 |
| **InteractiveMapWidget** | `map_widget.dart` | 可点击地图，轨迹显示 |
| **SegmentSelector** | `segment_selector.dart` | 路段选择器 |

### 状态管理

```dart
// 播放状态
class PlaybackState {
  bool isPlaying;
  Duration currentPosition;
  Duration totalDuration;
  ViewMode viewMode;           // video/map/pip
  LatLng? currentPositionGps;   // 当前GPS位置
  double currentSpeed;         // 当前速度
  double currentHeading;       // 当前方向
  String? activeSegmentId;     // 当前选中路段
}
```

### 视频↔地图联动算法

```dart
// 1. 视频播放 → 地图跟随
videoController.addListener(() {
  final time = videoController.value.position;
  final gpsFrame = gpsTrack.findFrameAtTime(time);
  
  // 更新状态 → 地图自动监听并移动
  playbackNotifier.updatePosition(time, gpsFrame: gpsFrame);
});

// 2. 地图点击 → 视频跳转
mapWidget.onTap((latLng) {
  final time = gpsTrack.findTimeAtPosition(latLng);
  videoController.seekTo(time);
});

// 3. 路段选择 → 定点播放
segmentSelector.onSelect((segment) {
  videoController.seekTo(segment.startTime);
  videoController.play();
  
  // 到达终点自动暂停
  videoController.onReach(segment.endTime, () {
    videoController.pause();
  });
});
```

### 二分查找GPS帧

```dart
GpsFrame? findFrameAtTime(Duration targetTime) {
  if (frames.isEmpty) return null;
  
  int left = 0, right = frames.length - 1;
  while (left < right) {
    int mid = (left + right) ~/ 2;
    if (frames[mid].timestamp < targetTime) {
      left = mid + 1;
    } else {
      right = mid;
    }
  }
  
  // 选择最接近的帧
  if (left > 0) {
    final prev = frames[left - 1];
    final curr = frames[left];
    return (targetTime - prev.timestamp).abs() < 
           (targetTime - curr.timestamp).abs() 
         ? prev : curr;
  }
  return frames[left];
}
```

---

## 数据存储

### 文件结构

```
/data/user/.../app_flutter/video_routes/
├── route_1713782400000.json    # 元数据
├── route_1713782400000.mp4     # 视频文件
├── route_1713782400000.gpx     # GPX导出（可选）
├── route_1713782500000.json
├── route_1713782500000.mp4
└── ...
```

### 元数据格式

```json
{
  "id": "route_1713782400000",
  "name": "行车记录 2024-04-22 14:30",
  "videoPath": "/data/.../route_1713782400000.mp4",
  "gpsTrack": {
    "id": "gps_1713782400000",
    "name": "GPS轨迹",
    "frames": [
      { "t": 0, "lat": 37.7749, "lng": -122.4194, "speed": 0, "heading": 0 },
      { "t": 1000, "lat": 37.7750, "lng": -122.4195, "speed": 30, "heading": 45 }
    ],
    "recordedAt": "2024-04-22T14:30:00.000Z"
  },
  "segments": [
    { "id": "seg_001", "name": "起点", "startTime": 0, "endTime": 30000 }
  ],
  "recordedAt": "2024-04-22T14:30:00.000Z",
  "duration": 300
}
```

---

## 权限配置

### Android (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS (Info.plist)

```xml
<key>NSCameraUsageDescription</key>
<string>需要使用摄像头录制行车视频</string>

<key>NSMicrophoneUsageDescription</key>
<string>需要使用麦克风录制行车视频的声音</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>需要获取位置信息以记录行车轨迹</string>
```

---

## 运行指南

### 安装依赖

```bash
cd video-map-demo
flutter pub get
```

### 运行应用

```bash
flutter run
```

### 测试功能

1. **录制测试**：点击"开始录制"，移动模拟GPS位置
2. **播放测试**：使用"播放演示"体验示例数据
3. **联动测试**：拖拽视频进度条，观察地图跟随

---

## 扩展方向

### 短期

- [ ] 接入 geolocator 获取真实GPS
- [ ] 后台录制保活
- [ ] 自动路段分割（根据速度变化）

### 中期

- [ ] 云端同步（Firebase/自建服务）
- [ ] 多设备协同（车机+手机）
- [ ] 语音标注路段

### 长期

- [ ] AI识别路况（红绿灯、限速）
- [ ] 社区路段分享
- [ ] 3D地图视角