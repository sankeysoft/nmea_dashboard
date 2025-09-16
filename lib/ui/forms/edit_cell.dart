// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/settings.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/specs.dart';
import 'package:nmea_dashboard/ui/forms/abstract.dart';
import 'package:provider/provider.dart';

/// A form that lets the user edit a data cell.
class EditCellPage extends StatefulFormPage {
  EditCellPage({required DataCellSpec spec, super.key})
    : super(
        title: 'Edit cell',
        actions: [const HelpButton('help_edit_cell.md')],
        child: _EditCellForm(spec: spec),
      );
}

/// The stateful form itself
class _EditCellForm extends StatefulWidget {
  final DataCellSpec spec;
  const _EditCellForm({required this.spec});

  @override
  State<_EditCellForm> createState() => _EditCellFormState();
}

class _CellTypeAndAssociatedFields {
  final CellType? type;
  final StatsInterval? statsInterval;
  final HistoryInterval? historyInterval;

  _CellTypeAndAssociatedFields(this.type, this.statsInterval, this.historyInterval);

  @override
  bool operator ==(Object other) =>
      other is _CellTypeAndAssociatedFields &&
      other.type == type &&
      other.statsInterval == statsInterval &&
      other.historyInterval == historyInterval;

  @override
  int get hashCode => Object.hash(type, statsInterval, historyInterval);
}

class _EditCellFormState extends StatefulFormState<_EditCellForm> {
  late DataSet _dataSet;
  late PageSettings _pageSettings;

  Source? _source;
  String? _element;
  String? _format;
  CellType? _type;
  StatsInterval? _statsInterval;
  HistoryInterval? _historyInterval;
  bool _isNameOverridden = false;
  final _nameController = TextEditingController();

  @override
  void initState() {
    _source = Source.fromString(widget.spec.source);
    // Derived elements don't have complile-time definitions, so don't sanitize element yet.
    _element = widget.spec.element;
    // We can't validate the format until we've get a dataSet to supply the dimension for any
    // derived data elements.
    _format = widget.spec.format;
    _type = CellType.fromString(widget.spec.type);
    _statsInterval = StatsInterval.fromString(widget.spec.statsInterval);
    _historyInterval = HistoryInterval.fromString(widget.spec.historyInterval);
    _isNameOverridden = (widget.spec.name != null);
    if (widget.spec.name != null) {
      _nameController.text = widget.spec.name!;
    } else {
      // Building the name field will update this to reflect the property.
      _nameController.text = '';
    }
    super.initState();
  }

  // Clears any internal fields that are now inconsistent given the present
  // value of higher level fields.
  void _wipeInvalidFields() {
    final dataElement = _dataSet.sources[_source]?[_element];
    if (dataElement == null) {
      _element = null;
    }

    if (_type == CellType.average && dataElement is! WithStats) {
      _type = null;
    }
    if (_type == CellType.history && dataElement is! WithHistory) {
      _type = null;
    }

    final dimension = dataElement?.property.dimension;
    if (!formattersFor(dimension).keys.contains(_format)) {
      _format = null;
    }
    if (_type == CellType.history && formattersFor(dimension)[_format] is! NumericFormatter) {
      _format = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _dataSet = Provider.of<DataSet>(context);
    _pageSettings = Provider.of<PageSettings>(context);

    _wipeInvalidFields();

    return Form(
      key: formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildSourceField(),
                _buildElementField(),
                _buildTypeField(),
                _buildFormatField(),
                _buildOverrideNameField(),
                _buildNameField(),
              ],
            ),
          ),
          buildSaveButton(
            postSaver: () {
              // By this stage all the fields will have saved back to our state
              // and we can be confident all the fields are populated. Just
              // create a new spec from these (reusing the previous key) and ask
              // the settings to use it.
              final cellSpec = DataCellSpec(
                _source?.name ?? '',
                _element ?? '',
                _type?.name ?? '',
                _format ?? '',
                name: _isNameOverridden ? _nameController.text : null,
                statsInterval: _statsInterval?.name,
                historyInterval: _historyInterval?.name,
                key: widget.spec.key,
              );
              _pageSettings.updateCell(cellSpec);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSourceField() {
    final selectableSources = Source.values.where((source) => source.selectable).toSet();
    return buildDropdownBox(
      label: 'Source',
      items: selectableSources.map((source) {
        return DropdownEntry(value: source, text: source.longName);
      }).toList(),
      initialValue: selectableSources.lookup(_source),
      onChanged: (Source? value) {
        setState(() {
          _source = value;
          _wipeInvalidFields();
        });
      },
    );
  }

  Widget _buildElementField() {
    final dataSet = Provider.of<DataSet>(context);
    final Map<String, DataElement> elements = dataSet.sources[_source] ?? {};

    return buildDropdownBox(
      label: 'Element',
      items: elements.keys
          .map((e) => DropdownEntry(value: e, text: elements[e]!.longName))
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
          return 'Property must be set';
        }
        return null;
      },
    );
  }

  Widget _buildTypeField() {
    final List<DropdownEntry<_CellTypeAndAssociatedFields>> entries = [
      DropdownEntry(
        value: _CellTypeAndAssociatedFields(CellType.current, null, null),
        text: CellType.current.longName,
      ),
    ];
    if (_dataSet.sources[_source]?[_element] is WithStats) {
      entries.addAll(
        StatsInterval.values.map(
          (s) => DropdownEntry(
            value: _CellTypeAndAssociatedFields(CellType.average, s, null),
            text: 'Average - ${s.display}',
          ),
        ),
      );
    }
    if (_dataSet.sources[_source]?[_element] is WithHistory) {
      entries.addAll(
        HistoryInterval.values.map(
          (h) => DropdownEntry(
            value: _CellTypeAndAssociatedFields(CellType.history, null, h),
            text: 'History - ${h.display}',
          ),
        ),
      );
    }
    final intended = _CellTypeAndAssociatedFields(_type, _statsInterval, _historyInterval);

    return buildDropdownBox(
      label: 'Display',
      items: entries,
      initialValue: entries.map((e) => e.value).toSet().contains(intended) ? intended : null,
      onChanged: (_CellTypeAndAssociatedFields? value) {
        setState(() {
          _type = value?.type;
          _statsInterval = value?.statsInterval;
          _historyInterval = value?.historyInterval;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Type must be set';
        }
        return null;
      },
    );
  }

  Widget _buildFormatField() {
    final dimension = _dataSet.sources[_source]?[_element]?.property.dimension;
    final Map<String, Formatter> eligibleFormatters = formattersFor(dimension);

    return buildDropdownBox(
      label: 'Format',
      items: eligibleFormatters.entries
          .map((entry) => DropdownEntry(value: entry.key, text: entry.value.longName))
          .toList(),
      initialValue: eligibleFormatters.keys.contains(_format) ? _format : null,
      onChanged: (String? value) {
        setState(() {
          _format = value;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Format must be set';
        }
        return null;
      },
    );
  }

  Widget _buildOverrideNameField() {
    return buildSwitch(
      label: 'Set manual name:',
      initialValue: _isNameOverridden,
      onChanged: (value) {
        setState(() {
          _isNameOverridden = value;
        });
      },
    );
  }

  Widget _buildNameField() {
    final enabled = _isNameOverridden;
    // If we're not overriding the name update the text to reflect the
    // current elementName.
    final element = _dataSet.sources[_source]?[_element];

    if (!_isNameOverridden) {
      if (_historyInterval != null && element != null) {
        _nameController.text = _historyInterval!.shortCellName(element);
      } else {
        _nameController.text = element?.shortName ?? '';
      }
    }
    return buildTextField(
      label: 'Name',
      enabled: enabled,
      controller: _nameController,
      maxLength: 20,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Name must not be empty';
        }
        return null;
      },
    );
  }
}
