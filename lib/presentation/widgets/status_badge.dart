import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/charge.dart';

/// Clean iOS-style status indicator badge with icon + text for dual-coding accessibility.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.icon,
  });

  factory StatusBadge.fromChargeStatus(ChargeStatus status) {
    switch (status) {
      case ChargeStatus.settled:
        return const StatusBadge(
          label: 'Settled',
          textColor: AppColors.settledGreen,
          backgroundColor: AppColors.settledGreenBg,
          icon: Icons.check_circle_outline,
        );
      case ChargeStatus.overdue:
        return const StatusBadge(
          label: 'Overdue',
          textColor: AppColors.overdueRed,
          backgroundColor: AppColors.overdueRedBg,
          icon: Icons.error_outline,
        );
      case ChargeStatus.partial:
        return const StatusBadge(
          label: 'Partially Paid',
          textColor: AppColors.partialBlue,
          backgroundColor: AppColors.partialBlueBg,
          icon: Icons.timelapse_outlined,
        );
      case ChargeStatus.unpaid:
        return const StatusBadge(
          label: 'Pending Due',
          textColor: AppColors.unpaidAmber,
          backgroundColor: AppColors.unpaidAmberBg,
          icon: Icons.schedule_outlined,
        );
    }
  }

  factory StatusBadge.archived() {
    return const StatusBadge(
      label: 'Archived',
      textColor: AppColors.archivedGray,
      backgroundColor: AppColors.archivedGrayBg,
      icon: Icons.archive_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
