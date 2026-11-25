import 'dart:math' as math;

import 'package:flutter/material.dart';
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
    final double reserved = ref.watch(guideHintReservedHeightProvider);
    // Same widget structure with or without a hint, so the routed app keeps
    // its state when a hint appears or goes away.
    return MediaQuery.removePadding(
      context: context,
      removeTop: reserved > 0,
      child: Padding(
        padding: EdgeInsets.only(top: reserved),
        child: child,
      ),
    );
  }
}

/// Puts a hint card at the top of an overlay [Stack] and reserves its height
/// in [GuideHintSpace]. Nothing is shown or reserved while the visible area is
/// too short, for example with the keyboard open on a small phone.
class GuideHintSlot extends ConsumerStatefulWidget {
  const GuideHintSlot({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<GuideHintSlot> createState() => _GuideHintSlotState();
}

class _GuideHintSlotState extends ConsumerState<GuideHintSlot> {
  static const double _minimumVisibleHeight = 360;
  static const double _minimumCardHeight = 176;

  final GlobalKey _measuredKey = GlobalKey(debugLabel: 'guide-hint-slot');
  late final GuideHintReservedHeight _reservation;
  bool _measureScheduled = false;
  bool _fits = false;

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
      final double height = _fits
          ? _measuredKey.currentContext?.size?.height ?? 0
          : 0;
      _reservation.reserve(this, height);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double visibleHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    _fits = visibleHeight >= _minimumVisibleHeight;
    _scheduleMeasure();
    if (!_fits) return const SizedBox.shrink();
    final double maxCardHeight = math.max(
      _minimumCardHeight,
      visibleHeight * .45,
    );
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
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
