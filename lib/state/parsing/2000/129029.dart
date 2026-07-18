// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser129029 extends PacketParser {
  @override
  final pgn = 129029;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validateMinPayloadLength(payload, 31);
    final days = _readUint16(payload, 1);
    final microseconds = _multiplyIfNotNull(_readUint32(payload, 2), 100);
    final lat = _scaleIfNotNull(_readInt64(payload, 7, 8), 1e-16);
    final long = _scaleIfNotNull(_readInt64(payload, 16, 8), 1e-16);
    final hdop = (payload.lengthInBytes >= 35)
        ? _scaleIfNotNull(_readUint16(payload, 33), 0.01)
        : null;

    final values = <BoundValue>[];
    if (lat != null && long != null) {
      values.add(boundDoubleValue(lat, long, Property.gpsPosition));
    }
    if (days != null && microseconds != null) {
      final dt = DateTime.utc(1970).add(Duration(days: days, microseconds: microseconds));
      values.add(boundSingleValue(dt, Property.utcTime));
    }
    if (hdop != null) {
      values.add(boundSingleValue(hdop, Property.gpsHdop));
    }
    return values;
  }
}
