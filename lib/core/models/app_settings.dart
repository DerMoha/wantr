import 'package:hive_flutter/hive_flutter.dart';

part 'app_settings.g.dart';

/// GPS update frequency mode
enum GpsMode {
  batterySaver, // 10m distance, 5s interval
  balanced,     // 5m distance, 3s interval
  highAccuracy, // 3m distance, 2s interval
}

/// App settings stored in Hive
@HiveType(typeId: 5)
class AppSettings extends HiveObject {
  @HiveField(0)
  int gpsModeIndex;

  @HiveField(1)
  bool showDebugInfo;

  AppSettings({
    this.gpsModeIndex = 0, // Default to batterySaver
    this.showDebugInfo = false,
  });

  GpsMode get gpsMode => GpsMode.values[gpsModeIndex];
  set gpsMode(GpsMode mode) => gpsModeIndex = mode.index;

  /// Get distance filter based on mode
  int get distanceFilter => switch (gpsMode) {
    GpsMode.batterySaver => 10,
    GpsMode.balanced => 5,
    GpsMode.highAccuracy => 3,
  };

  /// Get update interval based on mode  
  Duration get updateInterval => switch (gpsMode) {
    GpsMode.batterySaver => const Duration(seconds: 5),
    GpsMode.balanced => const Duration(seconds: 3),
    GpsMode.highAccuracy => const Duration(seconds: 2),
  };

  /// Human-readable mode name
  String get gpsModeLabel => switch (gpsMode) {
    GpsMode.batterySaver => 'Battery Saver',
    GpsMode.balanced => 'Balanced',
    GpsMode.highAccuracy => 'High Accuracy',
  };

  /// Mode description
  String get gpsModeDescription => switch (gpsMode) {
    GpsMode.batterySaver => 'Updates every 10m - Best battery life',
    GpsMode.balanced => 'Updates every 5m - Good balance',
    GpsMode.highAccuracy => 'Updates every 3m - Smoothest, drains battery',
  };
}
