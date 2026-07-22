// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser130306 extends PacketParser {
  @override
  final pgn = 130306;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);
    final reference = payload.getUint8(5) & 0x07;
    final speed = _scaleIfNotNull(_readUint16(payload, 1), 0.01);
    var angle = _scaleIfNotNull(_readUint16(payload, 3), 0.0001 * radiansToDegrees);

    final values = <BoundValue>[];
    if (speed != null) {
      values.add(
        boundSingleValue(
          speed,
          reference == 2 ? Property.apparentWindSpeed : Property.trueWindSpeed,
        ),
      );
    }

    if (angle != null) {
      _validateInRange(angle, 0.0, 360.0);
      if (reference == 0) {
        // Use true ground reference bearing directly.
        values.add(boundSingleValue(angle, Property.trueWindDirection));
      } else if (reference == 2 || reference == 3) {
        // Convert boat-referenced angles to signed angle from bow.
        if (angle > 180.0) angle -= 360.0;
        values.add(
          boundSingleValue(
            angle,
            reference == 2 ? Property.apparentWindAngle : Property.trueWindAngle,
          ),
        );
      }
      // Currently we don't use magnetic ground referenced or water referenced angles.
    }
    return values;
  }
}
