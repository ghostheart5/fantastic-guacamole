import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Explicit, optional operating context. It expires after two hours or at
/// the app closing and
/// is fenced against sign-out/account changes while the dialog is open.
class HumanStateCheckInDialog extends ConsumerStatefulWidget {
  const HumanStateCheckInDialog({required this.energy, super.key});

  final bool energy;

  @override
  ConsumerState<HumanStateCheckInDialog> createState() =>
      _HumanStateCheckInDialogState();
}

class _HumanStateCheckInDialogState
    extends ConsumerState<HumanStateCheckInDialog> {
  late final String? _account;
  late final int _generation;
  double? _reported;

  @override
  void initState() {
    super.initState();
    _account = ref.read(accountStorageScopeProvider).v2Namespace;
    _generation = ref.read(authSessionBoundaryProvider).generation;
    final state = ref.read(siStateProvider);
    _reported = widget.energy
        ? (state.hasObservedEnergy ? state.energy : null)
        : (state.hasObservedFatigue ? state.fatigue : null);
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(accountStorageScopeProvider);
    final validSession =
        scope.isAuthenticated &&
        scope.v2Namespace == _account &&
        ref.watch(authSessionBoundaryProvider).generation == _generation;
    return AlertDialog(
      title: Text(widget.energy ? 'Energy check-in' : 'Clarity check-in'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.energy
                  ? 'How much energy do you have right now?'
                  : 'How fatigued do you feel right now? Clarity is an estimate of 100% minus your reported fatigue, not a cognitive assessment.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Optional. Used for planning for up to two hours while the app stays open. You can clear it at any time.',
            ),
            const SizedBox(height: 12),
            Text(
              _reported == null
                  ? 'Not checked'
                  : '${widget.energy ? 'Energy' : 'Fatigue'}: ${(_reported! * 100).round()}%',
            ),
            Slider(
              label: '${((_reported ?? .5) * 100).round()}%',
              semanticFormatterCallback: (value) =>
                  '${widget.energy ? 'Energy' : 'Fatigue'} ${(value * 100).round()} percent',
              value: _reported ?? .5,
              divisions: 20,
              onChanged: validSession
                  ? (value) => setState(() => _reported = value)
                  : null,
            ),
            if (!validSession)
              const Text(
                'Your account changed. Close this check-in and reopen it.',
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: validSession ? () => _save(null) : null,
          child: const Text('Clear'),
        ),
        FilledButton(
          onPressed: validSession && _reported != null
              ? () => _save(_reported)
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save(double? value) {
    final scope = ref.read(accountStorageScopeProvider);
    if (!scope.isAuthenticated ||
        scope.v2Namespace != _account ||
        ref.read(authSessionBoundaryProvider).generation != _generation) {
      return;
    }
    final state = ref.read(siStateProvider);
    ref
        .read(siStateProvider.notifier)
        .replaceState(
          energy: widget.energy ? value ?? .5 : state.energy,
          fatigue: widget.energy ? state.fatigue : value ?? .5,
          energyOrigin: widget.energy
              ? (value == null
                    ? PredictiveEvidenceOrigin.unavailable
                    : PredictiveEvidenceOrigin.observed)
              : null,
          fatigueOrigin: widget.energy
              ? null
              : (value == null
                    ? PredictiveEvidenceOrigin.unavailable
                    : PredictiveEvidenceOrigin.observed),
        );
    Navigator.pop(context);
  }
}
