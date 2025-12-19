import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for managing the live tracking notification
/// Shows real-time stats: streets discovered and meters walked
class TrackingNotificationService {
  static final TrackingNotificationService _instance = TrackingNotificationService._internal();
  factory TrackingNotificationService() => _instance;
  TrackingNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  static const int _notificationId = 888; // Unique ID for tracking notification
  static const String _channelId = 'wantr_tracking';
  static const String _channelName = 'Exploration Tracking';
  static const String _channelDescription = 'Shows live stats while tracking your exploration';

  // Throttling: don't update notification more than once per 5 seconds
  static const Duration _throttleDuration = Duration(seconds: 5);
  DateTime? _lastNotificationUpdate;
  bool _pendingUpdate = false;

  bool _isInitialized = false;
  bool _isShowing = false;
  bool _hasPermission = false;

  // Session stats
  int _sessionMetersWalked = 0;
  int _sessionStreetsDiscovered = 0;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Only show notifications on Android
    if (!Platform.isAndroid) {
      _isInitialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notifications.initialize(initSettings);
    
    // Create the notification channel
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.low, // Low importance = no sound
          showBadge: false,
        ),
      );
    }
    
    _isInitialized = true;
    debugPrint('📱 Tracking notification service initialized');
  }

  /// Request notification permission (required for Android 13+)
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    
    // Check if we already have permission
    final status = await Permission.notification.status;
    if (status.isGranted) {
      _hasPermission = true;
      debugPrint('📱 Notification permission already granted');
      return true;
    }
    
    // Request permission
    final result = await Permission.notification.request();
    _hasPermission = result.isGranted;
    debugPrint('📱 Notification permission request result: $result');
    return _hasPermission;
  }

  /// Start showing the tracking notification
  Future<void> startTracking() async {
    if (!Platform.isAndroid || !_isInitialized) return;
    
    // Request permission if we don't have it yet
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        debugPrint('📱 Notification permission denied, skipping notification');
        return;
      }
    }
    
    _sessionMetersWalked = 0;
    _sessionStreetsDiscovered = 0;
    _isShowing = true;
    _lastNotificationUpdate = null;
    _pendingUpdate = false;
    
    await _showNotificationNow(); // Force immediate update on start
    debugPrint('📱 Started tracking notification');
  }

  /// Update the notification with new stats
  Future<void> updateStats({
    required int totalMetersWalked,
    required int totalStreetsDiscovered,
  }) async {
    if (!Platform.isAndroid || !_isInitialized || !_isShowing) return;
    
    _sessionMetersWalked = totalMetersWalked;
    _sessionStreetsDiscovered = totalStreetsDiscovered;
    
    await _throttledShowNotification();
  }

  /// Add distance walked (accumulates during session)
  Future<void> addDistance(double meters) async {
    if (!_isShowing) return;
    _sessionMetersWalked += meters.round();
    await _throttledShowNotification();
  }

  /// Add streets discovered (accumulates during session)
  Future<void> addStreets(int count) async {
    if (!_isShowing) return;
    _sessionStreetsDiscovered += count;
    await _throttledShowNotification();
  }

  /// Stop showing the tracking notification
  Future<void> stopTracking() async {
    if (!Platform.isAndroid || !_isInitialized) return;
    
    _isShowing = false;
    _pendingUpdate = false;
    await _notifications.cancel(_notificationId);
    debugPrint('📱 Stopped tracking notification');
  }

  /// Throttled notification update - prevents excessive battery drain
  Future<void> _throttledShowNotification() async {
    final now = DateTime.now();
    
    // If we haven't updated recently, update immediately
    if (_lastNotificationUpdate == null || 
        now.difference(_lastNotificationUpdate!) >= _throttleDuration) {
      await _showNotificationNow();
      return;
    }
    
    // Otherwise, schedule an update if not already pending
    if (!_pendingUpdate) {
      _pendingUpdate = true;
      final waitTime = _throttleDuration - now.difference(_lastNotificationUpdate!);
      
      Future.delayed(waitTime, () async {
        if (_isShowing && _pendingUpdate) {
          _pendingUpdate = false;
          await _showNotificationNow();
        }
      });
    }
  }

  /// Show notification immediately (internal)
  Future<void> _showNotificationNow() async {
    _lastNotificationUpdate = DateTime.now();
    
    final distanceText = _formatDistance(_sessionMetersWalked);
    final streetsText = _sessionStreetsDiscovered == 1 
        ? '1 street' 
        : '$_sessionStreetsDiscovered streets';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // Can't be swiped away
      autoCancel: false,
      showWhen: false,
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.service,
      // Style the notification content
      styleInformation: BigTextStyleInformation(
        '🗺️ $streetsText discovered\n📍 $distanceText walked',
        contentTitle: 'Exploring...',
        summaryText: 'Wantr',
      ),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _notificationId,
      'Exploring...',
      '🗺️ $streetsText • 📍 $distanceText',
      notificationDetails,
    );
  }

  /// Format distance in meters or kilometers
  String _formatDistance(int meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
    return '$meters m';
  }

  /// Whether the notification is currently showing
  bool get isShowing => _isShowing;

  /// Current session meters walked
  int get sessionMetersWalked => _sessionMetersWalked;

  /// Current session streets discovered
  int get sessionStreetsDiscovered => _sessionStreetsDiscovered;
}
