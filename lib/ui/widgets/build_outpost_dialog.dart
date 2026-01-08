import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/outpost.dart';
import '../../core/providers/game_provider.dart';
import '../../core/theme/app_theme.dart';

/// Dialog for building a new outpost at the current location
class BuildOutpostDialog extends StatefulWidget {
  const BuildOutpostDialog({super.key});

  @override
  State<BuildOutpostDialog> createState() => _BuildOutpostDialogState();
}

class _BuildOutpostDialogState extends State<BuildOutpostDialog> {
  final _nameController = TextEditingController();
  OutpostType? _selectedType;
  bool _isBuilding = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final currentGold = gameProvider.gameState?.gold ?? 0;
    final playerLevel = gameProvider.gameState?.level ?? 1;

    // Sort types by unlock level for better UX
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
          Icon(Icons.add_location_alt, color: WantrTheme.brass, size: 24),
          const SizedBox(width: 10),
          Text(
            'ESTABLISH OUTPOST',
            style: GoogleFonts.cormorant(
              color: WantrTheme.brass,
              fontWeight: FontWeight.w600,
              fontSize: 20,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name input
              TextField(
                controller: _nameController,
                style: GoogleFonts.crimsonPro(
                  color: WantrTheme.textPrimary,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  labelText: 'Outpost Name',
                  labelStyle: GoogleFonts.crimsonPro(color: WantrTheme.textMuted),
                  hintText: 'Enter a name...',
                  hintStyle: GoogleFonts.crimsonPro(color: WantrTheme.textMuted),
                  filled: true,
                  fillColor: WantrTheme.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: WantrTheme.borderBrass.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: WantrTheme.borderBrass.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: WantrTheme.brass, width: 1.5),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 20),

              // Type selection header
              Text(
                'SELECT TYPE',
                style: GoogleFonts.cormorant(
                  color: WantrTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 12),

              // Outpost type grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: sortedTypes.map((type) {
                  final cost = Outpost.getCost(type, 1);
                  final isUnlocked = Outpost.isUnlocked(type, playerLevel);
                  final canAfford = currentGold >= cost;
                  final isSelected = _selectedType == type;

                  return _OutpostTypeCard(
                    type: type,
                    cost: cost,
                    canAfford: canAfford,
                    isSelected: isSelected,
                    isUnlocked: isUnlocked,
                    requiredLevel: Outpost.getRequiredLevel(type),
                    onTap: isUnlocked && canAfford
                        ? () => setState(() => _selectedType = type)
                        : null,
                  );
                }).toList(),
              ),

              // Selected type details
              if (_selectedType != null) ...[
                const SizedBox(height: 16),
                _SelectedTypeDetails(
                  type: _selectedType!,
                  cost: Outpost.getCost(_selectedType!, 1),
                ),
              ],

              const SizedBox(height: 8),

              // Current gold display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.monetization_on, color: WantrTheme.gold, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Your gold: $currentGold',
                    style: GoogleFonts.jetBrainsMono(
                      color: WantrTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isBuilding ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.crimsonPro(color: WantrTheme.textMuted),
          ),
        ),
        ElevatedButton(
          onPressed: _canBuild() ? _buildOutpost : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: WantrTheme.brass,
            foregroundColor: WantrTheme.background,
            disabledBackgroundColor: WantrTheme.undiscovered,
            disabledForegroundColor: WantrTheme.textMuted,
          ),
          child: _isBuilding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: WantrTheme.background,
                  ),
                )
              : Text(
                  'Build',
                  style: GoogleFonts.crimsonPro(fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }

  bool _canBuild() {
    if (_isBuilding) return false;
    if (_nameController.text.trim().isEmpty) return false;
    if (_selectedType == null) return false;

    final gameProvider = context.read<GameProvider>();
    final currentGold = gameProvider.gameState?.gold ?? 0;
    final cost = Outpost.getCost(_selectedType!, 1);

    return currentGold >= cost;
  }

  Future<void> _buildOutpost() async {
    if (!_canBuild()) return;

    setState(() => _isBuilding = true);
    HapticFeedback.mediumImpact();

    final gameProvider = context.read<GameProvider>();
    final success = await gameProvider.buildOutpost(
      name: _nameController.text.trim(),
      type: _selectedType!,
    );

    if (!mounted) return;

    if (success) {
      HapticFeedback.heavyImpact();
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(
                _getIconForType(_selectedType!),
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_nameController.text.trim()} established!',
                  style: GoogleFonts.crimsonPro(),
                ),
              ),
            ],
          ),
          backgroundColor: WantrTheme.brass,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() => _isBuilding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to build outpost',
            style: GoogleFonts.crimsonPro(),
          ),
          backgroundColor: WantrTheme.error,
        ),
      );
    }
  }

  String _getIconForType(OutpostType type) {
    return switch (type) {
      OutpostType.tradingPost => '🏪',
      OutpostType.warehouse => '🏭',
      OutpostType.workshop => '⚒️',
      OutpostType.inn => '🏨',
      OutpostType.bank => '🏦',
      OutpostType.scoutTower => '🗼',
    };
  }
}

/// Card for selecting an outpost type
class _OutpostTypeCard extends StatelessWidget {
  final OutpostType type;
  final int cost;
  final bool canAfford;
  final bool isSelected;
  final bool isUnlocked;
  final int requiredLevel;
  final VoidCallback? onTap;

  const _OutpostTypeCard({
    required this.type,
    required this.cost,
    required this.canAfford,
    required this.isSelected,
    required this.isUnlocked,
    required this.requiredLevel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Outpost.getIcon(type);
    final name = Outpost.getTypeName(type);

    // Locked state takes precedence
    if (!isUnlocked) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: WantrTheme.surfaceElevated.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: WantrTheme.borderBrass.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Opacity(
          opacity: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 28)),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: WantrTheme.background.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: WantrTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: GoogleFonts.crimsonPro(
                    color: WantrTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.trending_up,
                      size: 12,
                      color: WantrTheme.textMuted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Lvl $requiredLevel',
                      style: GoogleFonts.jetBrainsMono(
                        color: WantrTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? WantrTheme.brass.withOpacity(0.15)
              : WantrTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? WantrTheme.brass
                : canAfford
                    ? WantrTheme.borderBrass.withOpacity(0.3)
                    : WantrTheme.error.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: WantrTheme.brass.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Opacity(
          opacity: canAfford ? 1.0 : 0.5,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: GoogleFonts.crimsonPro(
                    color: isSelected ? WantrTheme.brass : WantrTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.monetization_on,
                      size: 12,
                      color: canAfford ? WantrTheme.gold : WantrTheme.error,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$cost',
                      style: GoogleFonts.jetBrainsMono(
                        color: canAfford ? WantrTheme.gold : WantrTheme.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Details panel for selected outpost type
class _SelectedTypeDetails extends StatelessWidget {
  final OutpostType type;
  final int cost;

  const _SelectedTypeDetails({
    required this.type,
    required this.cost,
  });

  @override
  Widget build(BuildContext context) {
    final description = switch (type) {
      OutpostType.tradingPost => 'Produces trade goods over time. Essential for upgrades.',
      OutpostType.warehouse => 'Increases storage capacity for all resources by +500.',
      OutpostType.workshop => 'Produces materials for future crafting.',
      OutpostType.inn => 'Restores energy over time. (Coming soon)',
      OutpostType.bank => 'Generates passive gold income.',
      OutpostType.scoutTower => 'Reveals nearby undiscovered streets. (Coming soon)',
    };

    final production = switch (type) {
      OutpostType.tradingPost => '+5 goods/hr',
      OutpostType.warehouse => '+500 capacity',
      OutpostType.workshop => '+3 materials/hr',
      OutpostType.inn => '+10 energy/hr',
      OutpostType.bank => '+2 gold/hr',
      OutpostType.scoutTower => 'Passive reveal',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WantrTheme.backgroundAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: WantrTheme.brass.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: WantrTheme.brass, size: 16),
              const SizedBox(width: 8),
              Text(
                production,
                style: GoogleFonts.jetBrainsMono(
                  color: WantrTheme.brass,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.crimsonPro(
              color: WantrTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
