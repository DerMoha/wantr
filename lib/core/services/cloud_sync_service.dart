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

  CloudSyncService(this._authService);
  
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
  void _addToPendingQueue(RevealedSegment segment) {
    if (!_pendingSyncQueue.any((s) => s.id == segment.id)) {
      _pendingSyncQueue.add(segment);
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
      } catch (e) {
        // Re-add to queue on failure
        _addToPendingQueue(segment);
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
      _addToPendingQueue(segment);
      return;
    }

    try {
      await _syncSegmentNow(segment);
    } catch (e) {
      debugPrint('☁️ Sync failed, queuing for retry: $e');
      _addToPendingQueue(segment);
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

    final existingDoc = await segmentRef.get();
    
    if (existingDoc.exists) {
      // Segment already discovered by team, update walk count
      await segmentRef.update({
        'timesWalked': FieldValue.increment(1),
        'lastWalkedAt': FieldValue.serverTimestamp(),
        'lastWalkedBy': userId,
      });
    } else {
      // New discovery for team
      await segmentRef.set({
        'streetId': segment.streetId,
        'streetName': segment.streetName,
        'startLat': segment.startLat,
        'startLng': segment.startLng,
        'endLat': segment.endLat,
        'endLng': segment.endLng,
        'discoveredBy': userId,
        'firstDiscoveredAt': FieldValue.serverTimestamp(),
        'timesWalked': 1,
        'lastWalkedAt': FieldValue.serverTimestamp(),
        'lastWalkedBy': userId,
      });

      // Increment team stats
      await _firestore.collection('teams').doc(teamId).update({
        'stats.totalSegments': FieldValue.increment(1),
      });
    }

    debugPrint('☁️ Synced segment ${segment.streetName ?? segment.id} to team');
  }

  /// Sync distance walked to team stats
  Future<void> syncDistanceWalked(double distanceMeters) async {
    final teamId = await _authService.getUserTeamId();
    if (teamId == null) return;

    await _firestore.collection('teams').doc(teamId).update({
      'stats.totalDistance': FieldValue.increment(distanceMeters),
    });
  }

  /// Get all team's revealed segments (for loading teammate discoveries)
  Future<List<RevealedSegment>> getTeamRevealedSegments() async {
    final teamId = await _authService.getUserTeamId();
    if (teamId == null) return [];

    final userId = _authService.userId;
    
    final snapshot = await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('revealedSegments')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final discoveredBy = data['discoveredBy'] as String?;
      
      return RevealedSegment(
        id: doc.id,
        streetId: data['streetId'] as String,
        streetName: data['streetName'] as String?,
        startLat: data['startLat'] as double,
        startLng: data['startLng'] as double,
        endLat: data['endLat'] as double,
        endLng: data['endLng'] as double,
        timesWalked: data['timesWalked'] as int? ?? 1,
        discoveredByMe: discoveredBy == userId, // Mark as mine or teammate's
      );
    }).toList();
  }

  /// Stream team's revealed segments for real-time updates
  Stream<List<RevealedSegment>> teamSegmentsStream(String teamId) {
    final userId = _authService.userId;
    
    return _firestore
        .collection('teams')
        .doc(teamId)
        .collection('revealedSegments')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          final discoveredBy = data['discoveredBy'] as String?;
          
          return RevealedSegment(
            id: doc.id,
            streetId: data['streetId'] as String,
            streetName: data['streetName'] as String?,
            startLat: data['startLat'] as double,
            startLng: data['startLng'] as double,
            endLat: data['endLat'] as double,
            endLng: data['endLng'] as double,
            timesWalked: data['timesWalked'] as int? ?? 1,
            discoveredByMe: discoveredBy == userId,
          );
        }).toList());
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
    
    // Update team stats with new total
    final newTotal = existingIds.length + uploadedCount;
    await teamRef.update({
      'stats.totalSegments': newTotal,
    });

    debugPrint('☁️ Uploaded $uploadedCount new segments to team (total: $newTotal)');
    return uploadedCount;
  }
}


