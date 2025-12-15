import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/providers/game_provider.dart';
import '../../core/theme/app_theme.dart';

/// Stats dashboard showing detailed progress information
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WantrTheme.background,
      appBar: AppBar(
        title: const Text('Stats'),
        backgroundColor: WantrTheme.surface,
      ),
      body: Consumer<GameProvider>(
        builder: (context, gameProvider, _) {
          final gameState = gameProvider.gameState;
          final segments = gameProvider.revealedSegments;
          
          if (gameState == null) {
            return const Center(
              child: CircularProgressIndicator(color: WantrTheme.discovered),
            );
          }

          // Calculate stats
          final totalDistance = gameState.totalDistanceWalked;
          final totalSegments = segments.length;
          final mySegments = segments.where((s) => s.discoveredByMe).length;
          final teamSegments = totalSegments - mySegments;
          final masteredSegments = segments.where((s) => s.timesWalked >= 10).length;
          final legendarySegments = segments.where((s) => s.timesWalked >= 50).length;
          
          // Calculate unique streets
          final uniqueStreets = segments.map((s) => s.streetId).toSet().length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Overview card
                _buildOverviewCard(
                  totalDistance: totalDistance,
                  totalSegments: totalSegments,
                  uniqueStreets: uniqueStreets,
                  xp: gameState.xp,
                  level: gameState.level,
                ),
                
                const SizedBox(height: 16),
                
                // Discovery breakdown
                _buildDiscoveryCard(
                  mySegments: mySegments,
                  teamSegments: teamSegments,
                  masteredSegments: masteredSegments,
                  legendarySegments: legendarySegments,
                ),
                
                const SizedBox(height: 16),
                
                // Progress bars
                _buildProgressCard(
                  gameState: gameState,
                  totalSegments: totalSegments,
                ),
                
                const SizedBox(height: 16),
                
                // Recent activity
                _buildRecentActivityCard(segments),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard({
    required double totalDistance,
    required int totalSegments,
    required int uniqueStreets,
    required int xp,
    required int level,
  }) {
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
              Icon(Icons.insights, color: WantrTheme.discovered),
              SizedBox(width: 8),
              Text(
                'Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: WantrTheme.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Stats grid
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.directions_walk,
                  value: _formatDistance(totalDistance),
                  label: 'Distance',
                  color: WantrTheme.energy,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.route,
                  value: '$totalSegments',
                  label: 'Segments',
                  color: WantrTheme.discovered,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.map,
                  value: '$uniqueStreets',
                  label: 'Streets',
                  color: WantrTheme.streetGold,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.star,
                  value: 'Lvl $level',
                  label: '$xp XP',
                  color: WantrTheme.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: WantrTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: WantrTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveryCard({
    required int mySegments,
    required int teamSegments,
    required int masteredSegments,
    required int legendarySegments,
  }) {
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
              Icon(Icons.explore, color: WantrTheme.discovered),
              SizedBox(width: 8),
              Text(
                'Discovery Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: WantrTheme.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          _buildBreakdownRow(
            icon: Icons.person,
            label: 'My discoveries',
            value: mySegments,
            color: WantrTheme.streetYellow,
          ),
          const SizedBox(height: 12),
          _buildBreakdownRow(
            icon: Icons.group,
            label: 'Team discoveries',
            value: teamSegments,
            color: WantrTheme.streetTeamGreen,
          ),
          const SizedBox(height: 12),
          _buildBreakdownRow(
            icon: Icons.military_tech,
            label: 'Mastered (10+ walks)',
            value: masteredSegments,
            color: WantrTheme.streetGold,
          ),
          const SizedBox(height: 12),
          _buildBreakdownRow(
            icon: Icons.emoji_events,
            label: 'Legendary (50+ walks)',
            value: legendarySegments,
            color: WantrTheme.streetLegendary,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withAlpha(40),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: WantrTheme.textPrimary),
          ),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard({
    required dynamic gameState,
    required int totalSegments,
  }) {
    final xpToNext = gameState.xpForNextLevel;
    final currentXp = gameState.xp % xpToNext;
    final progress = currentXp / xpToNext;

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
              Icon(Icons.trending_up, color: WantrTheme.discovered),
              SizedBox(width: 8),
              Text(
                'Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: WantrTheme.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Level progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level ${gameState.level}',
                style: const TextStyle(color: WantrTheme.textPrimary),
              ),
              Text(
                '$currentXp / $xpToNext XP',
                style: const TextStyle(color: WantrTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: WantrTheme.undiscovered,
              valueColor: const AlwaysStoppedAnimation(WantrTheme.discovered),
              minHeight: 8,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Discovery points
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Discovery Points',
                style: TextStyle(color: WantrTheme.textPrimary),
              ),
              Text(
                '${gameState.discoveryPoints}',
                style: const TextStyle(
                  color: WantrTheme.discovered,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard(List<dynamic> segments) {
    // Get 5 most recent discoveries
    final sortedSegments = List.from(segments)
      ..sort((a, b) => b.firstDiscoveredAt.compareTo(a.firstDiscoveredAt));
    final recent = sortedSegments.take(5).toList();

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
              Icon(Icons.history, color: WantrTheme.discovered),
              SizedBox(width: 8),
              Text(
                'Recent Discoveries',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: WantrTheme.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (recent.isEmpty)
            const Text(
              'No discoveries yet. Start exploring!',
              style: TextStyle(color: WantrTheme.textSecondary),
            )
          else
            ...recent.map((segment) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: segment.discoveredByMe 
                          ? WantrTheme.streetYellow 
                          : WantrTheme.streetTeamGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      segment.streetName ?? 'Unknown street',
                      style: const TextStyle(color: WantrTheme.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatDate(segment.firstDiscoveredAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: WantrTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}
