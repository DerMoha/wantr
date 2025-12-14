import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Location data with accuracy information
class LocationData {
  final LatLng position;
  final double accuracy; // meters
  final DateTime timestamp;

  LocationData({
    required this.position,
    required this.accuracy,
    required this.timestamp,
  });

  /// Check if this is a high-quality reading
  bool get isHighQuality => accuracy <= 50.0; // 50m threshold
}

/// Service for handling GPS location tracking
/// Designed for background operation during walks
class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  final _locationController = StreamController<LatLng>.broadcast();
  
  LatLng? _lastPosition;
  DateTime? _lastTimestamp;
  bool _isTracking = false;
  
  // GPS quality thresholds
  static const double _maxAccuracyMeters = 50.0; // Reject readings with accuracy > 50m
  static const double _maxSpeedMps = 25.0; // ~90 km/h - reject teleportation

  /// Stream of location updates (only high-quality readings)
  Stream<LatLng> get locationStream => _locationController.stream;

  /// Current position
  LatLng? get currentPosition => _lastPosition;

  /// Whether tracking is active
  bool get isTracking => _isTracking;

  /// Check and request location permissions
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current location once
  Future<LatLng?> getCurrentLocation() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Check accuracy before accepting
      if (position.accuracy > _maxAccuracyMeters) {
        debugPrint('📍 Rejected low-quality GPS: ${position.accuracy}m accuracy');
        return _lastPosition; // Return last known good position
      }

      _lastPosition = LatLng(position.latitude, position.longitude);
      _lastTimestamp = DateTime.now();
      return _lastPosition;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  /// Start continuous location tracking
  /// Uses foreground service on Android for background tracking
  Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      debugPrint('Location permission not granted');
      return;
    }

    _isTracking = true;

    // Platform-specific location settings
    late LocationSettings locationSettings;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android: Use foreground service for background tracking
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // meters
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'Wantr is tracking your exploration',
          notificationTitle: 'Exploring...',
          enableWakeLock: true,
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS: Use Apple settings for background
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      // Default for other platforms
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _processPosition(position);
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );
  }

  /// Process and validate a GPS position before emitting
  void _processPosition(Position position) {
    final now = DateTime.now();
    final newPosition = LatLng(position.latitude, position.longitude);
    
    // Check 1: Accuracy threshold
    if (position.accuracy > _maxAccuracyMeters) {
      debugPrint('📍 Rejected: Low accuracy (${position.accuracy.toStringAsFixed(0)}m)');
      return;
    }
    
    // Check 2: Teleportation detection (unrealistic speed)
    if (_lastPosition != null && _lastTimestamp != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );
      
      final timeDiff = now.difference(_lastTimestamp!).inSeconds;
      if (timeDiff > 0) {
        final speed = distance / timeDiff; // meters per second
        
        if (speed > _maxSpeedMps) {
          debugPrint('📍 Rejected: Teleportation detected (${(speed * 3.6).toStringAsFixed(0)} km/h, ${distance.toStringAsFixed(0)}m jump)');
          return;
        }
      }
    }
    
    // Position passes all checks - emit it
    _lastPosition = newPosition;
    _lastTimestamp = now;
    _locationController.add(newPosition);
  }

  /// Stop location tracking
  void stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Calculate distance between two points in meters
  double calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    _locationController.close();
  }
}
