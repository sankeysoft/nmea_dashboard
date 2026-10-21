// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/data_set.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/settings/clipboard.dart';
import 'package:nmea_dashboard/state/settings/format.dart';
import 'package:nmea_dashboard/state/settings/page.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
import 'package:nmea_dashboard/ui/forms/abstract.dart';
import 'package:nmea_dashboard/ui/forms/edit_alarms.dart';
import 'package:provider/provider.dart';

/// A form that lets the user edit a data cell. Defined as a basic StatelessWidget rather than
/// a StatefulFormPage to share a form key betwween the _AlarmsButton and the Form.
class EditCellPage extends StatelessWidget {
  final DataCellSpec spec;
  final _formKey = GlobalKey<_EditCellFormState>();

  EditCellPage({required this.spec, super.key});

  @override
  Widget build(BuildContext context) {
    return StatefulFormPage(
      title: 'Edit cell',
      actions: [
        _AlarmsButton(_formKey),
        CopyButton(kind: ClipboardKind.cell, getText: (_) => _formKey.currentState?.clipboardText),
        PasteButton(
          kind: ClipboardKind.cell,
          isValid: (_, text) => PageSettings.cellFromClipboard(text) != null,
          onPaste: (_, text) => _formKey.currentState?.paste(text),
        ),
        const HelpButton('edit_cell.md'),
      ],
      child: _EditCellForm(key: _formKey, spec: spec),
    );
  }
}

class _AlarmsButton extends StatelessWidget {
  final GlobalKey<_EditCellFormState> _formKey;
  const _AlarmsButton(this._formKey);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.notifications_outlined),
      onPressed: () {
        final element = _formKey.currentState?.dataElement;
        if (element != null) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (context) => EditAlarmsPage(element: element)));
        }
      },
    );
  }
}

/// The stateful form itself
class _EditCellForm extends StatefulWidget {
  final DataCellSpec spec;
  const _EditCellForm({required this.spec, super.key});

  @override
  State<_EditCellForm> createState() => _EditCellFormState();
}

class _EditCellFormState extends StatefulFormState<_EditCellForm> {
  late DataSet _dataSet;
  late PageSettings _pageSettings;
  late FormatPreferences _formatPrefs;

  Source? _source;
  Group? _group;
  String? _element;
  String? _format;
  CellType? _type;
  StatsInterval? _statsInterval;
  HistoryInterval? _historyInterval;
  bool _isNameOverridden = false;
  final _nameController = TextEditingController();
  // Incremented on each paste to force all fields to rebuild from the new state.
  int _pasteCount = 0;

  @override
  void initState() {
    _loadSpec(widget.spec);
    super.initState();
  }

  // Sets all the fields in the form state from the supplied spec.
  void _loadSpec(DataCellSpec spec) {
    _source = Source.fromString(spec.source);
    // Init group to null now, will set if revelant in build when we have a dataSet.
    _group = null;
    // Derived elements don't have complile-time definitions, so don't sanitize element yet.
    _element = spec.element;
    // We can't validate the format until we've get a dataSet to supply the dimension for any
    // derived data elements.
    _format = spec.format;
    _type = CellType.fromString(spec.type);
    _statsInterval = StatsInterval.fromString(spec.statsInterval);
    _historyInterval = HistoryInterval.fromString(spec.historyInterval);
    _isNameOverridden = (spec.name != null);
    if (spec.name != null) {
      _nameController.text = spec.name!;
    } else {
      // Building the name field will update this to reflect the property.
      _nameController.text = '';
    }
  }

  // Returns a new spec from the current form state, reusing the key of the original spec.
  DataCellSpec _currentSpec() {
    return DataCellSpec(
      _source?.name ?? '',
      _element ?? '',
      _type?.name ?? '',
      _format ?? '',
      name: _isNameOverridden ? _nameController.text : null,
      statsInterval: _statsInterval?.name,
      historyInterval: _historyInterval?.name,
      key: widget.spec.key,
    );
  }

  /// Returns clipboard text for the current form contents, or null if the form is not valid.
  String? get clipboardText {
    if (!formKey.currentState!.validate()) {
      return null;
    }
    return PageSettings.cellToClipboard(_currentSpec());
  }

  /// Replaces the form contents with a cell from clipboard text, returning an error message if
  /// the cell could not be used.
  String? paste(String text) {
    final spec = PageSettings.cellFromClipboard(text);
    if (spec == null) {
      return 'Clipboard does not contain valid cell definition json';
    }
    if (_dataSet.sources[Source.fromString(spec.source)]?[spec.element] == null) {
      return 'Clipboard cell uses an element that is not available';
    }
    setState(() {
      _loadSpec(spec);
      _pasteCount++;
    });
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  DataElement? get dataElement {
    return _dataSet.sources[_source]?[_element];
  }

  // Clears any internal fields that are now inconsistent given the present value of higher level
  // fields. For format we return to the user's prefered default for the dimension.
  void _wipeInvalidFields() {
    // Clear the data element if its not known on this source or is not in the correct group.
    var dataElement = _dataSet.sources[_source]?[_element];
    if (dataElement == null || _source == null) {
      _element = null;
    } else if (_source!.usesGrouping() && dataElement.property.group != _group) {
      // Source being null implies dataElement is null hence the other branch but dart can't figure
      // that out so use the explicit !. in the if statement.
      dataElement = null;
      _element = null;
    }

    // Clear the type if there isn't a data element. Set to Current value by default when selecting
    // a new data element or a data element that doesn't support the previous value.
    if (dataElement == null) {
      _type = null;
    } else if (_type == null) {
      _type = CellType.current;
    } else if (_type == CellType.average && dataElement is! WithStats) {
      _type = CellType.current;
    } else if (_type == CellType.history && dataElement is! WithHistory) {
      _type = CellType.current;
    }

    // Clear any interval that doesn't apply to the type, and default to one that does.
    switch (_type) {
      case null:
      case CellType.current:
        _statsInterval = null;
        _historyInterval = null;
      case CellType.average:
        _statsInterval ??= StatsInterval.fifteenSec;
        _historyInterval = null;
      case CellType.history:
        _statsInterval = null;
        _historyInterval ??= HistoryInterval.twoHours;
    }

    // Clear the format if there isn't a data element or if the current format needs to support
    // history and doesn't. Set the default format for the dimension if the current format is
    // not valid for the element.
    final dimension = dataElement?.property.dimension;
    if (dimension == null) {
      _format = null;
    } else {
      if (!formattersFor(dimension).keys.contains(_format)) {
        _format = _formatPrefs.forDimension(dimension.name);
      }
      if (_type == CellType.history && formattersFor(dimension)[_format] is! NumericFormatter) {
        _format = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _dataSet = Provider.of<DataSet>(context);
    _pageSettings = Provider.of<PageSettings>(context);
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              key: ValueKey(_pasteCount),
              children: [
                _buildSourceField(),
                _buildElementField(),
                _buildTypeField(),
                _buildIntervalField(),
                _buildFormatField(),
                _buildOverrideNameField(),
                _buildNameField(),
              ],
            ),
          ),
          buildSaveButton(
            postSaver: () {
              // By this stage all the fields will have saved back to our state and we can be
              // confident all the fields are populated. Just create a new spec from these
              // (reusing the previous key) and ask the settings to use it.
              _pageSettings.updateCell(_currentSpec());
              final dimension = _dataSet.sources[_source]?[_element]?.property.dimension;
              _formatPrefs.recordUsage(dimension?.name, _format);

              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSourceField() {
    final sourceGroups = SourceAndGroup.set();

    return buildDropdownBox(
      label: 'Source',
      items: sourceGroups.map((sg) => DropdownEntry(value: sg, text: sg.text)).toList(),
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
    final sourceElements = dataSet.sources[_source];
    if (sourceElements != null && _source!.usesGrouping()) {
      elements.addEntries(sourceElements.entries.where((e) => e.value.property.group == _group));
    } else if (sourceElements != null) {
      elements.addAll(sourceElements);
    }

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

  Widget _buildTypeField() {
    final dataElement = _dataSet.sources[_source]?[_element];

    final List<DropdownEntry<CellType>> entries = [];
    if (dataElement != null) {
      entries.add(DropdownEntry(value: CellType.current, text: CellType.current.longName));
    }
    if (dataElement is WithStats) {
      entries.add(DropdownEntry(value: CellType.average, text: CellType.average.longName));
    }
    if (dataElement is WithHistory) {
      entries.add(DropdownEntry(value: CellType.history, text: CellType.history.longName));
    }

    return buildDropdownBox(
      label: 'Display',
      items: entries,
      initialValue: entries.any((e) => e.value == _type) ? _type : null,
      onChanged: (CellType? value) {
        setState(() {
          _type = value;
          _wipeInvalidFields();
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

  Widget _buildIntervalField() {
    final List<DropdownEntry<Enum>> entries = switch (_type) {
      CellType.average =>
        StatsInterval.values.map((s) => DropdownEntry<Enum>(value: s, text: s.display)).toList(),
      CellType.history =>
        HistoryInterval.values.map((h) => DropdownEntry<Enum>(value: h, text: h.display)).toList(),
      _ => [],
    };
    final Enum? value = switch (_type) {
      CellType.average => _statsInterval,
      CellType.history => _historyInterval,
      _ => null,
    };

    return buildDropdownBox<Enum>(
      label: 'Interval',
      items: entries,
      initialValue: value,
      enabled: entries.isNotEmpty,
      onChanged: (Enum? value) {
        setState(() {
          if (value is StatsInterval) {
            _statsInterval = value;
          } else if (value is HistoryInterval) {
            _historyInterval = value;
          }
        });
      },
      validator: (value) {
        if (entries.isNotEmpty && value == null) {
          return 'Interval must be set';
        }
        return null;
      },
    );
  }

  Widget _buildFormatField() {
    final dimension = _dataSet.sources[_source]?[_element]?.property.dimension;
    final formatters = formattersFor(dimension);

    return buildDropdownBox(
      label: 'Format',
      items: formatters.entries
          .map((e) => DropdownEntry(value: e.key, text: e.value.longName))
          .toList(),
      initialValue: formatters.keys.contains(_format) ? _format : null,
      onChanged: (String? value) {
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

  Widget _buildOverrideNameField() {
    return buildSwitch(
      label: 'Set manual name',
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
    // If we're not overriding the name, update the text to reflect the current elementName.
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
