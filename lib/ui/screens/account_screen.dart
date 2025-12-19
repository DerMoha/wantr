import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_settings.dart';
import '../../core/providers/game_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cloud_sync_service.dart';
import '../../core/services/team_service.dart';
import '../../core/theme/app_theme.dart';

/// Account settings screen with optional login
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final AuthService _authService = AuthService();
  late final TeamService _teamService;
  
  bool _isLoading = false;
  bool _isSyncing = false;  // Separate loading state for sync button
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
    
    // Load custom display name from Firestore
    final userId = _authService.userId;
    if (userId != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists && mounted) {
        setState(() {
          _customDisplayName = userDoc.data()?['displayName'];
        });
      }
    }
    
    // Load team data
    final teamId = await _authService.getUserTeamId();
    if (teamId != null) {
      final data = await _teamService.getTeamData(teamId);
      if (data != null) {
        data['id'] = teamId;
      }
      if (mounted) setState(() => _teamData = data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WantrTheme.background,
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: WantrTheme.surface,
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
                // Account status card
                _buildAccountCard(user, isLoggedIn),
                
                const SizedBox(height: 16),
                
                // Team section (only if logged in)
                if (isLoggedIn) ...[
                  _buildTeamCard(),
                  const SizedBox(height: 16),
                ],
                
                // Settings section
                _buildSettingsCard(),
                
                const SizedBox(height: 16),
                
                // Info card for non-logged in users
                if (!isLoggedIn)
                  _buildInfoCard(),
                
                // Error display
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountCard(User? user, bool isLoggedIn) {
    final isAnonymous = _authService.isAnonymous;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WantrTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WantrTheme.undiscovered),
      ),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 40,
            backgroundColor: isAnonymous ? WantrTheme.streetTeamGreen : WantrTheme.discovered,
            backgroundImage: user?.photoURL != null 
                ? NetworkImage(user!.photoURL!) 
                : null,
            child: user?.photoURL == null
                ? Icon(
                    isLoggedIn ? (isAnonymous ? Icons.person_outline : Icons.person) : Icons.person_outline,
                    size: 40,
                    color: WantrTheme.background,
                  )
                : null,
          ),
          
          const SizedBox(height: 16),
          
          // Name/Status with edit button
          if (isLoggedIn)
            GestureDetector(
              onTap: _showEditUsernameDialog,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _customDisplayName ?? user?.displayName ?? 'Wanderer',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: WantrTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.edit,
                    size: 16,
                    color: WantrTheme.textSecondary,
                  ),
                ],
              ),
            )
          else
            Text(
              'Not Logged In',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: WantrTheme.textPrimary,
              ),
            ),
          
          if (isAnonymous)
            const Text(
              'Temporary account - link to Google to save progress',
              style: TextStyle(
                color: WantrTheme.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            )
          else if (isLoggedIn && user?.email != null)
            Text(
              user!.email!,
              style: const TextStyle(
                color: WantrTheme.textSecondary,
              ),
            ),
          
          const SizedBox(height: 20),
          
          // Login/Logout button
          if (_isLoading)
            const CircularProgressIndicator(color: WantrTheme.discovered)
          else if (isAnonymous)
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _linkWithGoogle,
                  icon: const Icon(Icons.link),
                  label: const Text('Link to Google Account'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WantrTheme.discovered,
                    foregroundColor: WantrTheme.background,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _signOut,
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(color: WantrTheme.textSecondary),
                  ),
                ),
              ],
            )
          else if (isLoggedIn)
            OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: WantrTheme.textSecondary,
              ),
            )
          else
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WantrTheme.discovered,
                    foregroundColor: WantrTheme.background,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _continueAsGuest,
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Continue as Guest'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WantrTheme.textSecondary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTeamCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WantrTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WantrTheme.undiscovered),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group, color: WantrTheme.discovered),
              const SizedBox(width: 8),
              const Text(
                'Team',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: WantrTheme.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (_teamData != null) ...[
            // Show current team
            Text(
              _teamData!['name'] ?? 'Unnamed Team',
              style: const TextStyle(
                fontSize: 16,
                color: WantrTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.vpn_key, size: 16, color: WantrTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Invite code: ${_teamData!['inviteCode']}',
                  style: const TextStyle(color: WantrTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${(_teamData!['members'] as List?)?.length ?? 0}/3 members',
              style: const TextStyle(color: WantrTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _syncDiscoveries,
                    icon: _isSyncing 
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: WantrTheme.background,
                            ),
                          )
                        : const Icon(Icons.cloud_upload, size: 18),
                    label: Text(_isSyncing ? 'Syncing...' : 'Sync Discoveries'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WantrTheme.streetTeamGreen,
                      foregroundColor: WantrTheme.background,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _leaveTeam,
                  child: const Text('Leave', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            const Divider(color: WantrTheme.undiscovered),
            const SizedBox(height: 12),
            
            // Team Leaderboard
            const Row(
              children: [
                Icon(Icons.leaderboard, size: 18, color: WantrTheme.discovered),
                SizedBox(width: 8),
                Text(
                  'Team Leaderboard',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: WantrTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _teamService.getTeamMemberStats(_teamData!['id'] ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: WantrTheme.discovered),
                    ),
                  );
                }
                
                final members = snapshot.data ?? [];
                if (members.isEmpty) {
                  return const Text(
                    'No data yet - start exploring!',
                    style: TextStyle(color: WantrTheme.textSecondary),
                  );
                }
                
                return Column(
                  children: members.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final member = entry.value;
                    final isMe = member['isCurrentUser'] as bool;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? WantrTheme.discovered.withAlpha(30) : WantrTheme.undiscovered.withAlpha(50),
                        borderRadius: BorderRadius.circular(8),
                        border: isMe ? Border.all(color: WantrTheme.discovered, width: 1) : null,
                      ),
                      child: Row(
                        children: [
                          // Rank
                          SizedBox(
                            width: 28,
                            child: Text(
                              rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '#$rank',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: rank <= 3 ? WantrTheme.textPrimary : WantrTheme.textSecondary,
                              ),
                            ),
                          ),
                          
                          // Avatar
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: WantrTheme.streetTeamGreen,
                            backgroundImage: member['photoUrl'] != null
                                ? NetworkImage(member['photoUrl'])
                                : null,
                            child: member['photoUrl'] == null
                                ? const Icon(Icons.person, size: 14, color: WantrTheme.background)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          
                          // Name
                          Expanded(
                            child: Text(
                              member['displayName'] ?? 'Unknown',
                              style: TextStyle(
                                color: isMe ? WantrTheme.discovered : WantrTheme.textPrimary,
                                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          
                          // Segments count
                          Text(
                            '${member['segments']} 🗺️',
                            style: const TextStyle(
                              color: WantrTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ] else ...[
            // No team - show options
            const Text(
              'Join a team to share discoveries with others!',
              style: TextStyle(color: WantrTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showCreateTeamDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WantrTheme.discovered,
                      foregroundColor: WantrTheme.background,
                    ),
                    child: const Text('Create Team'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _showJoinTeamDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WantrTheme.discovered,
                    ),
                    child: const Text('Join Team'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WantrTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WantrTheme.streetYellow.withAlpha(100)),
      ),
      child: Column(
        children: [
          const Icon(Icons.info_outline, color: WantrTheme.streetYellow, size: 32),
          const SizedBox(height: 12),
          const Text(
            'Playing without an account',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: WantrTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '• Your discoveries are saved locally on this device\n'
            '• You cannot join teams or share progress\n'
            '• Leaderboards require an account\n'
            '• Sign in anytime to sync your progress',
            style: TextStyle(
              color: WantrTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    // Try to get already-opened box, or open new one
    Box? settingsBox;
    try {
      settingsBox = Hive.box('app_settings');
    } catch (e) {
      // Box not open yet, will open it
    }
    
    if (settingsBox != null && settingsBox.isOpen) {
      return _buildSettingsContent(settingsBox);
    }
    
    return FutureBuilder<Box>(
      future: Hive.openBox('app_settings'),
      builder: (context, snapshot) {
        // Show loading indicator while opening box
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: WantrTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: WantrTheme.undiscovered),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: WantrTheme.discovered),
            ),
          );
        }
        
        // Show error if failed
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: WantrTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent),
            ),
            child: Text(
              'Settings error: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }
        
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        return _buildSettingsContent(snapshot.data!);
      },
    );
  }
  
  Widget _buildSettingsContent(Box box) {
    // Get or create settings
    dynamic rawSettings = box.get('settings');
    AppSettings settings;
    
    if (rawSettings is AppSettings) {
      settings = rawSettings;
    } else {
      settings = AppSettings();
      box.put('settings', settings);
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WantrTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WantrTheme.undiscovered),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings, color: WantrTheme.discovered),
              SizedBox(width: 8),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: WantrTheme.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          const Text(
            'GPS Update Frequency',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: WantrTheme.textPrimary,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            settings.gpsModeDescription,
            style: const TextStyle(
              color: WantrTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // GPS mode selector
          Row(
            children: GpsMode.values.map((mode) {
              final isSelected = settings.gpsMode == mode;
              final label = switch (mode) {
                GpsMode.batterySaver => '🔋 Saver',
                GpsMode.balanced => '⚖️ Balanced',
                GpsMode.highAccuracy => '🎯 Smooth',
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
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? WantrTheme.discovered 
                            : WantrTheme.undiscovered,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
          
          const SizedBox(height: 8),
          
          const Text(
            '💡 Changes apply next time you start tracking.',
            style: TextStyle(
              color: WantrTheme.textSecondary,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          
          const SizedBox(height: 20),
          const Divider(color: WantrTheme.undiscovered),
          const SizedBox(height: 12),
          
          // WiFi-only sync toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WiFi-only sync',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: WantrTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Only sync to team when on WiFi',
                    style: TextStyle(
                      fontSize: 12,
                      color: WantrTheme.textSecondary,
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
                activeColor: WantrTheme.discovered,
              ),
            ],
          ),
        ],
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
        title: const Text('Edit Username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your username',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: WantrTheme.discovered,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _customDisplayName) {
      // Update in Firestore
      final userId = _authService.userId;
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'displayName': newName});
        
        setState(() => _customDisplayName = newName);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Username updated!'),
              backgroundColor: WantrTheme.discovered,
            ),
          );
        }
      }
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) setState(() => _teamData = null);
  }

  Future<void> _leaveTeam() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WantrTheme.surface,
        title: const Text('Leave Team?'),
        content: const Text('You will no longer share discoveries with this team.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _teamService.leaveTeam();
      setState(() => _teamData = null);
    }
  }

  Future<void> _syncDiscoveries() async {
    if (!mounted) return;
    setState(() => _isSyncing = true);

    try {
      // Get all local segments from GameProvider
      final gameProvider = context.read<GameProvider>();
      final localSegments = gameProvider.revealedSegments;
      
      // Upload to cloud
      final cloudSync = CloudSyncService(_authService);
      final count = await cloudSync.uploadLocalSegments(localSegments);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced $count discoveries to team!'),
            backgroundColor: WantrTheme.streetTeamGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _showCreateTeamDialog() async {
    final nameController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WantrTheme.surface,
        title: const Text('Create Team'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'Team name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _teamService.createTeam(result);
      await _loadUserData();
    }
  }

  Future<void> _showJoinTeamDialog() async {
    final codeController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WantrTheme.surface,
        title: const Text('Join Team'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            hintText: 'Enter invite code',
          ),
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, codeController.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final success = await _teamService.joinTeam(result);
      if (success) {
        await _loadUserData();
      } else {
        setState(() => _error = 'Could not join team. Check the code and try again.');
      }
    }
  }
}
