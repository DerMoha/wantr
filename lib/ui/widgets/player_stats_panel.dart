import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/game_provider.dart';
import '../../core/theme/app_theme.dart';

/// Panel showing player statistics
class PlayerStatsPanel extends StatelessWidget {
  const PlayerStatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final state = gameProvider.gameState;
        if (state == null) return const SizedBox.shrink();

        return Container(
          width: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WantrTheme.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: WantrTheme.undiscovered.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Player title
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: WantrTheme.discovered,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.title.toUpperCase(),
                          style: const TextStyle(
                            color: WantrTheme.discovered,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          state.playerName,
                          style: const TextStyle(
                            color: WantrTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(
                  color: WantrTheme.undiscovered,
                  height: 1,
                  thickness: 1,
                ),
              ),
              
              // Stats list
              _StatRow(
                label: 'STREETS',
                value: '${state.streetsDiscovered}',
                icon: Icons.alt_route,
                color: WantrTheme.energy,
              ),
              const SizedBox(height: 12),
              _StatRow(
                label: 'DISTANCE',
                value: _formatDistance(state.totalDistanceWalked),
                icon: Icons.directions_walk,
                color: WantrTheme.accent,
              ),
              const SizedBox(height: 12),
              _StatRow(
                label: 'OUTPOSTS',
                value: '${state.outpostsBuilt}',
                icon: Icons.store,
                color: WantrTheme.discovered,
              ),
              const SizedBox(height: 12),
              _StatRow(
                label: 'TRADES',
                value: '${state.tradesCompleted}',
                icon: Icons.swap_horiz,
                color: WantrTheme.gold,
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} KM';
    }
    return '${meters.toStringAsFixed(0)} M';
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: color.withOpacity(0.8),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: WantrTheme.textSecondary.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: WantrTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
