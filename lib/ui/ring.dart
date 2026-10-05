import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Ring proportions from Codenotch's NotchLayout.swift: a 117px ring with a
/// 15.5px track and an 8px arc (44/117 pt per px).
abstract final class NL {
  static const double _k = 44 / 117;
  static final ring = 117 * _k;
  static final trackStroke = 15.5 * _k;
  static final progressStroke = 8 * _k;
}

/// Grey track with a thinner coloured arc from 12 o'clock, clockwise
/// (Sources/Features/ProviderRing.swift).
class UsageRing extends StatefulWidget {
  const UsageRing({
    super.key,
    required this.fraction,
    required this.color,
    this.size,
    this.child,
    this.spinning = false,
    this.track = Notch.ringTrack,
  });

  final double fraction;
  final Color color;
  final double? size;
  final Widget? child;
  final bool spinning;
  final Color track;

  @override
  State<UsageRing> createState() => _UsageRingState();
}

class _UsageRingState extends State<UsageRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
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
    final size = widget.size ?? NL.ring;
    final scale = size / NL.ring;
    return SizedBox.square(
      dimension: size,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, child) => CustomPaint(
          painter: _RingPainter(
            fraction: widget.spinning ? 0.25 : widget.fraction.clamp(0, 1),
            rotation: widget.spinning ? _spin.value : 0,
            color: widget.color,
            track: widget.track,
            trackStroke: NL.trackStroke * scale,
            progressStroke: NL.progressStroke * scale,
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
    required this.trackStroke,
    required this.progressStroke,
  });

  final double fraction;
  final double rotation;
  final Color color;
  final Color track;
  final double trackStroke;
  final double progressStroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(trackStroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackStroke
        ..color = track,
    );
    if (fraction <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2 + rotation * math.pi * 2,
      math.pi * 2 * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = progressStroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.fraction != fraction ||
      o.rotation != rotation ||
      o.color != color ||
      o.track != track;
}
