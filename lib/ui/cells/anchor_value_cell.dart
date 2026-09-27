import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmea_dashboard/state/data_element.dart';
import 'package:nmea_dashboard/state/formatting.dart';
import 'package:nmea_dashboard/state/network.dart';
import 'package:nmea_dashboard/ui/cells/abstract.dart';
import 'package:provider/provider.dart';

class AnchorValueCell extends HeadingContentsCell {
  AnchorValueCell({
    required DataElement element,
    required Formatter formatter,
    required super.spec,
    required InternetAddress gatewayAddress,
    required int gatewayPort,
    super.key,
  }) : super(
         heading: spec.name ?? (element.shortName.isEmpty ? ' ' : element.shortName),
         units: formatter.units ?? ' ',
         content: ChangeNotifierProvider<DataElement>.value(
           value: element,
           child: _AnchorValue(
             formatter: formatter,
             gatewayAddress: gatewayAddress,
             gatewayPort: gatewayPort,
           ),
         ),
         alarmState: (element is WithAlarms) ? element.alarmState : null,
       );
}

class _AnchorValue extends StatelessWidget {
  final Formatter formatter;
  final InternetAddress gatewayAddress;
  final int gatewayPort;

  const _AnchorValue({
    required this.formatter,
    required this.gatewayAddress,
    required this.gatewayPort,
  });

  @override
  Widget build(BuildContext context) {
    final element = Provider.of<DataElement>(context);
    final value = element.value;

    return Column(
      children: [
        Expanded(
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.headlineLarge!,
            child: FractionallySizedBox(
              heightFactor: formatter.heightFraction,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(formatter.format(value), textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: FilledButton.icon(
            onPressed: () => _confirmReset(context),
            icon: const Icon(Icons.restart_alt),
            label: const Text('RESET'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kettenzähler zurücksetzen?'),
        content: const Text('Der aktuelle Kettenzähler wird dauerhaft auf 0 gesetzt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Auf 0 setzen'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await sendAnchorResetCommand(gatewayAddress, gatewayPort);
  }
}
