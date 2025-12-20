import 'package:flutter/material.dart';

/// A utility widget that provides a subtle scale animation on tap.
class AnimatedTapContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleOnTap;
  final Duration duration;

  const AnimatedTapContainer({
    super.key,
    required this.child,
    this.onTap,
    this.scaleOnTap = 0.95,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<AnimatedTapContainer> createState() => _AnimatedTapContainerState();
}

class _AnimatedTapContainerState extends State<AnimatedTapContainer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleOnTap).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
