// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nmea_dashboard/state/settings/network.dart';
import 'package:nmea_dashboard/ui/forms/abstract.dart';

/// A form that lets the user edit network settings.
class NetworkSettingsPage extends StatefulFormPage {
  NetworkSettingsPage({required NetworkSettings settings, super.key})
    : super(
        title: 'Network settings',
        actions: [const HelpButton('network_settings.md')],
        child: _NetworkSettingsForm(settings),
      );
}

/// The stateful form itself
class _NetworkSettingsForm extends StatefulWidget {
  // Pass settings explicitly since we don't have
  // a build context when initializing state.
  final NetworkSettings _settings;

  const _NetworkSettingsForm(this._settings);

  @override
  State<_NetworkSettingsForm> createState() => _NetworkSettingsFormState();
}

class _NetworkSettingsFormState extends StatefulFormState<_NetworkSettingsForm> {
  late int _portNum;
  late InternetAddress _ipAddress;
  late NetworkMode _mode;
  late NetworkProtocol _protocol;
  late bool _requireChecksum;
  late Duration _staleness;

  @override
  void initState() {
    _ipAddress = widget._settings.ipAddress;
    _portNum = widget._settings.port;
    _mode = widget._settings.mode;
    _protocol = widget._settings.protocol;
    _requireChecksum = widget._settings.requireChecksum;
    _staleness = widget._settings.staleness;
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
            child: ListView(
              children: [
                _buildModeField(),
                _buildIpField(),
                _buildPortField(),
                _buildProtocolField(),
                _buildRequireChecksumField(),
                _buildStalenessField(),
              ],
            ),
          ),
          buildSaveButton(
            postSaver: () {
              widget._settings.set(
                mode: _mode,
                port: _portNum,
                ipAddress: _ipAddress,
                protocol: _protocol,
                requireChecksum: _requireChecksum,
                staleness: _staleness,
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeField() {
    buildItem(NetworkMode mode) => DropdownEntry(value: mode, text: mode.description);
    return buildDropdownBox(
      label: 'Mode',
      items: [buildItem(NetworkMode.udpListen), buildItem(NetworkMode.tcpConnect)],
      initialValue: _mode,
      onChanged: (value) {
        setState(() {
          // Setting state lets us change enable on the IP field.
          if (value != null) {
            _mode = value;
          }
        });
      },
    );
  }

  Widget _buildIpField() {
    final regex = RegExp(r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$');
    final enabled = (_mode != NetworkMode.udpListen);
    return buildTextField(
      label: 'IP address',
      initialValue: _ipAddress.address,
      alphabet: Alphabet.any,
      enabled: enabled,
      maxLength: 15,
      validator: (value) {
        if (!regex.hasMatch(value ?? '')) {
          return 'IP address must be a valid IPv4 address such as 192.168.1.1';
        }
        return null;
      },
      onSaved: (value) {
        if (value != null) {
          _ipAddress = InternetAddress(value);
        }
      },
    );
  }

  Widget _buildPortField() {
    return buildTextField(
      label: 'Port number',
      initialValue: _portNum.toString(),
      alphabet: Alphabet.integer,
      maxLength: 5,
      validator: (value) {
        final number = int.tryParse(value ?? '');
        if (number == null || number < 1 || number > 65536) {
          return 'Port must be between 1 and 65536';
        }
        return null;
      },
      onSaved: (value) {
        if (value != null) {
          _portNum = int.parse(value);
        }
      },
    );
  }

  Widget _buildProtocolField() {
    buildItem(NetworkProtocol protocol) =>
        DropdownEntry(value: protocol, text: protocol.description);
    return buildDropdownBox(
      label: 'Protocol',
      items: NetworkProtocol.values.map(buildItem).toList(),
      initialValue: _protocol,
      onChanged: (value) {
        setState(() {
          // Setting state lets us change enable on the checksum field.
          if (value != null) {
            _protocol = value;
          }
        });
      },
    );
  }

  Widget _buildRequireChecksumField() {
    return buildSwitch(
      label: 'Require checksum',
      initialValue: _requireChecksum,
      enabled: _protocol == NetworkProtocol.nmea0183,
      onSaved: (value) {
        if (value != null) {
          _requireChecksum = value;
        }
      },
    );
  }

  Widget _buildStalenessField() {
    return buildTextField(
      label: 'Staleness',
      initialValue: _staleness.inSeconds.toString(),
      suffix: 'seconds',
      maxLength: 4,
      alphabet: Alphabet.integer,
      validator: (value) {
        final number = int.tryParse(value ?? '');
        if (number == null || number < 1 || number > 3600) {
          return 'Must be between 1 and 3600 seconds';
        }
        return null;
      },
      onSaved: (value) {
        if (value != null) {
          _staleness = Duration(seconds: int.parse(value));
        }
      },
    );
  }
}
