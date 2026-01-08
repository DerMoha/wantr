import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_settings.dart';
import '../../core/providers/game_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/team_service.dart';
import '../../core/theme/app_theme.dart';

/// Account screen styled as an "Explorer's Guild" interface
/// Features parchment cards and brass accents
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final AuthService _authService = AuthService();
  late final TeamService _teamService;

  bool _isLoading = false;
  bool _isLoadingTeam = false;
  bool _isSyncing = false;
  bool _isLeader = false;
  bool _isTeamOperationInProgress = false;
  String? _error;
  Map<String, dynamic>? _teamData;
  String? _customDisplayName;

  @override
  void initState() {
    super.initState();
    _teamService = TeamService(_authService);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!_authService.isLoggedIn) return;

    final userId = _authService.userId;
    if (userId != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get()
          .then((userDoc) {
        if (userDoc.exists && mounted) {
          setState(() {
            _customDisplayName = userDoc.data()?['displayName'];
          });
        }
      });
    }

    final teamId = await _authService.getUserTeamId();
    if (teamId != null) {
      if (mounted) setState(() => _isLoadingTeam = true);
      try {
        final data = await _teamService.getTeamData(teamId);
        if (data != null) {
          data['id'] = teamId;
        }
        final isLeader = await _teamService.isTeamLeader(teamId);
        if (mounted) {
          setState(() {
            _teamData = data;
            _isLeader = isLeader;
          });
        }
      } finally {
        if (mounted) setState(() => _isLoadingTeam = false);
      }
    } else {
      if (mounted) {
        setState(() {
          _teamData = null;
          _isLeader = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WantrTheme.background,
      appBar: AppBar(
        title: Text(
          "EXPLORER'S GUILD",
          style: GoogleFonts.cormorant(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 3.0,
          ),
        ),
        backgroundColor: WantrTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WantrTheme.brass),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          final user = snapshot.data;
          final isLoggedIn = user != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Explorer profile card
                _ExplorerProfileCard(
                  user: user,
                  isLoggedIn: isLoggedIn,
                  customDisplayName: _customDisplayName,
                  isLoading: _isLoading,
                  onSignInWithGoogle: _signInWithGoogle,
                  onContinueAsGuest: _continueAsGuest,
                  onLinkWithGoogle: _linkWithGoogle,
                  onSignOut: _signOut,
                  onEditUsername: _showEditUsernameDialog,
                ),

                const SizedBox(height: 20),

                // Expedition party (team) card
                if (isLoggedIn) ...[
                  _ExpeditionPartyCard(
                    teamData: _teamData,
                    isLoadingTeam: _isLoadingTeam,
                    isSyncing: _isSyncing,
                    isLeader: _isLeader,
                    isOperationInProgress: _isTeamOperationInProgress,
                    currentUserId: _authService.userId,
                    teamService: _teamService,
                    onSyncDiscoveries: _syncDiscoveries,
                    onLeaveTeam: _leaveTeam,
                    onCreateTeam: _showCreateTeamDialog,
                    onJoinTeam: _showJoinTeamDialog,
                    onRegenerateCode: _isLeader ? _regenerateInviteCode : null,
                    onKickMember: _isLeader ? _kickMember : null,
                    onTransferLeadership: _isLeader ? _transferLeadership : null,
                  ),
                  const SizedBox(height: 20),
                ],

                // Settings card
                _SettingsCard(),

                const SizedBox(height: 20),

                // Info card for guests
                if (!isLoggedIn) _GuestInfoCard(),

                // Error display
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: WantrTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: WantrTheme.error.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: GoogleFonts.crimsonPro(
                          color: WantrTheme.error,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _authService.signInWithGoogle();
      await _loadUserData();
    } catch (e) {
      if (mounted) setState(() => _error = 'Sign in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _authService.signInAnonymously();
    } catch (e) {
      if (mounted) setState(() => _error = 'Guest sign in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _linkWithGoogle() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _authService.linkWithGoogle();
      await _loadUserData();
    } catch (e) {
      if (mounted) setState(() => _error = 'Link failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showEditUsernameDialog() async {
    final controller = TextEditingController(
      text: _customDisplayName ?? _authService.currentUser?.displayName ?? '',
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WantrTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: WantrTheme.brass.withOpacity(0.3)),
        ),
        title: Text(
          'Edit Explorer Name',
          style: GoogleFonts.cormorant(
            color: WantrTheme.brass,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.crimsonPro(color: WantrTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: TextStyle(color: WantrTheme.textMuted),
          ),
          autofocus: true,
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.crimsonPro(color: WantrTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: WantrTheme.brass,
            ),
            child: Text(
              'Save',
              style: GoogleFonts.crimsonPro(color: WantrTheme.background),
            ),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _customDisplayName) {
      final userId = _authService.userId;
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'displayName': newName});

        setState(() => _customDisplayName = newName);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Explorer name updated!',
                style: GoogleFonts.crimsonPro(),
              ),
              backgroundColor: WantrTheme.brass,
            ),
          );
        }
      }
    }
  }

  Future<void> _signOut() async {
    // Clean up local state before signing out
    if (mounted) {
      await context.read<GameProvider>().onSignOut();
    }
    await _authService.signOut();
    if (mounted) setState(() => _teamData = null);
  }

  Future<void> _kickMember(String memberId, String memberName) async {
    final teamId = _teamData?['id'] as String?;
    if (teamId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WantrTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: WantrTheme.brass.withOpacity(0.3)),
        ),
        title: Text(
          'Remove Explorer?',
          style: GoogleFonts.cormorant(
            color: WantrTheme.brass,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Remove $memberName from your expedition party?',
          style: GoogleFonts.crimsonPro(color: WantrTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.crimsonPro(color: WantrTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: WantrTheme.error),
            child: Text(
              'Remove',
              style: GoogleFonts.crimsonPro(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _teamService.kickMember(teamId, memberId);
      if (result == 'success') {
        await _loadUserData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$memberName has been removed.',
                style: GoogleFonts.crimsonPro(),
              ),
              backgroundColor: WantrTheme.brass,
            ),
          );
        }
      } else {
        setState(() => _error = 'Failed to remove member.');
      }
    }
  }

  Future<void> _transferLeadership(String memberId, String memberName) async {
    final teamId = _teamData?['id'] as String?;
    if (teamId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WantrTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: WantrTheme.brass.withOpacity(0.3)),
        ),
        title: Text(
          'Transfer Leadership?',
          style: GoogleFonts.cormorant(
            color: WantrTheme.brass,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Make $memberName the new expedition leader? You will remain a member.',
          style: GoogleFonts.crimsonPro(color: WantrTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.crimsonPro(color: WantrTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: WantrTheme.brass),
            child: Text(
              'Transfer',
              style: GoogleFonts.crimsonPro(color: WantrTheme.background),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _teamService.transferLeadership(teamId, memberId);
      if (result == 'success') {
        await _loadUserData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$memberName is now the expedition leader.',
                style: GoogleFonts.crimsonPro(),
              ),
              backgroundColor: WantrTheme.brass,
            ),
          );
        }
      } else {
        setState(() => _error = 'Failed to transfer leadership.');
      }
    }
  }

  Future<void> _regenerateInviteCode() async {
    final teamId = _teamData?['id'] as String?;
    if (teamId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WantrTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: WantrTheme.brass.withOpacity(0.3)),
        ),
        title: Text(
          'Regenerate Charter Code?',
          style: GoogleFonts.cormorant(
            color: WantrTheme.brass,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'The old code will no longer work. Share the new code with your party members.',
          style: GoogleFonts.crimsonPro(color: WantrTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.crimsonPro(color: WantrTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: WantrTheme.brass),
            child: Text(
              'Regenerate',
              style: GoogleFonts.crimsonPro(color: WantrTheme.background),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final newCode = await _teamService.regenerateInviteCode(teamId);
      if (newCode != null) {
        await _loadUserData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'New charter code: $newCode',
                style: GoogleFonts.crimsonPro(),
              ),
              backgroundColor: WantrTheme.brass,
            ),
          );
        }
      } else {
        setState(() => _error = 'Failed to regenerate charter code.');
      }
    }
  }

  Future<void> _leaveTeam() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WantrTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: WantrTheme.brass.withOpacity(0.3)),
        ),
        title: Text(
          'Leave Expedition?',
          style: GoogleFonts.cormorant(
            color: WantrTheme.brass,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'You will no longer share discoveries with this party.',
          style: GoogleFonts.crimsonPro(color: WantrTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.crimsonPro(color: WantrTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Leave',
              style: GoogleFonts.crimsonPro(color: WantrTheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isTeamOperationInProgress = true);
      try {
        final leftTeamId = await _teamService.leaveTeam();
        if (leftTeamId != null && mounted) {
          // Clear local team state in GameProvider
          await context.read<GameProvider>().clearTeamState();
        }
        if (mounted) setState(() => _teamData = null);
      } finally {
        if (mounted) setState(() => _isTeamOperationInProgress = false);
      }
    }
  }

  Future<void> _syncDiscoveries() async {
    if (!mounted) return;
    setState(() => _isSyncing = true);

    try {
      final gameProvider = context.read<GameProvider>();
      final localSegments = gameProvider.revealedSegments;
      // Use the shared CloudSyncService instance from GameProvider
      final count = await gameProvider.cloudSyncService.uploadLocalSegments(localSegments);

      // Also pull any team discoveries we might be missing
      await gameProvider.refreshTeamSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Synced $count discoveries to expedition!',
              style: GoogleFonts.crimsonPro(),
            ),
            backgroundColor: WantrTheme.streetTeamGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync failed: $e',
              style: GoogleFonts.crimsonPro(),
            ),
            backgroundColor: WantrTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _showCreateTeamDialog() async {
    final nameController = TextEditingController();
    String? validationError;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: WantrTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: WantrTheme.brass.withOpacity(0.3)),
          ),
          title: Text(
            'Found Expedition Party',
            style: GoogleFonts.cormorant(
              color: WantrTheme.brass,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: GoogleFonts.crimsonPro(color: WantrTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Party name (2-30 chars)',
                  hintStyle: TextStyle(color: WantrTheme.textMuted),
                  errorText: validationError,
                  errorStyle: GoogleFonts.crimsonPro(color: WantrTheme.error),
                ),
                maxLength: 30,
                autofocus: true,
                onChanged: (_) {
                  if (validationError != null) {
                    setDialogState(() => validationError = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.crimsonPro(color: WantrTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final error = _teamService.validateTeamName(nameController.text);
                if (error != null) {
                  setDialogState(() => validationError = error);
                } else {
                  Navigator.pop(context, nameController.text);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: WantrTheme.brass),
              child: Text(
                'Found',
                style: GoogleFonts.crimsonPro(color: WantrTheme.background),
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _isTeamOperationInProgress = true);
      try {
        final teamId = await _teamService.createTeam(result);
        if (teamId != null) {
          await _loadUserData();
          // Refresh team sync to load any existing discoveries
          if (mounted) {
            await context.read<GameProvider>().refreshTeamSync();
          }
        } else {
          setState(() => _error = 'Failed to create expedition party.');
        }
      } finally {
        if (mounted) setState(() => _isTeamOperationInProgress = false);
      }
    }
  }

  Future<void> _showJoinTeamDialog() async {
    final codeController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WantrTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: WantrTheme.brass.withOpacity(0.3)),
        ),
        title: Text(
          'Join Expedition',
          style: GoogleFonts.cormorant(
            color: WantrTheme.brass,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: codeController,
          style: GoogleFonts.crimsonPro(color: WantrTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter charter code',
            hintStyle: TextStyle(color: WantrTheme.textMuted),
          ),
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.crimsonPro(color: WantrTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, codeController.text),
            style: ElevatedButton.styleFrom(backgroundColor: WantrTheme.brass),
            child: Text(
              'Join',
              style: GoogleFonts.crimsonPro(color: WantrTheme.background),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _isTeamOperationInProgress = true);
      try {
        final joinResult = await _teamService.joinTeam(result);
        switch (joinResult) {
          case 'success':
            await _loadUserData();
            // Refresh team sync to load team's existing discoveries
            if (mounted) {
              await context.read<GameProvider>().refreshTeamSync();
            }
            break;
          case 'not_found':
            setState(() => _error = 'No expedition found with that charter code.');
            break;
          case 'full':
            setState(() => _error = 'This expedition is full (max 3 explorers).');
            break;
          default:
            setState(() => _error = 'Could not join expedition. Please try again.');
        }
      } finally {
        if (mounted) setState(() => _isTeamOperationInProgress = false);
      }
    }
  }
}

/// Explorer profile card styled as a guild membership badge
class _ExplorerProfileCard extends StatelessWidget {
  final User? user;
  final bool isLoggedIn;
  final String? customDisplayName;
  final bool isLoading;
  final VoidCallback onSignInWithGoogle;
  final VoidCallback onContinueAsGuest;
  final VoidCallback onLinkWithGoogle;
  final VoidCallback onSignOut;
  final VoidCallback onEditUsername;

  const _ExplorerProfileCard({
    required this.user,
    required this.isLoggedIn,
    required this.customDisplayName,
    required this.isLoading,
    required this.onSignInWithGoogle,
    required this.onContinueAsGuest,
    required this.onLinkWithGoogle,
    required this.onSignOut,
    required this.onEditUsername,
  });

  @override
  Widget build(BuildContext context) {
    final isAnonymous = user?.isAnonymous ?? false;

    return Container(
      decoration: WantrTheme.cardDecoration,
      child: Stack(
        children: [
          // Corner ornaments
          Positioned(
            top: 12,
            left: 12,
            child: CartographicDecorations.cornerOrnament(
              position: CornerPosition.topLeft,
              size: 20,
              color: WantrTheme.brass.withOpacity(0.4),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: CartographicDecorations.cornerOrnament(
              position: CornerPosition.topRight,
              size: 20,
              color: WantrTheme.brass.withOpacity(0.4),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar with brass ring
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: WantrTheme.brass,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: WantrTheme.brass.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: isAnonymous
                        ? WantrTheme.streetTeamGreen
                        : WantrTheme.brass,
                    backgroundImage:
                        user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                    child: user?.photoURL == null
                        ? Icon(
                            isLoggedIn
                                ? (isAnonymous
                                    ? Icons.person_outline
                                    : Icons.person)
                                : Icons.person_outline,
                            size: 40,
                            color: WantrTheme.background,
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 16),

                // Name with edit option
                if (isLoggedIn)
                  GestureDetector(
                    onTap: onEditUsername,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          customDisplayName ?? user?.displayName ?? 'Wanderer',
                          style: GoogleFonts.cormorant(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: WantrTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: WantrTheme.brass,
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'Not Registered',
                    style: GoogleFonts.cormorant(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: WantrTheme.textPrimary,
                    ),
                  ),

                if (isAnonymous)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Temporary charter - link to preserve progress',
                      style: GoogleFonts.crimsonPro(
                        color: WantrTheme.textMuted,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (isLoggedIn && user?.email != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      user!.email!,
                      style: GoogleFonts.crimsonPro(
                        color: WantrTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Action buttons
                if (isLoading)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: WantrTheme.brass,
                      strokeWidth: 2,
                    ),
                  )
                else if (isAnonymous)
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: onLinkWithGoogle,
                        icon: const Icon(Icons.link, size: 18),
                        label: Text(
                          'Link Google Account',
                          style: GoogleFonts.crimsonPro(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WantrTheme.brass,
                          foregroundColor: WantrTheme.background,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: onSignOut,
                        child: Text(
                          'Sign Out',
                          style: GoogleFonts.crimsonPro(
                            color: WantrTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (isLoggedIn)
                  OutlinedButton.icon(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(
                      'Sign Out',
                      style: GoogleFonts.crimsonPro(),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WantrTheme.textSecondary,
                      side: BorderSide(color: WantrTheme.textMuted),
                    ),
                  )
                else
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: onSignInWithGoogle,
                        icon: const Icon(Icons.login, size: 18),
                        label: Text(
                          'Sign in with Google',
                          style: GoogleFonts.crimsonPro(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WantrTheme.brass,
                          foregroundColor: WantrTheme.background,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: onContinueAsGuest,
                        icon: const Icon(Icons.person_outline, size: 18),
                        label: Text(
                          'Continue as Guest',
                          style: GoogleFonts.crimsonPro(),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: WantrTheme.textSecondary,
                          side: BorderSide(color: WantrTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Expedition party (team) card
class _ExpeditionPartyCard extends StatelessWidget {
  final Map<String, dynamic>? teamData;
  final bool isLoadingTeam;
  final bool isSyncing;
  final bool isLeader;
  final bool isOperationInProgress;
  final String? currentUserId;
  final TeamService teamService;
  final VoidCallback onSyncDiscoveries;
  final VoidCallback onLeaveTeam;
  final VoidCallback onCreateTeam;
  final VoidCallback onJoinTeam;
  final VoidCallback? onRegenerateCode;
  final void Function(String memberId, String memberName)? onKickMember;
  final void Function(String memberId, String memberName)? onTransferLeadership;

  const _ExpeditionPartyCard({
    required this.teamData,
    required this.isLoadingTeam,
    required this.isSyncing,
    required this.isLeader,
    required this.isOperationInProgress,
    required this.currentUserId,
    required this.teamService,
    required this.onSyncDiscoveries,
    required this.onLeaveTeam,
    required this.onCreateTeam,
    required this.onJoinTeam,
    this.onRegenerateCode,
    this.onKickMember,
    this.onTransferLeadership,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: WantrTheme.cardDecoration,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: WantrTheme.brass.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.group_outlined,
                  color: WantrTheme.brass,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'EXPEDITION PARTY',
                style: GoogleFonts.cormorant(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: WantrTheme.brass,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (isLoadingTeam)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: WantrTheme.brass,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (teamData != null) ...[
            // Team info
            Text(
              teamData!['name'] ?? 'Unnamed Expedition',
              style: GoogleFonts.cormorant(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: WantrTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.vpn_key_outlined,
                    size: 16, color: WantrTheme.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Charter Code: ',
                  style: GoogleFonts.crimsonPro(
                    color: WantrTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      final code = teamData!['inviteCode'] as String?;
                      if (code != null) {
                        Clipboard.setData(ClipboardData(text: code));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Charter code copied!',
                              style: GoogleFonts.crimsonPro(),
                            ),
                            backgroundColor: WantrTheme.brass,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${teamData!['inviteCode']}',
                            style: GoogleFonts.jetBrainsMono(
                              color: WantrTheme.brass,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy,
                            size: 14,
                            color: WantrTheme.brass.withOpacity(0.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isLeader && onRegenerateCode != null) ...[
                  const Spacer(),
                  Tooltip(
                    message: 'Generate new code',
                    child: GestureDetector(
                      onTap: onRegenerateCode,
                      child: Icon(
                        Icons.refresh,
                        size: 18,
                        color: WantrTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${(teamData!['members'] as List?)?.length ?? 0}/3 explorers',
                  style: GoogleFonts.crimsonPro(
                    color: WantrTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                if ((teamData!['members'] as List?)?.length == 3) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: WantrTheme.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'FULL',
                      style: GoogleFonts.crimsonPro(
                        color: WantrTheme.error,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Invite prompt when alone
            if ((teamData!['members'] as List?)?.length == 1) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: WantrTheme.brass.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Share your charter code to invite fellow explorers!',
                      style: GoogleFonts.crimsonPro(
                        color: WantrTheme.brass.withOpacity(0.7),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Actions row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isSyncing ? null : onSyncDiscoveries,
                    icon: isSyncing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: WantrTheme.background,
                            ),
                          )
                        : const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: Text(
                      isSyncing ? 'Syncing...' : 'Sync',
                      style: GoogleFonts.crimsonPro(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WantrTheme.streetTeamGreen,
                      foregroundColor: WantrTheme.background,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: isOperationInProgress ? null : onLeaveTeam,
                  child: isOperationInProgress
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: WantrTheme.error,
                          ),
                        )
                      : Text(
                          'Leave',
                          style: GoogleFonts.crimsonPro(color: WantrTheme.error),
                        ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Decorative divider
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    WantrTheme.brass.withOpacity(0.0),
                    WantrTheme.brass.withOpacity(0.3),
                    WantrTheme.brass.withOpacity(0.0),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Leaderboard
            Row(
              children: [
                Icon(Icons.leaderboard_outlined,
                    size: 16, color: WantrTheme.brass),
                const SizedBox(width: 8),
                Text(
                  'RANKINGS',
                  style: GoogleFonts.cormorant(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: WantrTheme.brass,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: teamService.getTeamMemberStats(teamData!['id'] ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        color: WantrTheme.brass,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }

                final members = snapshot.data ?? [];
                if (members.isEmpty) {
                  return Text(
                    'No data yet - start exploring!',
                    style: GoogleFonts.crimsonPro(
                      color: WantrTheme.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }

                return Column(
                  children: members.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final member = entry.value;
                    final isMe = member['isCurrentUser'] as bool;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe
                            ? WantrTheme.brass.withOpacity(0.1)
                            : WantrTheme.backgroundAlt.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: isMe
                            ? Border.all(
                                color: WantrTheme.brass.withOpacity(0.4))
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Rank
                          SizedBox(
                            width: 28,
                            child: Text(
                              rank == 1
                                  ? '1st'
                                  : rank == 2
                                      ? '2nd'
                                      : rank == 3
                                          ? '3rd'
                                          : '#$rank',
                              style: GoogleFonts.cormorant(
                                fontWeight: FontWeight.bold,
                                color: rank == 1
                                    ? WantrTheme.gold
                                    : rank == 2
                                        ? WantrTheme.textSecondary
                                        : rank == 3
                                            ? WantrTheme.copper
                                            : WantrTheme.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ),

                          // Avatar
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: WantrTheme.brass.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: WantrTheme.streetTeamGreen,
                              backgroundImage: member['photoUrl'] != null
                                  ? NetworkImage(member['photoUrl'])
                                  : null,
                              child: member['photoUrl'] == null
                                  ? const Icon(Icons.person,
                                      size: 12, color: WantrTheme.background)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Name + leader badge + (You) label
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    member['displayName'] ?? 'Unknown',
                                    style: GoogleFonts.crimsonPro(
                                      color: isMe
                                          ? WantrTheme.brass
                                          : WantrTheme.textPrimary,
                                      fontWeight:
                                          isMe ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '(You)',
                                    style: GoogleFonts.crimsonPro(
                                      color: WantrTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (member['userId'] == teamData?['leaderId']) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.star,
                                    size: 14,
                                    color: WantrTheme.gold,
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Segment count
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${member['segments']}',
                                style: GoogleFonts.jetBrainsMono(
                                  color: WantrTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.explore_outlined,
                                size: 12,
                                color: WantrTheme.textMuted,
                              ),
                            ],
                          ),

                          // Leader actions (kick/transfer) for non-self members
                          if (isLeader && !isMe) ...[
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                size: 18,
                                color: WantrTheme.textMuted,
                              ),
                              color: WantrTheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: WantrTheme.brass.withOpacity(0.3),
                                ),
                              ),
                              onSelected: (value) {
                                final memberId = member['userId'] as String;
                                final memberName = member['displayName'] as String? ?? 'Unknown';
                                if (value == 'kick') {
                                  onKickMember?.call(memberId, memberName);
                                } else if (value == 'transfer') {
                                  onTransferLeadership?.call(memberId, memberName);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'transfer',
                                  child: Row(
                                    children: [
                                      Icon(Icons.star_outline,
                                          size: 16, color: WantrTheme.brass),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Make Leader',
                                        style: GoogleFonts.crimsonPro(
                                          color: WantrTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'kick',
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_remove_outlined,
                                          size: 16, color: WantrTheme.error),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Remove',
                                        style: GoogleFonts.crimsonPro(
                                          color: WantrTheme.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ] else ...[
            // No team - options
            Text(
              'Join an expedition to share discoveries with fellow explorers!',
              style: GoogleFonts.crimsonPro(
                color: WantrTheme.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),
            if (isOperationInProgress)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    color: WantrTheme.brass,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onCreateTeam,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WantrTheme.brass,
                        foregroundColor: WantrTheme.background,
                      ),
                      child: Text(
                        'Found Party',
                        style: GoogleFonts.crimsonPro(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onJoinTeam,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: WantrTheme.brass,
                        side: const BorderSide(color: WantrTheme.brass),
                      ),
                      child: Text(
                        'Join Party',
                        style: GoogleFonts.crimsonPro(),
                      ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Settings card
class _SettingsCard extends StatefulWidget {
  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> {
  @override
  Widget build(BuildContext context) {
    Box? settingsBox;
    try {
      settingsBox = Hive.box('app_settings');
    } catch (e) {
      // Box not open
    }

    if (settingsBox != null && settingsBox.isOpen) {
      return _buildContent(settingsBox);
    }

    return FutureBuilder<Box>(
      future: Hive.openBox('app_settings'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: WantrTheme.cardDecoration,
            padding: const EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(
                color: WantrTheme.brass,
                strokeWidth: 2,
              ),
            ),
          );
        }

        if (!snapshot.hasData) return const SizedBox.shrink();
        return _buildContent(snapshot.data!);
      },
    );
  }

  Widget _buildContent(Box box) {
    dynamic rawSettings = box.get('settings');
    AppSettings settings;

    if (rawSettings is AppSettings) {
      settings = rawSettings;
    } else {
      settings = AppSettings();
      box.put('settings', settings);
    }

    return Container(
      decoration: WantrTheme.cardDecoration,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: WantrTheme.brass.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.settings_outlined,
                  color: WantrTheme.brass,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'EXPEDITION SETTINGS',
                style: GoogleFonts.cormorant(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: WantrTheme.brass,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            'GPS Precision',
            style: GoogleFonts.crimsonPro(
              fontWeight: FontWeight.w600,
              color: WantrTheme.textPrimary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            settings.gpsModeDescription,
            style: GoogleFonts.crimsonPro(
              color: WantrTheme.textMuted,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 14),

          // GPS mode selector
          Row(
            children: GpsMode.values.map((mode) {
              final isSelected = settings.gpsMode == mode;
              final label = switch (mode) {
                GpsMode.batterySaver => 'Saver',
                GpsMode.balanced => 'Balanced',
                GpsMode.highAccuracy => 'Precise',
              };

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: mode != GpsMode.highAccuracy ? 8 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () async {
                      settings.gpsMode = mode;
                      await box.put('settings', settings);
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? WantrTheme.brass
                            : WantrTheme.backgroundAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? WantrTheme.brass
                              : WantrTheme.brass.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.crimsonPro(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? WantrTheme.background
                              : WantrTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 6),
          Text(
            'Changes apply on next tracking session.',
            style: GoogleFonts.crimsonPro(
              color: WantrTheme.textMuted,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),

          const SizedBox(height: 20),

          // Divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  WantrTheme.brass.withOpacity(0.0),
                  WantrTheme.brass.withOpacity(0.3),
                  WantrTheme.brass.withOpacity(0.0),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // WiFi sync toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WiFi-only sync',
                    style: GoogleFonts.crimsonPro(
                      fontWeight: FontWeight.w600,
                      color: WantrTheme.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sync only when connected to WiFi',
                    style: GoogleFonts.crimsonPro(
                      fontSize: 12,
                      color: WantrTheme.textMuted,
                    ),
                  ),
                ],
              ),
              Switch(
                value: settings.wifiOnlySync,
                onChanged: (value) async {
                  settings.wifiOnlySync = value;
                  await box.put('settings', settings);
                  setState(() {});
                },
                activeColor: WantrTheme.brass,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Info card for guests
class _GuestInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: WantrTheme.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: WantrTheme.brass.withOpacity(0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            color: WantrTheme.brass,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'Exploring without charter',
            style: GoogleFonts.cormorant(
              fontWeight: FontWeight.bold,
              color: WantrTheme.textPrimary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '• Discoveries saved locally on this device\n'
            '• Cannot join expedition parties\n'
            '• Rankings require registration\n'
            '• Register anytime to sync progress',
            style: GoogleFonts.crimsonPro(
              color: WantrTheme.textSecondary,
              height: 1.6,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
