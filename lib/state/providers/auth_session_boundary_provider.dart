import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthSessionBoundary {
  const AuthSessionBoundary({
    required this.generation,
    required this.userId,
    required this.isTransitioning,
    required this.isStorageReady,
    this.blockingIssue,
    this.canRecoverBySigningOut = false,
    this.canDiscardPreservedLegacyData = false,
  });

  const AuthSessionBoundary.initial()
    : generation = 0,
      userId = null,
      isTransitioning = true,
      isStorageReady = false,
      blockingIssue = null,
      canRecoverBySigningOut = false,
      canDiscardPreservedLegacyData = false;

  final int generation;
  final String? userId;
  final bool isTransitioning;
  final bool isStorageReady;
  final String? blockingIssue;
  final bool canRecoverBySigningOut;
  final bool canDiscardPreservedLegacyData;
}

final authSessionBoundaryProvider =
    NotifierProvider<AuthSessionBoundaryNotifier, AuthSessionBoundary>(
      AuthSessionBoundaryNotifier.new,
    );

class AuthSessionBoundaryNotifier extends Notifier<AuthSessionBoundary> {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary.initial();

  int begin({required String? userId, required bool isTransitioning}) {
    final int generation = state.generation + 1;
    state = AuthSessionBoundary(
      generation: generation,
      userId: userId,
      isTransitioning: isTransitioning,
      isStorageReady: false,
      canRecoverBySigningOut: false,
      canDiscardPreservedLegacyData: false,
    );
    return generation;
  }

  void markStorageReady(int generation) {
    if (state.generation != generation) return;
    state = AuthSessionBoundary(
      generation: state.generation,
      userId: state.userId,
      isTransitioning: true,
      isStorageReady: true,
      canRecoverBySigningOut: false,
      canDiscardPreservedLegacyData: false,
    );
  }

  void complete(int generation, {bool storageReady = true}) {
    if (state.generation != generation) return;
    state = AuthSessionBoundary(
      generation: state.generation,
      userId: state.userId,
      isTransitioning: false,
      isStorageReady: storageReady,
      canRecoverBySigningOut: false,
      canDiscardPreservedLegacyData: false,
    );
  }

  void block(
    int generation, {
    String? issue,
    bool canRecoverBySigningOut = false,
    bool canDiscardPreservedLegacyData = false,
  }) {
    if (state.generation != generation) return;
    state = AuthSessionBoundary(
      generation: state.generation,
      userId: state.userId,
      isTransitioning: false,
      isStorageReady: state.isStorageReady,
      canRecoverBySigningOut: canRecoverBySigningOut,
      canDiscardPreservedLegacyData: canDiscardPreservedLegacyData,
      blockingIssue: issue ?? 'ChronoSpark could not isolate data safely.',
    );
  }
}
