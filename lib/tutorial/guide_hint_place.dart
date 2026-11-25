import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The [GuidancePlaces] key each screen in view declared, by its route.
final guideHintPlacesProvider =
    NotifierProvider<GuideHintPlaces, Map<Route<dynamic>, String>>(
      GuideHintPlaces.new,
    );

class GuideHintPlaces extends Notifier<Map<Route<dynamic>, String>> {
  @override
  Map<Route<dynamic>, String> build() => const <Route<dynamic>, String>{};

  void declare(Route<dynamic> route, String place) {
    if (!ref.mounted || state[route] == place) return;
    state = <Route<dynamic>, String>{...state, route: place};
  }

  /// Forgets [route]'s place only if it is still [place], so a place that
  /// replaced it on the same route stays.
  void forget(Route<dynamic> route, String place) {
    if (!ref.mounted || state[route] != place) return;
    state = <Route<dynamic>, String>{...state}..remove(route);
  }
}

/// Marks the screen or area it wraps as a [GuidancePlaces] key, so the
/// contextual hint about it can appear while it is in view, including on a
/// screen opened on top of another without a router path of its own.
class GuideHintPlace extends ConsumerStatefulWidget {
  const GuideHintPlace({required this.place, required this.child, super.key});

  final String place;
  final Widget child;

  @override
  ConsumerState<GuideHintPlace> createState() => _GuideHintPlaceState();
}

class _GuideHintPlaceState extends ConsumerState<GuideHintPlace> {
  late final GuideHintPlaces _places;
  Route<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _places = ref.read(guideHintPlacesProvider.notifier);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Route<dynamic>? route = ModalRoute.of(context);
    if (identical(route, _route)) return;
    final Route<dynamic>? previous = _route;
    _route = route;
    final String place = widget.place;
    // Providers cannot change while widgets build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (previous != null) _places.forget(previous, place);
      if (mounted && route != null) _places.declare(route, place);
    });
  }

  @override
  void dispose() {
    final Route<dynamic>? route = _route;
    final GuideHintPlaces places = _places;
    final String place = widget.place;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => places.forget(route, place),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Counts saves of something with a reminder while notifications are off and
/// this account already refused the request. The guide overlay shows the
/// reminders hint once, on the screen in view when a new save is counted.
/// Kept in memory only: whether the hint was seen is stored with the guide.
final remindersOffHintRequestsProvider =
    NotifierProvider<RemindersOffHintRequests, int>(
      RemindersOffHintRequests.new,
    );

class RemindersOffHintRequests extends Notifier<int> {
  @override
  int build() => 0;

  void reminderSavedWhileOff() => state++;
}
