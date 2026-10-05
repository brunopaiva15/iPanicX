import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Codenotch-style ring: a translucent track with a coloured arc that starts
/// at 12 o'clock and sweeps clockwise by [fraction]. A [child] (glyph) sits in
/// the middle. With [spinning], a short arc rotates (indeterminate wait).
class UsageRing extends StatefulWidget {
  const UsageRing({
    super.key,
    required this.fraction,
    required this.color,
    this.size = 56,
    this.stroke,
    this.child,
    this.spinning = false,
  });

  final double fraction;
  final Color color;
  final double size;
  final double? stroke;
  final Widget? child;
  final bool spinning;

  @override
  State<UsageRing> createState() => _UsageRingState();
}

class _UsageRingState extends State<UsageRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _spin.repeat();
  }

  @override
  void didUpdateWidget(UsageRing old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_spin.isAnimating) _spin.repeat();
    if (!widget.spinning && _spin.isAnimating) _spin.stop();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = AppColors.of(context).track;
    final stroke = widget.stroke ?? (widget.size * 0.085).clamp(2.5, 9.0);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.fraction.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => AnimatedBuilder(
          animation: _spin,
          builder: (context, child) => CustomPaint(
            painter: _RingPainter(
              fraction: widget.spinning ? 0.22 : value,
              rotation: widget.spinning ? _spin.value : 0,
              color: widget.color,
              track: track,
              stroke: stroke,
            ),
            child: child,
          ),
          child: child,
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.rotation,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double fraction;
  final double rotation;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base..color = track);
    if (fraction <= 0) return;
    canvas.drawArc(
      arcRect,
      -math.pi / 2 + rotation * math.pi * 2,
      math.pi * 2 * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.rotation != rotation ||
      old.color != color ||
      old.track != track;
}

/// Ring with its reading underneath, like a notch cell ("73%").
class RingStat extends StatelessWidget {
  const RingStat({
    super.key,
    required this.fraction,
    required this.color,
    required this.icon,
    required this.label,
    this.value,
    this.size = 58,
  });

  final double fraction;
  final Color color;
  final IconData icon;
  final String label;

  /// Defaults to the percentage.
  final String? value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Tooltip(
      message: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UsageRing(
            fraction: fraction,
            color: color,
            size: size,
            child: Icon(icon, color: colors.ink, size: size * 0.36),
          ),
          const SizedBox(height: 10),
          Text(
            value ?? '${(fraction * 100).round()}%',
            style: numeralStyle(context, size: 20),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.secondaryText, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// Tooltip-card row: label left, secondary note right, thin rounded bar, then
/// a caption ("73% Used").
class BarRow extends StatelessWidget {
  const BarRow({
    super.key,
    required this.label,
    required this.fraction,
    required this.color,
    this.trailing,
    this.caption,
  });

  final String label;
  final double fraction;
  final Color color;
  final String? trailing;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(color: colors.secondaryText, fontSize: 12.5),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: colors.track,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(end: fraction.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Container(
                  height: 6,
                  width: math.max(6, c.maxWidth * v),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 7),
          Text(caption!, style: const TextStyle(fontSize: 12.5)),
        ],
      ],
    );
  }
}
