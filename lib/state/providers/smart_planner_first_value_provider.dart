import 'package:flutter_riverpod/flutter_riverpod.dart';

const Duration smartPlannerFirstValueRequestLifetime = Duration(minutes: 10);

final smartPlannerFirstValueProvider =
    NotifierProvider<
      SmartPlannerFirstValueNotifier,
      SmartPlannerFirstValueRequest?
    >(SmartPlannerFirstValueNotifier.new);

final class SmartPlannerFirstValueRequest {
  SmartPlannerFirstValueRequest({
    required String accountScopeId,
    String? prompt,
    this.energy,
    required DateTime createdAt,
  }) : accountScopeId = _normalizeAccountScopeId(accountScopeId),
       prompt = _normalizePrompt(prompt),
       createdAt = createdAt.toUtc() {
    final double? value = energy;
    if (value != null && (!value.isFinite || value < 0 || value > 1)) {
      throw ArgumentError.value(
        value,
        'energy',
        'must be finite and between 0 and 1',
      );
    }
  }

  final String accountScopeId;
  final String? prompt;
  final double? energy;
  final DateTime createdAt;

  DateTime get expiresAt =>
      createdAt.add(smartPlannerFirstValueRequestLifetime);

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt);
}

final class SmartPlannerFirstValueNotifier
    extends Notifier<SmartPlannerFirstValueRequest?> {
  @override
  SmartPlannerFirstValueRequest? build() => null;

  void stage(SmartPlannerFirstValueRequest request) => state = request;

  SmartPlannerFirstValueRequest? takeFor({
    required String accountScopeId,
    required DateTime now,
  }) {
    final SmartPlannerFirstValueRequest? pending = state;
    if (pending == null) return null;

    state = null;
    final String currentAccountScopeId = accountScopeId.trim();
    final DateTime currentTime = now.toUtc();
    if (currentAccountScopeId.isEmpty ||
        pending.accountScopeId != currentAccountScopeId ||
        pending.createdAt.isAfter(currentTime) ||
        pending.isExpiredAt(currentTime)) {
      return null;
    }
    return pending;
  }
}

String _normalizeAccountScopeId(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, 'accountScopeId', 'must not be blank');
  }
  return normalized;
}

String? _normalizePrompt(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
