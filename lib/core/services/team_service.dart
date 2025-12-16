import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'auth_service.dart';

/// Team service for managing teams and invites
class TeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;
  
  static const int maxTeamMembers = 3;

  TeamService(this._authService);

  /// Create a new team
  Future<String?> createTeam(String teamName) async {
    if (!_authService.isLoggedIn) {
      debugPrint('❌ Must be logged in to create team');
      return null;
    }

    final userId = _authService.userId!;
    
    // Generate a unique invite code (6 chars)
    final inviteCode = _generateInviteCode();
    
    // Create team document
    final teamRef = await _firestore.collection('teams').add({
      'name': teamName,
      'inviteCode': inviteCode,
      'leaderId': userId,
      'members': [userId],
      'createdAt': FieldValue.serverTimestamp(),
      'stats': {
        'totalStreets': 0,
        'totalDistance': 0.0,
      },
    });

    // Update user's teamId
    await _firestore.collection('users').doc(userId).update({
      'teamId': teamRef.id,
    });

    debugPrint('✅ Created team "$teamName" with code: $inviteCode');
    return teamRef.id;
  }

  /// Join a team using invite code
  Future<bool> joinTeam(String inviteCode) async {
    if (!_authService.isLoggedIn) {
      debugPrint('❌ Must be logged in to join team');
      return false;
    }

    final userId = _authService.userId!;
    
    // Find team by invite code
    final query = await _firestore
        .collection('teams')
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      debugPrint('❌ No team found with code: $inviteCode');
      return false;
    }

    final teamDoc = query.docs.first;
    final teamData = teamDoc.data();
    final members = List<String>.from(teamData['members'] ?? []);

    // Check if team is full
    if (members.length >= maxTeamMembers) {
      debugPrint('❌ Team is full (max $maxTeamMembers members)');
      return false;
    }

    // Check if already a member
    if (members.contains(userId)) {
      debugPrint('ℹ️ Already a member of this team');
      return true;
    }

    // Add to team
    await teamDoc.reference.update({
      'members': FieldValue.arrayUnion([userId]),
    });

    // Update user's teamId
    await _firestore.collection('users').doc(userId).update({
      'teamId': teamDoc.id,
    });

    debugPrint('✅ Joined team "${teamData['name']}"');
    return true;
  }

  /// Leave current team
  Future<bool> leaveTeam() async {
    if (!_authService.isLoggedIn) return false;

    final userId = _authService.userId!;
    final teamId = await _authService.getUserTeamId();
    
    if (teamId == null) {
      debugPrint('ℹ️ Not in a team');
      return true;
    }

    final teamDoc = _firestore.collection('teams').doc(teamId);
    final teamSnapshot = await teamDoc.get();
    
    if (!teamSnapshot.exists) return true;

    final teamData = teamSnapshot.data()!;
    final members = List<String>.from(teamData['members'] ?? []);
    final isLeader = teamData['leaderId'] == userId;

    if (isLeader && members.length > 1) {
      // Transfer leadership to next member
      final newLeader = members.firstWhere((m) => m != userId);
      await teamDoc.update({
        'leaderId': newLeader,
        'members': FieldValue.arrayRemove([userId]),
      });
    } else if (members.length == 1) {
      // Last member - delete team
      await teamDoc.delete();
    } else {
      // Just remove from team
      await teamDoc.update({
        'members': FieldValue.arrayRemove([userId]),
      });
    }

    // Clear user's teamId
    await _firestore.collection('users').doc(userId).update({
      'teamId': null,
    });

    debugPrint('👋 Left team');
    return true;
  }

  /// Get team data
  Future<Map<String, dynamic>?> getTeamData(String teamId) async {
    final doc = await _firestore.collection('teams').doc(teamId).get();
    return doc.data();
  }

  /// Get team member stats for leaderboard
  Future<List<Map<String, dynamic>>> getTeamMemberStats(String teamId) async {
    final teamDoc = await _firestore.collection('teams').doc(teamId).get();
    if (!teamDoc.exists) return [];
    
    final members = List<String>.from(teamDoc.data()?['members'] ?? []);
    
    // Get segment counts per member
    final segmentDocs = await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('revealedSegments')
        .get();
    
    // Count segments by discoverer
    final segmentCounts = <String, int>{};
    for (final doc in segmentDocs.docs) {
      final discoveredBy = doc.data()['discoveredBy'] as String?;
      if (discoveredBy != null) {
        segmentCounts[discoveredBy] = (segmentCounts[discoveredBy] ?? 0) + 1;
      }
    }
    
    // Fetch user info for each member
    final memberStats = <Map<String, dynamic>>[];
    for (final memberId in members) {
      final userDoc = await _firestore.collection('users').doc(memberId).get();
      final userData = userDoc.data() ?? {};
      
      memberStats.add({
        'userId': memberId,
        'displayName': userData['displayName'] ?? 'Unknown',
        'photoUrl': userData['photoUrl'],
        'segments': segmentCounts[memberId] ?? 0,
        'isCurrentUser': memberId == _authService.userId,
      });
    }
    
    // Sort by segments (descending)
    memberStats.sort((a, b) => (b['segments'] as int).compareTo(a['segments'] as int));
    
    return memberStats;
  }

  /// Stream team updates
  Stream<DocumentSnapshot<Map<String, dynamic>>> teamStream(String teamId) {
    return _firestore.collection('teams').doc(teamId).snapshots();
  }

  /// Generate a 6-character invite code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No confusing chars
    final random = DateTime.now().millisecondsSinceEpoch;
    final code = List.generate(6, (i) {
      return chars[(random ~/ (i + 1)) % chars.length];
    }).join();
    return code;
  }
}
