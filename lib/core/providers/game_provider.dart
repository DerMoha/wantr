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
import '../services/tracking_notification_service.dart';

/// Main game provider - manages all game state and logic
class GameProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final OsmStreetService _osmService = OsmStreetService();
  final AuthService _authService = AuthService();
  final TrackingNotificationService _notificationService = TrackingNotificationService();
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
  StreamSubscription? _teamSegmentsSubscription; // New subscription for real-time team sync
  LatLng? _currentLocation;
  final List<LatLng> _currentWalkPath = [];
  
  // OSM loading state
  bool _isLoadingStreets = false;
  String? _osmError;

  bool _isInitialized = false;

  // Throttling for notifyListeners (max 2x per second)
  DateTime? _lastNotifyTime;
  bool _notifyPending = false;
  static const Duration _notifyThrottleDuration = Duration(milliseconds: 500);
  
  // Auto-fetch OSM when user moves far
  LatLng? _lastOsmFetchLocation;
  static const double _osmRefetchDistanceKm = 1.0; // Refetch when moved 1km from last fetch

  // Constants
  static const double _minDistanceForNewPoint = 15.0; // meters
  static const double _streetFetchRadiusKm = 2.0; // km
  static const double _revealRadius = 15.0; // meters - fog of war reveal radius

  /// Whether the provider has finished its initial load
  bool get isInitialized => _isInitialized;

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
    if (_isInitialized) return;

    await Hive.initFlutter();
    
    // Initialize cloud sync
    _cloudSyncService = CloudSyncService(_authService);
    
    // Initialize notification service
    await _notificationService.initialize();
    
    // Register Hive adapters
    registerHiveAdapters();
    
    // Open boxes (will create if not exists)
    _gameStateBox = await Hive.openBox<GameState>('game_state');
    _streetBox = await Hive.openBox<DiscoveredStreet>('discovered_streets');
    _segmentBox = await Hive.openBox<RevealedSegment>('revealed_segments');
    _outpostBox = await Hive.openBox<Outpost>('outposts');

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

    // Initialize OSM service (in background to speed up startup)
    _osmService.initialize().catchError((e) => debugPrint('❌ OSM init error: $e'));

    // Populate AuthService cache from persisted GameState
    if (_gameState?.teamId != null) {
      _authService.updateCachedTeamId(_gameState!.teamId);
    }

    // Load discovered streets (legacy)
    _discoveredStreets.addAll(_streetBox!.values);
    
    // Load revealed segments from local storage
    _revealedSegments.addAll(_segmentBox!.values);
    debugPrint('📍 Loaded ${_revealedSegments.length} local revealed segments');
    
    // Load outposts
    _outposts.addAll(_outpostBox!.values);

    // Finalize initialization
    _isInitialized = true;
    notifyListeners();

    // Background tasks that don't need to block UI
    _backgroundLoading();
  }

  /// Non-blocking background loading tasks
  Future<void> _backgroundLoading() async {
    if (!_authService.isLoggedIn) return;

    // 1. Refresh teamId from Firestore to catch up with changes on other devices
    try {
      final freshTeamId = await _authService.getUserTeamId(forceRefresh: true);
      if (freshTeamId != _gameState?.teamId) {
        _gameState?.teamId = freshTeamId;
        await _saveGameState();
      }
    } catch (e) {
      debugPrint('⚠️ Error refreshing teamId: $e');
    }

    // 2. Start real-time sync for team segments (incremental if we have a timestamp)
    _startTeamSegmentsStream(freshTeamId, lastSyncAt: _gameState?.lastTeamSyncAt);
  }

  /// Start real-time listener for team discoveries
  void _startTeamSegmentsStream(String? teamId, {DateTime? lastSyncAt}) {
    if (teamId == null) return;
    
    _teamSegmentsSubscription?.cancel();
    _teamSegmentsSubscription = _cloudSyncService.teamSegmentsStream(
      teamId, 
      lastSyncAt: lastSyncAt
    ).listen((teamSegments) async {
      if (teamSegments.isEmpty) return;

      int addedCount = 0;
      DateTime? latestUpdate;

      for (final teamSegment in teamSegments) {
        final existingIndex = _revealedSegments.indexWhere((s) => s.id == teamSegment.id);
        
        if (existingIndex == -1) {
          // New segment from team - add it
          _revealedSegments.add(teamSegment);
          await _segmentBox!.put(teamSegment.id, teamSegment);
          addedCount++;
        }

        // Track the latest update timestamp (not yet available in RevealedSegment, but we can use DateTime.now() 
        // as a safe checkpoint, or better, we could add lastWalkedAt to the model if we had it)
        // For now, let's use the current time as the "last sync" checkpoint.
      }
      
      if (addedCount > 0) {
        debugPrint('☁️ Synced $addedCount new team segments in real-time');
        notifyListeners();
      }

      // Update sync timestamp to now (to catch only future updates)
      if (_gameState != null) {
        _gameState!.lastTeamSyncAt = DateTime.now();
        await _saveGameState();
      }
    });
  }
  
  /// Load team segments from cloud and merge with local
  Future<void> _loadTeamSegments() async {
    if (!_authService.isLoggedIn) return;
    
    try {
      final teamSegments = await _cloudSyncService!.getTeamRevealedSegments();
      
      // Merge team segments with local (team discoveries that aren't in local)
      int addedCount = 0;
      for (final teamSegment in teamSegments) {
        final existingIndex = _revealedSegments.indexWhere((s) => s.id == teamSegment.id);
        
        if (existingIndex == -1) {
          // New segment from team - add it
          _revealedSegments.add(teamSegment);
          await _segmentBox!.put(teamSegment.id, teamSegment);
          addedCount++;
        }
      }
      
      if (addedCount > 0) {
        debugPrint('☁️ Loaded $addedCount team segments from cloud');
      }
    } catch (e) {
      debugPrint('⚠️ Error loading team segments: $e');
    }
  }

  /// Start location tracking
  Future<void> startTracking() async {
    // Load GPS settings
    final settingsBox = await Hive.openBox<dynamic>('app_settings');
    final settings = settingsBox.get('settings');
    
    int distanceFilter = 10;
    Duration interval = const Duration(seconds: 5);
    bool isBatterySaver = true; // Default to battery saver
    
    if (settings != null) {
      // Get settings values based on mode index
      final gpsModeIndex = settings.gpsModeIndex ?? 0;
      isBatterySaver = gpsModeIndex == 0; // 0 = batterySaver mode
      
      distanceFilter = switch (gpsModeIndex) {
        1 => 5,  // balanced
        2 => 3,  // highAccuracy
        _ => 10, // batterySaver
      };
      interval = switch (gpsModeIndex) {
        1 => const Duration(seconds: 3),
        2 => const Duration(seconds: 2),
        _ => const Duration(seconds: 5),
      };
    }
    
    await _locationService.startTracking(
      distanceFilter: distanceFilter,
      interval: interval,
      batterySaverMode: isBatterySaver,
    );
    
    // Start the live tracking notification
    await _notificationService.startTracking();
    
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
  Future<void> stopTracking() async {
    _locationService.stopTracking();
    _locationSubscription?.cancel();
    _locationSubscription = null;
    
    // Stop the live tracking notification
    await _notificationService.stopTracking();
    
    notifyListeners();
  }

  /// Handle location update
  void _handleLocationUpdate(LatLng newLocation) {
    final previousLocation = _currentLocation;
    _currentLocation = newLocation;
    
    // Always check for street discovery at current location
    _checkStreetDiscovery(newLocation);

    if (previousLocation != null) {
      final distance = _locationService.calculateDistance(
        previousLocation,
        newLocation,
      );

      // Only record walk path/distance if moved significantly
      if (distance >= _minDistanceForNewPoint) {
        _currentWalkPath.add(newLocation);
        _gameState?.addDistance(distance);
        _saveGameState();
        
        // Update live notification with distance walked
        _notificationService.addDistance(distance);
      }
    } else {
      _currentWalkPath.add(newLocation);
    }
    
    // Auto-fetch OSM data if we've moved far from last fetch location
    _checkAndRefetchOsmData(newLocation);

    _throttledNotifyListeners();
  }
  
  /// Throttled version of notifyListeners to prevent UI jank
  void _throttledNotifyListeners() {
    final now = DateTime.now();
    
    if (_lastNotifyTime == null || 
        now.difference(_lastNotifyTime!) >= _notifyThrottleDuration) {
      _lastNotifyTime = now;
      notifyListeners();
      return;
    }
    
    // Schedule a delayed notify if not already pending
    if (!_notifyPending) {
      _notifyPending = true;
      Future.delayed(_notifyThrottleDuration, () {
        _notifyPending = false;
        _lastNotifyTime = DateTime.now();
        notifyListeners();
      });
    }
  }
  
  /// Check if we need to refetch OSM data (moved far from last fetch)
  void _checkAndRefetchOsmData(LatLng currentLocation) {
    if (_lastOsmFetchLocation == null) {
      _lastOsmFetchLocation = currentLocation;
      return;
    }
    
    final distanceFromLastFetch = _locationService.calculateDistance(
      _lastOsmFetchLocation!,
      currentLocation,
    ) / 1000; // Convert to km
    
    if (distanceFromLastFetch >= _osmRefetchDistanceKm) {
      debugPrint('📍 Moved ${distanceFromLastFetch.toStringAsFixed(1)}km, refetching OSM data...');
      _fetchStreetsForArea(currentLocation);
      _lastOsmFetchLocation = currentLocation;
    }
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
      
      // Update live notification with streets discovered
      _notificationService.addStreets(newSegments);
    }
  }
  
  /// Sync a segment to cloud (fire and forget)
  void _syncSegmentToCloud(RevealedSegment segment) {
    if (!_authService.isLoggedIn) return;
    
    _cloudSyncService!.syncRevealedSegment(segment).catchError((e) {
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
    _locationSubscription?.cancel();
    _teamSegmentsSubscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}
