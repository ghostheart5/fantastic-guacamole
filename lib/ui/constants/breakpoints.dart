/// Centralizes the width thresholds that individual screens previously
/// re-derived on their own (Phase 6, M-1) — 340/390 for Nexus and Login's
/// "ultraCompact"/"compact" pairs, 760 for SI Console's single "compact"
/// threshold. Values match what was already in use; this is a consolidation
/// pass, not a new set of cutoffs.
class Breakpoints {
  const Breakpoints._();

  static const double ultraCompact = 340;
  static const double compact = 390;
  static const double medium = 760;
}

enum WidthClass {
  ultraCompact,
  compact,
  regular;

  static WidthClass of(double width) {
    if (width < Breakpoints.ultraCompact) return WidthClass.ultraCompact;
    if (width < Breakpoints.compact) return WidthClass.compact;
    return WidthClass.regular;
  }
}
