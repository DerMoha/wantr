import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../models/game_state.dart';
import '../models/discovered_street.dart';
import '../models/revealed_segment.dart';
import '../models/outpost.dart';
import '../models/hive_adapters.dart';
import '../services/location_service.dart';
import '../services/osm_street_service.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';

/// Main game provider - manages all game state and logic
class GameProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final OsmStreetService _osmService = OsmStreetService();
  final AuthService _authService = AuthService();
  late final CloudSyncService _cloudSyncService;
  
  GameState? _gameState;
  final List<DiscoveredStreet> _discoveredStreets = []; // Legacy, kept for compatibility
  final List<RevealedSegment> _revealedSegments = [];
  final List<Outpost> _outposts = [];
  
  // Hive boxes
  Box<GameState>? _gameStateBox;
  Box<DiscoveredStreet>? _streetBox;
  Box<RevealedSegment>? _segmentBox;
  Box<Outpost>? _outpostBox;

  // Location tracking
  StreamSubscription? _locationSubscription;
  LatLng? _currentLocation;
  final List<LatLng> _currentWalkPath = [];
  
  // OSM loading state
  bool _isLoadingStreets = false;
  String? _osmError;

  // Constants
  static const double _minDistanceForNewPoint = 15.0; // meters
  static const double _streetFetchRadiusKm = 2.0; // km
  static const double _revealRadius = 15.0; // meters - fog of war reveal radius

  /// Current game state
  GameState? get gameState => _gameState;

  /// All revealed segments (for fog of war display)
  List<RevealedSegment> get revealedSegments => List.unmodifiable(_revealedSegments);

  /// All discovered streets (legacy, for compatibility)
  List<DiscoveredStreet> get discoveredStreets => List.unmodifiable(_discoveredStreets);
  
  /// All outposts
  List<Outpost> get outposts => List.unmodifiable(_outposts);
  
  /// Current location
  LatLng? get currentLocation => _currentLocation;

  /// Current walk path (points collected this session)
  List<LatLng> get currentWalkPath => List.unmodifiable(_currentWalkPath);

  /// Whether location tracking is active
  bool get isTracking => _locationService.isTracking;

  /// Location service for direct access
  LocationService get locationService => _locationService;
  
  /// OSM street service for direct access
  OsmStreetService get osmService => _osmService;
  
  /// Whether OSM streets are loading
  bool get isLoadingStreets => _isLoadingStreets;
  
  /// Any OSM loading error
  String? get osmError => _osmError;
  
  /// Auth service for login state
  AuthService get authService => _authService;

  /// Initialize the game provider
  Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Initialize cloud sync
    _cloudSyncService = CloudSyncService(_authService);
    
    // Register Hive adapters
    registerHiveAdapters();
    
    // Open boxes (will create if not exists)
    _gameStateBox = await Hive.openBox<GameState>('game_state');
    _streetBox = await Hive.openBox<DiscoveredStreet>('discovered_streets');
    _segmentBox = await Hive.openBox<RevealedSegment>('revealed_segments');
    _outpostBox = await Hive.openBox<Outpost>('outposts');

    // Initialize OSM service
    await _osmService.initialize();

    // Load or create game state
    if (_gameStateBox!.isEmpty) {
      _gameState = GameState(
        playerId: const Uuid().v4(),
        playerName: 'Wanderer',
      );
      await _gameStateBox!.put('current', _gameState!);
    } else {
      _gameState = _gameStateBox!.get('current');
    }

    // Load discovered streets (legacy)
    _discoveredStreets.addAll(_streetBox!.values);
    
    // Load revealed segments
    _revealedSegments.addAll(_segmentBox!.values);
    debugPrint('📍 Loaded ${_revealedSegments.length} revealed segments');

    // Load outposts
    _outposts.addAll(_outpostBox!.values);

    notifyListeners();
  }

  /// Start location tracking
  Future<void> startTracking() async {
    await _locationService.startTracking();
    
    _locationSubscription = _locationService.locationStream.listen((location) {
      _handleLocationUpdate(location);
    });

    // Get initial location
    _currentLocation = await _locationService.getCurrentLocation();
    
    // Fetch OSM streets for area
    if (_currentLocation != null) {
      await _fetchStreetsForArea(_currentLocation!);
    }
    
    notifyListeners();
  }
  
  /// Fetch OSM street data for an area
  Future<void> _fetchStreetsForArea(LatLng center) async {
    if (_isLoadingStreets) return;
    
    _isLoadingStreets = true;
    _osmError = null;
    notifyListeners();
    
    try {
      await _osmService.fetchStreetsForArea(center, _streetFetchRadiusKm);
      debugPrint('📍 Loaded ${_osmService.cachedStreets.length} OSM streets');
    } catch (e) {
      _osmError = 'Failed to load streets: $e';
      debugPrint(_osmError);
    } finally {
      _isLoadingStreets = false;
      notifyListeners();
    }
  }

  /// Stop location tracking
  void stopTracking() {
    _locationService.stopTracking();
    _locationSubscription?.cancel();
    _locationSubscription = null;
    notifyListeners();
  }

  /// Handle location update
  void _handleLocationUpdate(LatLng newLocation) {
    final previousLocation = _currentLocation;
    _currentLocation = newLocation;

    if (previousLocation != null) {
      final distance = _locationService.calculateDistance(
        previousLocation,
        newLocation,
      );

      // Only record if moved significantly
      if (distance >= _minDistanceForNewPoint) {
        _currentWalkPath.add(newLocation);
        _gameState?.addDistance(distance);
        
        // Check for street discovery using OSM data
        _checkStreetDiscovery(newLocation);
        
        _saveGameState();
      }
    } else {
      _currentWalkPath.add(newLocation);
    }

    notifyListeners();
  }

  /// Reveal street segments within 30m radius of current location
  void _checkStreetDiscovery(LatLng location) {
    int newSegments = 0;
    
    // Check all cached OSM streets
    for (final osmStreet in _osmService.cachedStreets) {
      // Walk through each segment of the street
      for (int i = 0; i < osmStreet.points.length - 1; i++) {
        final segmentStart = osmStreet.points[i];
        final segmentEnd = osmStreet.points[i + 1];
        
        // Check if user is within reveal radius of this segment
        final distanceToSegment = _pointToSegmentDistance(location, segmentStart, segmentEnd);
        
        if (distanceToSegment <= _revealRadius) {
          // This segment should be revealed!
          final segmentId = '${osmStreet.id}_$i';
          
          // Check if already revealed
          final existing = _revealedSegments.where((s) => s.id == segmentId).firstOrNull;
          
          if (existing != null) {
            // Already revealed, increment walk count
            existing.recordWalk();
            existing.save();
          } else {
            // New segment revealed!
            final segment = RevealedSegment(
              id: segmentId,
              streetId: osmStreet.id,
              streetName: osmStreet.name,
              startLat: segmentStart.latitude,
              startLng: segmentStart.longitude,
              endLat: segmentEnd.latitude,
              endLng: segmentEnd.longitude,
            );
            
            _revealedSegments.add(segment);
            _segmentBox?.add(segment);
            newSegments++;
            
            // Sync to team cloud (if logged in and in a team)
            _syncSegmentToCloud(segment);
          }
        }
      }
    }
    
    // Award XP for new segments discovered
    if (newSegments > 0) {
      _gameState?.addXp(newSegments * 5); // 5 XP per segment
      _gameState?.discoveryPoints += newSegments;
      debugPrint('🗺️ Revealed $newSegments new segments! Total: ${_revealedSegments.length}');
    }
  }
  
  /// Sync a segment to cloud (fire and forget)
  void _syncSegmentToCloud(RevealedSegment segment) {
    if (!_authService.isLoggedIn) return;
    
    // Convert to DiscoveredStreet for cloud sync (uses existing sync logic)
    final streetForSync = DiscoveredStreet(
      id: segment.id,
      startLat: segment.startLat,
      startLng: segment.startLng,
      endLat: segment.endLat,
      endLng: segment.endLng,
      streetName: segment.streetName,
    );
    
    _cloudSyncService.syncDiscoveredStreet(streetForSync).catchError((e) {
      debugPrint('☁️ Sync error (will retry): $e');
    });
  }
  
  /// Calculate distance from a point to a line segment
  double _pointToSegmentDistance(LatLng point, LatLng segStart, LatLng segEnd) {
    const distance = Distance();
    
    final dx = segEnd.longitude - segStart.longitude;
    final dy = segEnd.latitude - segStart.latitude;
    
    if (dx == 0 && dy == 0) {
      // Segment is a point
      return distance.as(LengthUnit.Meter, point, segStart);
    }
    
    // Calculate projection parameter
    final t = max(0.0, min(1.0,
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

  /// Build an outpost at the current location
  Future<bool> buildOutpost({
    required String name,
    required OutpostType type,
  }) async {
    if (_currentLocation == null) return false;
    
    final cost = Outpost.getCost(type, 1);
    if (!(_gameState?.spendGold(cost) ?? false)) {
      return false; // Not enough gold
    }

    final outpost = Outpost(
      id: const Uuid().v4(),
      name: name,
      lat: _currentLocation!.latitude,
      lng: _currentLocation!.longitude,
      type: type,
    );

    _outposts.add(outpost);
    await _outpostBox?.add(outpost);
    
    _gameState?.outpostsBuilt++;
    _gameState?.addXp(50); // XP for building
    
    await _saveGameState();
    notifyListeners();
    
    return true;
  }

  /// Collect resources from an outpost
  Future<int> collectFromOutpost(Outpost outpost) async {
    final amount = outpost.collectResources();
    
    switch (outpost.type) {
      case OutpostType.tradingPost:
        _gameState?.tradeGoods += amount;
        break;
      case OutpostType.workshop:
        _gameState?.materials += amount;
        break;
      case OutpostType.inn:
        _gameState?.energy = (_gameState!.energy + amount).clamp(0, 100);
        break;
      case OutpostType.bank:
        _gameState?.addGold(amount);
        break;
      default:
        break;
    }

    await outpost.save();
    await _saveGameState();
    notifyListeners();
    
    return amount;
  }

  /// Save game state to storage
  Future<void> _saveGameState() async {
    if (_gameState != null) {
      await _gameStateBox?.put('current', _gameState!);
    }
  }

  /// Calculate total map coverage as percentage
  double get mapCoverage {
    // Simplified calculation based on discovered streets
    // In production, this would compare against total streets in the area
    return _discoveredStreets.length / 100.0; // Placeholder
  }

  @override
  void dispose() {
    stopTracking();
    _locationService.dispose();
    super.dispose();
  }
}
