import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import '../models/discovered_street.dart';

/// Cloud sync service for syncing discovered streets to Firebase
class CloudSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;

  CloudSyncService(this._authService);

  /// Sync a discovered street to the team's collection
  Future<void> syncDiscoveredStreet(DiscoveredStreet street) async {
    final teamId = await _authService.getUserTeamId();
    if (teamId == null) return; // Not in a team, skip sync

    final userId = _authService.userId!;
    
    final streetRef = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('discoveredStreets')
        .doc(street.id);

    final existingDoc = await streetRef.get();
    
    if (existingDoc.exists) {
      // Street already discovered by team, update walk count
      await streetRef.update({
        'timesWalked': FieldValue.increment(1),
        'lastWalkedAt': FieldValue.serverTimestamp(),
        'lastWalkedBy': userId,
      });
    } else {
      // New discovery for team
      await streetRef.set({
        'streetName': street.streetName,
        'startLat': street.startLat,
        'startLng': street.startLng,
        'endLat': street.endLat,
        'endLng': street.endLng,
        'discoveredBy': userId,
        'firstDiscoveredAt': FieldValue.serverTimestamp(),
        'timesWalked': 1,
        'lastWalkedAt': FieldValue.serverTimestamp(),
        'lastWalkedBy': userId,
      });

      // Increment team stats
      await _firestore.collection('teams').doc(teamId).update({
        'stats.totalStreets': FieldValue.increment(1),
      });
    }

    debugPrint('☁️ Synced street ${street.streetName ?? street.id} to team');
  }

  /// Sync distance walked to team stats
  Future<void> syncDistanceWalked(double distanceMeters) async {
    final teamId = await _authService.getUserTeamId();
    if (teamId == null) return;

    await _firestore.collection('teams').doc(teamId).update({
      'stats.totalDistance': FieldValue.increment(distanceMeters),
    });
  }

  /// Get all team's discovered streets
  Future<List<DiscoveredStreet>> getTeamDiscoveredStreets() async {
    final teamId = await _authService.getUserTeamId();
    if (teamId == null) return [];

    final snapshot = await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('discoveredStreets')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return DiscoveredStreet(
        id: doc.id,
        startLat: data['startLat'] as double,
        startLng: data['startLng'] as double,
        endLat: data['endLat'] as double,
        endLng: data['endLng'] as double,
        streetName: data['streetName'] as String?,
        timesWalked: data['timesWalked'] as int? ?? 1,
      );
    }).toList();
  }

  /// Stream team's discovered streets for real-time updates
  Stream<List<DiscoveredStreet>> teamStreetsStream(String teamId) {
    return _firestore
        .collection('teams')
        .doc(teamId)
        .collection('discoveredStreets')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return DiscoveredStreet(
            id: doc.id,
            startLat: data['startLat'] as double,
            startLng: data['startLng'] as double,
            endLat: data['endLat'] as double,
            endLng: data['endLng'] as double,
            streetName: data['streetName'] as String?,
            timesWalked: data['timesWalked'] as int? ?? 1,
          );
        }).toList());
  }

  /// Upload all local discoveries to team (for migration after login)
  Future<int> uploadLocalDiscoveries(List<DiscoveredStreet> localStreets) async {
    final teamId = await _authService.getUserTeamId();
    if (teamId == null) return 0;

    int uploadedCount = 0;
    for (final street in localStreets) {
      await syncDiscoveredStreet(street);
      uploadedCount++;
    }

    debugPrint('☁️ Uploaded $uploadedCount local discoveries to team');
    return uploadedCount;
  }
}
