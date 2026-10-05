import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Codenotch's notch and tooltip card, with the proportions of
/// Sources/Notch/NotchLayout.swift (measured off the 2000px design frame,
/// 44/117 pt per px) scaled ×1.25 for use inside a window.
abstract final class NL {
  static const double _k = 44 / 117 * 1.25;
  static double px(double v) => v * _k;

  static final ring = px(117);
  static final trackStroke = px(15.5);
  static final progressStroke = px(8);
  static final glyph = px(46);
  static final ringLabelGap = px(26.9);
  static final cellSpacing = px(83.5);
  static final padTop = px(69.5);
  static final padBottom = px(50.1);
  static final notchCorner = px(78.8);
  static final notchWidth = px(190);

  static final cardWidth = px(600);
  static final cardCorner = px(49.5);
  static final cardPadding = px(32);
  static final tailLength = px(75);
  static final tailHeight = px(87);
  static final barHeight = px(10.5);
  static final headerGap = px(17);
  static final headerToBlock = px(21);
  static final labelToBar = px(16.8);
  static final barToUsed = px(17.8);
  static final blockSpacing = px(20);

  /// Point size whose capitals are [cap] px tall in the frame (SF cap 0.714).
  static double font(double cap) => px(cap) / 0.714;
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

/// One cell of the notch: ring with glyph, reading underneath.
class NotchCell {
  const NotchCell({
    required this.icon,
    required this.fraction,
    required this.color,
    required this.reading,
    required this.card,
    this.onOpen,
  });

  final IconData icon;
  final double fraction;
  final Color color;
  final String reading;
  final TooltipCardData card;
  final VoidCallback? onOpen;
}

class TooltipBlock {
  const TooltipBlock({
    required this.label,
    required this.note,
    required this.fraction,
    required this.color,
    required this.reading,
  });

  /// Left of the label line ("Current session").
  final String label;

  /// Right of the label line, secondary ink ("Resets in 51 min").
  final String note;
  final double fraction;
  final Color color;

  /// Under the bar ("73% Used").
  final String reading;
}

class TooltipCardData {
  const TooltipCardData({
    required this.icon,
    required this.title,
    required this.blocks,
  });

  final IconData icon;
  final String title;
  final List<TooltipBlock> blocks;
}

/// The vertical black notch with its tooltip card aimed at the hovered cell,
/// as in docs/design/frame-124-hover-tooltip.png.
class NotchPanel extends StatefulWidget {
  const NotchPanel({super.key, required this.cells});

  final List<NotchCell> cells;

  static double heightFor(int n) =>
      NL.padTop +
      n * (NL.ring + NL.ringLabelGap + NL.font(27) * 1.2) +
      (n - 1) * NL.cellSpacing +
      NL.padBottom;

  @override
  State<NotchPanel> createState() => _NotchPanelState();
}

class _NotchPanelState extends State<NotchPanel> {
  int _selected = 0;

  // Text line boxes differ slightly per platform font: keep a few points of
  // slack so the card never clips its last line.
  static final _cardHeight =
      6 +
      NL.cardPadding * 2 +
      NL.font(26) * 1.25 +
      NL.headerToBlock +
      2 *
          (NL.font(18) * 1.25 * 2 +
              NL.labelToBar +
              NL.barHeight +
              NL.barToUsed) +
      NL.blockSpacing;

  double _ringCenter(int i) =>
      NL.padTop +
      i * (NL.ring + NL.ringLabelGap + NL.font(27) * 1.2 + NL.cellSpacing) +
      NL.ring / 2;

  @override
  Widget build(BuildContext context) {
    final cells = widget.cells;
    if (cells.isEmpty) return const SizedBox.shrink();
    final sel = _selected.clamp(0, cells.length - 1);
    final notchH = NotchPanel.heightFor(cells.length);
    final height = math.max(notchH, _cardHeight);
    final notchTop = (height - notchH) / 2;
    final center = notchTop + _ringCenter(sel);
    final cardTop = (center - _cardHeight / 2).clamp(0.0, height - _cardHeight);
    final tailTop = (center - NL.tailHeight / 2).clamp(
      cardTop + NL.cardCorner * 0.6,
      cardTop + _cardHeight - NL.cardCorner * 0.6 - NL.tailHeight,
    );
    final width = NL.cardWidth + NL.tailLength + NL.notchWidth;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            left: 0,
            top: cardTop,
            width: NL.cardWidth,
            height: _cardHeight,
            child: MouseRegion(
              cursor: cells[sel].onOpen == null
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: GestureDetector(
                onTap: cells[sel].onOpen,
                child: TooltipCard(data: cells[sel].card),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            left: NL.cardWidth - 0.5,
            top: tailTop,
            width: NL.tailLength + 1,
            height: NL.tailHeight,
            child: CustomPaint(painter: _TailPainter()),
          ),
          Positioned(
            right: 0,
            top: notchTop,
            width: NL.notchWidth,
            height: notchH,
            child: Container(
              decoration: BoxDecoration(
                color: Notch.surface,
                borderRadius: BorderRadius.circular(NL.notchCorner),
              ),
              padding: EdgeInsets.only(top: NL.padTop, bottom: NL.padBottom),
              child: Column(
                children: [
                  for (var i = 0; i < cells.length; i++) ...[
                    if (i > 0) SizedBox(height: NL.cellSpacing),
                    MouseRegion(
                      onEnter: (_) => setState(() => _selected = i),
                      cursor: cells[i].onOpen == null
                          ? SystemMouseCursors.basic
                          : SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          if (_selected != i) {
                            setState(() => _selected = i);
                          } else {
                            cells[i].onOpen?.call();
                          }
                        },
                        child: Column(
                          children: [
                            UsageRing(
                              fraction: cells[i].fraction,
                              color: cells[i].color,
                              child: Icon(
                                cells[i].icon,
                                size: NL.glyph,
                                color: Notch.ink,
                              ),
                            ),
                            SizedBox(height: NL.ringLabelGap),
                            Text(
                              cells[i].reading,
                              style: TextStyle(
                                color: Notch.ink,
                                fontSize: NL.font(27),
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The tooltip card itself (Sources/Features/TooltipCard.swift).
class TooltipCard extends StatelessWidget {
  const TooltipCard({super.key, required this.data});

  final TooltipCardData data;

  @override
  Widget build(BuildContext context) {
    final body = TextStyle(
      color: Notch.ink,
      fontSize: NL.font(18),
      height: 1.25,
    );
    return Container(
      decoration: BoxDecoration(
        color: Notch.surface,
        borderRadius: BorderRadius.circular(NL.cardCorner),
      ),
      padding: EdgeInsets.all(NL.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(data.icon, color: Notch.ink, size: NL.font(26) * 1.15),
              SizedBox(width: NL.headerGap),
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Notch.ink,
                    fontSize: NL.font(26),
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: NL.headerToBlock),
          for (var i = 0; i < data.blocks.length; i++) ...[
            if (i > 0) SizedBox(height: NL.blockSpacing),
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.blocks[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  data.blocks[i].note,
                  style: body.copyWith(color: Notch.ink2),
                ),
              ],
            ),
            SizedBox(height: NL.labelToBar),
            _Bar(
              fraction: data.blocks[i].fraction,
              color: data.blocks[i].color,
            ),
            SizedBox(height: NL.barToUsed),
            Text(data.blocks[i].reading, style: body),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final f = fraction.clamp(0.0, 1.0);
        return Container(
          height: NL.barHeight,
          decoration: ShapeDecoration(
            color: Notch.barTrack,
            shape: const StadiumBorder(),
          ),
          alignment: Alignment.centerLeft,
          child: f <= 0
              ? null
              : Container(
                  width: math.max(NL.barHeight, c.maxWidth * f),
                  decoration: ShapeDecoration(
                    color: color,
                    shape: const StadiumBorder(),
                  ),
                ),
        );
      },
    );
  }
}

/// The speech-bubble tail: shoulders leave the card tangent to its edge, the
/// tip is crisp (TooltipTail, direction .leading).
class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(0, h * 0.25, w - w * 0.42, h / 2 - h * 0.12, w, h / 2)
      ..cubicTo(w - w * 0.42, h / 2 + h * 0.12, 0, h - h * 0.25, 0, h)
      ..close();
    canvas.drawPath(path, Paint()..color = Notch.surface);
  }

  @override
  bool shouldRepaint(_TailPainter old) => false;
}
