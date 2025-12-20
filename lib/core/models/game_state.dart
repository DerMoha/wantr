import 'package:hive/hive.dart';

part 'game_state.g.dart';

/// Player's game state - persisted locally
@HiveType(typeId: 0)
class GameState extends HiveObject {
  @HiveField(0)
  String playerId;

  @HiveField(1)
  String playerName;

  @HiveField(2)
  int level;

  @HiveField(3)
  int xp;

  @HiveField(4)
  int gold;

  @HiveField(5)
  int discoveryPoints;

  @HiveField(6)
  int tradeGoods;

  @HiveField(7)
  int influence;

  @HiveField(8)
  int energy;

  @HiveField(9)
  int materials;

  @HiveField(10)
  double totalDistanceWalked; // in meters

  @HiveField(11)
  int streetsDiscovered;

  @HiveField(12)
  int outpostsBuilt;

  @HiveField(13)
  int tradesCompleted;

  @HiveField(14)
  DateTime createdAt;

  @HiveField(15)
  DateTime lastActiveAt;

  @HiveField(16)
  String? teamId;

  GameState({
    required this.playerId,
    this.playerName = 'Wanderer',
    this.level = 1,
    this.xp = 0,
    this.gold = 100, // Starting gold
    this.discoveryPoints = 0,
    this.tradeGoods = 10, // Starting goods
    this.influence = 0,
    this.energy = 100,
    this.materials = 0,
    this.totalDistanceWalked = 0,
    this.streetsDiscovered = 0,
    this.outpostsBuilt = 0,
    this.tradesCompleted = 0,
    this.teamId,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastActiveAt = lastActiveAt ?? DateTime.now();

  /// Get player title based on level
  String get title {
    if (level <= 10) return 'Wanderer';
    if (level <= 25) return 'Peddler';
    return 'Merchant';
  }

  /// XP needed for next level
  int get xpForNextLevel => level * 100;

  /// Progress to next level (0.0 - 1.0)
  double get levelProgress => xp / xpForNextLevel;

  /// Add XP and handle level ups
  void addXp(int amount) {
    xp += amount;
    while (xp >= xpForNextLevel) {
      xp -= xpForNextLevel;
      level++;
    }
    lastActiveAt = DateTime.now();
  }

  /// Add gold
  void addGold(int amount) {
    gold += amount;
    lastActiveAt = DateTime.now();
  }

  /// Spend gold (returns false if not enough)
  bool spendGold(int amount) {
    if (gold < amount) return false;
    gold -= amount;
    lastActiveAt = DateTime.now();
    return true;
  }

  /// Record a discovered street
  void recordStreetDiscovery({int xpReward = 10, int dpReward = 1}) {
    streetsDiscovered++;
    discoveryPoints += dpReward;
    addXp(xpReward);
  }

  /// Record distance walked
  void addDistance(double meters) {
    totalDistanceWalked += meters;
    lastActiveAt = DateTime.now();
  }
}
