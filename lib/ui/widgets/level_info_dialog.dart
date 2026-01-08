import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/outpost.dart';
import '../../core/providers/game_provider.dart';
import '../../core/theme/app_theme.dart';

/// Dialog showing level progress and upcoming unlocks
class LevelInfoDialog extends StatelessWidget {
  const LevelInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final state = gameProvider.gameState;
    if (state == null) return const SizedBox.shrink();

    final playerLevel = state.level;

    // Sort outpost types by unlock level
    final sortedTypes = OutpostType.values.toList()
      ..sort((a, b) =>
          Outpost.getRequiredLevel(a).compareTo(Outpost.getRequiredLevel(b)));

    return AlertDialog(
      backgroundColor: WantrTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: WantrTheme.brass.withOpacity(0.3)),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: WantrTheme.brass, width: 2),
              color: WantrTheme.surfaceElevated,
            ),
            child: Center(
              child: Text(
                '${state.level}',
                style: GoogleFonts.cormorant(
                  color: WantrTheme.brass,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.title.toUpperCase(),
                  style: GoogleFonts.cormorant(
                    color: WantrTheme.brass,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                // XP progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.levelProgress,
                    backgroundColor: WantrTheme.undiscovered,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(WantrTheme.brass),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${state.xp} / ${state.xpForNextLevel} XP',
                  style: GoogleFonts.jetBrainsMono(
                    color: WantrTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Speed rewards section
            _SpeedRewardsInfo(),
            const SizedBox(height: 16),
            // Divider
            Container(
              height: 1,
              color: WantrTheme.borderBrass.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            // Outpost unlocks section
            Text(
              'OUTPOST UNLOCKS',
              style: GoogleFonts.cormorant(
                color: WantrTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            ...sortedTypes.map((type) => _UnlockRow(
                  type: type,
                  playerLevel: playerLevel,
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: GoogleFonts.crimsonPro(color: WantrTheme.brass),
          ),
        ),
      ],
    );
  }
}

/// Info panel explaining speed-based rewards
class _SpeedRewardsInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EXPLORATION REWARDS',
          style: GoogleFonts.cormorant(
            color: WantrTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: WantrTheme.backgroundAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: WantrTheme.borderBrass.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A true wanderer takes time to explore. '
                'Walking rewards the most XP!',
                style: GoogleFonts.crimsonPro(
                  color: WantrTheme.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 10),
              _SpeedRow(
                icon: Icons.directions_walk,
                label: 'Walking',
                speed: '< 8 km/h',
                reward: '100%',
                color: WantrTheme.brass,
              ),
              const SizedBox(height: 6),
              _SpeedRow(
                icon: Icons.directions_bike,
                label: 'Cycling / Bus',
                speed: '8-25 km/h',
                reward: '50%',
                color: WantrTheme.copper,
              ),
              const SizedBox(height: 6),
              _SpeedRow(
                icon: Icons.directions_car,
                label: 'Driving',
                speed: '> 25 km/h',
                reward: 'Map only',
                color: WantrTheme.textMuted,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpeedRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String speed;
  final String reward;
  final Color color;

  const _SpeedRow({
    required this.icon,
    required this.label,
    required this.speed,
    required this.reward,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.crimsonPro(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          speed,
          style: GoogleFonts.jetBrainsMono(
            color: WantrTheme.textMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            reward,
            style: GoogleFonts.jetBrainsMono(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _UnlockRow extends StatelessWidget {
  final OutpostType type;
  final int playerLevel;

  const _UnlockRow({
    required this.type,
    required this.playerLevel,
  });

  @override
  Widget build(BuildContext context) {
    final requiredLevel = Outpost.getRequiredLevel(type);
    final isUnlocked = Outpost.isUnlocked(type, playerLevel);
    final isNext = !isUnlocked &&
        OutpostType.values
            .where((t) =>
                !Outpost.isUnlocked(t, playerLevel) &&
                Outpost.getRequiredLevel(t) <= requiredLevel)
            .length ==
            1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Level indicator
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUnlocked
                  ? WantrTheme.brass.withOpacity(0.2)
                  : isNext
                      ? WantrTheme.warning.withOpacity(0.2)
                      : WantrTheme.surfaceElevated,
              border: Border.all(
                color: isUnlocked
                    ? WantrTheme.brass
                    : isNext
                        ? WantrTheme.warning
                        : WantrTheme.borderBrass.withOpacity(0.3),
                width: isUnlocked || isNext ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(
                '$requiredLevel',
                style: GoogleFonts.jetBrainsMono(
                  color: isUnlocked
                      ? WantrTheme.brass
                      : isNext
                          ? WantrTheme.warning
                          : WantrTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Icon
          Opacity(
            opacity: isUnlocked ? 1.0 : 0.5,
            child: Text(
              Outpost.getIcon(type),
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 10),
          // Name and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Outpost.getTypeName(type),
                  style: GoogleFonts.crimsonPro(
                    color: isUnlocked
                        ? WantrTheme.textPrimary
                        : WantrTheme.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  Outpost.getTypeDescription(type),
                  style: GoogleFonts.crimsonPro(
                    color: WantrTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Unlocked indicator
          if (isUnlocked)
            Icon(
              Icons.check_circle,
              color: WantrTheme.brass,
              size: 18,
            )
          else if (isNext)
            Text(
              'NEXT',
              style: GoogleFonts.jetBrainsMono(
                color: WantrTheme.warning,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
