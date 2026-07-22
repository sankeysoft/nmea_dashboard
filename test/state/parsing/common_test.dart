// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/parsing/common.dart';
import 'package:nmea_dashboard/state/parsing/validators.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:test/test.dart';

import '../utils.dart';

/// A minimal MessageParser used to exercise the counting and logging behavior implemented by
/// the abstract base class, independent of any real protocol.
class _FakeParser extends MessageParser<String, String> {
  @override
  Set<String> get ignoredTypes => {'IGN'};

  @override
  Set<String> get supportedTypes => {'OK', 'EMPTY', 'ERR'};

  @override
  List<BoundValue> parse(ValidatedMessage<String, String> message) {
    switch (message.type) {
      case 'OK':
        return [boundSingleValue(1.0, Property.depthUncalibrated)];
      case 'EMPTY':
        return [];
      case 'ERR':
        throw const FormatException('simulated error');
      default:
        throw const FormatException('unexpected type in fake parser');
    }
  }
}

ValidatedMessage<String, String> _msg(String type) => ValidatedMessage(type, 'YD', 'payload');

void main() {
  group('MessageCounts', () {
    test('starts empty', () {
      final counts = MessageCounts<String>();
      expect(counts.isEmpty, isTrue);
      expect(counts.total, 0);
      expect(counts.summary, '');
    });

    test('increment tracks per-type and total counts', () {
      final counts = MessageCounts<String>();
      expect(counts.increment('A'), 1);
      expect(counts.increment('A'), 2);
      expect(counts.increment('B'), 1);
      expect(counts.isEmpty, isFalse);
      expect(counts.total, 3);
      expect(counts.summary, 'A:2, B:1');
    });

    test('clear resets counts', () {
      final counts = MessageCounts<String>();
      counts.increment('A');
      counts.clear();
      expect(counts.isEmpty, isTrue);
      expect(counts.total, 0);
    });
  });

  group('MessageParser.parseWithCounting', () {
    test('silently counts ignored messages', () {
      final parser = _FakeParser();
      expect(parser.parseWithCounting(_msg('IGN')), BoundValueListMatches([]));
      expect(parser.ignoredCounts.total, 1);
      expect(parser.unsupportedCounts.total, 0);
      expect(parser.successCounts.total, 0);
      expect(parser.emptyCounts.total, 0);
      expect(parser.errorCounts.total, 0);
    });

    test('counts unsupported messages without throwing', () {
      final parser = _FakeParser();
      expect(parser.parseWithCounting(_msg('XXX')), BoundValueListMatches([]));
      expect(parser.unsupportedCounts.total, 1);
      expect(parser.parseWithCounting(_msg('XXX')), BoundValueListMatches([]));
      expect(parser.unsupportedCounts.total, 2);
    });

    test('counts and returns successful parses', () {
      final parser = _FakeParser();
      expect(
        parser.parseWithCounting(_msg('OK')),
        BoundValueListMatches([boundSingleValue(1.0, Property.depthUncalibrated)]),
      );
      expect(parser.successCounts.total, 1);
      expect(parser.emptyCounts.total, 0);
    });

    test('counts empty parse results without throwing', () {
      final parser = _FakeParser();
      expect(parser.parseWithCounting(_msg('EMPTY')), BoundValueListMatches([]));
      expect(parser.emptyCounts.total, 1);
      expect(parser.parseWithCounting(_msg('EMPTY')), BoundValueListMatches([]));
      expect(parser.emptyCounts.total, 2);
      expect(parser.successCounts.total, 0);
    });

    test('rethrows parse errors up to five times per type then swallows them', () {
      final parser = _FakeParser();
      for (var i = 1; i <= 5; i++) {
        expect(() => parser.parseWithCounting(_msg('ERR')), throwsFormatException);
      }
      expect(parser.errorCounts.total, 5);
      expect(parser.parseWithCounting(_msg('ERR')), BoundValueListMatches([]));
      expect(parser.errorCounts.total, 6);
      expect(parser.successCounts.total, 0);
    });
  });

  group('MessageParser logging', () {
    test('logAndClearIfNeeded is a no-op before the interval elapses', () {
      _FakeParser().logAndClearIfNeeded();
    });

    test('logAndClearCounts logs the no-messages notice when all counts are zero', () {
      _FakeParser().logAndClearCounts();
    });

    test('logAndClearCounts resets all counts to zero', () {
      final parser = _FakeParser();
      parser.parseWithCounting(_msg('OK'));
      parser.parseWithCounting(_msg('EMPTY'));
      parser.parseWithCounting(_msg('IGN'));
      parser.parseWithCounting(_msg('XXX'));
      expect(() => parser.parseWithCounting(_msg('ERR')), throwsFormatException);

      parser.logAndClearCounts();

      expect(parser.successCounts.total, 0);
      expect(parser.emptyCounts.total, 0);
      expect(parser.ignoredCounts.total, 0);
      expect(parser.unsupportedCounts.total, 0);
      expect(parser.errorCounts.total, 0);
    });
  });
}
