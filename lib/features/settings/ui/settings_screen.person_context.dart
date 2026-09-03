part of 'settings_screen.dart';

class _PersonContextSection extends ConsumerWidget {
  const _PersonContextSection();

  static const Set<PersonContextKind> _aboutYouKinds = <PersonContextKind>{
    PersonContextKind.role,
    PersonContextKind.value,
    PersonContextKind.lifeArea,
    PersonContextKind.preferredSupportStyle,
    PersonContextKind.boundary,
    PersonContextKind.importantRelationship,
  };

  static const Set<PersonContextKind> _rightNowKinds = <PersonContextKind>{
    PersonContextKind.currentPriority,
    PersonContextKind.presentCapacity,
    PersonContextKind.commitment,
  };

  String _kindLabel(PersonContextKind kind) => switch (kind) {
    PersonContextKind.role => 'Role',
    PersonContextKind.value => 'Value',
    PersonContextKind.currentPriority => 'Current priority',
    PersonContextKind.lifeArea => 'Life area',
    PersonContextKind.presentCapacity => 'Capacity right now',
    PersonContextKind.preferredSupportStyle => 'Preferred support style',
    PersonContextKind.boundary => 'Boundary',
    PersonContextKind.importantRelationship => 'Important relationship',
    PersonContextKind.commitment => 'Commitment',
    PersonContextKind.outcomeHistory => 'Confirmed outcome',
  };

  String _surfaceLabel(PersonContextSurface surface) => switch (surface) {
    PersonContextSurface.smartPlanner => 'Smart Planner',
    PersonContextSurface.siConsole => 'SI Console',
    PersonContextSurface.nexus => 'Nexus',
    PersonContextSurface.trajectory => 'Trajectory',
    PersonContextSurface.creator => 'Creator',
    PersonContextSurface.settings => 'Settings',
  };

  PersonContextPurpose _purposeFor(PersonContextKind kind) => switch (kind) {
    PersonContextKind.role ||
    PersonContextKind.value ||
    PersonContextKind.lifeArea ||
    PersonContextKind.currentPriority ||
    PersonContextKind.presentCapacity ||
    PersonContextKind.commitment => PersonContextPurpose.decisionSupport,
    PersonContextKind.preferredSupportStyle ||
    PersonContextKind.boundary ||
    PersonContextKind.importantRelationship =>
      PersonContextPurpose.planningGuidance,
    PersonContextKind.outcomeHistory => PersonContextPurpose.outcomeLearning,
  };

  Duration _freshnessFor(PersonContextKind kind) => switch (kind) {
    PersonContextKind.presentCapacity => const Duration(hours: 24),
    PersonContextKind.currentPriority ||
    PersonContextKind.commitment => const Duration(days: 30),
    PersonContextKind.outcomeHistory => const Duration(days: 90),
    _ => const Duration(days: 180),
  };

  Duration _expiryFor(PersonContextKind kind) => switch (kind) {
    PersonContextKind.presentCapacity => const Duration(hours: 24),
    PersonContextKind.currentPriority ||
    PersonContextKind.commitment => const Duration(days: 90),
    _ => const Duration(days: 366),
  };

  PersonContextDeletionBehavior _deletionFor(PersonContextKind kind) =>
      kind == PersonContextKind.presentCapacity
      ? PersonContextDeletionBehavior.expiresAutomatically
      : PersonContextDeletionBehavior.userRemovable;

  String _date(DateTime value) =>
      value.toLocal().toIso8601String().split('T').first;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final TextEditingController textController = TextEditingController();
    PersonContextKind kind = PersonContextKind.currentPriority;
    final Set<PersonContextSurface> selected = <PersonContextSurface>{};
    final _PersonContextDraft? draft = await showDialog<_PersonContextDraft>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final String grouping = _aboutYouKinds.contains(kind)
              ? 'About you'
              : 'Right now';
          return AlertDialog(
            title: const Text('Add person context'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Nothing is inferred. ChronoSpark will use only the exact text you choose to save.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Before you opt in: Person Context is stored only on this device, excluded from backup and sync, and will not be restored after reinstalling ChronoSpark or changing devices.',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PersonContextKind>(
                      key: const Key('person-context-kind'),
                      initialValue: kind,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items:
                          <PersonContextKind>[
                                ..._aboutYouKinds,
                                ..._rightNowKinds,
                              ]
                              .map(
                                (PersonContextKind value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_kindLabel(value)),
                                ),
                              )
                              .toList(growable: false),
                      onChanged: (PersonContextKind? value) {
                        if (value != null) {
                          setState(() {
                            kind = value;
                            selected.retainAll(
                              allowedPersonContextSurfacesFor(
                                _purposeFor(value),
                              ),
                            );
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('$grouping · ${_purposeFor(kind).name}'),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('person-context-value'),
                      controller: textController,
                      minLines: 2,
                      maxLines: 5,
                      maxLength: PersonContextSignal.maxValueLength,
                      decoration: const InputDecoration(
                        labelText: 'Exact text to remember',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Where may ChronoSpark use this?'),
                    const Text(
                      'Settings review is administrative and does not require behavioral consent.',
                    ),
                    ...allowedPersonContextSurfacesFor(_purposeFor(kind)).map(
                      (PersonContextSurface surface) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_surfaceLabel(surface)),
                        value: selected.contains(surface),
                        onChanged: (bool? checked) {
                          setState(() {
                            if (checked ?? false) {
                              selected.add(surface);
                            } else {
                              selected.remove(surface);
                            }
                          });
                        },
                      ),
                    ),
                    Text(
                      'Fresh for ${_freshnessFor(kind).inHours <= 24 ? '${_freshnessFor(kind).inHours} hours' : '${_freshnessFor(kind).inDays} days'} · expires after ${_expiryFor(kind).inHours <= 24 ? '${_expiryFor(kind).inHours} hours' : '${_expiryFor(kind).inDays} days'}',
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('person-context-confirm-add'),
                onPressed: () {
                  final String text = textController.text.trim();
                  if (text.isEmpty || selected.isEmpty) return;
                  Navigator.of(dialogContext).pop(
                    _PersonContextDraft(
                      kind: kind,
                      value: text,
                      surfaces: selected,
                    ),
                  );
                },
                child: const Text('Save with consent'),
              ),
            ],
          );
        },
      ),
    );
    textController.dispose();
    if (draft == null) return;
    final DateTime now = ref.read(personContextClockProvider)().toUtc();
    final int existingCount =
        ref.read(personContextSpineProvider).value?.signals.length ?? 0;
    final PersonContextSignal signal = PersonContextSignal(
      id: '${draft.kind.name}-${now.microsecondsSinceEpoch}-$existingCount',
      kind: draft.kind,
      value: draft.value,
      source: PersonContextSource.userAuthored,
      consent: PersonContextConsent.granted,
      consentedAt: now,
      purpose: _purposeFor(draft.kind),
      surfaceScopes: draft.surfaces,
      recordedAt: now,
      freshUntil: now.add(_freshnessFor(draft.kind)),
      expiresAt: now.add(_expiryFor(draft.kind)),
      exportBehavior: PersonContextExportBehavior.include,
      deletionBehavior: _deletionFor(draft.kind),
    );
    try {
      await ref.read(personContextActionsProvider).upsert(signal);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Person context saved with consent.')),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _correct(
    BuildContext context,
    WidgetRef ref,
    PersonContextSignal signal,
  ) async {
    final TextEditingController valueController = TextEditingController(
      text: signal.value,
    );
    final TextEditingController reasonController = TextEditingController();
    final _PersonContextCorrectionDraft? draft =
        await showDialog<_PersonContextCorrectionDraft>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Correct person context'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: valueController,
                    maxLength: PersonContextSignal.maxValueLength,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Exact text'),
                  ),
                  TextField(
                    controller: reasonController,
                    maxLength: PersonContextCorrection.maxReasonLength,
                    decoration: const InputDecoration(
                      labelText: 'Why are you correcting it?',
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final String value = valueController.text.trim();
                  final String reason = reasonController.text.trim();
                  if (value.isEmpty || reason.isEmpty) return;
                  Navigator.of(dialogContext).pop(
                    _PersonContextCorrectionDraft(value: value, reason: reason),
                  );
                },
                child: const Text('Save correction'),
              ),
            ],
          ),
        );
    valueController.dispose();
    reasonController.dispose();
    if (draft == null) return;
    final DateTime now = ref.read(personContextClockProvider)().toUtc();
    await ref
        .read(personContextActionsProvider)
        .correct(
          signalId: signal.id,
          value: draft.value,
          correctedAt: now,
          reason: draft.reason,
          freshUntil: now.add(_freshnessFor(signal.kind)),
          expiresAt: now.add(_expiryFor(signal.kind)),
        );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    PersonContextSignal signal,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete this person context?'),
            content: Text(
              '“${signal.value}” will be permanently removed. Tasks, goals, and Timeline items are unchanged.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(personContextActionsProvider).remove(signal.id);
  }

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    PersonContextSignal signal,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Withdraw consent?'),
            content: Text(
              'ChronoSpark will immediately stop using “${signal.value}”. The timestamped record remains available for review, export, correction, or deletion.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Withdraw consent'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final DateTime now = ref.read(personContextClockProvider)().toUtc();
    await ref
        .read(personContextActionsProvider)
        .withdrawConsent(signalId: signal.id, withdrawnAt: now);
  }

  Future<void> _review(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          final AsyncValue<PersonContextSpine?> spineAsync = ref.watch(
            personContextSpineProvider,
          );
          return AlertDialog(
            title: const Text('Review person context'),
            content: SizedBox(
              width: 620,
              child: spineAsync.when(
                loading: () => const Text('Loading consented context…'),
                error: (_, _) => const Text(
                  'Recoverable context data needs attention and is not available for review.',
                ),
                data: (PersonContextSpine? spine) {
                  final List<PersonContextSignal>? signals = spine?.signals;
                  if (signals == null) {
                    return const Text(
                      'Person context is unavailable for this account.',
                    );
                  }
                  if (signals.isEmpty) {
                    return const Text(
                      'Not provided. ChronoSpark will not invent personal context.',
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: signals.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (BuildContext context, int index) {
                      final PersonContextSignal signal = signals[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(signal.value),
                        subtitle: Text(
                          '${_kindLabel(signal.kind)} · ${signal.source.name}\n'
                          'Purpose: ${signal.purpose.name} · Consent: ${signal.consent.name}\n'
                          'Surfaces: ${signal.surfaceScopes.map(_surfaceLabel).join(', ')}\n'
                          'Fresh until: ${_date(signal.freshUntil)} · Expires: ${_date(signal.expiresAt)}\n'
                          'Corrections: ${signal.corrections.length} · Export: ${signal.exportBehavior.name} · Deletion: ${signal.deletionBehavior.name}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (signal.consent == PersonContextConsent.granted)
                              IconButton(
                                tooltip: 'Withdraw consent',
                                onPressed: () => unawaited(
                                  _withdraw(dialogContext, ref, signal),
                                ),
                                icon: const Icon(Icons.block_outlined),
                              ),
                            IconButton(
                              tooltip: 'Correct',
                              onPressed: () => unawaited(
                                _correct(dialogContext, ref, signal),
                              ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => unawaited(
                                _remove(dialogContext, ref, signal),
                              ),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final Map<String, dynamic> export = await ref
          .read(personContextActionsProvider)
          .export();
      await Clipboard.setData(
        ClipboardData(text: const JsonEncoder.withIndent('  ').convert(export)),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Person context export copied.')),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deleteAll(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    if (count == 0) return;
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete all person context?'),
            content: Text(
              'This permanently removes $count user-authored context item${count == 1 ? '' : 's'}. Tasks, goals, and Timeline items are unchanged.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete all'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(personContextActionsProvider).clear();
  }

  Future<void> _clearCorruptData(BuildContext context, WidgetRef ref) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Permanently clear corrupt Person Context?'),
            content: const Text(
              'This permanently clears only recoverable or corrupt Person Context payloads stored on this device. Tasks, goals, and Timeline items are unaffected. This cannot be undone.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('person-context-confirm-clear-corrupt'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Permanently clear'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await ref.read(personContextActionsProvider).clear();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Corrupt Person Context data cleared.')),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PersonContextSpine?> spineAsync = ref.watch(
      personContextSpineProvider,
    );
    return _Section(
      label: 'PERSON CONTEXT',
      accentColor: AppColors.neonViolet,
      child: spineAsync.when(
        loading: () => const _NeonStatusTile(
          title: 'Person context',
          subtitle: 'Loading consented context…',
        ),
        error: (Object error, _) {
          if (error is PersonContextCorruptionException) {
            return Column(
              children: <Widget>[
                const _NeonStatusTile(
                  title: 'Person context unavailable',
                  subtitle:
                      'Recoverable context data needs attention. It is not being treated as empty or used for guidance.',
                ),
                _NeonNavTile(
                  title: 'Clear corrupt Person Context data',
                  subtitle:
                      'Permanently clears only recoverable or corrupt Person Context payloads.',
                  onTap: () => unawaited(_clearCorruptData(context, ref)),
                ),
              ],
            );
          }
          return Column(
            children: <Widget>[
              const _NeonStatusTile(
                title: 'Person context temporarily unavailable',
                subtitle:
                    'Stored context was not changed or treated as empty. Retry after the account or device storage is ready.',
              ),
              _NeonNavTile(
                title: 'Retry person context',
                subtitle: 'Attempts a fresh read without deleting anything.',
                onTap: () => ref.invalidate(personContextSpineProvider),
              ),
            ],
          );
        },
        data: (PersonContextSpine? spine) {
          if (spine == null) {
            return const _NeonStatusTile(
              title: 'Person context unavailable',
              subtitle:
                  'A verified signed-in account is required. No personal context will be invented.',
            );
          }
          final List<PersonContextSignal> aboutYou = spine.signals
              .where((signal) => _aboutYouKinds.contains(signal.kind))
              .toList(growable: false);
          final List<PersonContextSignal> rightNow = spine.signals
              .where((signal) => _rightNowKinds.contains(signal.kind))
              .toList(growable: false);
          final int outcomes = spine.signals
              .where(
                (signal) => signal.kind == PersonContextKind.outcomeHistory,
              )
              .length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Text(
                  'Optional and co-authored. ChronoSpark uses only the exact context you save, only for the purposes and surfaces you choose. Unknown stays unknown.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Stored only on this device. Person Context is excluded from backup and sync, and will not be restored after reinstalling ChronoSpark or changing devices.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              _NeonStatusTile(
                title: 'About you',
                subtitle: aboutYou.isEmpty
                    ? 'Not provided'
                    : '${aboutYou.length} reviewable item${aboutYou.length == 1 ? '' : 's'}',
              ),
              _NeonStatusTile(
                title: 'Right now',
                subtitle: rightNow.isEmpty
                    ? 'Not provided'
                    : '${rightNow.length} freshness-limited item${rightNow.length == 1 ? '' : 's'}',
              ),
              _NeonStatusTile(
                title: 'Confirmed outcomes',
                subtitle: outcomes == 0
                    ? 'No outcome history recorded'
                    : '$outcomes reviewable outcome${outcomes == 1 ? '' : 's'}',
              ),
              _NeonNavTile(
                title: 'Add person context',
                subtitle: 'Choose exact text, purpose, surfaces, and expiry.',
                onTap: () => unawaited(_add(context, ref)),
              ),
              _NeonNavTile(
                title: 'Review and correct',
                subtitle:
                    'Inspect source, consent, scope, freshness, history, and controls.',
                onTap: () => unawaited(_review(context)),
              ),
              _NeonNavTile(
                title: 'Export person context',
                subtitle: 'Copies only items marked for export.',
                onTap: () => unawaited(_export(context, ref)),
              ),
              _NeonNavTile(
                title: 'Delete all person context',
                subtitle:
                    'Permanently removes all ${spine.signals.length} context items.',
                onTap: () =>
                    unawaited(_deleteAll(context, ref, spine.signals.length)),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _PersonContextDraft {
  const _PersonContextDraft({
    required this.kind,
    required this.value,
    required this.surfaces,
  });

  final PersonContextKind kind;
  final String value;
  final Set<PersonContextSurface> surfaces;
}

final class _PersonContextCorrectionDraft {
  const _PersonContextCorrectionDraft({
    required this.value,
    required this.reason,
  });

  final String value;
  final String reason;
}
