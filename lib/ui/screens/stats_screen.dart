import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/providers/game_provider.dart';
import '../../core/theme/app_theme.dart';

/// Stats dashboard styled as an "Expedition Log"
/// Features parchment-style cards with cartographic decorations
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WantrTheme.background,
      appBar: AppBar(
        title: Text(
          'EXPEDITION LOG',
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
      body: Consumer<GameProvider>(
        builder: (context, gameProvider, _) {
          final gameState = gameProvider.gameState;
          final segments = gameProvider.revealedSegments;

          if (gameState == null) {
            return Center(
              child: CircularProgressIndicator(
                color: WantrTheme.brass,
                strokeWidth: 2,
              ),
            );
          }

          // Calculate stats
          final totalDistance = gameState.totalDistanceWalked;
          final totalSegments = segments.length;
          final mySegments = segments.where((s) => s.discoveredByMe).length;
          final teamSegments = totalSegments - mySegments;
          final masteredSegments =
              segments.where((s) => s.timesWalked >= 10).length;
          final legendarySegments =
              segments.where((s) => s.timesWalked >= 50).length;
          final uniqueStreets = segments.map((s) => s.streetId).toSet().length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Overview card - The main expedition summary
                _ExpeditionSummaryCard(
                  totalDistance: totalDistance,
                  totalSegments: totalSegments,
                  uniqueStreets: uniqueStreets,
                  xp: gameState.xp,
                  level: gameState.level,
                ),

                const SizedBox(height: 20),

                // Discovery breakdown
                _DiscoveryBreakdownCard(
                  mySegments: mySegments,
                  teamSegments: teamSegments,
                  masteredSegments: masteredSegments,
                  legendarySegments: legendarySegments,
                  hasTeam: gameState.teamId != null,
                ),

                const SizedBox(height: 20),

                // Progress card
                _ProgressCard(
                  level: gameState.level,
                  currentXp: gameState.xp % gameState.xpForNextLevel,
                  xpToNext: gameState.xpForNextLevel,
                  discoveryPoints: gameState.discoveryPoints,
                ),

                const SizedBox(height: 20),

                // Recent discoveries
                _RecentDiscoveriesCard(segments: segments),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Main expedition summary card with key statistics
class _ExpeditionSummaryCard extends StatelessWidget {
  final double totalDistance;
  final int totalSegments;
  final int uniqueStreets;
  final int xp;
  final int level;

  const _ExpeditionSummaryCard({
    required this.totalDistance,
    required this.totalSegments,
    required this.uniqueStreets,
    required this.xp,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
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

          // Content
          Padding(
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
                        Icons.auto_graph,
                        color: WantrTheme.brass,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'EXPEDITION OVERVIEW',
                      style: GoogleFonts.cormorant(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: WantrTheme.brass,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Stats grid
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        icon: Icons.straighten,
                        value: _formatDistance(totalDistance),
                        label: 'TRAVELED',
                        color: WantrTheme.energy,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatBox(
                        icon: Icons.route,
                        value: '$totalSegments',
                        label: 'SEGMENTS',
                        color: WantrTheme.brass,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        icon: Icons.map_outlined,
                        value: '$uniqueStreets',
                        label: 'STREETS',
                        color: WantrTheme.gold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatBox(
                        icon: Icons.military_tech,
                        value: 'Lvl $level',
                        label: '$xp XP',
                        color: WantrTheme.copper,
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

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }
}

/// Individual stat display box
class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WantrTheme.backgroundAlt.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: WantrTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.crimsonPro(
              fontSize: 11,
              color: WantrTheme.textMuted,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Discovery breakdown card
class _DiscoveryBreakdownCard extends StatelessWidget {
  final int mySegments;
  final int teamSegments;
  final int masteredSegments;
  final int legendarySegments;
  final bool hasTeam;

  const _DiscoveryBreakdownCard({
    required this.mySegments,
    required this.teamSegments,
    required this.masteredSegments,
    required this.legendarySegments,
    required this.hasTeam,
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
                  Icons.explore_outlined,
                  color: WantrTheme.brass,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'DISCOVERY RECORD',
                style: GoogleFonts.cormorant(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: WantrTheme.brass,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _DiscoveryRow(
            icon: Icons.person_outline,
            label: 'Charted by you',
            value: mySegments,
            color: WantrTheme.discovered,
          ),
          if (hasTeam) ...[
            const SizedBox(height: 14),
            _DiscoveryRow(
              icon: Icons.group_outlined,
              label: 'Expedition party finds',
              value: teamSegments,
              color: WantrTheme.streetTeamGreen,
            ),
          ],
          const SizedBox(height: 14),
          _DiscoveryRow(
            icon: Icons.verified_outlined,
            label: 'Mastered routes (10+)',
            value: masteredSegments,
            color: WantrTheme.streetGold,
          ),
          const SizedBox(height: 14),
          _DiscoveryRow(
            icon: Icons.workspace_premium_outlined,
            label: 'Legendary paths (50+)',
            value: legendarySegments,
            color: WantrTheme.streetLegendary,
          ),
        ],
      ),
    );
  }
}

/// Individual discovery row
class _DiscoveryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _DiscoveryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.crimsonPro(
              fontSize: 14,
              color: WantrTheme.textPrimary,
            ),
          ),
        ),
        Text(
          '$value',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Progress card with level and XP
class _ProgressCard extends StatelessWidget {
  final int level;
  final int currentXp;
  final int xpToNext;
  final int discoveryPoints;

  const _ProgressCard({
    required this.level,
    required this.currentXp,
    required this.xpToNext,
    required this.discoveryPoints,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentXp / xpToNext;

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
                  Icons.trending_up,
                  color: WantrTheme.brass,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'ADVANCEMENT',
                style: GoogleFonts.cormorant(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: WantrTheme.brass,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Level progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Explorer Rank $level',
                style: GoogleFonts.crimsonPro(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: WantrTheme.textPrimary,
                ),
              ),
              Text(
                '$currentXp / $xpToNext XP',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: WantrTheme.textMuted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar with brass styling
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: WantrTheme.undiscovered,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: WantrTheme.brassGradient,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: WantrTheme.brass.withOpacity(0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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

          const SizedBox(height: 20),

          // Discovery points
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Discovery Points',
                style: GoogleFonts.crimsonPro(
                  fontSize: 15,
                  color: WantrTheme.textPrimary,
                ),
              ),
              Text(
                '$discoveryPoints',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: WantrTheme.brass,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Recent discoveries card
class _RecentDiscoveriesCard extends StatelessWidget {
  final List<dynamic> segments;

  const _RecentDiscoveriesCard({required this.segments});

  @override
  Widget build(BuildContext context) {
    final sortedSegments = List.from(segments)
      ..sort((a, b) => b.firstDiscoveredAt.compareTo(a.firstDiscoveredAt));
    final recent = sortedSegments.take(5).toList();

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
                  Icons.history,
                  color: WantrTheme.brass,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'RECENT FINDINGS',
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

          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No discoveries yet. Begin your expedition!',
                style: GoogleFonts.crimsonPro(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: WantrTheme.textMuted,
                ),
              ),
            )
          else
            ...recent.map((segment) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      // Discovery indicator dot
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: segment.discoveredByMe
                              ? WantrTheme.discovered
                              : WantrTheme.streetTeamGreen,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (segment.discoveredByMe
                                      ? WantrTheme.discovered
                                      : WantrTheme.streetTeamGreen)
                                  .withOpacity(0.4),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          segment.streetName ?? 'Unknown territory',
                          style: GoogleFonts.crimsonPro(
                            fontSize: 14,
                            color: WantrTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatDate(segment.firstDiscoveredAt),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: WantrTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
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
