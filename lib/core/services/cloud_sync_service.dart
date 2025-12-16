import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import '../models/revealed_segment.dart';

/// Cloud sync service for syncing revealed segments to Firebase
class CloudSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;

  CloudSyncService(this._authService);

  /// Sync a revealed segment to the team's collection
  Future<void> syncRevealedSegment(RevealedSegment segment) async {
    final teamId = await _authService.getUserTeamId();
    if (teamId == null) return; // Not in a team, skip sync

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

  /// Upload all local segments to team (for migration after joining team)
  Future<int> uploadLocalSegments(List<RevealedSegment> localSegments) async {
    final teamId = await _authService.getUserTeamId();
    if (teamId == null) return 0;

    int uploadedCount = 0;
    for (final segment in localSegments) {
      await syncRevealedSegment(segment);
      uploadedCount++;
    }

    debugPrint('☁️ Uploaded $uploadedCount local segments to team');
    return uploadedCount;
  }
}
