import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/diagnostic_result.dart';
import 'common.dart';
import 'panic_card.dart';
import 'ring.dart';
import 'status_badge.dart';

/// Headline of a diagnosis, in the tooltip-card style: ring (confidence,
/// tinted by severity), large title, badges, summary, disclaimer.
class DiagnosticCard extends StatelessWidget {
  const DiagnosticCard({super.key, required this.result, this.footer});

  final DiagnosticResult result;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final sev = colors.severity(result.severity);
    final fraction = result.isKnownSignature
        ? confidenceFraction(result.confidence)
        : 0.0;
    return SectionCard(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UsageRing(
                fraction: fraction,
                color: sev,
                size: 86,
                stroke: 7,
                child: Icon(
                  result.isKnownSignature
                      ? Icons.bolt_rounded
                      : Icons.question_mark_rounded,
                  color: colors.ink,
                  size: 34,
                ),
              ),
              const SizedBox(width: 26),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.title, style: theme.textTheme.displaySmall),
                    const SizedBox(height: 12),
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
          const SizedBox(height: 24),
          Text(
            result.summary,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.5,
              fontSize: 16,
            ),
          ),
          if (result.disclaimer != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.raised,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 17, color: colors.ink),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.disclaimer!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: colors.secondaryText,
                      ),
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
