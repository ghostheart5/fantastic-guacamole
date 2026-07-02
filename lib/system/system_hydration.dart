class SystemHydration {
  bool _hydrated = false;

  bool get isHydrated => _hydrated;

  void hydrateIfNeeded() {
    if (_hydrated) return;
    _hydrated = true;
  }
}
