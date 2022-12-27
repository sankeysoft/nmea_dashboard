/// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/common.dart';
import '../state/data_element.dart';
import '../state/data_set.dart';
import '../state/formatting.dart';
import '../state/settings.dart';
import 'form.dart';

/// The initial spec for a freshly created page.
final _defaultDerivedDataSpec =
    DerivedDataSpec('', 'network', '', '', '', 0);

/// A function called on successful creation of a DerivedDataSpec.
typedef CreateDerivedDataFunction = void Function(DerivedDataSpec spec);

/// A form that lets the user edit a single derived element.
class EditDerivedDataPage extends StatefulFormPage {
  EditDerivedDataPage(
      {DerivedDataSpec? spec,
      required CreateDerivedDataFunction onCreate,
      super.key})
      : super(title: 'Edit derived element', child: _EditDerivedDataForm(spec, onCreate));
}

class _EditDerivedDataForm extends StatefulWidget {
  final CreateDerivedDataFunction _onCreate;
  final DerivedDataSpec _spec;

  _EditDerivedDataForm(DerivedDataSpec? spec, this._onCreate)
      : _spec = spec ?? _defaultDerivedDataSpec;

  @override
  State<_EditDerivedDataForm> createState() => _EditDerivedDataFormState();
}

class _EditDerivedDataFormState
    extends StatefulFormState<_EditDerivedDataForm> {
  late DataSet _dataSet;
  late String _name;
  Source? _inputSource;
  String? _inputName;
  String? _inputFormat;
  Operation _operation = Operation.add;
  double _operand = 0.0;

  @override
  void initState() {
    _name = widget._spec.name;
    _inputSource = Source.fromString(widget._spec.inputSource);
    _inputName = widget._spec.inputElement;
    _inputFormat = widget._spec.inputFormat;
    _operation = Operation.fromString(widget._spec.operation) ?? Operation.add;
    _operand = widget._spec.operand;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _dataSet = Provider.of<DataSet>(context);
    // If the spec we loaded was invalid (like the default, nullify now).
    _wipeInvalidFields();

    return Form(
      key: formKey,
      child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNameField(),
            _buildSourceField(),
            _buildElementField(),
            _buildFormatField(),
            Row(children: [
              Expanded(child: _buildOperationField()),
              const SizedBox(width: 20),
              SizedBox(width: 180, child: _buildOperandField())
            ]),
            const Expanded(
              child: SizedBox(height: 50),
            ),
            buildSaveButton(
                postSaver: () {
                  final spec = DerivedDataSpec(
                      _name,
                      _inputSource?.name ?? '',
                      _inputName ?? '',
                      _inputFormat ?? '',
                      _operation.name,
                      _operand);
                  widget._onCreate(spec);
                  Navigator.pop(context);
                })
          ]),
    );
  }

  // Clears any internal fields that are now inconsistent given the present value of
  // higher level fields.
  void _wipeInvalidFields() {
    final inputElement = _dataSet.sources[_inputSource]?[_inputName];

    if (inputElement == null) {
      _inputName = null;
    }
    if (inputElement?.property == null ||
        !formattersFor(inputElement!.property.dimension)
            .keys
            .contains(_inputFormat)) {
      _inputFormat = null;
    }
  }

  Widget _buildNameField() {
    return buildTextField(
        label: 'Derived name',
        initialValue: _name,
        keyboardType: TextInputType.text,
        maxLength: 20,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Name must not be empty';
          }
          return null;
        },
        onSaved: (value) {
          if (value != null) {
            _name = value;
          }
        });
  }

  Widget _buildSourceField() {
    final selectableSources = Source.values
        .where((source) => source.selectable && source != Source.derived)
        .toSet();
    return buildDropdownBox(
      label: 'Input source',
      items: selectableSources.map((source) {
        return DropdownEntry(value: source, text: source.longName);
      }).toList(),
      initialValue: selectableSources.lookup(_inputSource),
      onChanged: (Source? value) {
        setState(() {
          _inputSource = value;
          _wipeInvalidFields();
        });
      },
    );
  }

  Widget _buildElementField() {
    final Map<String, DataElement> elements =
        _dataSet.sources[_inputSource] ?? {};

    return buildDropdownBox(
      label: 'Input element',
      items: elements.keys
          .where((e) => elements[e]!.property.dimension.derivationFriendly)
          .map((e) => DropdownEntry(value: e, text: elements[e]!.longName))
          .toList(),
      initialValue: _inputName,
      onChanged: (String? value) {
        setState(() {
          _inputName = value;
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

  Widget _buildFormatField() {
    final dimension =
        _dataSet.sources[_inputSource]?[_inputName]?.property.dimension;
    final Map<String, Formatter> eligibleFormatters = formattersFor(dimension);

    return buildDropdownBox(
        label: 'Input units',
        items: eligibleFormatters.entries
            .map((entry) =>
                DropdownEntry(value: entry.key, text: entry.value.longName))
            .toList(),
        initialValue: eligibleFormatters.keys.contains(_inputFormat)
            ? _inputFormat
            : null,
        onChanged: (String? value) {
          setState(() {
            _inputFormat = value;
          });
        },
        validator: (value) {
          if (value == null) {
            return 'Format must be set';
          }
          return null;
        });
  }

  Widget _buildOperationField() {
    return buildDropdownBox(
      label: 'Operation',
      items: Operation.values.map((op) {
        return DropdownEntry(value: op, text: op.display);
      }).toList(),
      initialValue: _operation,
      onChanged: (Operation? value) {
        setState(() {
          if (value != null) {
            _operation = value;
          }
        });
      },
    );
  }

  Widget _buildOperandField() {
    return buildTextField(
        initialValue: _operand.toString(),
        keyboardType: TextInputType.number,
        maxLength: 8,
        validator: (value) {
          return (double.tryParse(value ?? '') == null)
              ? 'Must be a valid number'
              : null;
        },
        onSaved: (value) {
          if (value != null) {
            _operand = double.parse(value);
          }
        });
  }
}
