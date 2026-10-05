import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/console_controller.dart';
import '../../app/theme.dart';
import '../../diagnostics/log_rules.dart';
import '../../l10n/lang_scope.dart';
import '../kit.dart';

/// Live device log with highlighted, explained events.
class ConsolePane extends StatelessWidget {
  const ConsolePane({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: app.console,
      builder: (context, _) => _build(context, app, app.console),
    );
  }

  Widget _build(BuildContext context, AppController app, ConsoleController k) {
    final t = context.tr;
    final c = AppColors.of(context);
    final connected = app.status.isConnected;
    final lines = k.visible;

    return Pane(
      title: t.consoleSection,
      trailing: connected
          ? Btn(
              k.running ? t.consoleStop : t.consoleStart,
              primary: !k.running,
              onPressed: k.running ? k.stop : k.start,
            )
          : null,
      children: [
        if (!connected && k.lineCount == 0)
          Group(
            children: [
              Item(
                leading: const Glyph(Icons.terminal),
                label: t.consoleNeedsDevice,
              ),
            ],
          )
        else ...[
          Group(
            children: [
              Item(
                label: t.consoleCount(k.lineCount, k.eventCount),
                hint: k.running || k.lineCount > 0 ? null : t.consoleIdle,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Seg<bool>(
                      options: {false: t.consoleAll, true: t.consoleEventsOnly},
                      value: k.eventsOnly,
                      onChanged: k.setEventsOnly,
                    ),
                    if (k.running) ...[
                      const SizedBox(width: 8),
                      Btn(
                        k.paused ? t.consoleResume : t.consolePause,
                        onPressed: k.togglePause,
                      ),
                    ],
                    const SizedBox(width: 8),
                    Btn(t.consoleClear, onPressed: k.clear),
                    const SizedBox(width: 8),
                    Btn(
                      t.consoleExport,
                      onPressed: k.lineCount == 0
                          ? null
                          : () => _export(context, app, k),
                    ),
                  ],
                ),
              ),
              if (k.error != null) TechnicalDetails(details: '${k.error}'),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 460,
            decoration: BoxDecoration(
              color: c.group,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.line),
            ),
            child: lines.isEmpty
                ? Center(
                    child: Text(
                      k.running ? t.consoleWaiting : t.consoleIdle,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: c.text3),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: lines.length,
                    itemBuilder: (context, i) => _LogLine(lines[i]),
                  ),
          ),
        ],
      ],
    );
  }

  Future<void> _export(
    BuildContext context,
    AppController app,
    ConsoleController k,
  ) async {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    final saved = await app.bridge.saveTextFile(
      suggestedName: 'iPanicX-console-$stamp.txt',
      contents: k.export(),
    );
    if (saved != null && context.mounted) {
      showToast(context, context.tr.savedTo(saved));
    }
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine(this.line);
  final ClassifiedLine line;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = context.tr;
    final color = switch (line.level) {
      LogLevel.problem => c.danger,
      LogLevel.warning => StatusColors.warning,
      LogLevel.info => c.accent,
      LogLevel.normal => Colors.transparent,
    };
    final explain = line.ruleKey == null ? '' : t.consoleExplain(line.ruleKey!);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      decoration: BoxDecoration(
        color: line.isEvent ? color.withValues(alpha: 0.10) : null,
        borderRadius: BorderRadius.circular(5),
        border: line.isEvent
            ? Border(left: BorderSide(color: color, width: 3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (explain.isNotEmpty)
            Text(
              explain,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          SelectableText(
            line.text,
            style: monoStyle(
              context,
              size: 11.5,
              color: line.isEvent ? c.text : c.text2,
            ),
          ),
        ],
      ),
    );
  }
}
