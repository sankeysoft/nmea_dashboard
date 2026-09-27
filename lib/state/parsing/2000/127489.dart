// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

part of 'common.dart';

class Parser127489 extends PacketParser {
  @override
  final pgn = 127489;

  @override
  bool get fastFrame => true;

  @override
  List<BoundValue> parse(ByteData payload) {
    _validatePayloadLength(payload, 26);

    final instance = payload.getUint8(0);

    final oilPressure = _scaleIfNotNull(_readUint16(payload, 1), 100.0);
    final oilTemperature = _scaleOffsetIfNotNull(
      _readUint16(payload, 3),
      0.1,
      absoluteZeroInCelcius,
    );

    final coolantTemperature = _scaleOffsetIfNotNull(
      _readUint16(payload, 5),
      0.01,
      absoluteZeroInCelcius,
    );

    final alternatorVoltage = _scaleIfNotNull(_readInt16(payload, 7), 0.01);

    final fuelRate = _scaleIfNotNull(_readInt16(payload, 9), 0.1);

    final engineHoursSeconds = _readUint32(payload, 11);
    final engineHours = engineHoursSeconds == null ? null : engineHoursSeconds / 3600.0;

    final coolantPressure = _scaleIfNotNull(_readUint16(payload, 15), 100.0);
    final fuelPressure = _scaleIfNotNull(_readUint16(payload, 17), 1000.0);
    final discreteStatus1 = _readUint16(payload, 20);
    final discreteStatus2 = _readUint16(payload, 22);
    final checkEngine = discreteStatus1 == null
        ? null
        : ((discreteStatus1 & (1 << 0)) != 0 ? 1 : 0);
    final overTemperature = discreteStatus1 == null
        ? null
        : ((discreteStatus1 & (1 << 1)) != 0 ? 1 : 0);
    final lowOilPressure = discreteStatus1 == null
        ? null
        : ((discreteStatus1 & (1 << 2)) != 0 ? 1 : 0);
    final lowSystemVoltage = discreteStatus1 == null
        ? null
        : ((discreteStatus1 & (1 << 5)) != 0 ? 1 : 0);
    final waterFlowAlarm = discreteStatus1 == null
        ? null
        : ((discreteStatus1 & (1 << 7)) != 0 ? 1 : 0);
    final waterInFuel = discreteStatus1 == null
        ? null
        : ((discreteStatus1 & (1 << 8)) != 0 ? 1 : 0);

    final powerReduction = discreteStatus2 == null
        ? null
        : ((discreteStatus2 & (1 << 2)) != 0 ? 1 : 0);
    final engineCommError = discreteStatus2 == null
        ? null
        : ((discreteStatus2 & (1 << 4)) != 0 ? 1 : 0);
    final checkEngineProperty = instance == 0 ? Property.engine1CheckEngine : null;

    final overTemperatureProperty = instance == 0 ? Property.engine1OverTemperature : null;

    final lowOilPressureProperty = instance == 0 ? Property.engine1LowOilPressure : null;

    final lowSystemVoltageProperty = instance == 0 ? Property.engine1LowSystemVoltage : null;

    final waterFlowAlarmProperty = instance == 0 ? Property.engine1WaterFlowAlarm : null;

    final waterInFuelProperty = instance == 0 ? Property.engine1WaterInFuel : null;

    final powerReductionProperty = instance == 0 ? Property.engine1PowerReduction : null;

    final engineCommErrorProperty = instance == 0 ? Property.engine1CommError : null;

    final oilPressureProperty = switch (instance) {
      0 => Property.engine1OilPressure,
      1 => Property.engine2OilPressure,
      _ => null,
    };

    final oilTemperatureProperty = switch (instance) {
      0 => Property.engine1OilTemperature,
      1 => Property.engine2OilTemperature,
      _ => null,
    };

    final temperatureProperty = switch (instance) {
      0 => Property.engine1Temperature,
      1 => Property.engine2Temperature,
      _ => null,
    };

    final alternatorProperty = switch (instance) {
      0 => Property.alternator1Voltage,
      1 => Property.alternator2Voltage,
      _ => null,
    };

    final fuelRateProperty = switch (instance) {
      0 => Property.engine1FuelRate,
      1 => Property.engine2FuelRate,
      _ => null,
    };

    final engineHoursProperty = switch (instance) {
      0 => Property.engine1Hours,
      1 => Property.engine2Hours,
      _ => null,
    };

    final coolantPressureProperty = switch (instance) {
      0 => Property.engine1CoolantPressure,
      1 => Property.engine2CoolantPressure,
      _ => null,
    };
    final fuelPressureProperty = switch (instance) {
      0 => Property.engine1FuelPressure,
      1 => Property.engine2FuelPressure,
      _ => null,
    };

    final values = <BoundValue>[];

    if (oilPressure != null && oilPressureProperty != null) {
      values.add(boundSingleValue(oilPressure, oilPressureProperty, tier: 1));
    }

    if (oilTemperature != null && oilTemperatureProperty != null) {
      values.add(boundSingleValue(oilTemperature, oilTemperatureProperty, tier: 1));
    }

    if (coolantTemperature != null && temperatureProperty != null) {
      values.add(boundSingleValue(coolantTemperature, temperatureProperty, tier: 1));
    }

    if (alternatorVoltage != null && alternatorProperty != null) {
      values.add(boundSingleValue(alternatorVoltage, alternatorProperty, tier: 1));
    }

    if (fuelRate != null && fuelRateProperty != null) {
      values.add(boundSingleValue(fuelRate, fuelRateProperty, tier: 1));
    }

    if (engineHours != null && engineHoursProperty != null) {
      values.add(boundSingleValue(engineHours, engineHoursProperty, tier: 1));
    }
    if (coolantPressure != null && coolantPressureProperty != null) {
      values.add(boundSingleValue(coolantPressure, coolantPressureProperty, tier: 1));
    }
    if (fuelPressure != null && fuelPressureProperty != null) {
      values.add(boundSingleValue(fuelPressure, fuelPressureProperty, tier: 1));
    }
    if (checkEngine != null && checkEngineProperty != null) {
      values.add(boundSingleValue(checkEngine, checkEngineProperty, tier: 1));
    }

    if (overTemperature != null && overTemperatureProperty != null) {
      values.add(boundSingleValue(overTemperature, overTemperatureProperty, tier: 1));
    }

    if (lowOilPressure != null && lowOilPressureProperty != null) {
      values.add(boundSingleValue(lowOilPressure, lowOilPressureProperty, tier: 1));
    }

    if (lowSystemVoltage != null && lowSystemVoltageProperty != null) {
      values.add(boundSingleValue(lowSystemVoltage, lowSystemVoltageProperty, tier: 1));
    }

    if (waterFlowAlarm != null && waterFlowAlarmProperty != null) {
      values.add(boundSingleValue(waterFlowAlarm, waterFlowAlarmProperty, tier: 1));
    }

    if (waterInFuel != null && waterInFuelProperty != null) {
      values.add(boundSingleValue(waterInFuel, waterInFuelProperty, tier: 1));
    }

    if (powerReduction != null && powerReductionProperty != null) {
      values.add(boundSingleValue(powerReduction, powerReductionProperty, tier: 1));
    }

    if (engineCommError != null && engineCommErrorProperty != null) {
      values.add(boundSingleValue(engineCommError, engineCommErrorProperty, tier: 1));
    }
    return values;
  }
}
