import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:flutter/material.dart';

/// Opens the date-bound Schedule without replacing the primary My plan tab.
/// Keeping this as a pushed route also returns to the originating preview on Back.
Future<void> openSchedule(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(builder: (_) => const TimelineScreen()));
