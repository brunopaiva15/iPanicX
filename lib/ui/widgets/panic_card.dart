import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/scan_result.dart';
import '../format.dart';
import 'status_badge.dart';

/// One panic in a list: diagnosis title, date, file name.
class PanicCard extends StatelessWidget {
  const PanicCard({super.key, required this.panic, required this.onTap});

  final AnalyzedPanic panic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final r = panic.result;
    final sevColor = colors.severity(r.severity);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: colors.border.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(
                  color: sevColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      panic.report.headline ?? panic.file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRelativeDate(panic.date),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  StatusBadge(
                    label: r.isKnownSignature
                        ? r.confidence.label
                        : 'Unknown signature',
                    color: colors.confidence(r.confidence),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colors.tertiaryText, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
