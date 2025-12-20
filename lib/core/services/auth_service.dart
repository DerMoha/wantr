import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Authentication service with optional login
/// Users can play without an account, but need one for teams/leaderboards
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _cachedTeamId;

  /// Current Firebase user (null if not logged in)
  User? get currentUser => _auth.currentUser;

  /// Whether user is logged in (including anonymous)
  bool get isLoggedIn => currentUser != null;

  /// Whether user is anonymous (not linked to Google/email)
  bool get isAnonymous => currentUser?.isAnonymous ?? false;

  /// User ID (Firebase UID or null)
  String? get userId => currentUser?.uid;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in anonymously (for team joining without Google account)
  Future<UserCredential?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      
      // Create user document
      await _createUserDocument(userCredential.user!, displayName: 'Guest Explorer');
      
      debugPrint('✅ Signed in anonymously as ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      debugPrint('❌ Anonymous sign-in error: $e');
      rethrow;
    }
  }

  /// Link anonymous account to Google
  Future<UserCredential?> linkWithGoogle() async {
    if (!isAnonymous) return null;
    
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await currentUser!.linkWithCredential(credential);
      
      // Update user document with Google info
      await _firestore.collection('users').doc(userId).update({
        'displayName': googleUser.displayName ?? 'Wanderer',
        'email': googleUser.email,
        'photoUrl': googleUser.photoUrl,
        'isAnonymous': false,
      });
      
      debugPrint('✅ Linked account to ${googleUser.displayName}');
      return userCredential;
    } catch (e) {
      debugPrint('❌ Link with Google error: $e');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Obtain the auth details
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // Create a credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Create/update user document in Firestore
      await _createUserDocument(userCredential.user!);
      
      debugPrint('✅ Signed in as ${userCredential.user?.displayName}');
      return userCredential;
    } catch (e) {
      debugPrint('❌ Google sign-in error: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      debugPrint('✅ Signed in as ${userCredential.user?.email}');
      return userCredential;
    } catch (e) {
      debugPrint('❌ Email sign-in error: $e');
      rethrow;
    }
  }

  /// Create account with email and password
  Future<UserCredential?> createAccountWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await userCredential.user?.updateDisplayName(displayName);
      
      // Create user document
      await _createUserDocument(userCredential.user!, displayName: displayName);
      
      debugPrint('✅ Created account for ${userCredential.user?.email}');
      return userCredential;
    } catch (e) {
      debugPrint('❌ Account creation error: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _cachedTeamId = null;
    await _googleSignIn.signOut();
    await _auth.signOut();
    debugPrint('👋 Signed out');
  }

  /// Create or update user document in Firestore
  Future<void> _createUserDocument(User user, {String? displayName}) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    
    final docSnapshot = await userDoc.get();
    
    if (!docSnapshot.exists) {
      // New user - create document
      await userDoc.set({
        'displayName': displayName ?? user.displayName ?? 'Wanderer',
        'email': user.email,
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'teamId': null,
      });
    } else {
      // Existing user - update last active
      await userDoc.update({
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Get user's team ID (if any)
  Future<String?> getUserTeamId({bool forceRefresh = false}) async {
    if (!isLoggedIn) return null;
    
    if (_cachedTeamId != null && !forceRefresh) {
      return _cachedTeamId;
    }
    
    final doc = await _firestore.collection('users').doc(userId).get();
    _cachedTeamId = doc.data()?['teamId'] as String?;
    return _cachedTeamId;
  }

  /// Manually update the cached team ID
  void updateCachedTeamId(String? teamId) {
    _cachedTeamId = teamId;
  }
}
