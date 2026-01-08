import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'auth_service.dart';
import '../models/revealed_segment.dart';
import '../models/app_settings.dart';

/// Cloud sync service for syncing revealed segments to Firebase
class CloudSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;

  // Pending sync queue for retrying failed syncs
  final List<RevealedSegment> _pendingSyncQueue = [];
  bool _isProcessingQueue = false;
  bool _isInitialized = false;

  // Distance buffering to protect quota
  double _distanceBuffer = 0.0;
  Timer? _distanceTimer;
  static const Duration _distanceBufferDuration = Duration(seconds: 60);
  static const double _distanceBufferThresholdMeters = 100.0;

  // Hive box name for persistence
  static const String _pendingQueueBoxName = 'pending_sync_queue';

  CloudSyncService(this._authService);

  /// Initialize the service and load persisted queue
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final box = await Hive.openBox<Map>(_pendingQueueBoxName);
      final persistedIds = box.keys.toList();

      for (final id in persistedIds) {
        final data = box.get(id);
        if (data != null) {
          try {
            final segment = RevealedSegment(
              id: data['id'] as String,
              streetId: data['streetId'] as String,
              streetName: data['streetName'] as String?,
              startLat: data['startLat'] as double,
              startLng: data['startLng'] as double,
              endLat: data['endLat'] as double,
              endLng: data['endLng'] as double,
              timesWalked: data['timesWalked'] as int? ?? 1,
              discoveredByMe: true,
            );
            if (!_pendingSyncQueue.any((s) => s.id == segment.id)) {
              _pendingSyncQueue.add(segment);
            }
          } catch (e) {
            debugPrint('⚠️ Failed to restore pending segment: $e');
          }
        }
      }

      _isInitialized = true;
      debugPrint('☁️ Loaded ${_pendingSyncQueue.length} pending syncs from storage');
    } catch (e) {
      debugPrint('⚠️ Error initializing pending queue: $e');
      _isInitialized = true; // Continue without persisted data
    }
  }

  /// Persist a segment to the pending queue storage
  Future<void> _persistToPendingQueue(RevealedSegment segment) async {
    try {
      final box = await Hive.openBox<Map>(_pendingQueueBoxName);
      await box.put(segment.id, {
        'id': segment.id,
        'streetId': segment.streetId,
        'streetName': segment.streetName,
        'startLat': segment.startLat,
        'startLng': segment.startLng,
        'endLat': segment.endLat,
        'endLng': segment.endLng,
        'timesWalked': segment.timesWalked,
      });
    } catch (e) {
      debugPrint('⚠️ Error persisting to pending queue: $e');
    }
  }

  /// Remove a segment from persisted pending queue
  Future<void> _removeFromPersistedQueue(String segmentId) async {
    try {
      final box = await Hive.openBox<Map>(_pendingQueueBoxName);
      await box.delete(segmentId);
    } catch (e) {
      debugPrint('⚠️ Error removing from persisted queue: $e');
    }
  }
  
  /// Check if sync should proceed based on WiFi setting
  Future<bool> _shouldSync() async {
    try {
      final settingsBox = await Hive.openBox<dynamic>('app_settings');
      final settings = settingsBox.get('settings');
      
      // If WiFi-only sync is disabled, always sync
      if (settings == null || !(settings is AppSettings) || !settings.wifiOnlySync) {
        return true;
      }
      
      // Check if we're on WiFi
      final connectivity = await Connectivity().checkConnectivity();
      final isOnWifi = connectivity.contains(ConnectivityResult.wifi);
      
      if (!isOnWifi) {
        debugPrint('☁️ WiFi-only sync enabled, skipping (on mobile data)');
      }
      
      return isOnWifi;
    } catch (e) {
      debugPrint('☁️ Error checking connectivity: $e');
      return true; // Default to syncing on error
    }
  }
  
  /// Add segment to pending queue (for retry later)
  Future<void> _addToPendingQueue(RevealedSegment segment) async {
    if (!_pendingSyncQueue.any((s) => s.id == segment.id)) {
      _pendingSyncQueue.add(segment);
      await _persistToPendingQueue(segment);
      debugPrint('☁️ Added segment to pending queue (${_pendingSyncQueue.length} pending)');
    }
  }
  
  /// Process pending sync queue
  Future<void> processPendingQueue() async {
    if (_isProcessingQueue || _pendingSyncQueue.isEmpty) return;

    if (!await _shouldSync()) return;

    _isProcessingQueue = true;
    debugPrint('☁️ Processing ${_pendingSyncQueue.length} pending syncs...');

    final toProcess = List<RevealedSegment>.from(_pendingSyncQueue);
    _pendingSyncQueue.clear();

    for (final segment in toProcess) {
      try {
        await _syncSegmentNow(segment);
        // Remove from persisted queue on success
        await _removeFromPersistedQueue(segment.id);
      } catch (e) {
        // Re-add to queue on failure
        await _addToPendingQueue(segment);
      }
    }

    _isProcessingQueue = false;
  }
  
  /// Get pending sync count
  int get pendingSyncCount => _pendingSyncQueue.length;

  /// Sync a revealed segment to the team's collection
  Future<void> syncRevealedSegment(RevealedSegment segment) async {
    final teamId = await _authService.getUserTeamId();
    if (teamId == null) return; // Not in a team, skip sync

    // Check WiFi setting
    if (!await _shouldSync()) {
      await _addToPendingQueue(segment);
      return;
    }

    try {
      await _syncSegmentNow(segment);
    } catch (e) {
      debugPrint('☁️ Sync failed, queuing for retry: $e');
      await _addToPendingQueue(segment);
    }
  }
  
  /// Actually sync segment (internal)
  Future<void> _syncSegmentNow(RevealedSegment segment) async {
    final teamId = await _authService.getUserTeamId();
    if (teamId == null) return;

    final userId = _authService.userId!;

    final segmentRef = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('revealedSegments')
        .doc(segment.id);

    // Check if segment already exists to avoid overwriting firstDiscoveredAt
    // and to correctly track totalSegments
    final existingDoc = await segmentRef.get();
    final isNewSegment = !existingDoc.exists;

    if (isNewSegment) {
      // New segment - set all fields including firstDiscoveredAt
      await segmentRef.set({
        'streetId': segment.streetId,
        'streetName': segment.streetName,
        'startLat': segment.startLat,
        'startLng': segment.startLng,
        'endLat': segment.endLat,
        'endLng': segment.endLng,
        'timesWalked': 1,
        'lastWalkedAt': FieldValue.serverTimestamp(),
        'lastWalkedBy': userId,
        'discoveredBy': userId,
        'firstDiscoveredAt': FieldValue.serverTimestamp(),
      });

      // Increment both total and per-user segment counts
      await _firestore.collection('teams').doc(teamId).update({
        'stats.totalSegments': FieldValue.increment(1),
        'stats.memberSegments.$userId': FieldValue.increment(1),
      });

      debugPrint('☁️ Synced NEW segment ${segment.streetName ?? segment.id} to team');
    } else {
      // Existing segment - only update walk info, preserve firstDiscoveredAt and discoveredBy
      await segmentRef.update({
        'timesWalked': FieldValue.increment(1),
        'lastWalkedAt': FieldValue.serverTimestamp(),
        'lastWalkedBy': userId,
      });

      debugPrint('☁️ Updated existing segment ${segment.streetName ?? segment.id}');
    }
  }

  /// Sync distance walked to team stats (with buffering)
  Future<void> syncDistanceWalked(double distanceMeters) async {
    _distanceBuffer += distanceMeters;
    
    // If we've walked enough, sync immediately
    if (_distanceBuffer >= _distanceBufferThresholdMeters) {
      await flushDistanceBuffer();
      return;
    }
    
    // Otherwise, start/reset timer for periodic sync
    _distanceTimer?.cancel();
    _distanceTimer = Timer(_distanceBufferDuration, () {
      flushDistanceBuffer();
    });
  }

  /// Push buffered distance to Firestore
  Future<void> flushDistanceBuffer() async {
    if (_distanceBuffer <= 0) return;
    
    final teamId = await _authService.getUserTeamId();
    if (teamId == null) return;

    final distanceToSync = _distanceBuffer;
    _distanceBuffer = 0; // Clear buffer before call to prevent double sync
    _distanceTimer?.cancel();

    try {
      await _firestore.collection('teams').doc(teamId).update({
        'stats.totalDistance': FieldValue.increment(distanceToSync),
      });
      debugPrint('☁️ Synced $distanceToSync meters to team (Buffered)');
    } catch (e) {
      debugPrint('☁️ Failed to sync distance, re-buffering: $e');
      _distanceBuffer += distanceToSync; // Re-add on failure
    }
  }

  /// Clean up resources
  void dispose() {
    _distanceTimer?.cancel();
    flushDistanceBuffer();
  }

  /// Get team's revealed segments (optionally after a certain date for incremental sync)
  Future<List<RevealedSegment>> getTeamRevealedSegments({DateTime? lastSyncAt}) async {
    final teamId = await _authService.getUserTeamId();
    if (teamId == null) return [];

    final userId = _authService.userId;
    
    Query query = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('revealedSegments');

    if (lastSyncAt != null) {
      query = query.where('lastWalkedAt', isGreaterThan: Timestamp.fromDate(lastSyncAt));
    }

    final snapshot = await query.get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      
      final discoveredBy = data['discoveredBy'] as String?;
      
      return RevealedSegment(
        id: doc.id,
        streetId: data['streetId'] as String,
        streetName: data['streetName'] as String?,
        startLat: data['startLat'] as double,
        startLng: data['startLng'] as double,
        endLat: data['endLat'] as double? ?? 0.0,
        endLng: data['endLng'] as double? ?? 0.0,
        timesWalked: data['timesWalked'] as int? ?? 1,
        discoveredByMe: discoveredBy == userId,
      );
    }).whereType<RevealedSegment>().toList();
  }

  /// Stream team's revealed segments for real-time updates (can be filtered for incremental sync)
  Stream<List<RevealedSegment>> teamSegmentsStream(String teamId, {DateTime? lastSyncAt}) {
    final userId = _authService.userId;
    
    Query query = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('revealedSegments');

    if (lastSyncAt != null) {
      query = query.where('lastWalkedAt', isGreaterThan: Timestamp.fromDate(lastSyncAt));
    }

    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return null;

          final discoveredBy = data['discoveredBy'] as String?;
          
          return RevealedSegment(
            id: doc.id,
            streetId: data['streetId'] as String,
            streetName: data['streetName'] as String?,
            startLat: data['startLat'] as double,
            startLng: data['startLng'] as double,
            endLat: data['endLat'] as double? ?? 0.0,
            endLng: data['endLng'] as double? ?? 0.0,
            timesWalked: data['timesWalked'] as int? ?? 1,
            discoveredByMe: discoveredBy == userId,
          );
        }).whereType<RevealedSegment>().toList());
  }

  /// Upload local segments to team that don't already exist in the cloud
  /// Uses batch writes for efficiency and skips existing segments to save quota
  Future<int> uploadLocalSegments(List<RevealedSegment> localSegments) async {
    final teamId = await _authService.getUserTeamId();
    if (teamId == null) return 0;
    if (localSegments.isEmpty) return 0;

    final userId = _authService.userId!;
    final teamRef = _firestore.collection('teams').doc(teamId);
    final segmentsRef = teamRef.collection('revealedSegments');
    
    // First, get all existing segment IDs from the cloud (just IDs, minimal reads)
    debugPrint('☁️ Checking for existing segments in cloud...');
    final existingSnapshot = await segmentsRef.get();
    final existingIds = existingSnapshot.docs.map((doc) => doc.id).toSet();
    debugPrint('☁️ Found ${existingIds.length} existing segments in cloud');
    
    // Filter to only new segments
    final newSegments = localSegments.where((s) => !existingIds.contains(s.id)).toList();
    
    if (newSegments.isEmpty) {
      debugPrint('☁️ All segments already synced, nothing to upload');
      return 0;
    }
    
    debugPrint('☁️ Uploading ${newSegments.length} new segments (skipping ${localSegments.length - newSegments.length} existing)');
    
    int uploadedCount = 0;
    
    // Process in batches of 500 (Firestore limit)
    const batchSize = 500;
    for (int i = 0; i < newSegments.length; i += batchSize) {
      final batch = _firestore.batch();
      final end = (i + batchSize > newSegments.length) 
          ? newSegments.length 
          : i + batchSize;
      
      for (int j = i; j < end; j++) {
        final segment = newSegments[j];
        final segmentRef = segmentsRef.doc(segment.id);
        
        batch.set(segmentRef, {
          'streetId': segment.streetId,
          'streetName': segment.streetName,
          'startLat': segment.startLat,
          'startLng': segment.startLng,
          'endLat': segment.endLat,
          'endLng': segment.endLng,
          'discoveredBy': userId,
          'firstDiscoveredAt': FieldValue.serverTimestamp(),
          'timesWalked': segment.timesWalked,
          'lastWalkedAt': FieldValue.serverTimestamp(),
          'lastWalkedBy': userId,
        });
        
        uploadedCount++;
      }
      
      await batch.commit();
      debugPrint('☁️ Committed batch ${(i ~/ batchSize) + 1}');
    }
    
    // Update team stats with new total and per-user count
    final newTotal = existingIds.length + uploadedCount;
    await teamRef.update({
      'stats.totalSegments': newTotal,
      'stats.memberSegments.$userId': FieldValue.increment(uploadedCount),
    });

    debugPrint('☁️ Uploaded $uploadedCount new segments to team (total: $newTotal)');
    return uploadedCount;
  }
}


