// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';

import 'package:nmea_dashboard/state/common.dart';
import 'package:nmea_dashboard/state/settings/clipboard.dart';
import 'package:nmea_dashboard/state/settings/page.dart';
import 'package:nmea_dashboard/state/settings/specs.dart';
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

/// A form that lets the user edit a single page. Defined as a StatelessWidget to share
/// a form key between the clipboard buttons and the Form.
class EditPagePage extends StatelessWidget {
  final DataPageSpec pageSpec;
  final CreatePageSpecFunction onCreate;
  final _formKey = GlobalKey<_EditPageFormState>();

  EditPagePage({DataPageSpec? pageSpec, required this.onCreate, super.key})
    : pageSpec = pageSpec ?? _createPageSpec();

  @override
  Widget build(BuildContext context) {
    return StatefulFormPage(
      title: 'Edit page',
      actions: [
        CopyButton(kind: ClipboardKind.page, getText: (_) => _formKey.currentState?.clipboardText),
        PasteButton(
          kind: ClipboardKind.page,
          isValid: (_, text) => PageSettings.pageFromClipboard(text) != null,
          onPaste: (_, text) => _formKey.currentState?.paste(text),
        ),
        const HelpButton('edit_page.md'),
      ],
      child: _EditPageForm(pageSpec, onCreate, key: _formKey),
    );
  }
}

class _EditPageForm extends StatefulWidget {
  final CreatePageSpecFunction _onCreate;
  final DataPageSpec _pageSpec;

  const _EditPageForm(this._pageSpec, this._onCreate, {super.key});

  @override
  State<_EditPageForm> createState() => _EditPageFormState();
}

class _EditPageFormState extends StatefulFormState<_EditPageForm> {
  late String _name;
  late int _size;
  late List<DataCellSpec> _cells;
  // Incremented on each paste to force all fields to rebuild from the new state.
  int _pasteCount = 0;

  @override
  void initState() {
    _name = widget._pageSpec.name;
    _size = widget._pageSpec.cells.length;
    _cells = widget._pageSpec.cells;
    super.initState();
  }

  // Returns the cells, truncated or grown with empty cells to match the current size.
  List<DataCellSpec> _resizedCells() {
    if (_size < _cells.length) {
      // Truncate the existing list.
      return _cells.sublist(0, _size);
    } else {
      // Grow the existing list with empty cells.
      return _cells + List.generate(_size - _cells.length, (_) => _createCellSpec());
    }
  }

  /// Returns clipboard text for the current form contents, or null if the form is not valid.
  String? get clipboardText {
    if (!formKey.currentState!.validate()) {
      return null;
    }
    formKey.currentState!.save();
    return PageSettings.pageToClipboard(DataPageSpec(_name, _resizedCells()));
  }

  /// Replaces the form contents with a page from clipboard text, returning an error message if
  /// the page could not be used.
  String? paste(String text) {
    final spec = PageSettings.pageFromClipboard(text);
    if (spec == null) {
      return 'Clipboard does not contain valid page definition json';
    }
    setState(() {
      _name = spec.name;
      _size = spec.cells.length;
      _cells = spec.cells;
      _pasteCount++;
    });
    return null;
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
            child: ListView(
              key: ValueKey(_pasteCount),
              children: [_buildNameField(), _buildSizeField()],
            ),
          ),
          buildSaveButton(
            postSaver: () {
              // Call the function we were told to call, keeping the original page key.
              widget._onCreate(DataPageSpec(_name, _resizedCells(), key: widget._pageSpec.key));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return buildTextField(
      label: 'Page name',
      initialValue: _name,
      alphabet: Alphabet.any,
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
      },
    );
  }

  Widget _buildSizeField() {
    return buildTextField(
      label: 'Cell count',
      initialValue: _size.toString(),
      alphabet: Alphabet.integer,
      maxLength: 2,
      validator: (value) {
        final number = int.tryParse(value ?? '');
        if (number == null || number < 1 || number > 64) {
          return 'Count must be between 1 and 65';
        }
        return null;
      },
      onSaved: (value) {
        if (value != null) {
          _size = int.parse(value);
        }
      },
    );
  }
}
