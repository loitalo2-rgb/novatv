import 'package:flutter/material.dart';

import '../../core/theme.dart';

class FocusableCard extends StatefulWidget {
  const FocusableCard({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = 10,
    this.scale = 1.05,
    this.onLongPress,
    this.focusColor,
  });

  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final double scale;
  final VoidCallback? onLongPress;
  final Color? focusColor;

  @override
  State<FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<FocusableCard> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    final radius = BorderRadius.circular(widget.borderRadius);
    return AnimatedScale(
      scale: active ? widget.scale : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: _focused ? (widget.focusColor ?? AppColors.accent) : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: (widget.focusColor ?? AppColors.accent).withValues(alpha: 0.22),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onHover: (value) => setState(() => _hovered = value),
            onFocusChange: (value) => setState(() => _focused = value),
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            splashColor: AppColors.accent.withValues(alpha: 0.12),
            highlightColor: Colors.white.withValues(alpha: 0.04),
            child: ClipRRect(borderRadius: radius, child: widget.child),
          ),
        ),
      ),
    );
  }
}
