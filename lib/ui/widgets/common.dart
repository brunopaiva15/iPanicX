import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';

/// Max content width so cards don't stretch across wide windows.
const double kContentMaxWidth = 1080;

/// Width-constrained scrolling page body.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(36, 4, 36, 44),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Page header: small eyebrow, large title, optional back button & actions.
class AppToolbar extends StatelessWidget {
  const AppToolbar({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 26, 36, 18),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (eyebrow != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SectionLabel(eyebrow!),
                      ),
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          subtitle!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.secondaryText,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              for (final a in actions) ...[const SizedBox(width: 8), a],
            ],
          ),
        ),
      ),
    );
  }
}

/// Round back button.
class BackPill extends StatelessWidget {
  const BackPill({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Tooltip(
      message: 'Back',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colors.raised,
            shape: BoxShape.circle,
            border: Border.all(color: colors.border),
          ),
          child: Icon(Icons.arrow_back_rounded, size: 17, color: colors.ink),
        ),
      ),
    );
  }
}

/// Small uppercase label above a group.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      color: AppColors.of(context).secondaryText,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.9,
    ),
  );
}

/// The "notch" surface: a large rounded card.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.icon,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color,
  });

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: color ?? colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: colors.ink),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

/// Settings-style group: rows separated by hairlines inside a rounded card.
class Group extends StatelessWidget {
  const Group({super.key, required this.children, this.label});

  final List<Widget> children;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 9),
            child: SectionLabel(label!),
          ),
        Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, indent: 18, color: colors.hairline),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Label / value row used in information groups.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.monospace = false,
    this.labelWidth = 140,
    this.padded = true,
  });

  final String label;
  final String? value;
  final bool monospace;
  final double labelWidth;

  /// Row padding for use inside a [Group].
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: padded
          ? const EdgeInsets.symmetric(horizontal: 18, vertical: 11)
          : const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: TextStyle(color: colors.secondaryText, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(
              value ?? '—',
              style: monospace
                  ? monoStyle(context, size: 12.5)
                  : TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.ink,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// List of entries with a leading glyph.
class BulletList extends StatelessWidget {
  const BulletList({
    super.key,
    required this.items,
    this.icon = Icons.circle,
    this.iconSize = 6,
    this.iconColor,
    this.emptyText = 'None identified',
    this.numbered = false,
  });

  final List<String> items;
  final IconData icon;
  final double iconSize;
  final Color? iconColor;
  final String emptyText;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (items.isEmpty) {
      return Text(emptyText, style: TextStyle(color: colors.secondaryText));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 21,
                  child: Center(
                    child: numbered
                        ? Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.raised,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.border),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : Icon(
                            icon,
                            size: iconSize,
                            color: iconColor ?? colors.secondaryText,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    items[i],
                    style: const TextStyle(fontSize: 14, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Collapsible raw technical output. Never shown expanded by default.
class TechnicalDetails extends StatelessWidget {
  const TechnicalDetails({super.key, required this.details, this.title});

  final String details;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // Own Material so the tile's ink isn't hidden by the card decoration.
    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          dense: true,
          iconColor: colors.secondaryText,
          collapsedIconColor: colors.secondaryText,
          title: Text(
            title ?? 'Technical details',
            style: TextStyle(fontSize: 13, color: colors.secondaryText),
          ),
          children: [
            CodeBlock(text: details),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    copyToClipboard(context, details, 'Details copied'),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Monospace, selectable block.
class CodeBlock extends StatelessWidget {
  const CodeBlock({super.key, required this.text, this.maxHeight});

  final String text;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final content = SelectableText(text, style: monoStyle(context, size: 11.5));
    return Container(
      width: double.infinity,
      constraints: maxHeight == null
          ? null
          : BoxConstraints(maxHeight: maxHeight!),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.codeBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: maxHeight == null
          ? content
          : SingleChildScrollView(child: content),
    );
  }
}

/// Copies [text] and confirms with a snackbar.
Future<void> copyToClipboard(
  BuildContext context,
  String text,
  String confirmation,
) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(confirmation),
        duration: const Duration(seconds: 2),
      ),
    );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Glyph inside a ring-like circle (static).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 56,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.raised,
        shape: BoxShape.circle,
        border: Border.all(color: colors.track, width: size * 0.06),
      ),
      child: Icon(icon, color: color, size: size * 0.45),
    );
  }
}

/// Coloured dot + label (status chip).
class SignalChip extends StatelessWidget {
  const SignalChip({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? color : colors.raised,
        borderRadius: BorderRadius.circular(999),
        border: filled ? null : Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!filled) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: filled ? colors.onSignal : colors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
