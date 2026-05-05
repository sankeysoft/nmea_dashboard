// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmea_dashboard/state/alarm_audio.dart';
import 'package:nmea_dashboard/state/alarms.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/specs.dart';
import 'package:nmea_dashboard/state/values.dart';

final _staleness = Staleness(const Duration(seconds: 30));

class _FakeRegistry with ChangeNotifier implements AlarmRegistry {
  final List<AlarmSpec> specs = [];

  @override
  Iterable<AlarmSpec> get alarmSpecs => specs;
}

class _NoopNotifier with ChangeNotifier {}

ConsistentDataElement<SingleValue<double>> _makeDepthElement() {
  return ConsistentDataElement.newForProperty(Source.network, Property.depthWithOffset, _staleness)
      as ConsistentDataElement<SingleValue<double>>;
}

void _push(DataElement<SingleValue<double>, SingleValue<double>> element, double meters) {
  element.updateValue(BoundValue(Source.network, element.property, SingleValue(meters)));
}

AlarmSpec _depthBelowFt(double feet, {bool audible = false}) {
  return AlarmSpec(
    'Shallow',
    Source.network.name,
    Property.depthWithOffset.name,
    'feet',
    AlarmComparison.below.name,
    feet,
    audible: audible,
  );
}

void main() {
  group('AlarmAudioController', () {
    late _FakeRegistry registry;
    late _NoopNotifier dataNotifier;
    late ConsistentDataElement<SingleValue<double>> depth;
    late int playCount;

    Future<void> playStub() async {
      playCount++;
    }

    AlarmManager makeManager() {
      return AlarmManager(
        registry: registry,
        lookup: (source, name) =>
            (source == Source.network && name == Property.depthWithOffset.name) ? depth : null,
        dataNotifier: dataNotifier,
      );
    }

    AlarmAudioController makeController(AlarmManager manager, {Duration? period}) {
      return AlarmAudioController(
        manager,
        period: period ?? const Duration(milliseconds: 30),
        play: playStub,
        registerLifecycleObserver: false,
      );
    }

    setUp(() {
      registry = _FakeRegistry();
      dataNotifier = _NoopNotifier();
      depth = _makeDepthElement();
      playCount = 0;
    });

    test('starts silent when no audible alarms', () {
      final manager = makeManager();
      final controller = makeController(manager);
      addTearDown(controller.dispose);
      expect(controller.isPlaying, false);
      expect(playCount, 0);
    });

    test('plays once immediately when an audible alarm activates', () {
      registry.specs.add(_depthBelowFt(40.0, audible: true));
      final manager = makeManager();
      final controller = makeController(manager);
      addTearDown(controller.dispose);
      _push(depth, 10.0);
      expect(controller.isPlaying, true);
      expect(playCount, 1);
    });

    test('keeps playing periodically while alarm stays audible', () async {
      registry.specs.add(_depthBelowFt(40.0, audible: true));
      final manager = makeManager();
      final controller = makeController(manager);
      addTearDown(controller.dispose);
      _push(depth, 10.0);
      final before = playCount;
      await Future.delayed(const Duration(milliseconds: 100));
      expect(playCount, greaterThan(before));
    });

    test('stops when the audible alarm is silenced', () {
      final spec = _depthBelowFt(40.0, audible: true);
      registry.specs.add(spec);
      final manager = makeManager();
      final controller = makeController(manager);
      addTearDown(controller.dispose);
      _push(depth, 10.0);
      expect(controller.isPlaying, true);

      manager.silence(spec.key);
      expect(controller.isPlaying, false);
    });

    test('pauses when foreground=false, resumes when true', () {
      registry.specs.add(_depthBelowFt(40.0, audible: true));
      final manager = makeManager();
      final controller = makeController(manager);
      addTearDown(controller.dispose);
      _push(depth, 10.0);
      expect(controller.isPlaying, true);

      controller.debugSetForeground(false);
      expect(controller.isPlaying, false);

      controller.debugSetForeground(true);
      expect(controller.isPlaying, true);
    });

    test('does not play when alarm is non-audible', () {
      registry.specs.add(_depthBelowFt(40.0, audible: false));
      final manager = makeManager();
      final controller = makeController(manager);
      addTearDown(controller.dispose);
      _push(depth, 10.0);
      expect(controller.isPlaying, false);
      expect(playCount, 0);
    });
  });
}
