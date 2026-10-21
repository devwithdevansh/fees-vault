import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

/// Professional card container with multi-layer shadow, clean border, and ink ripple.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? customShadow;
  final Border? customBorder;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.backgroundColor,
    this.borderRadius,
    this.customShadow,
    this.customBorder,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(18);

    final card = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: radius,
        border: customBorder ?? Border.all(color: AppColors.divider, width: 1),
        boxShadow: customShadow ?? AppColors.cardShadow,
      ),
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap!();
          },
          borderRadius: radius,
          splashColor: AppColors.brand.withValues(alpha: 0.06),
          highlightColor: AppColors.brand.withValues(alpha: 0.03),
          child: card,
        ),
      );
    }

    return card;
  }
}
