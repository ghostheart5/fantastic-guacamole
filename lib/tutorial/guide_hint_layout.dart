import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Height kept free at the top of the app for a visible hint card, so the
/// hint moves the page down instead of covering its controls, its notices or
/// the bottom navigation.
final guideHintReservedHeightProvider =
    NotifierProvider<GuideHintReservedHeight, double>(
      GuideHintReservedHeight.new,
    );

class GuideHintReservedHeight extends Notifier<double> {
  Object? _owner;

  @override
  double build() => 0;

  void reserve(Object owner, double height) {
    if (!ref.mounted) return;
    _owner = owner;
    if (state != height) state = height;
  }

  /// Frees the space only if [owner] still holds it, so a hint closing on one
  /// screen cannot remove the space of a hint that opened on the next.
  void release(Object owner) {
    if (!ref.mounted || !identical(_owner, owner)) return;
    _owner = null;
    if (state != 0) state = 0;
  }
}

/// Wraps the routed app so it starts below a visible hint card. Without a
/// hint it changes nothing.
class GuideHintSpace extends ConsumerWidget {
  const GuideHintSpace({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A hint never keeps space while the keyboard is open (GuideHintSlot
    // draws nothing then); dropping it here too, in the same frame, keeps
    // the page from being squeezed while the keyboard comes up.
    final double held = ref.watch(guideHintReservedHeightProvider);
    final double reserved = MediaQuery.viewInsetsOf(context).bottom > 0
        ? 0
        : held;
    // Same widget structure with or without a hint, so the routed app keeps
    // its state when a hint appears or goes away.
    return MediaQuery.removePadding(
      context: context,
      removeTop: reserved > 0,
      child: Padding(
        padding: EdgeInsets.only(top: reserved),
        // Sorted after the hint card ([GuideHintSlot] uses -1), so screen
        // readers reach the hint first. Both need a key for the order to
        // apply.
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          sortKey: const OrdinalSortKey(0),
          child: child,
        ),
      ),
    );
  }
}

/// Counts dialogs and bottom sheets open in the router's root navigator, so
/// a hint drawn above the app can step aside while one is on top, and keeps
/// the screens in it in order, so a hint about the router's page is not
/// drawn above a screen pushed on top of it. Register it in the router's
/// `observers` and call [attachTo] with that router.
class GuideHintModalObserver extends NavigatorObserver with ChangeNotifier {
  static final Expando<GuideHintModalObserver> _byRouter =
      Expando<GuideHintModalObserver>('guide-hint-modal-observer');

  /// The observer registered for [router], if any.
  static GuideHintModalObserver? of(Object router) => _byRouter[router];

  void attachTo(Object router) => _byRouter[router] = this;

  int _openModals = 0;
  final List<Route<dynamic>> _screens = <Route<dynamic>>[];

  bool get hasModalOnTop => _openModals > 0;

  /// The full screen on top, ignoring dialogs and sheets.
  Route<dynamic>? get topScreen {
    _screens.removeWhere((Route<dynamic> route) => !route.isActive);
    return _screens.isEmpty ? null : _screens.last;
  }

  /// Whether [route] was pushed directly (for example with
  /// `Navigator.push`) rather than by the router, so the router's location
  /// does not describe it.
  static bool isPushedScreen(Route<dynamic> route) =>
      route.settings is! Page<dynamic>;

  void _change(Route<dynamic>? route, int delta) {
    if (route is PageRoute<dynamic>) {
      delta > 0 ? _screens.add(route) : _screens.remove(route);
    } else if (route is PopupRoute<dynamic>) {
      _openModals = math.max(0, _openModals + delta);
    } else {
      return;
    }
    // Navigation can happen while widgets are building; tell listeners after.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, 1);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, -1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, -1);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _change(oldRoute, -1);
    _change(newRoute, 1);
  }
}

/// Puts a hint card at the top of an overlay [Stack] and reserves its height
/// in [GuideHintSpace].
///
/// Rules:
/// - Nothing is drawn or reserved while the keyboard is open or the visible
///   area is shorter than 360 dp (split screen, landscape phones).
/// - [onShown] is called once, after the card has actually been laid out on
///   screen and is not hidden. Only then does it count as seen.
/// - If the keyboard opens after the card was seen, the card leaves for the
///   rest of this visit, so the page does not jump back while the person
///   types. A card that was never seen appears once the keyboard closes.
/// - While [hidden] (a dialog or sheet is on top) a card already seen keeps
///   its space, so nothing moves under the dialog, but it is not drawn,
///   tappable or read by screen readers. A card not yet seen waits.
class GuideHintSlot extends ConsumerStatefulWidget {
  const GuideHintSlot({
    required this.child,
    this.hidden = false,
    this.onShown,
    super.key,
  });

  final Widget child;
  final bool hidden;
  final VoidCallback? onShown;

  @override
  ConsumerState<GuideHintSlot> createState() => _GuideHintSlotState();
}

class _GuideHintSlotState extends ConsumerState<GuideHintSlot> {
  static const double _minimumVisibleHeight = 360;
  static const double _minimumCardHeight = 176;

  final GlobalKey _measuredKey = GlobalKey(debugLabel: 'guide-hint-slot');
  late final GuideHintReservedHeight _reservation;
  bool _measureScheduled = false;
  bool _laidOut = false;
  bool _seen = false;
  bool _closedByKeyboard = false;

  @override
  void initState() {
    super.initState();
    _reservation = ref.read(guideHintReservedHeightProvider.notifier);
  }

  @override
  void dispose() {
    // The tree is locked while this is disposed; give the space back after.
    final GuideHintReservedHeight reservation = _reservation;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => reservation.release(this),
    );
    super.dispose();
  }

  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      final double height = _laidOut
          ? _measuredKey.currentContext?.size?.height ?? 0
          : 0;
      _reservation.reserve(this, height);
      if (height > 0 && !widget.hidden && !_seen) {
        _seen = true;
        widget.onShown?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.sizeOf(context).height;
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (keyboardOpen && _seen) _closedByKeyboard = true;
    _laidOut =
        !_closedByKeyboard &&
        !keyboardOpen &&
        height >= _minimumVisibleHeight &&
        (_seen || !widget.hidden);
    _scheduleMeasure();
    if (!_laidOut) return const SizedBox.shrink();
    final double maxCardHeight = math.max(_minimumCardHeight, height * .45);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          _scheduleMeasure();
          return true;
        },
        child: SizeChangedLayoutNotifier(
          child: SafeArea(
            key: _measuredKey,
            bottom: false,
            minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: maxCardHeight,
                ),
                // The card sits at the top, so screen readers reach it
                // before the page below.
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  sortKey: const OrdinalSortKey(-1),
                  child: Visibility(
                    visible: !widget.hidden,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
