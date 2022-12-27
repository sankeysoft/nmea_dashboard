// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:async';
import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/local.dart';

import 'data_element.dart';
import 'displayable.dart';
import 'network.dart';
import 'settings.dart';
import 'common.dart';

/// The default staleness. Used for non-network sources and for the network
/// until settings are read.
const _defaultStalenessDuration = Duration(seconds: 10);

/// All known elements of marine data, collected from a network, measured
/// on the current device, or derived from some other element.
class DataSet with ChangeNotifier {
  /// Network settings we can use to drive the network subscription.
  final NetworkSettings _networkSettings;

  /// Network settings we can use to drive the network subscription.
  final DerivedDataSettings _derivedDataSettings;

  /// The currently active subscription to network events.
  StreamSubscription? _networkSubscription;

  /// A single staleness provider used to notify network data elements
  /// how long to wait without updates before going invalid.
  final _networkStaleness = Staleness(_defaultStalenessDuration);

  /// A publicly assessible collections of data elements from the network.
  final Map<Source, Map<String, DataElement>> sources = {};

  DataSet(this._networkSettings, this._derivedDataSettings) {
    // Create all known data for primary sources.
    for (final source in [Source.network, Source.local]) {
      sources[source] = _createPrimaryDataElements(source);
    }
    // Create all known derived data and registed to rebuild if
    // the specs for this change.
    sources[Source.derived] = _createDerivedDataElements();
    _derivedDataSettings.addListener(() {
      sources[Source.derived] = _createDerivedDataElements();
      notifyListeners();
    });

    // Register to restart network if network settings change.
    _networkSettings.addListener(() => _collectNetworkData());
    // Start collecting data
    _collectNetworkData();
    _collectLocalData();
  }

  /// Create all known data for a primary sources, keyed by the name of the property
  /// and with special handling for variation.
  Map<String, DataElement> _createPrimaryDataElements(Source source) {
    /// Create a consistent staleness definition across the source (or reuse the member
    /// staleness for network so the value can be changed by network settings).
    final staleness = (source == Source.network)
        ? _networkStaleness
        : Staleness(_defaultStalenessDuration);

    /// Create a special data element to let all bearings on this source handle mag/true
    /// conversion. If no elements use it (e.g. source==local) it just falls out of scope.
    final variation = ConsistentDataElement<SingleValue<double>>(
        Property.variation, staleness);

    Map<String, DataElement> elementMap = {};
    for (final property in Property.values) {
      if (property.sources.contains(source)) {
        // Some special handling to pass the global variation to all bearings.
        if (property == Property.variation) {
          elementMap[property.name] = variation;
        } else if (property.dimension == Dimension.bearing) {
          elementMap[property.name] =
              BearingDataElement(variation, property, staleness);
        } else {
          elementMap[property.name] =
              ConsistentDataElement.newForProperty(property, staleness);
        }
      }
    }
    return elementMap;
  }

  /// Create all known derived data elements as a map keyed by the name.
  Map<String, DataElement> _createDerivedDataElements() {
    Map<String, DataElement> elementMap = {};

    for (final spec in _derivedDataSettings.derivedDataSpecs) {
      final source = Source.fromString(spec.inputSource);
      final inputElement = sources[source]?[spec.inputElement];
      final operation = Operation.fromString(spec.operation);
      final Formatter? formatter =
          formattersFor(inputElement?.property.dimension)[spec.inputFormat];

      // For now don't support deriving values from other values - the possibility of dependency
      // cycles makes that a fair bit more complex and with the current set of operations (and the
      // choice to describe all values with a format) there would be very few use cases.
      if (source == Source.derived) {
        log('Could not derive ${spec.name} from another derived value',
            level: Level.WARNING.value);
      } else if (inputElement == null) {
        log('Could not find ${spec.inputSource}:${spec.inputElement} to create ${spec.name}',
            level: Level.WARNING.value);
      } else if (formatter == null) {
        log('Could not find ${spec.inputFormat} format for ${inputElement.property.dimension}',
            level: Level.WARNING.value);
      } else if (operation == null) {
        log('Could not find operation ${spec.operation} to create ${spec.name}',
            level: Level.WARNING.value);
      } else if (inputElement is! DataElement<SingleValue<double>, Value>) {
        log('Could not create ${spec.name} from non-double ${spec.inputSource}:${spec.inputElement}',
            level: Level.WARNING.value);
      } else if (formatter is! SimpleFormatter) {
        log('Could not create ${spec.name} from non-simple format ${spec.inputFormat}',
            level: Level.WARNING.value);
      } else {
        elementMap[spec.name] = DerivedDataElement(
            spec.name, inputElement, formatter, operation, spec.operand);
      }
    }
    return elementMap;
  }

  /// Collects data from the network using the current network settings, cancelling
  /// any existing subscription if one exists.
  Future<void> _collectNetworkData() async {
    if (_networkSubscription != null) {
      log('Cancelling previous network subcription', level: Level.INFO.value);
      await _networkSubscription?.cancel();
      _networkSubscription = null;
    }
    // Update the staleness all elements use.
    _networkStaleness.duration = _networkSettings.staleness;
    // Push each value to the appropriate element.
    final networkElements = sources[Source.network]!;
    _networkSubscription = valuesFromNetwork(_networkSettings).listen((value) {
      // The presence of periodic null values lets us cancel this subscription but
      // we can ignore them during the processing.
      if (value != null) {
        final element = networkElements[value.property.name];
        if (element == null) {
          log('Got unrecognized network value: ${value.property}',
              level: Level.WARNING.value);
        } else {
          element.updateValue(value);
        }
      }
    });
  }

  // Start an infinite stream to keep network values up to date by listening
  // on the supplied port, returning the stream subscription.
  void _collectLocalData() {
    final localElements = sources[Source.local]!;
    log('Setting up new local value subcription');
    valuesFromLocalDevice().listen((value) {
      final element = localElements[value.property.name];
      if (element == null) {
        log('Got unrecognized local value: ${value.property}',
            level: Level.WARNING.value);
      } else {
        element.updateValue(value);
      }
    });
  }

  /// Returns a formatted view on one of the tracked data elements, or a
  /// displayable error if that could not be found.
  Displayable find(KeyedDataCellSpec spec) {
    final source = Source.fromString(spec.source);
    if (source == null) {
      if (spec.source.isNotEmpty) {
        log('Invalid spec source ${spec.source}', level: Level.WARNING.value);
      }
      return NotFoundDisplay(spec);
    } else if (source == Source.unset) {
      return UnsetDisplay(spec);
    }

    final DataElement? dataElement = sources[source]?[spec.element];
    if (dataElement == null) {
      log('Could not find ${spec.element} in source ${spec.source}',
          level: Level.WARNING.value);
      return NotFoundDisplay(spec);
    }

    final Formatter? formatter =
        formattersFor(dataElement.property.dimension)[spec.format];
    if (formatter == null) {
      log('Could not find ${spec.format} format for ${dataElement.property.dimension}',
          level: Level.WARNING.value);
      return NotFoundDisplay(spec);
    }

    return DataElementDisplay(dataElement, formatter, spec);
  }
}
