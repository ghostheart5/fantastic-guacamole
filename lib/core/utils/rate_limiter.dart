class SlidingWindowRateLimiter {
  SlidingWindowRateLimiter({
    required this.maxRequests,
    required this.window,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int maxRequests;
  final Duration window;
  final DateTime Function() _now;
  final List<DateTime> _events = <DateTime>[];

  bool tryAcquire() {
    _evict();
    if (_events.length >= maxRequests) return false;
    _events.add(_now());
    return true;
  }

  /// How many requests can still be made in the current window.
  int get remaining {
    _evict();
    return (maxRequests - _events.length).clamp(0, maxRequests);
  }

  /// How long until the next slot opens, or null if a slot is available now.
  Duration? get timeUntilNextSlot {
    _evict();
    if (_events.length < maxRequests) return null;
    final DateTime oldest = _events.first;
    final Duration wait = oldest.add(window).difference(_now());
    return wait.isNegative ? null : wait;
  }

  void reset() => _events.clear();

  void _evict() {
    final DateTime cutoff = _now().subtract(window);
    _events.removeWhere((DateTime t) => t.isBefore(cutoff));
  }
}
