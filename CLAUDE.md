# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

NMEA Dashboard is a Flutter app that displays real-time marine vessel data (GPS, wind, speed, engine, fuel, etc.) received over TCP/UDP network connections. It is published on the Android Play Store.

## Common Commands

```bash
flutter analyze          # Lint/static analysis
flutter test             # Run all tests
flutter run              # Run in debug mode
```

Line width is 100 characters (configured in `analysis_options.yaml`).

## Architecture

Data flows through these layers:

1. **Network** (`lib/state/network.dart`) — Opens TCP/UDP socket; emits raw NMEA sentence strings as a stream with auto-retry.
2. **Parser** (`lib/state/nmea.dart`) — Parses NMEA 0183 sentences into typed `SourceValue` objects mapped by `Property` enum.
3. **DataSet** (`lib/state/data_set.dart`) — Central aggregator. Holds `DataElement` objects for network data, local device sensors, and user-defined derived values. Extends `ChangeNotifier` for reactive UI updates via `provider`.
4. **UI** — A `PageView` of `DataTablePage` grids, each containing cells (`CurrentValueCell`, `HistoryCell`, `AverageValueCell`, `TextCell`). Settings, page editor, and derived data editor are in `lib/ui/forms/`.

### Key Abstractions

- **`DataElement<V, U>`** (`lib/state/data_element.dart`) — Base for all data values; tracks staleness and notifies listeners.
- **`Property` / `Dimension` / `Source`** (`lib/state/common.dart`) — Core enums that identify every kind of data the app can display and where it comes from.
- **Specs** (`lib/state/specs.dart`) — JSON-serializable structs (`PageSpec`, `CellSpec`, `DerivedDataSpec`) that define the full UI layout; persisted via `SharedPreferences`.
- **`Settings`** (`lib/state/settings.dart`) — All user preferences (network config, units, theme) backed by `SharedPreferences`.
- **Formatting** (`lib/state/formatting.dart`) — Unit conversions and display formatting for all value types.

## Approach

- Think before acting. Read existing files before writing code.
- Be concise in output but thorough in reasoning.
- Prefer editing over rewriting whole files.
- Do not re-read files you have already read unless the file may have changed.
- Test your code before declaring done.
- No sycophantic openers or closing fluff.
- Keep solutions simple and direct.
- User instructions always override this file.

