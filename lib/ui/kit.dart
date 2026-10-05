import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../l10n/lang_scope.dart';

/// Building blocks of Codenotch's settings window
/// (windows/codenotch/ui/settings.html): pane head, section captions,
/// grouped rows, `.btn`, `.seg`, sidebar badges, toast.

/// `#head` + `#body`: 52px head with a 22px semibold title, scrolling body
/// padded 0 20 20.
class Pane extends StatelessWidget {
  const Pane({
    super.key,
    required this.title,
    required this.children,
    this.leading,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.only(left: 24, right: 20),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

/// `.sec`: 13.5px semibold caption, margin 18 12 8.
class Sec extends StatelessWidget {
  const Sec(this.text, {super.key, this.first = false});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(12, first ? 0 : 18, 12, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: kBodySize,
        fontWeight: FontWeight.w600,
        color: AppColors.of(context).text,
      ),
    ),
  );
}

/// `.group`: rounded 10, 1px line, rows separated by `--sep`.
class Group extends StatelessWidget {
  const Group({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.group,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Container(height: 1, color: c.sep),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// `.item`: padding 9 12, min height 40, label left, value/control right.
class Item extends StatefulWidget {
  const Item({
    super.key,
    this.leading,
    required this.label,
    this.hint,
    this.value,
    this.trailing,
    this.onTap,
    this.mono = false,
    this.valueColor,
    this.wrapValue = false,
  });

  final Widget? leading;
  final String label;

  /// `.hint`: 12px secondary line under the label.
  final String? hint;

  /// `.value`: secondary text on the right.
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool mono;
  final Color? valueColor;

  /// Long values (paths, panic lines) go under the label instead.
  final bool wrapValue;

  @override
  State<Item> createState() => _ItemState();
}

class _ItemState extends State<Item> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final valueStyle = widget.mono
        ? monoStyle(context, size: 12.5, color: widget.valueColor ?? c.text2)
        : TextStyle(fontSize: kBodySize, color: widget.valueColor ?? c.text2);
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: TextStyle(fontSize: kBodySize, color: c.text),
        ),
        if (widget.hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              widget.hint!,
              style: TextStyle(fontSize: 12, color: c.text2),
            ),
          ),
        if (widget.wrapValue && widget.value != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: SelectableText(widget.value!, style: valueStyle),
          ),
      ],
    );
    Widget row = LayoutBuilder(
      builder: (context, box) {
        final valueMaxWidth = box.maxWidth * 0.62;
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 10),
                ],
                Expanded(child: label),
                if (!widget.wrapValue && widget.value != null) ...[
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: valueMaxWidth),
                    child: SelectableText(
                      widget.value!,
                      textAlign: TextAlign.right,
                      style: valueStyle,
                    ),
                  ),
                ],
                if (widget.trailing != null) ...[
                  const SizedBox(width: 12),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        );
      },
    );
    if (widget.onTap == null) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: ColoredBox(
          color: _hover ? c.hover : Colors.transparent,
          child: row,
        ),
      ),
    );
  }
}

/// `.item.cap`: 12px secondary text block.
class CapItem extends StatelessWidget {
  const CapItem(this.text, {super.key, this.mono = false});

  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SelectableText(
        text,
        style: mono
            ? monoStyle(context, size: 11.5, color: c.text2)
            : TextStyle(fontSize: 12, color: c.text2, height: 1.35),
      ),
    );
  }
}

/// `.btn`: neutral fill, radius 6, padding 5 12, 13px. [primary] uses the
/// accent like `.seg button.on`.
class Btn extends StatefulWidget {
  const Btn(this.label, {super.key, this.onPressed, this.primary = false});

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  State<Btn> createState() => _BtnState();
}

class _BtnState extends State<Btn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = widget.onPressed != null;
    final bg = widget.primary
        ? c.accent
        : (_hover && enabled ? c.btnHover : c.btn);
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                color: widget.primary ? Colors.white : c.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.seg`: segmented control, selected segment in the accent.
class Seg<T> extends StatelessWidget {
  const Seg({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.segBg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in options.entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onChanged(e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: e.key == value ? c.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 13,
                        color: e.key == value ? Colors.white : c.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sidebar `.badge`: 20px squircle, vertical gradient, 12px white glyph.
class SideBadge extends StatelessWidget {
  const SideBadge(this.icon, this.gradient, {super.key});

  final IconData icon;
  final List<Color> gradient;

  static const blue = [Color(0xFF4FA6FF), Color(0xFF0A6CFF)];
  static const indigo = [Color(0xFF8784FF), Color(0xFF5856D6)];
  static const gray = [Color(0xFFA6A6AB), Color(0xFF727277)];
  static const red = [Color(0xFFFF6D62), Color(0xFFDD3328)];

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(5.5),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: gradient,
      ),
    ),
    child: Icon(icon, size: 13, color: Colors.white),
  );
}

/// `.glyph`: 16px monochrome icon in front of a row.
class Glyph extends StatelessWidget {
  const Glyph(this.icon, {super.key, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: 16, color: color ?? AppColors.of(context).text);
}

/// Disclosure row revealing raw technical output (never open by default).
class TechnicalDetails extends StatefulWidget {
  const TechnicalDetails({super.key, required this.details, this.label});

  final String details;

  /// Defaults to "Technical details" in the active language.
  final String? label;

  @override
  State<TechnicalDetails> createState() => _TechnicalDetailsState();
}

class _TechnicalDetailsState extends State<TechnicalDetails> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Item(
          label: widget.label ?? context.tr.technicalDetails,
          onTap: () => setState(() => _open = !_open),
          trailing: Icon(
            _open ? Icons.expand_less : Icons.expand_more,
            size: 18,
            color: c.text2,
          ),
        ),
        if (_open) ...[
          Container(height: 1, color: c.sep),
          CapItem(widget.details, mono: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: Btn(
                context.tr.copy,
                onPressed: () =>
                    copyText(context, widget.details, context.tr.copied),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// `#toast`: small note bottom-right that fades out.
void showToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final c = AppColors.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      right: 18,
      bottom: 14,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 300),
          builder: (_, v, child) => Opacity(opacity: v, child: child),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: c.side,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.line),
              ),
              child: Text(
                message,
                style: TextStyle(fontSize: 12, color: c.text2),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 2400), () {
    if (entry.mounted) entry.remove();
  });
}

Future<void> copyText(BuildContext context, String text, String note) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showToast(context, note);
}
