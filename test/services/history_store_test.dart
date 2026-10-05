import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipanicx/services/history_store.dart';

void main() {
  late Directory tmp;
  late HistoryStore store;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ipanicx_history_');
    store = HistoryStore(root: Directory('${tmp.path}/h'));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  const udid = '00008120-001A2B3C4D5E6F7A';

  test('device key is stable and does not contain the UDID', () {
    final k = HistoryStore.deviceKey(udid);
    expect(k, hasLength(16));
    expect(k, HistoryStore.deviceKey(udid.toLowerCase()));
    expect(k, isNot(contains('1A2B3C')));
    expect(k, isNot(HistoryStore.deviceKey('00008110-000000000000001E')));
  });

  test('add, load, trim, count, clear', () async {
    expect(await store.load(udid), isEmpty);
    for (var i = 0; i < HistoryStore.maxEntries + 3; i++) {
      await store.add(
        udid,
        HistoryEntry(
          date: DateTime(2026, 1, 1).add(Duration(days: i)),
          panics: i,
          batteryHealth: 90 - i ~/ 10,
        ),
      );
    }
    final list = await store.load(udid);
    expect(list, hasLength(HistoryStore.maxEntries));
    expect(list.first.panics, 3);
    expect(list.last.batteryHealth, 85);
    expect(await store.count(), HistoryStore.maxEntries);
    // The file name is the hashed key, never the UDID.
    final names = tmp
        .listSync(recursive: true)
        .map((e) => e.path.split(Platform.pathSeparator).last);
    expect(names.any((n) => n.contains('1A2B3C')), isFalse);
    await store.clear();
    expect(await store.count(), 0);
  });

  test('corrupt file reads as empty, never throws', () async {
    await Directory('${tmp.path}/h').create(recursive: true);
    File(
      '${tmp.path}/h/${HistoryStore.deviceKey(udid)}.json',
    ).writeAsStringSync('{not json');
    expect(await store.load(udid), isEmpty);
    expect(await store.count(), 0);
  });
}
