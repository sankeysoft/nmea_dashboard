// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:typed_data';

import 'package:nmea_dashboard/state/parsing/validators.dart';
import 'package:test/test.dart';

void main() {
  group('ValidatedMessage.payloadToString', () {
    test('returns the string representation of a non-ByteData payload', () {
      final message = ValidatedMessage<String, String>('DPT', 'YD', '18.56,-1.61,140.0');
      expect(message.payloadToString(), '18.56,-1.61,140.0');
    });

    test('returns a hex representation of a short ByteData payload', () {
      final payload = ByteData.sublistView(Uint8List.fromList([0x01, 0x02, 0xab]));
      final message = ValidatedMessage<ByteData, int>(127251, 0x23, payload);
      expect(message.payloadToString(), '0x0102ab');
    });

    test('groups bytes of a longer ByteData payload in fours', () {
      final payload = ByteData.sublistView(
        Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05, 0x06]),
      );
      final message = ValidatedMessage<ByteData, int>(127251, 0x23, payload);
      expect(message.payloadToString(), '0x01020304_0506');
    });

    test('does not append a trailing separator on an exact multiple of four', () {
      final payload = ByteData.sublistView(Uint8List.fromList([0x01, 0x02, 0x03, 0x04]));
      final message = ValidatedMessage<ByteData, int>(127251, 0x23, payload);
      expect(message.payloadToString(), '0x01020304');
    });
  });
}
