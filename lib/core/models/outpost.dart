import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

part 'outpost.g.dart';

/// Types of outposts that can be built
@HiveType(typeId: 3)
enum OutpostType {
  @HiveField(0)
  tradingPost,    // Produces trade goods

  @HiveField(1)
  warehouse,      // Increases storage capacity

  @HiveField(2)
  workshop,       // Produces materials

  @HiveField(3)
  inn,            // Recovers energy

  @HiveField(4)
  bank,           // Generates passive gold

  @HiveField(5)
  scoutTower,     // Reveals nearby streets
}

/// Represents a player-built outpost
@HiveType(typeId: 2)
class Outpost extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double lat;

  @HiveField(3)
  double lng;

  @HiveField(4)
  OutpostType type;

  @HiveField(5)
  int level;

  @HiveField(6)
  DateTime builtAt;

  @HiveField(7)
  DateTime lastCollectedAt;

  Outpost({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    this.level = 1,
    DateTime? builtAt,
    DateTime? lastCollectedAt,
  })  : builtAt = builtAt ?? DateTime.now(),
        lastCollectedAt = lastCollectedAt ?? DateTime.now();

  /// Get location as LatLng
  LatLng get location => LatLng(lat, lng);

  /// Get display icon for outpost type
  String get icon {
    switch (type) {
      case OutpostType.tradingPost:
        return '🏪';
      case OutpostType.warehouse:
        return '🏭';
      case OutpostType.workshop:
        return '⚒️';
      case OutpostType.inn:
        return '🏨';
      case OutpostType.bank:
        return '🏦';
      case OutpostType.scoutTower:
        return '🗼';
    }
  }

  /// Get production rate per hour based on type and level
  int get productionPerHour {
    final base = switch (type) {
      OutpostType.tradingPost => 5,
      OutpostType.warehouse => 0, // Storage, no production
      OutpostType.workshop => 3,
      OutpostType.inn => 10,
      OutpostType.bank => 2,
      OutpostType.scoutTower => 0, // Passive ability, no production
    };
    return base * level;
  }

  /// Get build/upgrade cost
  static int getCost(OutpostType type, int level) {
    final baseCost = switch (type) {
      OutpostType.tradingPost => 500,
      OutpostType.warehouse => 800,
      OutpostType.workshop => 600,
      OutpostType.inn => 400,
      OutpostType.bank => 1000,
      OutpostType.scoutTower => 700,
    };
    return baseCost * level;
  }

  /// Calculate accumulated resources since last collection
  int calculateAccumulatedResources() {
    final hoursSinceCollection = 
        DateTime.now().difference(lastCollectedAt).inMinutes / 60.0;
    return (productionPerHour * hoursSinceCollection).floor();
  }

  /// Collect resources and reset timer
  int collectResources() {
    final amount = calculateAccumulatedResources();
    lastCollectedAt = DateTime.now();
    return amount;
  }
}
