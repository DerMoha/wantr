import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../models/game_state.dart';
import '../models/discovered_street.dart';
import '../models/outpost.dart';
import '../models/hive_adapters.dart';
import '../services/location_service.dart';

/// Main game provider - manages all game state and logic
class GameProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  
  GameState? _gameState;
  final List<DiscoveredStreet> _discoveredStreets = [];
  final List<Outpost> _outposts = [];
  
  // Hive boxes
  Box<GameState>? _gameStateBox;
  Box<DiscoveredStreet>? _streetBox;
  Box<Outpost>? _outpostBox;

  // Location tracking
  StreamSubscription? _locationSubscription;
  LatLng? _currentLocation;
  final List<LatLng> _currentWalkPath = [];

  // Constants
  static const double _minDistanceForNewPoint = 15.0; // meters

  /// Current game state
  GameState? get gameState => _gameState;

  /// All discovered streets
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

  /// Initialize the game provider
  Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Register Hive adapters
    registerHiveAdapters();
    
    // Open boxes (will create if not exists)
    _gameStateBox = await Hive.openBox<GameState>('game_state');
    _streetBox = await Hive.openBox<DiscoveredStreet>('discovered_streets');
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

    // Load discovered streets
    _discoveredStreets.addAll(_streetBox!.values);

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
    notifyListeners();
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
        
        // Check for street discovery
        _checkStreetDiscovery(previousLocation, newLocation);
        
        _saveGameState();
      }
    } else {
      _currentWalkPath.add(newLocation);
    }

    notifyListeners();
  }

  /// Check if we've discovered a new street segment
  void _checkStreetDiscovery(LatLng from, LatLng to) {
    // Simple implementation: create a new street segment
    // In production, this would match against real street data from OSM
    
    final streetId = '${from.latitude.toStringAsFixed(5)}_${from.longitude.toStringAsFixed(5)}_${to.latitude.toStringAsFixed(5)}_${to.longitude.toStringAsFixed(5)}';
    
    // Check if already discovered
    final existing = _discoveredStreets.where((s) => s.id == streetId).firstOrNull;
    
    if (existing != null) {
      // Already discovered, increment walk count
      existing.recordWalk();
      existing.save();
    } else {
      // New discovery!
      final newStreet = DiscoveredStreet(
        id: streetId,
        startLat: from.latitude,
        startLng: from.longitude,
        endLat: to.latitude,
        endLng: to.longitude,
      );
      
      _discoveredStreets.add(newStreet);
      _streetBox?.add(newStreet);
      
      // Award XP and discovery points
      _gameState?.recordStreetDiscovery();
      
      debugPrint('🗺️ New street discovered! Total: ${_discoveredStreets.length}');
    }
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
