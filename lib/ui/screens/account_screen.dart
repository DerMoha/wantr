import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/models/app_settings.dart';
import '../../core/services/auth_service.dart';
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
  String? _error;
  Map<String, dynamic>? _teamData;

  @override
  void initState() {
    super.initState();
    _teamService = TeamService(_authService);
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    if (!_authService.isLoggedIn) return;
    
    final teamId = await _authService.getUserTeamId();
    if (teamId != null) {
      final data = await _teamService.getTeamData(teamId);
      setState(() => _teamData = data);
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
            backgroundColor: WantrTheme.discovered,
            backgroundImage: user?.photoURL != null 
                ? NetworkImage(user!.photoURL!) 
                : null,
            child: user?.photoURL == null
                ? Icon(
                    isLoggedIn ? Icons.person : Icons.person_outline,
                    size: 40,
                    color: WantrTheme.background,
                  )
                : null,
          ),
          
          const SizedBox(height: 16),
          
          // Name/Status
          Text(
            isLoggedIn 
                ? (user?.displayName ?? 'Wanderer')
                : 'Not Logged In',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: WantrTheme.textPrimary,
            ),
          ),
          
          if (isLoggedIn && user?.email != null)
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
            TextButton(
              onPressed: _leaveTeam,
              child: const Text('Leave Team', style: TextStyle(color: Colors.redAccent)),
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
    return FutureBuilder<Box<AppSettings>>(
      future: Hive.openBox<AppSettings>('app_settings'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final box = snapshot.data!;
        AppSettings settings = box.get('settings') ?? AppSettings();
        
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
              
              const SizedBox(height: 12),
              
              const Text(
                '⚠️ Higher accuracy drains battery faster. Restart app to apply changes.',
                style: TextStyle(
                  color: WantrTheme.textSecondary,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
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
      await _loadTeamData();
    } catch (e) {
      if (mounted) setState(() => _error = 'Sign in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      await _loadTeamData();
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
        await _loadTeamData();
      } else {
        setState(() => _error = 'Could not join team. Check the code and try again.');
      }
    }
  }
}
