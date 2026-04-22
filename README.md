# 🚗 Video Map Demo - 视频地图行车记录

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter)
![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-lightgrey?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

**跨平台行车视频记录 App，类似谷歌街景的交互体验**

[功能特性](#-功能特性) · [快速开始](#-快速开始) · [技术架构](#-技术架构) · [贡献指南](#-贡献指南)

</div>

---

## ✨ 功能特性

| 功能 | 说明 |
|------|------|
| 📹 **视频录制** | 摄像头实时录制，支持暂停/继续，高清画质 |
| 📍 **真实GPS** | 使用 geolocator 获取精确位置，每秒更新 |
| 🔄 **后台保活** | Android 前台服务，锁屏后继续录制 |
| 🗺️ **地图联动** | 视频播放时地图自动跟随，类似街景体验 |
| 🖱️ **点击跳转** | 点击地图任意位置，视频自动跳转到对应时刻 |
| 📦 **路段选择** | 选择特定路段（如金门大桥段）定点播放 |
| ☁️ **云端同步** | 上传/下载路线数据，多设备共享 |
| 💾 **本地存储** | 视频+GPS数据本地保存，离线可用 |
| 📤 **GPX导出** | 可导出GPS轨迹为GPX格式，兼容其他地图软件 |

---

## 📱 界面预览

```
┌─────────────────────────────────────┐
│  首页                               │
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐   │
│  │ 🔴 开始录制 (增强版)        │   │
│  │    真实GPS + 后台保活       │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ 📚 历史记录                 │   │
│  │    查看和播放已录制行程     │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ ☁️ 云端同步                  │   │
│  │    上传/下载路线数据        │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ ▶️ 播放演示                  │   │
│  │    体验地图联动播放          │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

---

## 🚀 快速开始

### 前置要求

- Flutter SDK 3.x
- Android Studio / Xcode
- iOS 12.0+ / Android 5.0+

### 安装步骤

```bash
# 1. 克隆仓库
git clone https://github.com/geogleo/video-map-demo.git
cd video-map-demo

# 2. 安装依赖
flutter pub get

# 3. 运行应用
flutter run
```

### 权限说明

**首次运行需要授权：**

| 权限 | 用途 |
|------|------|
| 📷 摄像头 | 录制行车视频 |
| 🎤 麦克风 | 录制行车音频 |
| 📍 GPS定位 | 记录行车轨迹 |
| 📁 存储 | 保存视频和GPS数据 |
| 🔋 后台定位 | 锁屏后继续录制 |

---

## 🏗️ 技术架构

### 项目结构

```
video-map-demo/
├── lib/
│   ├── app.dart                    # 应用入口
│   ├── main.dart                   # 播放器主界面
│   ├── models/                     # 数据模型
│   │   ├── gps_frame.dart          # GPS帧
│   │   └── route_segment.dart      # 路段
│   ├── services/                   # 服务层
│   │   ├── real_gps_service.dart   # 真实GPS
│   │   ├── background_service.dart # 后台保活
│   │   ├── cloud_sync_service.dart# 云端同步
│   │   ├── gps_recorder.dart       # GPS录制
│   │   ├── video_recorder.dart     # 视频录制
│   │   └── route_recorder.dart    # 路线存储
│   ├── screens/                    # 界面
│   │   ├── enhanced_recorder_screen.dart
│   │   ├── history_screen.dart
│   │   └── cloud_sync_screen.dart
│   ├── widgets/                    # 组件
│   │   ├── map_widget.dart
│   │   ├── video_player_widget.dart
│   │   └── segment_selector.dart
│   └── providers/                  # 状态管理
│       └── playback_state.dart
├── android/                        # Android配置
├── ios/                           # iOS配置
└── pubspec.yaml                   # 依赖配置
```

### 技术栈

| 类别 | 技术 | 用途 |
|------|------|------|
| **框架** | Flutter 3.x | 跨平台UI |
| **状态管理** | Riverpod | 全局状态 |
| **地图** | flutter_map + OSM | 矢量地图 |
| **视频播放** | video_player | 视频控制 |
| **视频录制** | camera | 摄像头 |
| **GPS定位** | geolocator | 精确定位 |
| **后台服务** | foreground service | Android保活 |
| **网络请求** | dio | 云端同步 |

### 核心交互

```
┌─────────────────────────────────────────────────┐
│              视频 ↔ 地图 双向联动               │
├─────────────────────────────────────────────────┤
│                                                 │
│   [视频播放] ──────时间同步──────→ [地图跟随]   │
│       ↑                              │          │
│       │                              ↓          │
│   [视频跳转] ←─────位置查找────── [地图点击]   │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## 📖 使用指南

### 录制行车视频

1. 点击「开始录制」
2. 授权摄像头和GPS权限
3. 开始行车，App自动记录视频+轨迹
4. 可暂停/继续录制
5. 点击停止，自动保存

### 播放与地图联动

1. 进入「历史记录」选择路线
2. 视频播放时，地图自动跟随当前位置
3. 拖动视频进度条，地图同步移动
4. 点击地图任意位置，视频跳转到对应时刻
5. 选择「路段」，定点播放精彩片段

### 云端同步

1. 进入「云端同步」
2. 本地路线点击「上传」同步到云端
3. 云端路线点击「下载」保存到本地
4. 多设备共享行车记录

---

## 🔧 扩展功能

### 导出GPX轨迹

```dart
final storage = RouteStorageService();
await storage.exportGpx(route);
// 生成 .gpx 文件，可在 Google Earth 等软件中打开
```

### 自定义路段

```dart
final segment = RouteSegment(
  id: 'seg_001',
  name: '金门大桥段',
  startTime: Duration(minutes: 5),
  endTime: Duration(minutes: 10),
);
```

---

## 🤝 贡献指南

欢迎贡献代码！请查看 [CONTRIBUTING.md](CONTRIBUTING.md)

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交 Pull Request

---

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

---

## 🙏 致谢

- [flutter_map](https://github.com/fleaflet/flutter_map) - 优秀的Flutter地图库
- [geolocator](https://pub.dev/packages/geolocator) - 跨平台GPS定位
- [camera](https://pub.dev/packages/camera) - Flutter摄像头插件

---

<div align="center">

**⭐ 如果这个项目对你有帮助，请给一个 Star！**

Made with ❤️ by Geogleo[David Liao]

</div>
