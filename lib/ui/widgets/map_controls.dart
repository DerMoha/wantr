import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'animated_tap_container.dart';

/// Map control buttons for zoom and centering
class MapControls extends StatefulWidget {
  final VoidCallback onCenterPressed;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final bool isFollowing;

  const MapControls({
    super.key,
    required this.onCenterPressed,
    required this.onZoomIn,
    required this.onZoomOut,
    this.isFollowing = false,
  });

  @override
  State<MapControls> createState() => _MapControlsState();
}

class _MapControlsState extends State<MapControls> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  bool _isResettingNorth = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
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
      // Already following - trigger north reset animation
      setState(() => _isResettingNorth = true);
      _animationController.forward();
    }
    widget.onCenterPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WantrTheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: WantrTheme.undiscovered.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ControlButton(
            icon: Icons.add,
            onPressed: widget.onZoomIn,
            isTop: true,
          ),
          const Divider(
            height: 1,
            indent: 8,
            endIndent: 8,
            color: WantrTheme.undiscovered,
          ),
          _ControlButton(
            icon: Icons.remove,
            onPressed: widget.onZoomOut,
          ),
          const Divider(
            height: 1,
            indent: 8,
            endIndent: 8,
            color: WantrTheme.undiscovered,
          ),
          // Animated center/north button
          AnimatedTapContainer(
            onTap: _handleCenterPress,
            child: SizedBox(
              width: 56,
              height: 56,
              child: AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnimation.value * 2 * 3.14159, // Full rotation
                    child: Icon(
                      _isResettingNorth 
                          ? Icons.explore 
                          : (widget.isFollowing ? Icons.navigation : Icons.my_location),
                      color: widget.isFollowing 
                          ? WantrTheme.accent 
                          : WantrTheme.textPrimary,
                      size: 26,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedTapContainer(
      onTap: onPressed,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Icon(
          icon,
          color: WantrTheme.textPrimary,
          size: 26,
        ),
      ),
    );
  }
}
