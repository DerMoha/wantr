import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

part 'revealed_segment.g.dart';

/// Represents a revealed segment of a street (30m around user position)
/// Streets are gradually revealed as you walk them
@HiveType(typeId: 4)
class RevealedSegment extends HiveObject {
  /// Unique ID combining street ID and segment index
  @HiveField(0)
  String id;

  /// OSM street ID this segment belongs to
  @HiveField(1)
  String streetId;

  /// Street name (optional)
  @HiveField(2)
  String? streetName;

  /// Segment start latitude
  @HiveField(3)
  double startLat;

  /// Segment start longitude
  @HiveField(4)
  double startLng;

  /// Segment end latitude
  @HiveField(5)
  double endLat;

  /// Segment end longitude
  @HiveField(6)
  double endLng;

  /// How many times this segment was walked
  @HiveField(7)
  int timesWalked;

  /// When first discovered
  @HiveField(8)
  DateTime firstDiscoveredAt;

  /// When last walked
  @HiveField(9)
  DateTime lastWalkedAt;
  
  /// Whether discovered by current user (true) or teammate (false)
  @HiveField(10)
  bool discoveredByMe;

  RevealedSegment({
    required this.id,
    required this.streetId,
    this.streetName,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    this.timesWalked = 1,
    this.discoveredByMe = true,
    DateTime? firstDiscoveredAt,
    DateTime? lastWalkedAt,
  })  : firstDiscoveredAt = firstDiscoveredAt ?? DateTime.now(),
        lastWalkedAt = lastWalkedAt ?? DateTime.now();

  /// Get segment state based on times walked
  SegmentState get state {
    if (timesWalked >= 50) return SegmentState.legendary;
    if (timesWalked >= 10) return SegmentState.mastered;
    return SegmentState.discovered;
  }

  /// Start point as LatLng
  LatLng get startPoint => LatLng(startLat, startLng);

  /// End point as LatLng  
  LatLng get endPoint => LatLng(endLat, endLng);

  /// Points for drawing
  List<LatLng> get points => [startPoint, endPoint];

  /// Increment walk count and mark as discovered by me
  void recordWalk() {
    timesWalked++;
    lastWalkedAt = DateTime.now();
    discoveredByMe = true; // If I walk over teammate's segment, it becomes mine
  }

  /// Length of this segment in meters
  double get lengthMeters {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, startPoint, endPoint);
  }
}

/// Segment discovery states
enum SegmentState {
  undiscovered,    // Gray
  teamDiscovered,  // Green (teammate)
  discovered,      // Yellow (me)
  mastered,        // Gold  
  legendary,       // Bright gold
}
