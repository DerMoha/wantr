import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to monitor network connectivity status
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final _statusController = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  bool _isOnline = true;
  bool _isInitialized = false;

  /// Stream of connectivity status changes
  Stream<bool> get statusStream => _statusController.stream;

  /// Current online status
  bool get isOnline => _isOnline;

  /// Initialize and start monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Check initial status
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && 
                !results.contains(ConnectivityResult.none);
    
    if (wasOnline != _isOnline) {
      debugPrint('📶 Connectivity changed: ${_isOnline ? "Online" : "Offline"}');
      _statusController.add(_isOnline);
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
