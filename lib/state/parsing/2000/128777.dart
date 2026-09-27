part of 'common.dart';

class Parser128777 extends PacketParser {
  @override
  final pgn = 128777;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 8);

    // Kettenlänge: Byte 3-4, Auflösung 0,1 m
    final rodeCounterRaw = _readUint16(payload, 3);
    final rodeCounter = _scaleIfNotNull(rodeCounterRaw, 0.1);

    // Bewegungsstatus: Byte 2, Bits 0-1
    // 0 = STOP
    // 1 = DOWN / Deployment
    // 2 = UP / Retrieval
    // 3 = nicht verfügbar
    final motion = payload.getUint8(2) & 0x03;

    final values = <BoundValue>[];

    if (rodeCounter != null) {
      values.add(
        boundSingleValue(
          rodeCounter,
          Property.anchorRodeLength,
          tier: 1,
        ),
      );
    }

    if (motion != 3) {
      values.add(
        boundSingleValue(
          motion,
          Property.anchorMotion,
          tier: 1,
        ),
      );
    }

    return values;
  }
}