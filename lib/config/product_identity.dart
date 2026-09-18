/// User-facing product identity for the post-ChronoSpark experience.
///
/// Route names, storage keys, package identifiers and migration aliases remain
/// stable so an identity change never strands an existing user's data.
abstract final class ProductIdentity {
  static const String name = 'Axiomara';
  static const String wordmark = 'AXIOMARA';
  static const String category = 'Human Decision OS';
  static const String signature = 'AXIOMARA // HUMAN DECISION OS';

  /// Kept for support, migration and account continuity disclosures.
  static const String legacyName = 'ChronoSpark';
}
