import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/providers/game_provider.dart';
import '../../core/theme/app_theme.dart';
import 'level_info_dialog.dart';

/// Resource bar with "Explorer's Chronicle" aesthetic
/// Shows level, gold, discovery points, and trade goods in a parchment-style banner
class ResourceBar extends StatelessWidget {
  const ResourceBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final state = gameProvider.gameState;
        if (state == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Stack(
            children: [
              // Main bar container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      WantrTheme.surface.withOpacity(0.95),
                      WantrTheme.backgroundAlt.withOpacity(0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: WantrTheme.brass.withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: WantrTheme.shadowDeep.withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: WantrTheme.brass.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: -2,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Level badge with compass motif (tappable)
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => const LevelInfoDialog(),
                        );
                      },
                      child: _LevelBadge(
                        level: state.level,
                        progress: state.levelProgress,
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Decorative divider
                    Container(
                      width: 1,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            WantrTheme.brass.withOpacity(0.0),
                            WantrTheme.brass.withOpacity(0.5),
                            WantrTheme.brass.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Resources row
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ResourceItem(
                            icon: Icons.monetization_on_outlined,
                            value: _formatNumber(state.gold),
                            label: 'GOLD',
                            color: WantrTheme.gold,
                            capacity: gameProvider.getResourceCapacity('gold'),
                            currentValue: state.gold,
                          ),
                          _ResourceItem(
                            icon: Icons.explore_outlined,
                            value: _formatNumber(state.discoveryPoints),
                            label: 'FINDS',
                            color: WantrTheme.brass,
                          ),
                          _ResourceItem(
                            icon: Icons.inventory_2_outlined,
                            value: _formatNumber(state.tradeGoods),
                            label: 'GOODS',
                            color: WantrTheme.copper,
                            capacity: gameProvider.getResourceCapacity('tradeGoods'),
                            currentValue: state.tradeGoods,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Corner ornaments
              Positioned(
                top: 4,
                left: 4,
                child: CartographicDecorations.cornerOrnament(
                  position: CornerPosition.topLeft,
                  size: 16,
                  color: WantrTheme.brass.withOpacity(0.5),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: CartographicDecorations.cornerOrnament(
                  position: CornerPosition.topRight,
                  size: 16,
                  color: WantrTheme.brass.withOpacity(0.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

/// Level badge with circular progress and compass-like design
class _LevelBadge extends StatelessWidget {
  final int level;
  final double progress;

  const _LevelBadge({
    required this.level,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            WantrTheme.surfaceElevated,
            WantrTheme.surface,
          ],
        ),
        border: Border.all(
          color: WantrTheme.brass.withOpacity(0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: WantrTheme.brass.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress ring
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: WantrTheme.undiscovered.withOpacity(0.4),
              valueColor: const AlwaysStoppedAnimation<Color>(WantrTheme.brass),
            ),
          ),

          // Level number
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$level',
                style: GoogleFonts.cormorant(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: WantrTheme.brass,
                  height: 1,
                ),
              ),
              Text(
                'LVL',
                style: GoogleFonts.crimsonPro(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: WantrTheme.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Individual resource display with icon, value, and label
class _ResourceItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final int? capacity;
  final int? currentValue;

  const _ResourceItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.capacity,
    this.currentValue,
  });

  @override
  Widget build(BuildContext context) {
    // Show capacity warning when >80% full
    final showCapacity = capacity != null &&
        currentValue != null &&
        currentValue! > capacity! * 0.8;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        if (showCapacity)
          Text(
            '/ $capacity',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: WantrTheme.warning,
              letterSpacing: -0.3,
            ),
          )
        else
          Text(
            label,
            style: GoogleFonts.crimsonPro(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: WantrTheme.textMuted,
              letterSpacing: 1.2,
            ),
          ),
      ],
    );
  }
}
