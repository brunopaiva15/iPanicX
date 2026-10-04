import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/diagnostic_result.dart';
import 'common.dart';
import 'status_badge.dart';

/// Headline card of a diagnosis: title, severity, confidence, summary.
class DiagnosticCard extends StatelessWidget {
  const DiagnosticCard({super.key, required this.result, this.footer});

  final DiagnosticResult result;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final sevColor = colors.severity(result.severity);
    return SectionCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                icon: result.isKnownSignature
                    ? Icons.warning_amber_rounded
                    : Icons.help_outline_rounded,
                color: sevColor,
                size: 60,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.title, style: theme.textTheme.displaySmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        StatusBadge.severity(context, result.severity),
                        StatusBadge.confidence(context, result.confidence),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            result.summary,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          if (result.disclaimer != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 17, color: colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.disclaimer!,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (footer != null) ...[const SizedBox(height: 20), footer!],
        ],
      ),
    );
  }
}
