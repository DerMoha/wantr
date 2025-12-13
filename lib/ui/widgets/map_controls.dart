import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Map control buttons for zoom and centering
class MapControls extends StatelessWidget {
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
            onPressed: onZoomIn,
          ),
          const Divider(
            height: 1,
            color: WantrTheme.undiscovered,
          ),
          _ControlButton(
            icon: Icons.remove,
            onPressed: onZoomOut,
          ),
          const Divider(
            height: 1,
            color: WantrTheme.undiscovered,
          ),
          _ControlButton(
            icon: Icons.my_location,
            onPressed: onCenterPressed,
            isActive: isFollowing,
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
