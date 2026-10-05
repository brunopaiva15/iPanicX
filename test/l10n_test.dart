import 'package:flutter_test/flutter_test.dart';
import 'package:ipanicx/diagnostics/panic_analyzer.dart';
import 'package:ipanicx/diagnostics/panic_parser.dart';
import 'package:ipanicx/diagnostics/report_formatter.dart';
import 'package:ipanicx/l10n/strings.dart';
import 'package:ipanicx/models/diagnostic_file.dart';
import 'package:ipanicx/models/scan_result.dart';
import 'package:ipanicx/ui/format.dart';

import 'helpers.dart';

void main() {
  final kb = loadKnowledgeBase();
  const parser = PanicParser();
  tearDown(() => L10n.lang = AppLang.en);

  test('system locale picks the language', () {
    expect(AppLang.fromLocale('fr_FR'), AppLang.fr);
    expect(AppLang.fromLocale('fr-CA'), AppLang.fr);
    expect(AppLang.fromLocale('en_US'), AppLang.en);
    expect(AppLang.fromLocale('de_DE'), AppLang.en);
    expect(AppLang.fromLocale(null), AppLang.en);
  });

  test('every knowledge-base rule has a French title and summary', () {
    for (final r in kb.rules) {
      final fr = r.textFor(AppLang.fr);
      expect(fr.title, isNot(r.title), reason: r.id);
      expect(fr.summary, isNot(r.summary), reason: r.id);
    }
  });

  test('French diagnosis for the SMC example', () {
    final r = PanicAnalyzer(
      kb,
      lang: AppLang.fr,
    ).analyze(parser.parse(loadSample(smcSample)));
    expect(r.matchedRuleId, 'smc_bsc_iphone15_2_140000');
    expect(r.title, 'Panne de capteur SMC');
    expect(r.suspectedComponents, [
      'Nappe du connecteur de charge',
      'Nappe du bouton d’alimentation',
    ]);
    expect(r.disclaimer, contains('inspection matérielle'));
    expect(r.evidence, contains('Appareil iPhone15,2'));
    expect(r.evidence, contains('Masque capteur 0x140000'));
  });

  test('French texts for an unknown signature', () {
    final r = PanicAnalyzer(
      kb,
      lang: AppLang.fr,
    ).analyze(parser.parse(loadSample(unknownSample)));
    expect(r.isKnownSignature, isFalse);
    expect(r.title, 'Panic matériel inconnu');
    expect(r.recommendedActions.first, startsWith('Examinez'));
  });

  test('missing French fields fall back to English', () {
    final rule = kb.rules.first;
    expect(rule.textFor(AppLang.en).title, rule.title);
  });

  test('text report and dates follow the active language', () {
    L10n.lang = AppLang.fr;
    final report = parser.parse(loadSample(smcSample));
    final text = ReportFormatter.diagnosis(
      AnalyzedPanic(
        file: DiagnosticFile.fromPath(
          path: '/tmp/$smcSample',
          rootDirectory: '/tmp',
          sizeBytes: 1,
        ),
        report: report,
        result: PanicAnalyzer(kb, lang: AppLang.fr).analyze(report),
      ),
    );
    expect(text, startsWith('Rapport de diagnostic iPanicX'));
    expect(text, contains('Gravité : Élevée'));
    expect(text, contains('Composants suspectés :'));
    expect(text, contains('effectué localement'));

    final now = DateTime(2026, 10, 5, 12);
    expect(
      formatRelativeDate(DateTime(2026, 10, 5, 9, 7), now: now),
      'Aujourd’hui, 09:07',
    );
    expect(
      formatRelativeDate(DateTime(2026, 8, 3, 9, 7), now: now),
      '3 août 2026, 09:07',
    );
  });
}
