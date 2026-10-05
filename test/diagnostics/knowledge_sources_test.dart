import 'package:flutter_test/flutter_test.dart';
import 'package:ipanicx/diagnostics/panic_analyzer.dart';
import 'package:ipanicx/diagnostics/panic_parser.dart';
import 'package:ipanicx/l10n/strings.dart';
import 'package:ipanicx/models/diagnostic_result.dart';
import 'package:ipanicx/models/panic_report.dart';

import '../helpers.dart';

/// Per-model SMC mask table, missing-sensor decoding and the signatures
/// taken from public repair references (iFixit, iPad Rehab).
void main() {
  final kb = loadKnowledgeBase();
  final analyzer = PanicAnalyzer(kb);
  const parser = PanicParser();

  /// The SMC sample with another product and sensor mask.
  PanicReport smc(String product, int mask) => parser.parse(
    loadSample(
      smcSample,
    ).replaceAll('iPhone15,2', product).replaceAll('1310720', '$mask'),
  );

  /// A minimal panic-full whose panic string is [panic].
  PanicReport panic(String panic, {String product = 'iPhone14,5'}) {
    final escaped = panic.replaceAll('\n', r'\n').replaceAll('"', r'\"');
    return parser.parse(
      '{"bug_type":"210","timestamp":"2026-10-01 10:00:00.00 +0200",'
      '"os_version":"iPhone OS 18.6 (22G86)"}\n'
      '{"product":"$product","bug_type":"210",'
      '"panicString":"$escaped"}',
    );
  }

  test('table, parts and sources load without warnings', () {
    expect(kb.warnings, isEmpty);
    expect(kb.smcMasks.length, greaterThanOrEqualTo(7));
    expect(kb.sources.keys, containsAll(['ifixit_smc', 'ipadrehab']));
    for (final m in kb.smcMasks) {
      for (final c in m.codes) {
        expect(kb.parts, contains(c.part), reason: '${m.model} ${c.mask}');
        expect(c.sources, isNotEmpty, reason: '${m.model} ${c.mask}');
        for (final s in c.sources) {
          expect(kb.sources, contains(s));
        }
      }
    }
    for (final r in kb.rules) {
      for (final s in r.sources) {
        expect(kb.sources, contains(s), reason: r.id);
      }
    }
  });

  group('decodeSmcMask', () {
    List<String> parts(String product, int mask) => [
      for (final c in kb.decodeSmcMask(product, mask)!.hits) c.part,
    ];

    test('exact codes', () {
      expect(parts('iPhone14,5', 0x800), ['chargePort']);
      expect(parts('iPhone14,7', 0x400000), ['coil']);
      expect(parts('iPhone16,2', 0x300000), ['chargePort']);
      expect(parts('iPhone17,1', 3145728), ['chargePort']);
      expect(parts('iPhone14,4', 0x400), ['gyro']);
    });

    test('combined codes are split bit by bit', () {
      expect(parts('iPhone14,2', 0x1800), ['chargePort', 'frontSensor']);
      expect(parts('iPhone15,3', 0x1c0000), [
        'chargePort',
        'frontSensor',
        'powerFlex',
      ]);
      // 15 Pro: the two-bit charge port code is taken first.
      expect(parts('iPhone16,1', 0x700000), ['chargePort', 'coil']);
      final d = kb.decodeSmcMask('iPhone15,2', 0x140000)!;
      expect(d.confidence, Confidence.high);
      expect(d.unknownBits, 0);
    });

    test('exact-only battery code wins, overlapping reading kept', () {
      final d = kb.decodeSmcMask('iPhone14,7', 0x500000)!;
      expect(d.hits.single.part, 'battery');
      expect(d.alternative.map((c) => c.part), ['chargePort', 'coil']);
      expect(d.confidence, Confidence.medium);
      // Never used to split another mask.
      expect(parts('iPhone14,7', 0x700000), [
        'chargePort',
        'frontSensor',
        'coil',
      ]);
    });

    test('unknown bits are reported, never guessed', () {
      final d = kb.decodeSmcMask('iPhone15,2', 0x140001)!;
      expect(d.hits.map((c) => c.part), ['chargePort', 'powerFlex']);
      expect(d.unknownBits, 0x1);
      expect(d.confidence, Confidence.medium);
      final none = kb.decodeSmcMask('iPhone15,2', 0x8)!;
      expect(none.isMapped, isFalse);
    });

    test('confidence follows the sources', () {
      // iPad Rehab + workshop data agree on 0x4000; iFixit alone on 0x40000.
      expect(
        kb.decodeSmcMask('iPhone14,5', 0x4000)!.confidence,
        Confidence.high,
      );
      expect(
        kb.decodeSmcMask('iPhone14,5', 0x40000)!.confidence,
        Confidence.low,
      );
      // 15 Pro proximity: sources disagree (0x100000 / 0x200000).
      expect(
        kb.decodeSmcMask('iPhone16,1', 0x200000)!.confidence,
        Confidence.medium,
      );
    });

    test('workshop combinations decode as listed', () {
      expect(parts('iPhone14,8', 0x600000), ['frontSensor', 'coil']);
      expect(parts('iPhone16,2', 0x600000), ['frontSensor', 'coil']);
      expect(parts('iPhone16,2', 0x700000), ['chargePort', 'coil']);
      expect(parts('iPhone15,3', 0x180000), ['frontSensor', 'powerFlex']);
      expect(parts('iPhone15,2', 0x20000), ['gyro']);
    });

    test('models outside the table and zero masks give nothing', () {
      expect(kb.decodeSmcMask('iPhone12,1', 0x800), isNull);
      expect(kb.decodeSmcMask(null, 0x800), isNull);
      expect(kb.decodeSmcMask('iPhone14,5', 0), isNull);
    });
  });

  group('analyzer with the table', () {
    test('generic SMC rule names the parts of the model', () {
      final r = analyzer.analyze(smc('iPhone14,7', 0x300000));
      expect(r.matchedRuleId, 'smc_bsc_generic');
      expect(r.suspectedComponents, [
        'Charging Port Flex',
        'Front Sensor (Proximity) Flex',
      ]);
      expect(r.confidence, Confidence.high);
      expect(r.technicalReason, contains('0x200000 → Front Sensor'));
      expect(r.summary, contains('Charging Port Flex'));
      expect(r.evidence, contains('SMC mask table: iPhone 14 / 14 Plus'));
      expect(r.sources.join(), contains('ifixit.com'));
      expect(r.sources.join(), contains('rossmanngroup.com'));
    });

    test('in French', () {
      final fr = PanicAnalyzer(kb, lang: AppLang.fr);
      final r = fr.analyze(smc('iPhone16,1', 0x300000));
      expect(r.suspectedComponents, ['Nappe du connecteur de charge']);
      expect(r.technicalReason, contains('Sur iPhone 15 Pro / 15 Pro Max'));
    });

    test('unreferenced mask keeps the generic texts and says so', () {
      final r = analyzer.analyze(smc('iPhone15,2', 0x8));
      expect(r.confidence, Confidence.medium);
      expect(r.technicalReason, contains('not referenced for iPhone 14 Pro'));
    });

    test('missing sensors name their parts', () {
      final r = analyzer.analyze(
        panic(
          'userspace watchdog timeout: no successful checkins from '
          'thermalmonitord. Missing sensor(s): mic2 TB0V',
        ),
      );
      expect(r.matchedRuleId, 'thermalmonitord_missing_sensor');
      expect(r.suspectedComponents.first, contains('Power Button Flex'));
      expect(r.suspectedComponents.last, 'Battery (gas gauge)');
      expect(r.confidence, Confidence.high);
    });

    test('an unreferenced missing sensor keeps medium confidence', () {
      final r = analyzer.analyze(
        panic(
          'userspace watchdog timeout: no successful checkins from '
          'thermalmonitord. Missing sensor(s): TG0B XYZ9',
        ),
      );
      expect(r.confidence, Confidence.medium);
      expect(r.technicalReason, contains('XYZ9'));
    });
  });

  group('signatures from public references', () {
    final cases = {
      'apcie: link down (wlan)': 'apcie_wlan',
      'apcie[0]: link down': 'apcie_nand',
      'nvme: command timeout': 'nand_nvme',
      'ANS Recoverabe Panic - assert': 'nand_storage_generic',
      'WKDMD decompression failed': 'wkdm_memory',
      'WDT timeout: 0x1': 'wdt_timeout',
      'AppleCS42L75Audio::timeout': 'audio_codec_cs42l75',
      'LLC Bus error at 0x2': 'llc_bus_error',
      'AOP PANIC - unexpected i2c timeout': 'aop_i2c_timeout',
      'AOP PANIC - no pulse on vibe': 'aop_no_pulse',
      'AOP PANIC - SCMto:0 - prox': 'aop_prox',
      'AOP PANIC - Systick Watchdog2 not pet': 'aop_systick',
      'AOP DATA ABORT at pc 0x1': 'aop_data_abort',
      'SMC DATA ABORT at pc 0x1': 'smc_data_abort',
      'AppleTriStar2: unexpected status': 'tristar',
      'SCL display PMU timeout': 'display_pmu',
      "Can't find valid timing element for display": 'display_timing',
      'PMP NMI FIQ': 'pmp_nmi_fiq',
      'DCP PANIC - assert': 'dcp_panic',
      'could not authenticate personalized root hash': 'root_hash_auth',
      'userspace watchdog timeout: no successful checkins from '
              'com.apple.thermalmonitord':
          'thermalmonitord_checkin',
      'AOP PANIC - NMI POWER asserted': 'aop_nmi_power',
      'AOP PANIC - K2 - Bosch control channel write failure': 'aop_bosch_audio',
      'AppleSocHot: Hot Hot Hot': 'soc_hot',
      'SEP ROM boot panic: SEPROM failed': 'sep_rom',
      'i2c0::_doTransaction timeout, device 0x39 (ALS)': 'i2c_bus_generic',
      'Undefined kernel instruction: pc=0xfffffff0':
          'undefined_kernel_instruction',
      'userspace watchdog timeout: missing gas gauge temperature service':
          'battery_gas_gauge',
      'AppleBCMWLANCore::trap: firmware trap': 'wlan_generic',
    };
    for (final e in cases.entries) {
      test(e.value, () {
        final r = analyzer.analyze(panic(e.key));
        expect(r.matchedRuleId, e.value);
        expect(r.sources, isNotEmpty);
        final fr = PanicAnalyzer(kb, lang: AppLang.fr).analyze(panic(e.key));
        expect(fr.title, isNot(r.title), reason: 'French title');
      });
    }

    test('iPad Pro 10.5 watchdog points to the display', () {
      expect(
        analyzer
            .analyze(
              panic(
                'userspace watchdog timeout: no successful checkins from '
                'backboardd',
                product: 'iPad7,3',
              ),
            )
            .matchedRuleId,
        'ipad_watchdog_lcd',
      );
    });

    test('I²C bus is decoded with the chips of the model', () {
      final r = analyzer.analyze(
        panic('i2c1::_doTransaction timeout', product: 'iPhone9,3'),
      );
      expect(r.matchedRuleId, 'i2c_bus_generic');
      expect(r.suspectedComponents, ['Chips on i2c1: U1801 / U2101 / U4601']);
      expect(r.technicalReason, contains('iPhone 7 / 7 Plus'));
      expect(r.sources.join(), contains('Workshop data'));
      // iPhone X: shared 8/X bus table plus the X-only i2c3.
      final x = analyzer.analyze(
        panic('i2c3::_doTransaction timeout', product: 'iPhone10,3'),
      );
      expect(x.suspectedComponents.single, contains('J4500 (Face ID)'));
      // Model outside the table: generic texts.
      final other = analyzer.analyze(
        panic('i2c1::_doTransaction timeout', product: 'iPhone14,5'),
      );
      expect(other.suspectedComponents.single, contains('model-specific'));
    });

    test('mic-temp-sens names are mapped', () {
      final r = analyzer.analyze(
        panic(
          'userspace watchdog timeout: no successful checkins from '
          'thermalmonitord. Missing sensor(s): mic-temp-sens1',
        ),
      );
      expect(r.suspectedComponents.single, contains('Charging Port Flex'));
      expect(r.confidence, Confidence.high);
    });

    test('an AOP i2c panic stays an AOP sensor panic', () {
      final r = analyzer.analyze(panic('AOP PANIC - i2c timeout on sensor'));
      expect(r.matchedRuleId, 'aop_sensorhub_generic');
    });
  });
}
