import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fantastic_guacamole/core/services/calendar_service.dart';

final calendarServiceProvider = Provider<CalendarService>(
  (ref) => CalendarService(),
);
