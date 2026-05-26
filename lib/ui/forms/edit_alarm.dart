// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nmea_dashboard/state/alarms.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/settings/format.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/state/values.dart';
import 'package:nmea_dashboard/ui/forms/abstract.dart';
import 'package:provider/provider.dart';

const _defaultLevel = AlarmLevel.warning;
final _numberFormat = NumberFormat("0.##");

AlarmSpec _createDefaultSpec() {
  return AlarmSpec('network', '', AlarmLevel.caution.name, '');
}

/// A function called on successful creation or update of an AlarmSpec.
typedef CreateAlarmFunction = void Function(AlarmSpec spec);

/// A form that lets the user edit a single alarm.
class EditAlarmPage extends StatefulFormPage {
  EditAlarmPage({AlarmSpec? spec, required CreateAlarmFunction onCreate, super.key})
    : super(
        title: 'Edit alarm',
        actions: [const HelpButton('edit_alarm.md')],
        child: _EditAlarmForm(spec, onCreate),
      );
}

class _EditAlarmForm extends StatefulWidget {
  final CreateAlarmFunction _onCreate;
  final AlarmSpec _spec;

  _EditAlarmForm(AlarmSpec? spec, this._onCreate) : _spec = spec ?? _createDefaultSpec();

  @override
  State<_EditAlarmForm> createState() => _EditAlarmFormState();
}

class _EditAlarmFormState extends StatefulFormState<_EditAlarmForm> {
  late DataSet _dataSet;
  late FormatPreferences _formatPrefs;

  Source? _source;
  Group? _group;
  String? _element;
  AlarmLevel _level = _defaultLevel;
  StatsInterval? _averagingInterval;
  String? _format;
  NumericFormatter? _formatter;
  String? _sound;
  final _minController = TextEditingController();
  final _maxController = TextEditingController();

  @override
  void initState() {
    final spec = widget._spec;
    _source = Source.fromString(spec.source);
    // Init group to null, will set from dataSet in build if relevant.
    _group = null;
    // Derived elements don't have complile-time definitions, so don't sanitize element yet.
    _element = spec.element;
    _level = AlarmLevel.values.asNameMap()[spec.type] ?? _defaultLevel;
    _averagingInterval = StatsInterval.fromString(spec.averagingInterval);
    // We can't validate the format until we've get a dataSet to supply the dimension for any
    // derived data elements.
    _format = spec.format;
    _formatter = null;
    // The spec was stored in the same units as formatter so set the text boxes now even though
    // we haven't validated the format.
    _minController.text = spec.min == null ? '' : _numberFormat.format(spec.min);
    _maxController.text = spec.max == null ? '' : _numberFormat.format(spec.max);
    // TODO(alarms): Validate the sound string.
    _sound = widget._spec.sound;
    super.initState();
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  // Clears any internal fields that are now inconsistent given the present value of higher level
  // fields. For format we return to the user's prefered default for the dimension.
  void _wipeInvalidFields() {
    // Clear the data element if its not known on this source or is not in the correct group.
    var dataElement = _dataSet.sources[_source]?[_element];
    if (dataElement == null || _source == null) {
      dataElement = null;
      _element = null;
    } else if (_source!.usesGrouping() && dataElement.property.group != _group) {
      dataElement = null;
      _element = null;
    }

    // Clear the format if there isn't a data element. Set the default format for the dimension
    // if the current format is not valid for the element. In either case the values are probably
    // misleading so clear them
    final dimension = dataElement?.property.dimension;
    if (dimension == null) {
      _format = null;
      _formatter = null;
      _minController.text = '';
      _maxController.text = '';
    } else {
      final formatters = numericFormattersFor(dimension);
      if (!formatters.keys.contains(_format)) {
        _format = _formatPrefs.forDimension(dimension.name);
        _formatter = formatters[_format];
        _minController.text = '';
        _maxController.text = '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _dataSet = Provider.of<DataSet>(context);
    _formatPrefs = Provider.of<FormatPreferences>(context);

    // Set the group from the element now we have a dataSet to do the lookup.
    final elementProperty = _dataSet.sources[_source]?[_element]?.property;
    if (elementProperty != null && _source!.usesGrouping()) {
      _group = elementProperty.group;
    }

    _wipeInvalidFields();

    return Form(
      key: formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildSourceField(),
                _buildElementField(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    SizedBox(width: 200, child: _buildAveragingIntervalField()),
                    Expanded(child: _buildFormatField()),
                  ],
                ),
                _buildMinMaxField(isMin: true),
                _buildMinMaxField(isMin: false),
                _buildLevelField(),
                _buildSoundField(),
              ],
            ),
          ),
          buildSaveButton(
            postSaver: () {
              final minText = _minController.text;
              final maxText = _maxController.text;
              final spec = AlarmSpec(
                _source?.name ?? '',
                _element ?? '',
                _level.name,
                _format ?? '',
                averagingInterval: _averagingInterval?.name,
                min: minText.isNotEmpty ? double.tryParse(minText) : null,
                max: maxText.isNotEmpty ? double.tryParse(maxText) : null,
                sound: (_level == AlarmLevel.warning) ? _sound : null,
                key: widget._spec.key,
              );

              widget._onCreate(spec);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSourceField() {
    final dataSet = Provider.of<DataSet>(context);

    Set<SourceAndGroup> sourceGroups = SourceAndGroup.set();

    return buildDropdownBox(
      label: 'Source',
      items: sourceGroups
          .where((sg) => _suitableElements(dataSet, sg.source, sg.group).isNotEmpty)
          .map((sg) => DropdownEntry(value: sg, text: sg.text))
          .toList(),
      initialValue: SourceAndGroup.lookupInSet(sourceGroups, _source, _group),
      onChanged: (SourceAndGroup? value) {
        setState(() {
          _source = value?.source;
          _group = value?.group;
          _wipeInvalidFields();
        });
      },
    );
  }

  Widget _buildElementField() {
    final dataSet = Provider.of<DataSet>(context);

    final Map<String, DataElement> elements = {};
    elements.addEntries(_suitableElements(dataSet, _source, _group));

    return buildDropdownBox(
      label: 'Element',
      items: elements.entries
          .map((e) => DropdownEntry(value: e.key, text: e.value.longName))
          .toList(),
      initialValue: _element,
      onChanged: (String? value) {
        setState(() {
          _element = value;
          _wipeInvalidFields();
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Element must be set';
        }
        return null;
      },
    );
  }

  /// Returns entries for alarm suitable elements in the selected source and group, i.e those
  /// that implement the WithAlarms mixin.
  Iterable<MapEntry<String, DataElement<Value, Value>>> _suitableElements(
    DataSet dataSet,
    Source? source,
    Group? group,
  ) {
    final sourceElements = dataSet.sources[source];
    if (sourceElements == null) {
      return {};
    }
    if (source!.usesGrouping()) {
      return sourceElements.entries.where(
        (e) => e.value.property.group == group && e.value is WithAlarms,
      );
    }
    return sourceElements.entries.where((e) => e.value is WithAlarms);
  }

  Widget _buildLevelField() {
    // TODO(alarms): Build a switcher instead
    return buildDropdownBox(
      label: 'Alarm type',
      items: AlarmLevel.values.map((t) => DropdownEntry(value: t, text: t.name)).toList(),
      initialValue: _level,
      onChanged: (AlarmLevel? value) {
        setState(() {
          if (value != null) _level = value;
        });
      },
    );
  }

  Widget _buildAveragingIntervalField() {
    final entries = [
      DropdownEntry<StatsInterval?>(value: null, text: 'Current'),
      ...StatsInterval.values.map(
        (s) => DropdownEntry<StatsInterval?>(value: s, text: "${s.short} avg"),
      ),
    ];
    return buildDropdownBox<StatsInterval?>(
      label: 'Value',
      items: entries,
      initialValue: _averagingInterval,
      onChanged: (StatsInterval? value) {
        setState(() => _averagingInterval = value);
      },
    );
  }

  Widget _buildFormatField() {
    final dimension = _dataSet.sources[_source]?[_element]?.property.dimension;
    final formatters = numericFormattersFor(dimension);

    // Initialize the formatter object variable if the format text is valid.
    _formatter = formatters[_format];

    return buildDropdownBox(
      label: null,
      items: formatters.entries
          .map((e) => DropdownEntry(value: e.key, text: e.value.longName))
          .toList(),
      initialValue: _formatter == null ? null : _format,
      onChanged: (String? value) {
        final oldFormatter = _formatter;
        final newFormatter = formatters[value];
        _formatter = newFormatter;
        // If we have old and new formatters use them to convert any valid bounds.
        if (oldFormatter != null && newFormatter != null) {
          for (final c in [_minController, _maxController]) {
            final numberOldUnits = double.tryParse(c.text);
            if (numberOldUnits != null) {
              final valueOldUnits = oldFormatter.fromNumber(numberOldUnits);
              if (valueOldUnits != null) {
                final numberNewUnits = newFormatter.toNumber(valueOldUnits);
                if (numberNewUnits != null) {
                  c.text = _numberFormat.format(numberNewUnits);
                }
              }
            }
          }
        }
        setState(() => _format = value);
      },
      validator: (value) {
        if (value == null) {
          return 'Format must be set';
        }
        return null;
      },
    );
  }

  Widget _buildMinMaxField({required bool isMin}) {
    return buildTextField(
      label: isMin ? 'Alarm below' : 'Alarm above',
      controller: isMin ? _minController : _maxController,
      alphabet: Alphabet.floatingPoint,
      maxLength: 10,
      enabled: _formatter != null,
      validator: (value) {
        // Don't complain about anything else if the format is not set - we don't have the
        // information to validate, user can't edit the field anyway, and we don't want everything
        // on the form red.
        final formatter = _formatter;
        if (formatter == null) {
          return null;
        }
        // Notify errors local to this field first.
        final valueStr = value ?? '';
        if (valueStr.isNotEmpty) {
          final num = double.tryParse(valueStr);
          if (num == null) {
            return 'Must be a valid number';
          } else if (formatter.minValue != null && num < formatter.minValue!) {
            return 'Must be ≥ ${_numberFormat.format(formatter.minValue)}';
          } else if (formatter.maxValue != null && num > formatter.maxValue!) {
            return 'Must be ≤ ${_numberFormat.format(formatter.maxValue)}';
          }
        }
        // Notify inconsistencies with the other form.
        if (isMin) {
          return _validateBoundConsistency(valueStr, _maxController.text);
        } else {
          return _validateBoundConsistency(_minController.text, valueStr);
        }
      },
    );
  }

  // Checks that the two bounds are consistently populated. For bearings bounds either side of
  // 0 could be confusing. Always require both bounds and accept whatever arc is between them.
  String? _validateBoundConsistency(String min, String max) {
    final minVal = double.tryParse(min);
    final maxVal = double.tryParse(max);
    if (_formatter?.dimension == Dimension.bearing) {
      if (min.isEmpty || max.isEmpty) {
        return 'Below and above must be set for bearings';
      } else if (minVal != null && maxVal != null && maxVal == minVal) {
        return 'Above must not equal below';
      }
    } else {
      if (min.isEmpty && max.isEmpty) {
        return 'Below and/or above must be set';
      } else if (minVal != null && maxVal != null && maxVal <= minVal) {
        return 'Above must be greater than below';
      }
    }
    return null;
  }

  Widget _buildSoundField() {
    return buildTextField(
      label: 'Sound',
      initialValue: _sound ?? '',
      alphabet: Alphabet.any,
      maxLength: 40,
      onSaved: (value) {
        _sound = (value != null && value.isNotEmpty) ? value : null;
      },
    );
  }
}
