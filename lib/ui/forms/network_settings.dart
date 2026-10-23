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

/// An entry in the protocol dropdown. NMEA0183 is split into entries with and without checksum
/// validation, other protocols do not use the checksum setting so leave it null.
typedef _ProtocolOption = ({NetworkProtocol protocol, bool? requireChecksum});

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
  late bool _allowDefaultVariation;
  late double _defaultVariation;

  @override
  void initState() {
    _ipAddress = widget._settings.ipAddress;
    _portNum = widget._settings.port;
    _mode = widget._settings.mode;
    _protocol = widget._settings.protocol;
    _requireChecksum = widget._settings.requireChecksum;
    _staleness = widget._settings.staleness;
    _allowDefaultVariation = widget._settings.defaultVariationEnabled;
    _defaultVariation = widget._settings.defaultVariationValue;
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
                _buildStalenessField(),
                _buildAllowDefaultVariationField(),
                _buildDefaultVariationField(),
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
                defaultVariationEnabled: _allowDefaultVariation,
                // The variation field isn't validated while disabled, so retain the previous
                // value rather than saving it.
                defaultVariationValue: _allowDefaultVariation ? _defaultVariation : null,
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
    final List<DropdownEntry<_ProtocolOption>> items = [];
    for (final protocol in NetworkProtocol.values) {
      if (protocol == NetworkProtocol.nmea0183) {
        items.add(
          DropdownEntry(
            value: (protocol: protocol, requireChecksum: true),
            text: '${protocol.description} (checksum)',
          ),
        );
        items.add(
          DropdownEntry(
            value: (protocol: protocol, requireChecksum: false),
            text: '${protocol.description} (no checksum)',
          ),
        );
      } else {
        items.add(
          DropdownEntry(
            value: (protocol: protocol, requireChecksum: null),
            text: protocol.description,
          ),
        );
      }
    }
    return buildDropdownBox<_ProtocolOption>(
      label: 'Protocol',
      items: items,
      initialValue: (
        protocol: _protocol,
        requireChecksum: _protocol == NetworkProtocol.nmea0183 ? _requireChecksum : null,
      ),
      onChanged: (value) {
        if (value != null) {
          _protocol = value.protocol;
          // Retain the previous checksum setting when selecting a protocol that doesn't use it.
          _requireChecksum = value.requireChecksum ?? _requireChecksum;
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

  Widget _buildAllowDefaultVariationField() {
    return buildSwitch(
      label: 'Default magnetic variation',
      initialValue: _allowDefaultVariation,
      onChanged: (value) {
        // Setting state lets us change enable on the default variation field.
        setState(() => _allowDefaultVariation = value);
      },
      onSaved: (value) {
        if (value != null) {
          _allowDefaultVariation = value;
        }
      },
    );
  }

  Widget _buildDefaultVariationField() {
    final regex = RegExp(r'^\d{1,2}(\.\d)?$');
    final enabled = _allowDefaultVariation;
    final textStyle = Theme.of(context).textTheme.labelMedium!;
    // Indent the row with no label so it appears to belong to the switch above.
    return Padding(
      padding: const EdgeInsets.only(left: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 10,
        children: [
          Expanded(
            child: buildTextField(
              initialValue: _defaultVariation.abs().toStringAsFixed(1),
              suffix: '°',
              maxLength: 4,
              alphabet: Alphabet.floatingPoint,
              enabled: enabled,
              validator: (value) {
                if (!enabled) {
                  return null;
                }
                final number = double.tryParse(value ?? '');
                if (!regex.hasMatch(value ?? '') || number == null || number > 30) {
                  return 'Must be between 0.0 and 30.0';
                }
                return null;
              },
              onSaved: (value) {
                final number = double.tryParse(value ?? '');
                if (number != null) {
                  _defaultVariation = _defaultVariation.isNegative ? -number : number;
                }
              },
            ),
          ),
          // The selector sets the sign of _defaultVariation, with true meaning negative (west). We
          // use isNegative rather than < 0 so -0.0 can represent zero west.
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(textStyle: textStyle),
            segments: const [
              ButtonSegment<bool>(value: true, label: Text('W')),
              ButtonSegment<bool>(value: false, label: Text('E')),
            ],
            selected: {_defaultVariation.isNegative},
            onSelectionChanged: enabled
                ? (Set<bool> values) {
                    if (values.first != _defaultVariation.isNegative) {
                      setState(() => _defaultVariation = -_defaultVariation);
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
