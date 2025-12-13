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
          width: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WantrTheme.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: WantrTheme.undiscovered,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Player title
              Text(
                state.title,
                style: const TextStyle(
                  color: WantrTheme.discovered,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                state.playerName,
                style: const TextStyle(
                  color: WantrTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              
              const Divider(
                color: WantrTheme.undiscovered,
                height: 24,
              ),
              
              // Stats list
              _StatRow(
                label: 'Streets',
                value: '${state.streetsDiscovered}',
                icon: Icons.alt_route,
              ),
              const SizedBox(height: 8),
              _StatRow(
                label: 'Distance',
                value: _formatDistance(state.totalDistanceWalked),
                icon: Icons.directions_walk,
              ),
              const SizedBox(height: 8),
              _StatRow(
                label: 'Outposts',
                value: '${state.outpostsBuilt}',
                icon: Icons.store,
              ),
              const SizedBox(height: 8),
              _StatRow(
                label: 'Trades',
                value: '${state.tradesCompleted}',
                icon: Icons.swap_horiz,
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: WantrTheme.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: WantrTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: WantrTheme.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
