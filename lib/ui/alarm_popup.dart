// Copyright Jody M Sankey 2026
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENCE.md file for details.

import 'package:flutter/material.dart';
import 'package:nmea_dashboard/state/alarms.dart';
import 'package:provider/provider.dart';

/// Wraps [child] with a banner overlay that surfaces triggered alarms.
///
/// The banner appears whenever any alarm is in `active` or `silenced` state,
/// stacks on top of the page content (visible across all dashboard pages),
/// and offers a single "Silence" action that mutes any audible alarms while
/// leaving the visual highlight in place.
class AlarmOverlay extends StatelessWidget {
  final Widget child;

  const AlarmOverlay({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Consumer<AlarmManager>(
            builder: (context, manager, _) {
              final triggered = manager.triggered.toList();
              if (triggered.isEmpty) return const SizedBox.shrink();
              return SafeArea(child: _AlarmBanner(triggered: triggered, manager: manager));
            },
          ),
        ),
      ],
    );
  }
}

class _AlarmBanner extends StatelessWidget {
  final List<TriggeredAlarm> triggered;
  final AlarmManager manager;

  const _AlarmBanner({required this.triggered, required this.manager});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasAudible = manager.audible.isNotEmpty;

    final names = triggered.map((t) => t.spec.name).join(', ');
    final headline = triggered.length == 1
        ? '1 alarm active'
        : '${triggered.length} alarms active';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Material(
        color: scheme.errorContainer,
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_outlined, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      names,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (hasAudible)
                TextButton(
                  onPressed: () {
                    for (final alarm in manager.audible.toList()) {
                      manager.silence(alarm.spec.key);
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: scheme.onErrorContainer),
                  child: const Text('SILENCE'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
