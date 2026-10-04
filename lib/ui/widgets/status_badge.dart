import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/diagnostic_result.dart';

/// Small rounded pill (severity, confidence, connection status…).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
    this.uppercase = false,
  });

  factory StatusBadge.severity(BuildContext context, Severity s) => StatusBadge(
    label: s == Severity.unknown ? 'Unknown severity' : '${s.label} severity',
    color: AppColors.of(context).severity(s),
    filled: s == Severity.high,
    uppercase: true,
  );

  factory StatusBadge.confidence(BuildContext context, Confidence c) =>
      StatusBadge(
        label: c.label,
        color: AppColors.of(context).confidence(c),
        icon: c == Confidence.none
            ? Icons.help_outline
            : Icons.verified_outlined,
      );

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            uppercase ? label.toUpperCase() : label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: uppercase ? 0.6 : 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Coloured dot + text, for connection states.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: AppColors.of(context).secondaryText,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
