import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

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
        color: WantrTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: WantrTheme.undiscovered,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ControlButton(
            icon: Icons.add,
            onPressed: widget.onZoomIn,
          ),
          const Divider(
            height: 1,
            color: WantrTheme.undiscovered,
          ),
          _ControlButton(
            icon: Icons.remove,
            onPressed: widget.onZoomOut,
          ),
          const Divider(
            height: 1,
            color: WantrTheme.undiscovered,
          ),
          // Animated center/north button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleCenterPress,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 48,
                height: 48,
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
                        size: 24,
                      ),
                    );
                  },
                ),
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
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: isActive ? WantrTheme.accent : WantrTheme.textPrimary,
            size: 24,
          ),
        ),
      ),
    );
  }
}
