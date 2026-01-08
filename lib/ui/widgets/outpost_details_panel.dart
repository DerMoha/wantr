import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/outpost.dart';
import '../../core/models/game_state.dart';
import '../../core/providers/game_provider.dart';
import '../../core/theme/app_theme.dart';

/// Bottom sheet panel showing outpost details with collect and upgrade actions
class OutpostDetailsPanel extends StatefulWidget {
  final Outpost outpost;

  const OutpostDetailsPanel({
    super.key,
    required this.outpost,
  });

  @override
  State<OutpostDetailsPanel> createState() => _OutpostDetailsPanelState();
}

class _OutpostDetailsPanelState extends State<OutpostDetailsPanel> {
  bool _isCollecting = false;
  bool _isUpgrading = false;

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final gameState = gameProvider.gameState;
    final outpost = widget.outpost;

    final accumulated = outpost.calculateAccumulatedResources();
    final canCollect = accumulated > 0;
    final isMaxLevel = outpost.level >= Outpost.maxLevel;

    final upgradeGoldCost = isMaxLevel ? 0 : Outpost.getUpgradeGoldCost(outpost.type, outpost.level);
    final upgradeTradeCost = isMaxLevel ? 0 : Outpost.getUpgradeTradeGoodsCost(outpost.level);
    final canAffordUpgrade = !isMaxLevel &&
        (gameState?.gold ?? 0) >= upgradeGoldCost &&
        (gameState?.tradeGoods ?? 0) >= upgradeTradeCost;

    return Container(
      decoration: BoxDecoration(
        color: WantrTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: WantrTheme.brass.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: WantrTheme.shadowDeep.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: WantrTheme.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            WantrTheme.parchment,
                            WantrTheme.parchmentDark,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: WantrTheme.brass,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: WantrTheme.brass.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          outpost.icon,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Name and type
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            outpost.name,
                            style: GoogleFonts.cormorant(
                              color: WantrTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                outpost.typeName,
                                style: GoogleFonts.crimsonPro(
                                  color: WantrTheme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: WantrTheme.brass.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Lv ${outpost.level}',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: WantrTheme.brass,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Close button
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: WantrTheme.textMuted,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Production info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: WantrTheme.backgroundAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: WantrTheme.borderBrass.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: WantrTheme.brass,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Production: ',
                        style: GoogleFonts.crimsonPro(
                          color: WantrTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        outpost.productionDescription,
                        style: GoogleFonts.jetBrainsMono(
                          color: WantrTheme.brass,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Accumulated resources & Collect button
                if (outpost.type != OutpostType.warehouse &&
                    outpost.type != OutpostType.scoutTower) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: canCollect
                          ? LinearGradient(
                              colors: [
                                WantrTheme.brass.withOpacity(0.1),
                                WantrTheme.brass.withOpacity(0.05),
                              ],
                            )
                          : null,
                      color: canCollect ? null : WantrTheme.backgroundAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: canCollect
                            ? WantrTheme.brass.withOpacity(0.4)
                            : WantrTheme.borderBrass.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getResourceIcon(outpost.type),
                              color: canCollect
                                  ? WantrTheme.brass
                                  : WantrTheme.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    canCollect
                                        ? '$accumulated ${_getResourceName(outpost.type)} ready'
                                        : 'Nothing to collect yet',
                                    style: GoogleFonts.crimsonPro(
                                      color: canCollect
                                          ? WantrTheme.textPrimary
                                          : WantrTheme.textMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getTimeInfo(outpost),
                                    style: GoogleFonts.crimsonPro(
                                      color: WantrTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (canCollect) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isCollecting ? null : _collectResources,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: WantrTheme.brass,
                                foregroundColor: WantrTheme.background,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _isCollecting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: WantrTheme.background,
                                      ),
                                    )
                                  : Text(
                                      'COLLECT +$accumulated',
                                      style: GoogleFonts.crimsonPro(
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Upgrade section
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: WantrTheme.backgroundAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: WantrTheme.borderBrass.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.upgrade,
                            color: isMaxLevel
                                ? WantrTheme.textMuted
                                : WantrTheme.copper,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isMaxLevel
                                ? 'MAX LEVEL REACHED'
                                : 'UPGRADE TO LEVEL ${outpost.level + 1}',
                            style: GoogleFonts.cormorant(
                              color: isMaxLevel
                                  ? WantrTheme.textMuted
                                  : WantrTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      if (!isMaxLevel) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Gold cost
                            _CostChip(
                              icon: Icons.monetization_on,
                              value: upgradeGoldCost,
                              color: (gameState?.gold ?? 0) >= upgradeGoldCost
                                  ? WantrTheme.gold
                                  : WantrTheme.error,
                            ),
                            const SizedBox(width: 12),
                            // Trade goods cost
                            _CostChip(
                              icon: Icons.inventory_2,
                              value: upgradeTradeCost,
                              color: (gameState?.tradeGoods ?? 0) >= upgradeTradeCost
                                  ? WantrTheme.copper
                                  : WantrTheme.error,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: canAffordUpgrade && !_isUpgrading
                                ? _upgradeOutpost
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: WantrTheme.copper,
                              side: BorderSide(
                                color: canAffordUpgrade
                                    ? WantrTheme.copper
                                    : WantrTheme.textMuted,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: _isUpgrading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: WantrTheme.copper,
                                    ),
                                  )
                                : Text(
                                    canAffordUpgrade
                                        ? 'UPGRADE'
                                        : 'INSUFFICIENT RESOURCES',
                                    style: GoogleFonts.crimsonPro(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                      color: canAffordUpgrade
                                          ? WantrTheme.copper
                                          : WantrTheme.textMuted,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Bottom padding for safe area
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getResourceIcon(OutpostType type) {
    return switch (type) {
      OutpostType.tradingPost => Icons.inventory_2,
      OutpostType.workshop => Icons.handyman,
      OutpostType.inn => Icons.battery_charging_full,
      OutpostType.bank => Icons.monetization_on,
      _ => Icons.help_outline,
    };
  }

  String _getTimeInfo(Outpost outpost) {
    final hoursSinceCollection =
        DateTime.now().difference(outpost.lastCollectedAt).inMinutes / 60.0;
    final hoursUntilFull = 24.0 - hoursSinceCollection;

    final sinceText = _formatDuration(hoursSinceCollection);

    if (hoursUntilFull <= 0) {
      return 'Collected $sinceText ago • Storage full';
    } else {
      final untilText = _formatDuration(hoursUntilFull);
      return 'Collected $sinceText ago • Full in $untilText';
    }
  }

  String _formatDuration(double hours) {
    if (hours < 1) {
      final minutes = (hours * 60).round();
      return '${minutes}m';
    } else if (hours < 24) {
      final h = hours.floor();
      final m = ((hours - h) * 60).round();
      if (m == 0) return '${h}h';
      return '${h}h ${m}m';
    } else {
      final days = (hours / 24).floor();
      return '${days}d';
    }
  }

  String _getResourceName(OutpostType type) {
    return switch (type) {
      OutpostType.tradingPost => 'goods',
      OutpostType.workshop => 'materials',
      OutpostType.inn => 'energy',
      OutpostType.bank => 'gold',
      _ => 'resources',
    };
  }

  Future<void> _collectResources() async {
    setState(() => _isCollecting = true);
    HapticFeedback.mediumImpact();

    final gameProvider = context.read<GameProvider>();
    final amount = await gameProvider.collectFromOutpost(widget.outpost);

    if (!mounted) return;

    setState(() => _isCollecting = false);

    if (amount > 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '+$amount ${_getResourceName(widget.outpost.type)} collected!',
            style: GoogleFonts.crimsonPro(),
          ),
          backgroundColor: WantrTheme.brass,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _upgradeOutpost() async {
    setState(() => _isUpgrading = true);
    HapticFeedback.mediumImpact();

    final gameProvider = context.read<GameProvider>();
    final success = await gameProvider.upgradeOutpost(widget.outpost);

    if (!mounted) return;

    setState(() => _isUpgrading = false);

    if (success) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.outpost.name} upgraded to Level ${widget.outpost.level}!',
            style: GoogleFonts.crimsonPro(),
          ),
          backgroundColor: WantrTheme.copper,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Upgrade failed - not enough resources',
            style: GoogleFonts.crimsonPro(),
          ),
          backgroundColor: WantrTheme.error,
        ),
      );
    }
  }
}

/// Small chip showing resource cost
class _CostChip extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;

  const _CostChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: GoogleFonts.jetBrainsMono(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
