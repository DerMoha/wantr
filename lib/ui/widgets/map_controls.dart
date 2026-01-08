import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'animated_tap_container.dart';

/// Map control buttons styled as brass nautical instruments
/// Features zoom controls and a compass-style navigation button
class MapControls extends StatefulWidget {
  final VoidCallback onCenterPressed;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback? onHelpPressed;
  final bool isFollowing;

  const MapControls({
    super.key,
    required this.onCenterPressed,
    required this.onZoomIn,
    required this.onZoomOut,
    this.onHelpPressed,
    this.isFollowing = false,
  });

  @override
  State<MapControls> createState() => _MapControlsState();
}

class _MapControlsState extends State<MapControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  bool _isResettingNorth = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutCubic),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isResettingNorth = false);
        _animationController.reset();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleCenterPress() {
    if (widget.isFollowing) {
      setState(() => _isResettingNorth = true);
      _animationController.forward();
    }
    widget.onCenterPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Compass navigation button
        _CompassButton(
          onTap: _handleCenterPress,
          isFollowing: widget.isFollowing,
          isResettingNorth: _isResettingNorth,
          rotationAnimation: _rotationAnimation,
        ),

        const SizedBox(height: 12),

        // Zoom controls styled as brass dials
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                WantrTheme.surface.withOpacity(0.95),
                WantrTheme.backgroundAlt.withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: WantrTheme.brass.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: WantrTheme.shadowDeep.withOpacity(0.5),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ZoomButton(
                icon: Icons.add,
                onPressed: widget.onZoomIn,
                isTop: true,
              ),
              Container(
                width: 36,
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      WantrTheme.brass.withOpacity(0.0),
                      WantrTheme.brass.withOpacity(0.5),
                      WantrTheme.brass.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
              _ZoomButton(
                icon: Icons.remove,
                onPressed: widget.onZoomOut,
                isTop: false,
              ),
            ],
          ),
        ),

        // Help button
        if (widget.onHelpPressed != null) ...[
          const SizedBox(height: 12),
          _HelpButton(onTap: widget.onHelpPressed!),
        ],
      ],
    );
  }
}

/// Help button styled to match map controls
class _HelpButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HelpButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedTapContainer(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              WantrTheme.surfaceElevated,
              WantrTheme.surface,
            ],
            center: const Alignment(-0.2, -0.2),
          ),
          border: Border.all(
            color: WantrTheme.brass.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: WantrTheme.shadowDeep.withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          Icons.help_outline,
          color: WantrTheme.brass.withOpacity(0.8),
          size: 22,
        ),
      ),
    );
  }
}

/// Compass-style navigation button with animated needle
class _CompassButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isFollowing;
  final bool isResettingNorth;
  final Animation<double> rotationAnimation;

  const _CompassButton({
    required this.onTap,
    required this.isFollowing,
    required this.isResettingNorth,
    required this.rotationAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedTapContainer(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              WantrTheme.surfaceElevated,
              WantrTheme.surface,
            ],
            center: const Alignment(-0.2, -0.2),
          ),
          border: Border.all(
            color: isFollowing
                ? WantrTheme.brass
                : WantrTheme.brass.withOpacity(0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: WantrTheme.shadowDeep.withOpacity(0.6),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            if (isFollowing)
              BoxShadow(
                color: WantrTheme.brass.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring markings
            CustomPaint(
              size: const Size(56, 56),
              painter: _CompassRingPainter(
                color: WantrTheme.brass.withOpacity(0.3),
              ),
            ),

            // Animated compass needle
            AnimatedBuilder(
              animation: rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: rotationAnimation.value * 2 * math.pi,
                  child: CustomPaint(
                    size: const Size(40, 40),
                    painter: _CompassNeedlePainter(
                      northColor: isFollowing
                          ? WantrTheme.brass
                          : WantrTheme.textSecondary,
                      southColor: WantrTheme.copper.withOpacity(0.6),
                    ),
                  ),
                );
              },
            ),

            // Center dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WantrTheme.brass,
                boxShadow: [
                  BoxShadow(
                    color: WantrTheme.brass.withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),

            // Cardinal direction labels
            Positioned(
              top: 6,
              child: Text(
                'N',
                style: GoogleFonts.cormorant(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isFollowing
                      ? WantrTheme.brass
                      : WantrTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zoom button with brass styling
class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isTop;

  const _ZoomButton({
    required this.icon,
    required this.onPressed,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedTapContainer(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: isTop ? const Radius.circular(28) : Radius.zero,
            bottom: !isTop ? const Radius.circular(28) : Radius.zero,
          ),
        ),
        child: Icon(
          icon,
          color: WantrTheme.brass,
          size: 24,
        ),
      ),
    );
  }
}

/// Painter for the compass ring markings
class _CompassRingPainter extends CustomPainter {
  final Color color;

  _CompassRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Outer circle
    canvas.drawCircle(center, radius, paint);

    // Tick marks
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - math.pi / 2;
      final isCardinal = i % 2 == 0;
      final innerRadius = isCardinal ? radius - 6 : radius - 4;

      final start = Offset(
        center.dx + math.cos(angle) * innerRadius,
        center.dy + math.sin(angle) * innerRadius,
      );
      final end = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );

      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter for the compass needle
class _CompassNeedlePainter extends CustomPainter {
  final Color northColor;
  final Color southColor;

  _CompassNeedlePainter({
    required this.northColor,
    required this.southColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final halfHeight = size.height / 2 - 4;

    // North needle (filled)
    final northPath = Path()
      ..moveTo(center.dx, center.dy - halfHeight)
      ..lineTo(center.dx - 5, center.dy)
      ..lineTo(center.dx + 5, center.dy)
      ..close();

    final northPaint = Paint()
      ..color = northColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(northPath, northPaint);

    // South needle (outline)
    final southPath = Path()
      ..moveTo(center.dx, center.dy + halfHeight)
      ..lineTo(center.dx - 5, center.dy)
      ..lineTo(center.dx + 5, center.dy)
      ..close();

    final southPaint = Paint()
      ..color = southColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(southPath, southPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
