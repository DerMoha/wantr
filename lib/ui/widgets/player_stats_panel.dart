import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/providers/game_provider.dart';
import '../../core/theme/app_theme.dart';

/// Panel showing player statistics in an explorer's journal style
/// Styled as a weathered parchment page with ink-style typography
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                WantrTheme.parchment,
                WantrTheme.parchmentDark,
                WantrTheme.parchmentShadow.withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: WantrTheme.inkFaded.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: WantrTheme.shadowDeep.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(4, 6),
              ),
              BoxShadow(
                color: WantrTheme.inkDark.withOpacity(0.1),
                blurRadius: 1,
                spreadRadius: 0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative corner ornaments
              Positioned(
                top: 8,
                left: 8,
                child: CartographicDecorations.cornerOrnament(
                  position: CornerPosition.topLeft,
                  size: 20,
                  color: WantrTheme.inkFaded.withOpacity(0.4),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: CartographicDecorations.cornerOrnament(
                  position: CornerPosition.topRight,
                  size: 20,
                  color: WantrTheme.inkFaded.withOpacity(0.4),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: CartographicDecorations.cornerOrnament(
                  position: CornerPosition.bottomLeft,
                  size: 20,
                  color: WantrTheme.inkFaded.withOpacity(0.4),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: CartographicDecorations.cornerOrnament(
                  position: CornerPosition.bottomRight,
                  size: 20,
                  color: WantrTheme.inkFaded.withOpacity(0.4),
                ),
              ),

              // Main content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with title badge
                    _buildHeader(state.title, state.playerName),

                    const SizedBox(height: 16),

                    // Decorative divider
                    _buildDecorativeDivider(),

                    const SizedBox(height: 16),

                    // Stats list
                    _StatEntry(
                      label: 'Streets Charted',
                      value: '${state.streetsDiscovered}',
                      icon: Icons.map_outlined,
                    ),
                    const SizedBox(height: 14),
                    _StatEntry(
                      label: 'Distance Traveled',
                      value: _formatDistance(state.totalDistanceWalked),
                      icon: Icons.straighten,
                    ),
                    const SizedBox(height: 14),
                    _StatEntry(
                      label: 'Outposts Founded',
                      value: '${state.outpostsBuilt}',
                      icon: Icons.flag_outlined,
                    ),
                    const SizedBox(height: 14),
                    _StatEntry(
                      label: 'Trades Completed',
                      value: '${state.tradesCompleted}',
                      icon: Icons.handshake_outlined,
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

  Widget _buildHeader(String title, String playerName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: WantrTheme.inkDark.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: WantrTheme.inkDark.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.cormorant(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: WantrTheme.inkRed,
              letterSpacing: 2.0,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Player name
        Text(
          playerName,
          style: GoogleFonts.cormorant(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: WantrTheme.inkDark,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildDecorativeDivider() {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: WantrTheme.inkFaded.withOpacity(0.4),
              width: 1,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  WantrTheme.inkFaded.withOpacity(0.4),
                  WantrTheme.inkFaded.withOpacity(0.1),
                  WantrTheme.inkFaded.withOpacity(0.4),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: WantrTheme.inkFaded.withOpacity(0.4),
              width: 1,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }
}

/// Individual stat entry styled like handwritten journal text
class _StatEntry extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatEntry({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Icon in circular border
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: WantrTheme.inkDark.withOpacity(0.05),
            border: Border.all(
              color: WantrTheme.inkFaded.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 14,
            color: WantrTheme.inkFaded,
          ),
        ),

        const SizedBox(width: 12),

        // Label and value
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.crimsonPro(
                  fontSize: 11,
                  color: WantrTheme.inkFaded,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: WantrTheme.inkDark,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
