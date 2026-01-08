import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

/// Team service for managing teams and invites
class TeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;
  final Random _random = Random.secure();

  static const int maxTeamMembers = 3;
  static const int maxTeamNameLength = 30;
  static const int minTeamNameLength = 2;

  TeamService(this._authService);

  /// Validate team name
  String? validateTeamName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'Team name cannot be empty';
    }
    if (trimmed.length < minTeamNameLength) {
      return 'Team name must be at least $minTeamNameLength characters';
    }
    if (trimmed.length > maxTeamNameLength) {
      return 'Team name must be at most $maxTeamNameLength characters';
    }
    return null; // Valid
  }

  /// Create a new team
  Future<String?> createTeam(String teamName) async {
    if (!_authService.isLoggedIn) {
      debugPrint('❌ Must be logged in to create team');
      return null;
    }

    // Validate team name
    final validationError = validateTeamName(teamName);
    if (validationError != null) {
      debugPrint('❌ $validationError');
      return null;
    }

    final userId = _authService.userId!;

    // Leave current team if in one
    final currentTeamId = await _authService.getUserTeamId();
    if (currentTeamId != null) {
      debugPrint('ℹ️ Leaving current team before creating new one');
      await leaveTeam();
    }

    // Generate a unique invite code (6 chars)
    final inviteCode = await _generateUniqueInviteCode();

    // Create team document
    final teamRef = await _firestore.collection('teams').add({
      'name': teamName.trim(),
      'inviteCode': inviteCode,
      'leaderId': userId,
      'members': [userId],
      'createdAt': FieldValue.serverTimestamp(),
      'stats': {
        'totalSegments': 0,
        'totalDistance': 0.0,
      },
    });

    // Update user's teamId (use set with merge in case doc doesn't exist)
    await _firestore.collection('users').doc(userId).set({
      'teamId': teamRef.id,
    }, SetOptions(merge: true));

    // Update cache
    _authService.updateCachedTeamId(teamRef.id);

    debugPrint('✅ Created team "$teamName" with code: $inviteCode');
    return teamRef.id;
  }

  /// Join a team using invite code
  /// Returns: 'success', 'not_found', 'full', or 'error'
  Future<String> joinTeam(String inviteCode) async {
    if (!_authService.isLoggedIn) {
      debugPrint('❌ Must be logged in to join team');
      return 'error';
    }

    final userId = _authService.userId!;

    // Leave current team if in one
    final currentTeamId = await _authService.getUserTeamId();
    if (currentTeamId != null) {
      debugPrint('ℹ️ Leaving current team before joining new one');
      await leaveTeam();
    }

    // Find team by invite code
    final query = await _firestore
        .collection('teams')
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      debugPrint('❌ No team found with code: $inviteCode');
      return 'not_found';
    }

    final teamDocRef = query.docs.first.reference;
    final teamId = query.docs.first.id;

    // Use transaction to safely join team
    try {
      await _firestore.runTransaction((transaction) async {
        final teamSnapshot = await transaction.get(teamDocRef);
        if (!teamSnapshot.exists) {
          throw Exception('Team no longer exists');
        }

        final teamData = teamSnapshot.data()!;
        final members = List<String>.from(teamData['members'] ?? []);

        // Check if team is full
        if (members.length >= maxTeamMembers) {
          throw Exception('full');
        }

        // Check if already a member (shouldn't happen after leaveTeam, but safety check)
        if (members.contains(userId)) {
          return; // Already a member, no action needed
        }

        // Add to team
        transaction.update(teamDocRef, {
          'members': FieldValue.arrayUnion([userId]),
        });

        // Update user's teamId (use set with merge in case doc doesn't exist)
        final userDocRef = _firestore.collection('users').doc(userId);
        transaction.set(userDocRef, {'teamId': teamId}, SetOptions(merge: true));
      });

      // Update cache
      _authService.updateCachedTeamId(teamId);

      debugPrint('✅ Joined team');
      return 'success';
    } catch (e) {
      if (e.toString().contains('full')) {
        debugPrint('❌ Team is full (max $maxTeamMembers members)');
        return 'full';
      }
      debugPrint('❌ Error joining team: $e');
      return 'error';
    }
  }

  /// Leave current team
  /// Returns the teamId that was left (for updating local state), or null if not in a team
  Future<String?> leaveTeam() async {
    if (!_authService.isLoggedIn) return null;

    final userId = _authService.userId!;
    final teamId = await _authService.getUserTeamId();

    if (teamId == null) {
      debugPrint('ℹ️ Not in a team');
      return null;
    }

    final teamDocRef = _firestore.collection('teams').doc(teamId);
    final userDocRef = _firestore.collection('users').doc(userId);

    try {
      await _firestore.runTransaction((transaction) async {
        final teamSnapshot = await transaction.get(teamDocRef);

        if (!teamSnapshot.exists) {
          // Team already deleted, just clear user's teamId
          transaction.set(userDocRef, {'teamId': null}, SetOptions(merge: true));
          return;
        }

        final teamData = teamSnapshot.data()!;
        final members = List<String>.from(teamData['members'] ?? []);
        final isLeader = teamData['leaderId'] == userId;

        if (isLeader && members.length > 1) {
          // Transfer leadership to next member
          final newLeader = members.firstWhere((m) => m != userId);
          transaction.update(teamDocRef, {
            'leaderId': newLeader,
            'members': FieldValue.arrayRemove([userId]),
          });
        } else if (members.length == 1) {
          // Last member - delete team (segments subcollection will be cleaned up separately)
          transaction.delete(teamDocRef);

          // Schedule cleanup of orphaned segments subcollection
          // Note: This runs outside the transaction as Firestore doesn't support
          // deleting subcollections in a transaction
          _cleanupTeamSegments(teamId);
        } else {
          // Just remove from team
          transaction.update(teamDocRef, {
            'members': FieldValue.arrayRemove([userId]),
          });
        }

        // Clear user's teamId
        transaction.set(userDocRef, {'teamId': null}, SetOptions(merge: true));
      });

      // Update cache
      _authService.updateCachedTeamId(null);

      debugPrint('👋 Left team');
      return teamId; // Return the teamId that was left
    } catch (e) {
      debugPrint('❌ Error leaving team: $e');
      return null;
    }
  }

  /// Get team data
  Future<Map<String, dynamic>?> getTeamData(String teamId) async {
    final doc = await _firestore.collection('teams').doc(teamId).get();
    return doc.data();
  }

  /// Get team member stats for leaderboard
  /// Uses pre-computed memberSegments counts for efficiency
  Future<List<Map<String, dynamic>>> getTeamMemberStats(String teamId) async {
    final teamDoc = await _firestore.collection('teams').doc(teamId).get();
    if (!teamDoc.exists) return [];

    final teamData = teamDoc.data()!;
    final members = List<String>.from(teamData['members'] ?? []);

    // Get pre-computed segment counts from team stats (O(1) instead of O(n) segments)
    final memberSegments = Map<String, dynamic>.from(
      teamData['stats']?['memberSegments'] ?? {}
    );

    // Batch fetch all user documents at once
    final userDocs = await Future.wait(
      members.map((id) => _firestore.collection('users').doc(id).get())
    );

    // Build member stats list
    final memberStats = <Map<String, dynamic>>[];
    for (int i = 0; i < members.length; i++) {
      final memberId = members[i];
      final userData = userDocs[i].data() ?? {};

      memberStats.add({
        'userId': memberId,
        'displayName': userData['displayName'] ?? 'Unknown',
        'photoUrl': userData['photoUrl'],
        'segments': (memberSegments[memberId] as num?)?.toInt() ?? 0,
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

  /// Regenerate invite code (leader only)
  Future<String?> regenerateInviteCode(String teamId) async {
    if (!_authService.isLoggedIn) return null;

    final userId = _authService.userId!;
    final teamDoc = await _firestore.collection('teams').doc(teamId).get();

    if (!teamDoc.exists) {
      debugPrint('❌ Team not found');
      return null;
    }

    final teamData = teamDoc.data()!;
    if (teamData['leaderId'] != userId) {
      debugPrint('❌ Only the team leader can regenerate the invite code');
      return null;
    }

    final newCode = await _generateUniqueInviteCode();
    await _firestore.collection('teams').doc(teamId).update({
      'inviteCode': newCode,
    });

    debugPrint('✅ Regenerated invite code: $newCode');
    return newCode;
  }

  /// Kick a member from the team (leader only)
  /// Returns: 'success', 'not_leader', 'not_found', 'cannot_kick_self', or 'error'
  Future<String> kickMember(String teamId, String memberIdToKick) async {
    if (!_authService.isLoggedIn) return 'error';

    final userId = _authService.userId!;

    if (memberIdToKick == userId) {
      debugPrint('❌ Cannot kick yourself, use leaveTeam instead');
      return 'cannot_kick_self';
    }

    final teamDocRef = _firestore.collection('teams').doc(teamId);
    final memberDocRef = _firestore.collection('users').doc(memberIdToKick);

    try {
      await _firestore.runTransaction((transaction) async {
        final teamSnapshot = await transaction.get(teamDocRef);

        if (!teamSnapshot.exists) {
          throw Exception('not_found');
        }

        final teamData = teamSnapshot.data()!;
        if (teamData['leaderId'] != userId) {
          throw Exception('not_leader');
        }

        final members = List<String>.from(teamData['members'] ?? []);
        if (!members.contains(memberIdToKick)) {
          throw Exception('not_found');
        }

        // Remove member from team
        transaction.update(teamDocRef, {
          'members': FieldValue.arrayRemove([memberIdToKick]),
        });

        // Clear member's teamId
        transaction.set(memberDocRef, {'teamId': null}, SetOptions(merge: true));
      });

      debugPrint('✅ Kicked member $memberIdToKick from team');
      return 'success';
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('not_leader')) {
        debugPrint('❌ Only the team leader can kick members');
        return 'not_leader';
      }
      if (errorMsg.contains('not_found')) {
        debugPrint('❌ Member not found in team');
        return 'not_found';
      }
      debugPrint('❌ Error kicking member: $e');
      return 'error';
    }
  }

  /// Check if current user is the team leader
  Future<bool> isTeamLeader(String teamId) async {
    if (!_authService.isLoggedIn) return false;

    final teamDoc = await _firestore.collection('teams').doc(teamId).get();
    if (!teamDoc.exists) return false;

    return teamDoc.data()?['leaderId'] == _authService.userId;
  }

  /// Transfer leadership to another member (leader only)
  /// Returns: 'success', 'not_leader', 'not_member', or 'error'
  Future<String> transferLeadership(String teamId, String newLeaderId) async {
    if (!_authService.isLoggedIn) return 'error';

    final userId = _authService.userId!;

    if (newLeaderId == userId) {
      debugPrint('ℹ️ Already the leader');
      return 'success';
    }

    final teamDocRef = _firestore.collection('teams').doc(teamId);

    try {
      await _firestore.runTransaction((transaction) async {
        final teamSnapshot = await transaction.get(teamDocRef);

        if (!teamSnapshot.exists) {
          throw Exception('not_found');
        }

        final teamData = teamSnapshot.data()!;
        if (teamData['leaderId'] != userId) {
          throw Exception('not_leader');
        }

        final members = List<String>.from(teamData['members'] ?? []);
        if (!members.contains(newLeaderId)) {
          throw Exception('not_member');
        }

        // Transfer leadership
        transaction.update(teamDocRef, {
          'leaderId': newLeaderId,
        });
      });

      debugPrint('✅ Transferred leadership to $newLeaderId');
      return 'success';
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('not_leader')) {
        debugPrint('❌ Only the team leader can transfer leadership');
        return 'not_leader';
      }
      if (errorMsg.contains('not_member')) {
        debugPrint('❌ New leader must be a team member');
        return 'not_member';
      }
      debugPrint('❌ Error transferring leadership: $e');
      return 'error';
    }
  }

  /// Clean up orphaned segments subcollection when team is deleted
  /// This runs in the background and doesn't block the leave operation
  Future<void> _cleanupTeamSegments(String teamId) async {
    try {
      final segmentsRef = _firestore
          .collection('teams')
          .doc(teamId)
          .collection('revealedSegments');

      // Delete in batches of 500 (Firestore limit)
      const batchSize = 500;
      QuerySnapshot snapshot;

      do {
        snapshot = await segmentsRef.limit(batchSize).get();

        if (snapshot.docs.isEmpty) break;

        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        debugPrint('🗑️ Deleted ${snapshot.docs.length} orphaned segments');
      } while (snapshot.docs.length == batchSize);

      debugPrint('✅ Cleaned up all orphaned segments for deleted team');
    } catch (e) {
      // Log but don't throw - this is a background cleanup operation
      debugPrint('⚠️ Error cleaning up orphaned segments: $e');
    }
  }

  /// Generate a unique 6-character invite code
  Future<String> _generateUniqueInviteCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No confusing chars
    const maxAttempts = 10;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      // Generate random code using secure random
      final code = List.generate(6, (_) {
        return chars[_random.nextInt(chars.length)];
      }).join();

      // Check if code already exists
      final existing = await _firestore
          .collection('teams')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        return code;
      }
      debugPrint('⚠️ Invite code collision, retrying...');
    }

    // Fallback: append timestamp suffix for uniqueness
    final fallbackCode = List.generate(4, (_) {
      return chars[_random.nextInt(chars.length)];
    }).join();
    return '$fallbackCode${DateTime.now().millisecondsSinceEpoch % 100}';
  }
}
