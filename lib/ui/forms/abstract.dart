// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';

typedef FormPostSaver = void Function();

// The standard padding
const double _elementPadding = 8;
// Default width, height, and padding
const double _defaultWidth = 400;
const double _defaultHeight = 500;
const double _defaultPad = 20;
// Padding of content in a list tile.
const double _tilePadding = 6;

// The standard radius for rounded shapes, e.g. buttons.
const BorderRadius roundedRadius = BorderRadius.all(Radius.circular(10));

/// A data type for specifying an entry in a dropdown list.
class DropdownEntry<V> {
  final V value;
  final String text;
  final String? font;

  DropdownEntry({required this.value, required this.text, this.font});
}

/// The stateless version of one of the forms in our application.
class StatelessFormPage extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;
  final double maxHeight;

  const StatelessFormPage(
      {super.key,
      required this.title,
      required this.content,
      this.actions,
      this.maxWidth = _defaultWidth,
      this.maxHeight = _defaultHeight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: Center(
            child: Container(
                padding: const EdgeInsets.all(_defaultPad),
                margin: const EdgeInsets.all(_defaultPad),
                constraints:
                    BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: theme.colorScheme.background,
                ),
                child: content)));
  }
}

/// Builds a list tile that can be reodrered in a reorderable list.
Widget buildMovableDeletableTile({
  required Key key,
  required int index,
  required BuildContext context,
  required String title,
  Icon? icon,
  required GestureTapCallback onTap,
  required GestureTapCallback onDeleteTap,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return Padding(
      key: key,
      padding: const EdgeInsets.all(_tilePadding),
      child: ReorderableDelayedDragStartListener(
          index: index,
          child: ListTile(
            title: Text(title),
            textColor: colorScheme.primary,
            iconColor: colorScheme.primary,
            tileColor: colorScheme.surfaceTint,
            shape: const RoundedRectangleBorder(borderRadius: roundedRadius),
            leading: icon,
            trailing: IconButton(
                icon: const Icon(Icons.delete_outline), onPressed: onDeleteTap),
            onTap: onTap,
          )));
}

/// Builds a list tile without reordering or delete.
Widget buildStaticTile({
  required BuildContext context,
  required String title,
  Icon? icon,
  required GestureTapCallback onTap,
}) {
  final theme = Theme.of(context);
  return Padding(
      padding: const EdgeInsets.all(_tilePadding),
      child: ListTile(
        title: Text(title),
        textColor: theme.colorScheme.primary,
        iconColor: theme.colorScheme.primary,
        tileColor: theme.canvasColor,
        shape: const RoundedRectangleBorder(borderRadius: roundedRadius),
        leading: icon,
        onTap: onTap,
      ));
}

/// Builds a button with custom text and behavior.
Widget buildOtherButton(
    {required BuildContext context,
    required VoidCallback onPressed,
    required String text}) {
  return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
            padding: const EdgeInsets.all(20)),
        onPressed: onPressed,
        child: Text(text),
      ));
}

/// Builds a button to close the current form.
Widget buildCloseButton(BuildContext context) {
  return buildOtherButton(
    context: context,
    onPressed: () => Navigator.of(context).pop(),
    text: 'CLOSE');
}

/// Diplays a standard snack bar with the provided text.
void showSnackBar(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

AlertDialog buildConfirmationDialog(
    {required BuildContext context,
    required String title,
    String? content,
    required VoidCallback onPressed}) {
  return AlertDialog(
      title: Text(title),
      content: (content != null) ? Text(content) : null,
      actionsPadding: const EdgeInsets.all(20),
      actions: [
        ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                padding: const EdgeInsets.all(20)),
            onPressed: () {
              onPressed();
              Navigator.of(context).pop();
            },
            child: const Text('OK')),
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
      ]);
}

/// A standard page containing one of the forms in our application.
class StatefulFormPage<T extends StatefulWidget> extends StatelessWidget {
  final String title;
  final T child;
  final List<Widget>? actions;
  final double maxWidth;
  final double maxHeight;

  const StatefulFormPage(
      {super.key,
      required this.title,
      required this.child,
      this.actions,
      this.maxWidth = _defaultWidth,
      this.maxHeight = _defaultHeight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: Center(
            child: Container(
                padding: const EdgeInsets.all(_defaultPad),
                margin: const EdgeInsets.all(_defaultPad),
                constraints:
                    BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: theme.colorScheme.background,
                ),
                child: child)));
  }
}

/// A form state with lots of command helpers to be reused by all our forms.
abstract class StatefulFormState<T extends StatefulWidget> extends State<T> {
  final formKey = GlobalKey<FormState>();

  Widget buildOtherButton(
      {required VoidCallback onPress, required String text, IconData? icon}) {
    final content = (icon == null)
        ? Text(text)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                Icon(icon),
                const SizedBox(width: _elementPadding),
                Text(text)
              ]);
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: _elementPadding),
        child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.all(20)),
              onPressed: onPress,
              child: content,
            )));
  }

  Widget buildSaveButton({required FormPostSaver postSaver}) {
    return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
              padding: const EdgeInsets.all(20)),
          onPressed: () {
            if (formKey.currentState!.validate()) {
              formKey.currentState!.save();
              postSaver();
            }
          },
          child: const Text('SAVE'),
        ));
  }

  Widget buildTextField({
    required int maxLength,
    String? label,
    String initialValue = '',
    bool enabled = true,
    bool expands = false,
    String? suffix,
    TextEditingController? controller,
    TextInputType? keyboardType,
    FormFieldValidator<String>? validator,
    FormFieldSetter<String>? onSaved,
  }) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.labelMedium!;
    final fieldColor =
        enabled ? theme.colorScheme.primary : theme.disabledColor;
    final headingColor = theme.colorScheme.primaryContainer;

    final labelWidget = (label == null)
        ? null
        : Text('$label:', style: textStyle.copyWith(color: headingColor));

    return Padding(
        padding: const EdgeInsets.symmetric(vertical: _elementPadding),
        child: TextFormField(
          controller: controller,
          initialValue: (controller != null) ? null : initialValue,
          enabled: enabled,
          expands: expands,
          maxLines: expands ? null : 1,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            icon: labelWidget,
            border: const OutlineInputBorder(),
            suffix: (suffix != null) ? Text(suffix) : null,
            suffixStyle: textStyle.copyWith(color: headingColor),
            counterText: '',
            isDense: true,
          ),
          textAlign: TextAlign.right,
          keyboardType: keyboardType,
          maxLength: maxLength,
          style: textStyle.copyWith(color: fieldColor),
          validator: validator,
          onSaved: onSaved,
        ));
  }

  Widget buildDropdownBox<V>({
    required String label,
    required List<DropdownEntry<V>> items,
    required V? initialValue,
    ValueChanged<V?>? onChanged,
    FormFieldValidator<V>? validator,
  }) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.labelMedium!;
    final headingColor = theme.colorScheme.primaryContainer;
    final dropdownItems = items.map((item) {
      final itemStyle = (item.font == null)
          ? textStyle
          : textStyle.copyWith(fontFamily: item.font);
      return DropdownMenuItem(
          value: item.value,
          child: Row(children: [
            const Expanded(child: SizedBox()),
            Text(item.text, style: itemStyle)
          ]));
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _elementPadding),
      child: DropdownButtonFormField<V>(
        items: dropdownItems,
        decoration: InputDecoration(
          icon: Text('$label:', style: textStyle.copyWith(color: headingColor)),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        iconEnabledColor: theme.colorScheme.tertiary,
        value: initialValue,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: onChanged,
        validator: validator,
        isExpanded: true,
      ),
    );
  }

  Widget buildSwitch(
      {required String label,
      required bool initialValue,
      ValueChanged<bool>? onChanged,
      FormFieldSetter<bool>? onSaved}) {
    final theme = Theme.of(context);
    final headingStyle = theme.textTheme.labelMedium!
        .copyWith(color: theme.colorScheme.primaryContainer);

    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text('$label:', style: headingStyle),
      const Expanded(child: SizedBox()),
      FormField<bool>(
        initialValue: initialValue,
        builder: (FormFieldState<bool> field) {
          return Switch(
            value: field.value ?? true,
            activeColor: theme.colorScheme.tertiary,
            onChanged: (val) {
              field.didChange(val);
              if (onChanged != null) {
                onChanged(val);
              }
            },
          );
        },
        onSaved: onSaved,
      )
    ]);
  }
}
