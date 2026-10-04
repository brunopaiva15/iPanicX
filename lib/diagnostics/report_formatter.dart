import '../models/iphone_device.dart';
import '../models/scan_result.dart';

/// Plain-text rendering of a diagnosis (clipboard + `.txt` export).
class ReportFormatter {
  const ReportFormatter._();

  static String diagnosis(AnalyzedPanic panic, {IPhoneDevice? device}) {
    final r = panic.result;
    final p = panic.report;
    final b = StringBuffer()
      ..writeln('iPaniX diagnostic report')
      ..writeln('=' * 40)
      ..writeln()
      ..writeln(r.title)
      ..writeln('Severity: ${r.severity.label}')
      ..writeln('Confidence: ${r.confidence.label}')
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

    list('Suspected components:', r.suspectedComponents);
    list('Possible causes:', r.possibleCauses);
    list('Recommended actions:', r.recommendedActions);

    b
      ..writeln()
      ..writeln('Technical details:');
    void row(String k, String? v) {
      if (v == null || v.isEmpty) return;
      b.writeln('  ${k.padRight(14)}$v');
    }

    row('Device', p.product ?? device?.productType);
    row('Model', marketingNameFor(p.product ?? device?.productType));
    row('iOS', p.osVersion ?? device?.productVersion);
    row('Build', p.build ?? device?.buildVersion);
    row('Date', panic.date?.toString());
    row('Bug type', p.bugType);
    row(
      'Sensor mask',
      p.sensorMask == null ? null : '${p.sensorMaskHex} (${p.sensorMask})',
    );
    row('SMC keys', p.sensorKeys.isEmpty ? null : p.sensorKeys.join(', '));
    row(
      'Missing',
      p.missingSensors.isEmpty ? null : p.missingSensors.join(', '),
    );
    row('Initiator', p.panicInitiator);
    row('Panicked', p.panickedProcess);
    row('Kexts', p.backtraceKexts.isEmpty ? null : p.backtraceKexts.join(', '));
    row('Panic flags', p.panicFlags);
    row('Kernel', p.kernelVersion);
    row('SoC', p.socId);
    row('Incident', p.incident);
    row('File', panic.file.name);
    row('Rule', r.matchedRuleId);
    row('Matched on', r.evidence.isEmpty ? null : r.evidence.join(' | '));
    if (r.rawCodes.isNotEmpty) row('Codes', r.rawCodes.join(' | '));
    if (p.hasPanicString) {
      b
        ..writeln()
        ..writeln('Panic string:')
        ..writeln(p.panicString!.trim());
    }
    b
      ..writeln()
      ..writeln('All diagnostic processing was performed locally on this Mac.');
    return b.toString();
  }
}
