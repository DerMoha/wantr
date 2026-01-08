import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

/// Welcome dialog shown on first launch to introduce the game
class WelcomeDialog extends StatefulWidget {
  final VoidCallback onComplete;

  const WelcomeDialog({super.key, required this.onComplete});

  @override
  State<WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<WelcomeDialog> {
  int _currentPage = 0;
  final _pageController = PageController();

  final _pages = const [
    _WelcomePage(
      icon: Icons.explore,
      title: 'Welcome, Wanderer',
      description:
          'You are a traveling merchant, exploring the world one street at a time. '
          'Walk through your city to reveal the map and discover new places.',
    ),
    _WelcomePage(
      icon: Icons.map_outlined,
      title: 'Reveal the Map',
      description:
          'Streets are hidden in fog until you walk near them. '
          'The more you explore on foot, the more XP and gold you earn. '
          'Walking gives full rewards - driving only reveals the map.',
    ),
    _WelcomePage(
      icon: Icons.store,
      title: 'Build Outposts',
      description:
          'Use your gold to build outposts at locations you visit. '
          'Outposts generate resources over time - collect them daily! '
          'New outpost types unlock as you level up.',
    ),
    _WelcomePage(
      icon: Icons.group,
      title: 'Join a Team',
      description:
          'Team up with friends to share map discoveries. '
          'When a teammate walks a street, it reveals for everyone! '
          'Create or join a team from the Account screen.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  void _skip() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 480),
        decoration: BoxDecoration(
          color: WantrTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: WantrTheme.brass.withOpacity(0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: WantrTheme.shadowDeep.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header decoration
            Container(
              height: 8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    WantrTheme.brass.withOpacity(0.3),
                    WantrTheme.brass.withOpacity(0.6),
                    WantrTheme.brass.withOpacity(0.3),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: _pages,
              ),
            ),

            // Page indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? WantrTheme.brass
                          : WantrTheme.undiscovered,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _skip,
                      child: Text(
                        'Skip',
                        style: GoogleFonts.crimsonPro(
                          color: WantrTheme.textMuted,
                          fontSize: 15,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 60),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WantrTheme.brass,
                      foregroundColor: WantrTheme.background,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentPage < _pages.length - 1
                          ? 'Next'
                          : 'Start Exploring',
                      style: GoogleFonts.crimsonPro(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual welcome page content
class _WelcomePage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _WelcomePage({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with decorative circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  WantrTheme.brass.withOpacity(0.2),
                  WantrTheme.brass.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: WantrTheme.brass.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: 48,
              color: WantrTheme.brass,
            ),
          ),
          const SizedBox(height: 28),

          // Title
          Text(
            title,
            style: GoogleFonts.cormorant(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: WantrTheme.brass,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            description,
            style: GoogleFonts.crimsonPro(
              fontSize: 16,
              color: WantrTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
