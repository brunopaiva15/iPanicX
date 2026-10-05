import '../l10n/strings.dart';
import '../models/iphone_device.dart';
import '../models/scan_result.dart';

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

extension on String {
  /// French puts a space before a colon, English does not.
  String colon(Strings t) => t.lang == AppLang.fr
      ? replaceFirst(RegExp(r'\s*:'), ' :')
      : replaceFirst(RegExp(r'\s*:'), ':');
}
