// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';

import '../state/common.dart';
import '../state/settings.dart';
import 'form.dart';

/// The initial spec for freshly created cells.
final _defaultCellSpec = DataCellSpec(Source.unset.name, "", "");

/// The initial spec for a freshly created page.
final _defaultPageSpec =
    DataPageSpec('', List.filled(8, _defaultCellSpec));

/// A function called on successful creation of a DataPageSpec.
typedef CreatePageSpecFunction = void Function(DataPageSpec spec);

/// A form that lets the user edit a single page.
class EditPagePage extends StatefulFormPage {

  EditPagePage({DataPageSpec? pageSpec, required CreatePageSpecFunction onCreate, super.key})
      : super(title: 'Edit page', child: _EditPageForm(pageSpec, onCreate));
}

class _EditPageForm extends StatefulWidget {
  final CreatePageSpecFunction _onCreate;
  final DataPageSpec _pageSpec;

  _EditPageForm(DataPageSpec? pageSpec, this._onCreate)
      : _pageSpec = pageSpec ?? _defaultPageSpec;

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
            _buildNameField(),
            _buildSizeField(),
            const SizedBox(height: 20),
            const Expanded(
              child: SizedBox(height: 100),
            ),
            buildSaveButton(
                postSaver: () {
                  final originalCells = widget._pageSpec.cells;
                  List<DataCellSpec> cells;
                  if (_size < originalCells.length) {
                    // Truncate the existing list.
                    cells = originalCells.sublist(0, _size);
                  } else {
                    // Grow the existing list with empty cells.
                    cells = originalCells +
                        List.filled(
                            _size - originalCells.length, _defaultCellSpec);
                  }
                  // Call the function we were told to call.
                  widget._onCreate(DataPageSpec(_name, cells));
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
