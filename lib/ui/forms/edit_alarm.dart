// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:nmea_dashboard/state/alarms.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/specs.dart';
import 'package:nmea_dashboard/ui/forms/abstract.dart';
import 'package:provider/provider.dart';

/// A function called on successful creation/update of an AlarmSpec.
typedef SaveAlarmFunction = void Function(AlarmSpec spec);

AlarmSpec _defaultSpec() {
  return AlarmSpec('', Source.network.name, '', '', AlarmComparison.below.name, 0.0);
}

/// A form that lets the user edit a single alarm.
class EditAlarmPage extends StatefulFormPage {
  EditAlarmPage({AlarmSpec? spec, required SaveAlarmFunction onSave, super.key})
    : super(title: 'Edit alarm', child: _EditAlarmForm(spec, onSave));
}

class _EditAlarmForm extends StatefulWidget {
  final SaveAlarmFunction _onSave;
  final AlarmSpec _spec;

  _EditAlarmForm(AlarmSpec? spec, this._onSave) : _spec = spec ?? _defaultSpec();

  @override
  State<_EditAlarmForm> createState() => _EditAlarmFormState();
}

class _EditAlarmFormState extends StatefulFormState<_EditAlarmForm> {
  late DataSet _dataSet;
  late String _name;
  Source? _source;
  String? _element;
  String? _format;
  AlarmComparison _comparison = AlarmComparison.below;
  double _threshold = 0.0;
  bool _audible = false;
  bool _enabled = true;

  @override
  void initState() {
    _name = widget._spec.name;
    _source = Source.fromString(widget._spec.source);
    _element = widget._spec.element;
    _format = widget._spec.format;
    _comparison = AlarmComparison.fromString(widget._spec.comparison) ?? AlarmComparison.below;
    _threshold = widget._spec.threshold;
    _audible = widget._spec.audible;
    _enabled = widget._spec.enabled;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _dataSet = Provider.of<DataSet>(context);
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
                _buildNameField(),
                _buildSourceField(),
                _buildElementField(),
                _buildFormatField(),
                Row(
                  children: [
                    Expanded(child: _buildComparisonField()),
                    const SizedBox(width: 20),
                    SizedBox(width: 170, child: _buildThresholdField()),
                  ],
                ),
                _buildAudibleSwitch(),
                _buildEnabledSwitch(),
                if (_audible) _buildAudibleNotice(context),
              ],
            ),
          ),
          buildSaveButton(
            postSaver: () {
              final spec = AlarmSpec(
                _name,
                _source?.name ?? '',
                _element ?? '',
                _format ?? '',
                _comparison.name,
                _threshold,
                audible: _audible,
                enabled: _enabled,
                key: widget._spec.key,
              );
              widget._onSave(spec);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  /// Clears any internal fields that are now inconsistent given the present
  /// value of higher level fields.
  void _wipeInvalidFields() {
    final element = _dataSet.sources[_source]?[_element];
    if (element == null) {
      _element = null;
    }
    final formatters = element == null
        ? const <String, Formatter>{}
        : formattersFor(element.property.dimension);
    if (formatters[_format] is! NumericFormatter) {
      _format = null;
    }
  }

  Widget _buildNameField() {
    return buildTextField(
      label: 'Name',
      initialValue: _name,
      keyboardType: TextInputType.text,
      maxLength: 30,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Name must not be empty';
        }
        return null;
      },
      onSaved: (value) {
        if (value != null) _name = value;
      },
    );
  }

  Widget _buildSourceField() {
    final selectableSources = Source.values.where((source) => source.selectable).toList();
    return buildDropdownBox(
      label: 'Source',
      items: selectableSources
          .map((source) => DropdownEntry(value: source, text: source.longName))
          .toList(),
      initialValue: selectableSources.contains(_source) ? _source : null,
      onChanged: (Source? value) {
        setState(() {
          _source = value;
          _wipeInvalidFields();
        });
      },
      validator: (value) => value == null ? 'Source must be set' : null,
    );
  }

  Widget _buildElementField() {
    final Map<String, DataElement> elements = _dataSet.sources[_source] ?? {};
    final eligible = elements.entries
        .where((entry) => formattersFor(entry.value.property.dimension).values.any((f) => f is NumericFormatter))
        .toList();

    return buildDropdownBox(
      label: 'Element',
      items: eligible
          .map((entry) => DropdownEntry(value: entry.key, text: entry.value.longName))
          .toList(),
      initialValue: elements.containsKey(_element) ? _element : null,
      onChanged: (String? value) {
        setState(() {
          _element = value;
          _wipeInvalidFields();
        });
      },
      validator: (value) => value == null ? 'Element must be set' : null,
    );
  }

  Widget _buildFormatField() {
    final dimension = _dataSet.sources[_source]?[_element]?.property.dimension;
    final eligible = formattersFor(dimension).entries.where((e) => e.value is NumericFormatter);

    return buildDropdownBox(
      label: 'Threshold units',
      items: eligible
          .map((entry) => DropdownEntry(value: entry.key, text: entry.value.longName))
          .toList(),
      initialValue: eligible.any((e) => e.key == _format) ? _format : null,
      onChanged: (String? value) {
        setState(() {
          _format = value;
        });
      },
      validator: (value) => value == null ? 'Units must be set' : null,
    );
  }

  Widget _buildComparisonField() {
    return buildDropdownBox(
      label: 'Trigger when',
      items: AlarmComparison.values
          .map((c) => DropdownEntry(value: c, text: c.name))
          .toList(),
      initialValue: _comparison,
      onChanged: (AlarmComparison? value) {
        setState(() {
          if (value != null) _comparison = value;
        });
      },
    );
  }

  Widget _buildThresholdField() {
    return buildTextField(
      initialValue: _threshold.toString(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      maxLength: 10,
      validator: (value) =>
          double.tryParse(value ?? '') == null ? 'Must be a valid number' : null,
      onSaved: (value) {
        if (value != null) _threshold = double.parse(value);
      },
    );
  }

  Widget _buildAudibleSwitch() {
    return buildSwitch(
      label: 'Audible',
      initialValue: _audible,
      onChanged: (val) => setState(() => _audible = val),
      onSaved: (val) {
        if (val != null) _audible = val;
      },
    );
  }

  Widget _buildEnabledSwitch() {
    return buildSwitch(
      label: 'Enabled',
      initialValue: _enabled,
      onChanged: (val) => setState(() => _enabled = val),
      onSaved: (val) {
        if (val != null) _enabled = val;
      },
    );
  }

  Widget _buildAudibleNotice(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Audible alarms only sound while the app is in the foreground and the '
        'screen is on.',
        style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.tertiary),
      ),
    );
  }
}
