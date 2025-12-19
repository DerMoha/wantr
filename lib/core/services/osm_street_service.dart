import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Represents a street from OpenStreetMap
class OsmStreet {
  final String id;
  final String? name;
  final List<LatLng> points;
  final String type; // residential, primary, secondary, etc.

  OsmStreet({
    required this.id,
    this.name,
    required this.points,
    required this.type,
  });

  /// Calculate distance from a point to this street
  double distanceToPoint(LatLng point) {
    double minDistance = double.infinity;
    
    for (int i = 0; i < points.length - 1; i++) {
      final distance = _pointToSegmentDistance(
        point,
        points[i],
        points[i + 1],
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    
    return minDistance;
  }

  /// Calculate perpendicular distance from point to line segment
  double _pointToSegmentDistance(LatLng point, LatLng segStart, LatLng segEnd) {
    final distance = const Distance();
    
    // Vector math to find closest point on segment
    final dx = segEnd.longitude - segStart.longitude;
    final dy = segEnd.latitude - segStart.latitude;
    
    if (dx == 0 && dy == 0) {
      // Segment is a point
      return distance.as(LengthUnit.Meter, point, segStart);
    }
    
    // Calculate projection parameter
    final t = max(0, min(1,
      ((point.longitude - segStart.longitude) * dx + 
       (point.latitude - segStart.latitude) * dy) / 
      (dx * dx + dy * dy)
    ));
    
    // Find closest point on segment
    final closestPoint = LatLng(
      segStart.latitude + t * dy,
      segStart.longitude + t * dx,
    );
    
    return distance.as(LengthUnit.Meter, point, closestPoint);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'points': points.map((p) => [p.latitude, p.longitude]).toList(),
    'type': type,
  };

  factory OsmStreet.fromJson(Map<String, dynamic> json) {
    final pointsList = (json['points'] as List)
        .map((p) => LatLng(p[0] as double, p[1] as double))
        .toList();
    
    return OsmStreet(
      id: json['id'] as String,
      name: json['name'] as String?,
      points: pointsList,
      type: json['type'] as String,
    );
  }
}

/// Service for fetching and caching OpenStreetMap street data
class OsmStreetService {
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const double _snapRadius = 30.0; // meters
  static const Duration _cacheMaxAge = Duration(days: 7); // Refresh cache after 7 days
  
  Box<String>? _streetCacheBox;
  List<OsmStreet> _cachedStreets = [];
  LatLng? _cachedCenter;
  double? _cachedRadius;
  DateTime? _cacheTimestamp;

  /// Initialize the service
  Future<void> initialize() async {
    _streetCacheBox = await Hive.openBox<String>('osm_street_cache');
    await _loadCachedStreets();
  }

  /// Load previously cached streets
  Future<void> _loadCachedStreets() async {
    final cachedData = _streetCacheBox?.get('streets');
    if (cachedData != null) {
      try {
        final data = jsonDecode(cachedData);
        
        // Check cache age - expire after 7 days
        if (data['timestamp'] != null) {
          _cacheTimestamp = DateTime.parse(data['timestamp'] as String);
          final age = DateTime.now().difference(_cacheTimestamp!);
          if (age > _cacheMaxAge) {
            debugPrint('📍 OSM cache expired (${age.inDays} days old), will refetch');
            return; // Don't load expired cache
          }
        }
        
        _cachedStreets = (data['streets'] as List)
            .map((s) => OsmStreet.fromJson(s))
            .toList();
        
        if (data['center'] != null) {
          _cachedCenter = LatLng(
            data['center']['lat'] as double,
            data['center']['lng'] as double,
          );
          _cachedRadius = data['radius'] as double?;
        }
        
        debugPrint('📍 Loaded ${_cachedStreets.length} cached streets');
      } catch (e) {
        debugPrint('Error loading cached streets: $e');
      }
    }
  }

  /// Fetch streets from Overpass API for an area
  Future<List<OsmStreet>> fetchStreetsForArea(LatLng center, double radiusKm) async {
    // Check if we already have this area cached
    if (_isCacheValid(center, radiusKm)) {
      debugPrint('📍 Using cached streets');
      return _cachedStreets;
    }
    
    debugPrint('📍 Fetching streets from Overpass API...');
    
    // Overpass QL query for all highway types (streets)
    final query = '''
[out:json][timeout:25];
(
  way["highway"~"^(residential|primary|secondary|tertiary|unclassified|living_street|pedestrian|footway|path|cycleway)\$"]
    (around:${radiusKm * 1000},${ center.latitude},${center.longitude});
);
out body;
>;
out skel qt;
''';

    try {
      final response = await http.post(
        Uri.parse(_overpassUrl),
        body: {'data': query},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final streets = _parseOverpassResponse(data);
        
        // Cache the results
        await _cacheStreets(streets, center, radiusKm);
        
        debugPrint('📍 Fetched ${streets.length} streets');
        return streets;
      } else {
        debugPrint('Overpass API error: ${response.statusCode}');
        return _cachedStreets; // Fall back to cache
      }
    } catch (e) {
      debugPrint('Error fetching streets: $e');
      return _cachedStreets; // Fall back to cache
    }
  }

  /// Parse Overpass API response into OsmStreet objects
  List<OsmStreet> _parseOverpassResponse(Map<String, dynamic> data) {
    final elements = data['elements'] as List;
    final nodes = <int, LatLng>{};
    final streets = <OsmStreet>[];

    // First pass: collect all nodes
    for (final element in elements) {
      if (element['type'] == 'node') {
        nodes[element['id'] as int] = LatLng(
          element['lat'] as double,
          element['lon'] as double,
        );
      }
    }

    // Second pass: build streets from ways
    for (final element in elements) {
      if (element['type'] == 'way') {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};
        final nodeIds = element['nodes'] as List;
        
        final points = <LatLng>[];
        for (final nodeId in nodeIds) {
          final node = nodes[nodeId as int];
          if (node != null) {
            points.add(node);
          }
        }

        if (points.length >= 2) {
          streets.add(OsmStreet(
            id: 'osm_${element['id']}',
            name: tags['name'] as String?,
            points: points,
            type: tags['highway'] as String? ?? 'unknown',
          ));
        }
      }
    }

    return streets;
  }

  /// Cache streets to local storage
  Future<void> _cacheStreets(List<OsmStreet> streets, LatLng center, double radiusKm) async {
    _cachedStreets = streets;
    _cachedCenter = center;
    _cachedRadius = radiusKm;

    final cacheData = jsonEncode({
      'streets': streets.map((s) => s.toJson()).toList(),
      'center': {'lat': center.latitude, 'lng': center.longitude},
      'radius': radiusKm,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await _streetCacheBox?.put('streets', cacheData);
  }

  /// Check if current cache covers the requested area
  bool _isCacheValid(LatLng center, double radiusKm) {
    if (_cachedCenter == null || _cachedRadius == null || _cachedStreets.isEmpty) {
      return false;
    }
    
    // Check if new center is within cached area
    final distance = const Distance();
    final centerDistance = distance.as(LengthUnit.Kilometer, center, _cachedCenter!);
    
    // Valid if the new request is within the cached radius
    return centerDistance + radiusKm <= _cachedRadius!;
  }

  /// Find the nearest street to a GPS point
  OsmStreet? findNearestStreet(LatLng point) {
    if (_cachedStreets.isEmpty) return null;
    
    OsmStreet? nearest;
    double minDistance = double.infinity;
    
    for (final street in _cachedStreets) {
      final distance = street.distanceToPoint(point);
      if (distance < minDistance && distance <= _snapRadius) {
        minDistance = distance;
        nearest = street;
      }
    }
    
    return nearest;
  }

  /// Snap a GPS point to the nearest street
  /// Returns the street ID if found, null otherwise
  String? snapToStreet(LatLng point) {
    final street = findNearestStreet(point);
    return street?.id;
  }

  /// Get all cached streets (for debugging/display)
  List<OsmStreet> get cachedStreets => List.unmodifiable(_cachedStreets);
  
  /// Check if streets are loaded
  bool get hasStreets => _cachedStreets.isNotEmpty;
}
