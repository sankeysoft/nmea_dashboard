// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';

import '../../state/settings.dart';
import 'abstract.dart';


/// A form that lets the user edit user interface settings.
class UiSettingsPage extends StatefulFormPage {
  UiSettingsPage({required UiSettings settings, key})
      : super(
            key: key,
            title: 'User interface settings',
            child: _UiSettingsForm(settings));
}

/// The stateful form itself
class _UiSettingsForm extends StatefulWidget {
  // Pass settings explicitly since we don't have
  // a build context when initializing state.
  final UiSettings _settings;

  const _UiSettingsForm(this._settings);

  @override
  State<_UiSettingsForm> createState() => _UiSettingsFormState();
}

class _UiSettingsFormState extends StatefulFormState<_UiSettingsForm> {
  late String _valueFont;
  late String _headingFont;

  @override
  void initState() {
    _valueFont = widget._settings.valueFont;
    _headingFont = widget._settings.headingFont;
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
            _buildValueField(),
            _buildHeadingField(),
            const Expanded(
              child: SizedBox(height: 100),
            ),
            buildSaveButton(postSaver: () {
              widget._settings.setFonts(
                  valueFont: _valueFont,
                  headingFont: _headingFont);
              Navigator.pop(context);
            })
          ]),
    );
  }

  Widget _buildValueField() {
    buildItem(String font) => DropdownEntry(value:font, text:font, font:font);
    return buildDropdownBox(
      label: 'Value font',
      items: UiSettings.availableFonts.map((f) => buildItem(f)).toList(),
      initialValue: _valueFont,
      onChanged: (value) {
        setState(() {
          if (value != null) {
            _valueFont = value;
          }
        });
      },
    );
  }

  Widget _buildHeadingField() {
    buildItem(String font) => DropdownEntry(value:font, text:font, font:font);
    return buildDropdownBox(
      label: 'Heading font',
      items: UiSettings.availableFonts.map((f) => buildItem(f)).toList(),
      initialValue: _headingFont,
      onChanged: (value) {
        setState(() {
          if (value != null) {
            _headingFont = value;
          }
        });
      },
    );
  }

}
