// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:fake_async/fake_async.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/local.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:test/test.dart';

void main() {
  group('valuesFromLocalDevice', () {
    test('emits both localTime and utcTime properties as 1/second', () {
      fakeAsync((async) {
        final events = <BoundValue>[];
        valuesFromLocalDevice().listen((v) => events.add(v));
        async.elapse(const Duration(seconds: 3));

        for (final event in events) {
          expect(event.source, Source.local);
          expect(event.tier, 1);
        }

        final localEvents = events.where((e) => e.property == Property.localTime);
        expect(localEvents.length, 3);
        for (final event in localEvents) {
          final value = event.value as SingleValue<DateTime>;
          expect(value.data.isUtc, isFalse);
        }

        final utcEvents = events.where((e) => e.property == Property.utcTime);
        expect(utcEvents.length, 3);
        for (final event in utcEvents) {
          final value = event.value as SingleValue<DateTime>;
          expect(value.data.isUtc, isTrue);
        }
      });
    });

    test('no events emitted before the first interval elapses', () {
      fakeAsync((async) {
        final events = <BoundValue>[];
        valuesFromLocalDevice().listen((v) => events.add(v));
        async.elapse(const Duration(milliseconds: 999));

        expect(events, isEmpty);
      });
    });

    test('timestamps are approximately current real time', () {
      fakeAsync((async) {
        final before = DateTime.now().toUtc();
        final events = <BoundValue>[];
        valuesFromLocalDevice().listen((v) => events.add(v));
        async.elapse(const Duration(seconds: 2));
        final after = DateTime.now().toUtc();

        for (final event in events) {
          final value = event.value as SingleValue<DateTime>;
          final ts = value.data.toUtc();
          expect(ts.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
          expect(ts.isBefore(after.add(const Duration(seconds: 1))), isTrue);
        }
      });
    });
  });
}
