import '../l10n/strings.dart';
import '../models/device_facts.dart';
import '../models/iphone_device.dart';
import '../models/scan_result.dart';
import 'health_report.dart';

/// Plain-text rendering of a diagnosis (clipboard + `.txt` export).
class ReportFormatter {
  const ReportFormatter._();

  static String diagnosis(AnalyzedPanic panic, {IPhoneDevice? device}) {
    final t = tr;
    final r = panic.result;
    final p = panic.report;
    final b = StringBuffer()
      ..writeln(t.reportTitle)
      ..writeln('=' * 40)
      ..writeln()
      ..writeln(r.title)
      ..writeln('${t.severity} : ${r.severity.label}'.colon(t))
      ..writeln('${t.confidence} : ${r.confidence.label}'.colon(t))
      ..writeln()
      ..writeln(r.summary);
    if (r.disclaimer != null) {
      b
        ..writeln()
        ..writeln(r.disclaimer);
    }

    void list(String title, List<String> items) {
      if (items.isEmpty) return;
      b
        ..writeln()
        ..writeln(title);
      for (final i in items) {
        b.writeln('  - $i');
      }
    }

    list('${t.suspectedComponents}:'.colon(t), r.suspectedComponents);
    list('${t.possibleCauses}:'.colon(t), r.possibleCauses);
    list('${t.recommendedActions}:'.colon(t), r.recommendedActions);

    b
      ..writeln()
      ..writeln('${t.technicalDetails}:'.colon(t));
    void row(String k, String? v) {
      if (v == null || v.isEmpty) return;
      b.writeln('  ${k.padRight(22)}$v');
    }

    row(t.device, p.product ?? device?.productType);
    row(t.model, marketingNameFor(p.product ?? device?.productType));
    row('iOS', p.osVersion ?? device?.productVersion);
    row(t.build, p.build ?? device?.buildVersion);
    row(t.date, panic.date?.toString());
    row(t.bugType, p.bugType);
    row(
      t.sensorMask,
      p.sensorMask == null ? null : '${p.sensorMaskHex} (${p.sensorMask})',
    );
    row(t.smcKeys, p.sensorKeys.isEmpty ? null : p.sensorKeys.join(', '));
    row(
      t.missingSensors,
      p.missingSensors.isEmpty ? null : p.missingSensors.join(', '),
    );
    row(t.initiator, p.panicInitiator);
    row(t.panickedTask, p.panickedProcess);
    row(t.kexts, p.backtraceKexts.isEmpty ? null : p.backtraceKexts.join(', '));
    row(t.panicFlags, p.panicFlags);
    row(t.kernel, p.kernelVersion);
    row('SoC', p.socId);
    row('Incident', p.incident);
    row(t.file, panic.file.name);
    row(t.rule, r.matchedRuleId);
    row(t.matchedOn, r.evidence.isEmpty ? null : r.evidence.join(' | '));
    if (r.rawCodes.isNotEmpty) row(t.codes, r.rawCodes.join(' | '));
    if (p.hasPanicString) {
      b
        ..writeln()
        ..writeln('${t.panicString}:'.colon(t))
        ..writeln(p.panicString!.trim());
    }
    b
      ..writeln()
      ..writeln(t.reportLocal);
    return b.toString();
  }
}

/// Whole-device report: health checklist, main issue, battery, storage,
/// correlation, then every kernel panic in one line.
abstract final class FullReport {
  static String render({
    required HealthReport health,
    ScanResult? scan,
    DeviceFacts? facts,
    IPhoneDevice? device,
    DateTime? now,
  }) {
    final t = tr;
    final b = StringBuffer()
      ..writeln('${t.reportTitle} — ${t.fullReport}')
      ..writeln('=' * 48)
      ..writeln();
    if (device != null) {
      b.writeln(
        [
          device.displayName,
          if (device.modelName != device.displayName) device.modelName,
          if (device.productType != null) device.productType,
          if (device.productVersion != null) 'iOS ${device.productVersion}',
          if (device.buildVersion != null) '(${device.buildVersion})',
        ].join('  '),
      );
    }
    b
      ..writeln(formatStamp(now ?? DateTime.now()))
      ..writeln()
      ..writeln('${t.overallState} : ${_overall(t, health.overall)}'.colon(t))
      ..writeln();

    for (final c in health.checks) {
      final mark = switch (c.status) {
        CheckStatus.ok => '[OK]  ',
        CheckStatus.warning => '[!]   ',
        CheckStatus.problem => '[X]   ',
        CheckStatus.info => '[i]   ',
        CheckStatus.unavailable => '[-]   ',
      };
      b.writeln('  $mark${c.title.padRight(26)}${c.value}');
    }

    final g = health.mainIssue;
    if (g != null) {
      b
        ..writeln()
        ..writeln('${t.mainIssue} :'.colon(t))
        ..writeln('  ${g.value}  (${g.count}×)')
        ..writeln(
          '  ${'${t.probableCause} : '.colon(t)}${g.component ?? t.componentUnknown}',
        )
        ..writeln('  ${'${t.confidence} : '.colon(t)}${g.confidence.label}');
      if (g.first != null) {
        b.writeln('  ${'${t.firstSeen} : '.colon(t)}${formatStamp(g.first!)}');
      }
      if (g.last != null) {
        b.writeln('  ${'${t.lastSeen} : '.colon(t)}${formatStamp(g.last!)}');
      }
      if (g.isHardware) b.writeln('  ${t.knownSignatureDisclaimer}');
    }

    final bat = facts?.battery;
    if (bat != null) {
      String v(Object? x, [String unit = '']) =>
          x == null ? t.unavailable : '$x$unit';
      b
        ..writeln()
        ..writeln('${t.battery} :'.colon(t))
        ..writeln('  ${t.charge.padRight(24)}${v(bat.chargePercent, ' %')}')
        ..writeln('  ${t.cycleCount.padRight(24)}${v(bat.cycleCount)}')
        ..writeln(
          '  ${t.designCapacity.padRight(24)}${v(bat.designCapacity, ' mAh')}',
        )
        ..writeln(
          '  ${t.currentCapacity.padRight(24)}${v(bat.fullChargeCapacity, ' mAh')}',
        )
        ..writeln(
          '  ${t.estimatedHealth.padRight(24)}${v(bat.healthPercent, ' %')}',
        );
    }

    if (health.groups.isNotEmpty) {
      b
        ..writeln()
        ..writeln('${t.correlation} :'.colon(t));
      for (final g in health.groups) {
        b.writeln(
          '  ${g.count.toString().padLeft(3)}×  ${g.value}'
          '${g.component == null ? '' : '  →  ${g.component}'}',
        );
      }
    }

    if (scan != null && scan.panics.isNotEmpty) {
      b
        ..writeln()
        ..writeln('${t.kernelPanicsSection} :'.colon(t));
      for (final p in scan.panics) {
        b.writeln(
          '  ${p.date == null ? '?' : formatStamp(p.date!)}  '
          '${p.result.title}  (${p.file.name})',
        );
      }
    }
    b
      ..writeln()
      ..writeln(t.reportLocal);
    return b.toString();
  }

  static String _overall(Strings t, CheckStatus s) => switch (s) {
    CheckStatus.problem => t.overallProblem,
    CheckStatus.warning => t.overallWarning,
    _ => t.overallOk,
  };

  static String formatStamp(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final l = d.toLocal();
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }
}

extension on String {
  /// French puts a space before a colon, English does not.
  String colon(Strings t) => t.lang == AppLang.fr
      ? replaceFirst(RegExp(r'\s*:'), ' :')
      : replaceFirst(RegExp(r'\s*:'), ':');
}
