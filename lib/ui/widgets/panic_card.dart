import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/diagnostic_result.dart';
import '../../models/scan_result.dart';
import '../format.dart';
import 'ring.dart';

/// Ring fill for a confidence level.
double confidenceFraction(Confidence c) => switch (c) {
  Confidence.high => 1,
  Confidence.medium => 0.66,
  Confidence.low => 0.33,
  Confidence.none => 0,
};

/// One panic row: confidence ring tinted by severity, title, panic line, date.
class PanicCard extends StatefulWidget {
  const PanicCard({super.key, required this.panic, required this.onTap});

  final AnalyzedPanic panic;
  final VoidCallback onTap;

  @override
  State<PanicCard> createState() => _PanicCardState();
}

class _PanicCardState extends State<PanicCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final r = widget.panic.result;
    final sev = colors.severity(r.severity);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hover ? colors.raised : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            children: [
              UsageRing(
                fraction: r.isKnownSignature
                    ? confidenceFraction(r.confidence)
                    : 0,
                color: sev,
                size: 36,
                stroke: 3.5,
                child: Icon(
                  r.isKnownSignature
                      ? Icons.bolt_rounded
                      : Icons.question_mark_rounded,
                  size: 15,
                  color: colors.ink,
                ),
              ),
              const SizedBox(width: 15),
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
                      widget.panic.report.headline ?? widget.panic.file.name,
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
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRelativeDate(widget.panic.date),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    r.isKnownSignature
                        ? r.confidence.label
                        : 'Unknown signature',
                    style: TextStyle(
                      color: colors.secondaryText,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.tertiaryText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
