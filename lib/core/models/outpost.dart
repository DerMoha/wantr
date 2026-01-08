import 'dart:math';

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
  /// Maximum level an outpost can reach
  static const int maxLevel = 10;

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

  /// Get required player level to unlock this outpost type
  static int getRequiredLevel(OutpostType type) {
    return switch (type) {
      OutpostType.tradingPost => 1,  // Available from start
      OutpostType.warehouse => 3,
      OutpostType.bank => 5,
      OutpostType.workshop => 8,
      OutpostType.inn => 12,
      OutpostType.scoutTower => 15,
    };
  }

  /// Check if outpost type is unlocked at given player level
  static bool isUnlocked(OutpostType type, int playerLevel) {
    return playerLevel >= getRequiredLevel(type);
  }

  /// Get icon for outpost type (static version)
  static String getIcon(OutpostType type) {
    return switch (type) {
      OutpostType.tradingPost => '🏪',
      OutpostType.warehouse => '🏭',
      OutpostType.workshop => '⚒️',
      OutpostType.inn => '🏨',
      OutpostType.bank => '🏦',
      OutpostType.scoutTower => '🗼',
    };
  }

  /// Get type name (static version)
  static String getTypeName(OutpostType type) {
    return switch (type) {
      OutpostType.tradingPost => 'Trading Post',
      OutpostType.warehouse => 'Warehouse',
      OutpostType.workshop => 'Workshop',
      OutpostType.inn => 'Inn',
      OutpostType.bank => 'Bank',
      OutpostType.scoutTower => 'Scout Tower',
    };
  }

  /// Get type description
  static String getTypeDescription(OutpostType type) {
    return switch (type) {
      OutpostType.tradingPost => 'Produces trade goods over time',
      OutpostType.warehouse => 'Increases storage capacity',
      OutpostType.workshop => 'Produces materials for crafting',
      OutpostType.inn => 'Restores energy over time',
      OutpostType.bank => 'Generates passive gold income',
      OutpostType.scoutTower => 'Reveals nearby streets',
    };
  }

  /// Maximum accumulation (cap at 24 hours of production)
  int get maxAccumulation => productionPerHour * 24;

  /// Calculate accumulated resources since last collection (capped at 24 hours)
  int calculateAccumulatedResources() {
    if (productionPerHour == 0) return 0;
    final hoursSinceCollection =
        DateTime.now().difference(lastCollectedAt).inMinutes / 60.0;
    return min((productionPerHour * hoursSinceCollection).floor(), maxAccumulation);
  }

  /// Collect resources and reset timer
  int collectResources() {
    final amount = calculateAccumulatedResources();
    lastCollectedAt = DateTime.now();
    return amount;
  }

  /// Check if resources are ready to collect
  bool get hasResourcesToCollect => calculateAccumulatedResources() > 0;

  /// Get gold cost for upgrading to next level
  static int getUpgradeGoldCost(OutpostType type, int currentLevel) {
    return getCost(type, currentLevel + 1);
  }

  /// Get trade goods cost for upgrading
  static int getUpgradeTradeGoodsCost(int currentLevel) {
    return currentLevel * 10;
  }

  /// Human-readable type name
  String get typeName => switch (type) {
    OutpostType.tradingPost => 'Trading Post',
    OutpostType.warehouse => 'Warehouse',
    OutpostType.workshop => 'Workshop',
    OutpostType.inn => 'Inn',
    OutpostType.bank => 'Bank',
    OutpostType.scoutTower => 'Scout Tower',
  };

  /// Production description for display
  String get productionDescription => switch (type) {
    OutpostType.tradingPost => '+$productionPerHour goods/hr',
    OutpostType.warehouse => '+${500 * level} capacity',
    OutpostType.workshop => '+$productionPerHour materials/hr',
    OutpostType.inn => '+$productionPerHour energy/hr',
    OutpostType.bank => '+$productionPerHour gold/hr',
    OutpostType.scoutTower => 'Reveals nearby streets',
  };
}
