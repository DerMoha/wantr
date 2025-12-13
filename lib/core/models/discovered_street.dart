import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

part 'discovered_street.g.dart';

/// Represents a discovered street segment
@HiveType(typeId: 1)
class DiscoveredStreet extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  double startLat;

  @HiveField(2)
  double startLng;

  @HiveField(3)
  double endLat;

  @HiveField(4)
  double endLng;

  @HiveField(5)
  String? streetName;

  @HiveField(6)
  int timesWalked;

  @HiveField(7)
  DateTime firstDiscoveredAt;

  @HiveField(8)
  DateTime lastWalkedAt;

  DiscoveredStreet({
    required this.id,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    this.streetName,
    this.timesWalked = 1,
    DateTime? firstDiscoveredAt,
    DateTime? lastWalkedAt,
  })  : firstDiscoveredAt = firstDiscoveredAt ?? DateTime.now(),
        lastWalkedAt = lastWalkedAt ?? DateTime.now();

  /// Get street state based on times walked
  StreetState get state {
    if (timesWalked >= 50) return StreetState.legendary;
    if (timesWalked >= 10) return StreetState.mastered;
    return StreetState.discovered;
  }

  /// Get start point as LatLng
  LatLng get startPoint => LatLng(startLat, startLng);

  /// Get end point as LatLng
  LatLng get endPoint => LatLng(endLat, endLng);

  /// Get list of points for drawing
  List<LatLng> get points => [startPoint, endPoint];

  /// Increment walk count
  void recordWalk() {
    timesWalked++;
    lastWalkedAt = DateTime.now();
  }
}

/// Street discovery states matching the design document
enum StreetState {
  unexplored,  // Gray - not yet visited
  discovered,  // Yellow - walked at least once
  mastered,    // Golden - walked 10+ times
  legendary,   // Animated gold - walked 50+ times
}
