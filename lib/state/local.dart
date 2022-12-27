// Copyright Jody M Sankey 2022
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'dart:async';

import 'package:async/async.dart';

import 'common.dart';

const _interval = Duration(seconds: 1);

/// Returns an infinite stream of valid values read from the local device
/// network port, logging any errors.
Stream<Value> valuesFromLocalDevice() {
  return StreamGroup.merge([
    Stream.periodic(_interval, (_) {
      return SingleValue(DateTime.now(), Source.local, Property.localTime);
    }),
    Stream.periodic(_interval, (_) {
      return SingleValue(
          DateTime.now().toUtc(), Source.local, Property.utcTime);
    })
  ]);
}
