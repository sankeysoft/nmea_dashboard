// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/specs.dart';
import 'package:nmea_dashboard/ui/forms/abstract.dart';

/// The initial spec for freshly created cells.
DataCellSpec _createCellSpec() {
  return DataCellSpec(Source.unset.name, '', CellType.current.name, '');
}

/// The initial spec for a freshly created page.
DataPageSpec _createPageSpec() {
  return DataPageSpec('', List.generate(8, (_) => _createCellSpec()));
}

/// A function called on successful creation of a DataPageSpec.
typedef CreatePageSpecFunction = void Function(DataPageSpec spec);

/// A form that lets the user edit a single page.
class EditPagePage extends StatefulFormPage {
  EditPagePage(
      {DataPageSpec? pageSpec,
      required CreatePageSpecFunction onCreate,
      super.key})
      : super(
            title: 'Edit page',
            actions: [const HelpButton('help_edit_page.md')],
            child: _EditPageForm(pageSpec, onCreate));
}

class _EditPageForm extends StatefulWidget {
  final CreatePageSpecFunction _onCreate;
  final DataPageSpec _pageSpec;

  _EditPageForm(DataPageSpec? pageSpec, this._onCreate)
      : _pageSpec = pageSpec ?? _createPageSpec();

  @override
  State<_EditPageForm> createState() => _EditPageFormState();
}

class _EditPageFormState extends StatefulFormState<_EditPageForm> {
  late String _name;
  late int _size;

  @override
  void initState() {
    _name = widget._pageSpec.name;
    _size = widget._pageSpec.cells.length;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
                child:
                    ListView(children: [_buildNameField(), _buildSizeField()])),
            buildSaveButton(postSaver: () {
              final originalCells = widget._pageSpec.cells;
              final originalKey = widget._pageSpec.key;
              List<DataCellSpec> cells;
              if (_size < originalCells.length) {
                // Truncate the existing list.
                cells = originalCells.sublist(0, _size);
              } else {
                // Grow the existing list with empty cells.
                cells = originalCells +
                    List.generate(
                        _size - originalCells.length, (_) => _createCellSpec());
              }
              // Call the function we were told to call.
              widget._onCreate(DataPageSpec(_name, cells, key: originalKey));
              Navigator.pop(context);
            })
          ]),
    );
  }

  Widget _buildNameField() {
    return buildTextField(
        label: 'Page name',
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

  Widget _buildSizeField() {
    return buildTextField(
        label: 'Cell count',
        initialValue: _size.toString(),
        keyboardType: TextInputType.number,
        maxLength: 2,
        validator: (value) {
          final number = int.tryParse(value ?? '');
          if (number == null || number < 1 || number > 64) {
            return 'Port must be between 1 and 65';
          }
          return null;
        },
        onSaved: (value) {
          if (value != null) {
            _size = int.parse(value);
          }
        });
  }
}
