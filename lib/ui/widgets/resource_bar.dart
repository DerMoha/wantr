import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/game_provider.dart';
import '../../core/theme/app_theme.dart';

/// Resource bar showing gold, XP, and other resources at top of screen
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: WantrTheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: WantrTheme.undiscovered.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Level badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: WantrTheme.discovered.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: WantrTheme.discovered.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lv.${state.level}',
                      style: const TextStyle(
                        color: WantrTheme.discovered,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: state.levelProgress,
                          backgroundColor: WantrTheme.undiscovered.withOpacity(0.5),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            WantrTheme.discovered,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Resources
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ResourceItem(
                      icon: '🪙',
                      value: _formatNumber(state.gold),
                      color: WantrTheme.gold,
                    ),
                    _ResourceItem(
                      icon: '🔍',
                      value: _formatNumber(state.discoveryPoints),
                      color: WantrTheme.accent,
                    ),
                    _ResourceItem(
                      icon: '📦',
                      value: _formatNumber(state.tradeGoods),
                      color: WantrTheme.energy,
                    ),
                  ],
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

class _ResourceItem extends StatelessWidget {
  final String icon;
  final String value;
  final Color color;

  const _ResourceItem({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
