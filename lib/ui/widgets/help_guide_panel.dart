import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/outpost.dart';
import '../../core/theme/app_theme.dart';

/// Help guide panel accessible from map controls
class HelpGuidePanel extends StatelessWidget {
  const HelpGuidePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
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
                color: WantrTheme.shadowDeep.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: WantrTheme.brass.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.menu_book, color: WantrTheme.brass, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      "WANDERER'S GUIDE",
                      style: GoogleFonts.cormorant(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: WantrTheme.brass,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              Divider(
                color: WantrTheme.borderBrass.withOpacity(0.2),
                height: 1,
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _HelpSection(
                      icon: Icons.map_outlined,
                      title: 'Exploring',
                      items: const [
                        _HelpItem(
                          title: 'Reveal Streets',
                          description:
                              'Walk near streets to reveal them on the map. '
                              'The fog lifts as you explore!',
                        ),
                        _HelpItem(
                          title: 'Earn XP',
                          description:
                              'Discover new streets to earn XP and level up. '
                              'Higher levels unlock new outpost types.',
                        ),
                        _HelpItem(
                          title: 'Tap Your Level',
                          description:
                              'Tap the level badge to see your progress '
                              'and upcoming unlocks.',
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    _HelpSection(
                      icon: Icons.speed,
                      title: 'Speed & Rewards',
                      items: const [
                        _HelpItem(
                          title: 'Walking (< 8 km/h)',
                          description: '100% XP and discovery points',
                        ),
                        _HelpItem(
                          title: 'Cycling / Bus (8-25 km/h)',
                          description: '50% rewards - still worth it!',
                        ),
                        _HelpItem(
                          title: 'Driving (> 25 km/h)',
                          description:
                              'Map reveals but no XP. Great for scouting!',
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    _HelpSection(
                      icon: Icons.store,
                      title: 'Outposts',
                      items: [
                        const _HelpItem(
                          title: 'Building',
                          description:
                              'Tap the + button to build an outpost at your '
                              'current location. Costs gold.',
                        ),
                        const _HelpItem(
                          title: 'Collecting',
                          description:
                              'Tap an outpost on the map to collect resources. '
                              'They accumulate over 24 hours.',
                        ),
                        const _HelpItem(
                          title: 'Upgrading',
                          description:
                              'Upgrade outposts with gold and trade goods '
                              'to increase production.',
                        ),
                        _HelpItem(
                          title: 'Types',
                          description: _buildOutpostTypesDescription(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    _HelpSection(
                      icon: Icons.monetization_on_outlined,
                      title: 'Resources',
                      items: const [
                        _HelpItem(
                          title: 'Gold',
                          description:
                              'Earned by exploring and from Banks. '
                              'Used to build and upgrade outposts.',
                        ),
                        _HelpItem(
                          title: 'Trade Goods',
                          description:
                              'Produced by Trading Posts. '
                              'Used for upgrades.',
                        ),
                        _HelpItem(
                          title: 'Capacity',
                          description:
                              'Resources have a max capacity. '
                              'Build Warehouses to increase it!',
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    _HelpSection(
                      icon: Icons.group,
                      title: 'Teams',
                      items: const [
                        _HelpItem(
                          title: 'Shared Maps',
                          description:
                              'Team members share map discoveries. '
                              'Streets revealed by teammates appear for you!',
                        ),
                        _HelpItem(
                          title: 'Join or Create',
                          description:
                              'Go to Account > Team to create a team '
                              'or join with an invite code.',
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _buildOutpostTypesDescription() {
    final buffer = StringBuffer();
    for (final type in OutpostType.values) {
      final icon = Outpost.getIcon(type);
      final name = Outpost.getTypeName(type);
      final level = Outpost.getRequiredLevel(type);
      buffer.writeln('$icon $name (Lvl $level)');
    }
    return buffer.toString().trim();
  }
}

class _HelpSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<_HelpItem> items;

  const _HelpSection({
    required this.icon,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(icon, size: 18, color: WantrTheme.brass),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: GoogleFonts.cormorant(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: WantrTheme.brass,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Items
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: WantrTheme.backgroundAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: WantrTheme.borderBrass.withOpacity(0.15),
            ),
          ),
          child: Column(
            children: items
                .map((item) => Padding(
                      padding: EdgeInsets.only(
                        bottom: items.last == item ? 0 : 12,
                      ),
                      child: item,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _HelpItem extends StatelessWidget {
  final String title;
  final String description;

  const _HelpItem({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: WantrTheme.brass.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.crimsonPro(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: WantrTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.crimsonPro(
                  fontSize: 13,
                  color: WantrTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
