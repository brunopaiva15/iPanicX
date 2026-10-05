import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/diagnostic_result.dart';

/// Pill badge: filled with the signal colour (severity) or a dark chip with a
/// coloured dot (confidence, states).
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
    filled: s != Severity.unknown,
    uppercase: true,
  );

  factory StatusBadge.confidence(BuildContext context, Confidence c) =>
      StatusBadge(label: c.label, color: AppColors.of(context).confidence(c));

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fg = filled ? colors.onSignal : colors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color : colors.raised,
        borderRadius: BorderRadius.circular(999),
        border: filled ? null : Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!filled) ...[
            icon != null
                ? Icon(icon, size: 12, color: color)
                : Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              uppercase ? label.toUpperCase() : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: uppercase ? 0.7 : 0,
              ),
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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 7),
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
