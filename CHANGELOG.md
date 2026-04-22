# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2024-04-22

### Added
- Initial release
- 📹 Video recording with camera
- 📍 Real GPS tracking using geolocator
- 🗺️ Interactive map with route trajectory
- 🔄 Video-Map bidirectional sync
  - Video playback → Map follows position
  - Map click → Video seeks to location
- 📦 Route segment selection and playback
- 🌙 Background recording support (Android)
- ☁️ Cloud sync service foundation
- 💾 Local storage for routes
- 📤 GPX export support
- 🎛️ Three view modes: Video/Map/PiP

### Technical
- Flutter 3.x cross-platform framework
- Riverpod state management
- flutter_map with OpenStreetMap
- geolocator for GPS positioning
- camera package for video recording
- dio for network requests

---

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).