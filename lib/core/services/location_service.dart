import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Service for handling GPS location tracking
/// Designed for background operation during walks
class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  final _locationController = StreamController<LatLng>.broadcast();
  
  LatLng? _lastPosition;
  bool _isTracking = false;

  /// Stream of location updates
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

      _lastPosition = LatLng(position.latitude, position.longitude);
      return _lastPosition;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  /// Start continuous location tracking
  /// Uses battery-optimized settings for background tracking
  Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      debugPrint('Location permission not granted');
      return;
    }

    _isTracking = true;

    // Location settings optimized for walking
    // Update every 10 meters or 5 seconds, whichever comes first
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _lastPosition = LatLng(position.latitude, position.longitude);
        _locationController.add(_lastPosition!);
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );
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
