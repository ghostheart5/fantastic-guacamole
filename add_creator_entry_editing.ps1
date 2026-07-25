$ErrorActionPreference = "Stop"

Write-Host "Adding Creator entry editing..." -ForegroundColor Cyan

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$taskProviderPath = ".\lib\state\providers\task_provider.dart"
$entryListsPath = ".\lib\features\creator\ui\widgets\creator_entry_lists.dart"

if (-not (Test-Path $taskProviderPath)) {
  throw "Missing task provider: $taskProviderPath"
}

if (-not (Test-Path $entryListsPath)) {
  throw "Missing Creator entry lists: $entryListsPath"
}

Copy-Item $taskProviderPath "$taskProviderPath.bak_creator_edit" -Force
Copy-Item $entryListsPath "$entryListsPath.bak_creator_edit" -Force

# ------------------------------------------------------------
# Add TaskActions.updateCreatorEntry
# ------------------------------------------------------------
$provider = Get-Content $taskProviderPath -Raw

if ($provider -notmatch "updateCreatorEntry") {
  $method = @"
  Future<void> updateCreatorEntry({
    required String id,
    required String title,
    String? description,
    required int priority,
  }) async {
    final String trimmedTitle = title.trim();
    if (id.trim().isEmpty || trimmedTitle.isEmpty) {
      throw StateError('Creator entry is missing required fields.');
    }

    final TaskEntity? existing = await _ref
        .read(domainTaskRepositoryProvider)
        .getTaskById(id);

    if (existing == null || existing.isCompleted || existing.isCanceled) {
      throw StateError('Creator entry not found.');
    }

    final String? normalizedDescription =
        description == null || description.trim().isEmpty
        ? null
        : description.trim();

    final TaskEntity updated = existing.copyWith(
      title: trimmedTitle,
      description: normalizedDescription,
      priority: priority.clamp(1, 5),
    );

    await _ref.read(updateTaskUseCaseProvider).call(updated);

    await _bestEffort(
      () => _ref
          .read(logsActionsProvider)
          .addMirroredEntry(source: 'creator_entry_updated', message: updated.title),
    );

    _ref
        .read(eventBusProvider)
        .emit(
          TaskLifecycleEvent(
            taskId: updated.id,
            title: updated.title,
            action: 'updated',
          ),
        );

    _ref.invalidate(tasksProvider);
    _ref.invalidate(goalProgressProvider);
    _ref.invalidate(domainSiDecisionProvider);
  }

"@

  $marker = "  Future<void> _refreshCoachDecision"
  if (-not $provider.Contains($marker)) {
    throw "Could not find insertion point in task_provider.dart."
  }

  $provider = $provider.Replace($marker, $method + $marker)
  [System.IO.File]::WriteAllText($taskProviderPath, $provider, $utf8NoBom)
}

# ------------------------------------------------------------
# Add edit flow to CreatorEntryLists
# ------------------------------------------------------------
$entry = Get-Content $entryListsPath -Raw

if ($entry -notmatch "updateEntry\(Task entry") {
  $updateBlock = @"
    Future<void> updateEntry(
      Task entry, {
      required String title,
      String? description,
      required int priority,
    }) async {
      await ref.read(taskActionsProvider).updateCreatorEntry(
            id: entry.id,
            title: title,
            description: description,
            priority: priority,
          );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Updated ' + title + '.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }

"@

  $marker = "    void openEntry(Task entry) {"
  if (-not $entry.Contains($marker)) {
    throw "Could not find openEntry insertion point."
  }

  $entry = $entry.Replace($marker, $updateBlock + $marker)
}

# Add onEdit callback in _CreatorEntryDetailSheet call.
if ($entry -notmatch "onEdit: \(\) async") {
  $entry = [System.Text.RegularExpressions.Regex]::Replace(
    $entry,
    "(?s)(return _CreatorEntryDetailSheet\([\s\S]*?onSkip: \(\) async \{[\s\S]*?await skipEntry\(entry\);\s*\},)(\s*\);)",
    {
      param($m)
      $m.Groups[1].Value + @"

            onEdit: () async {
              Navigator.of(sheetContext).maybePop();
              await Future<void>.delayed(
                const Duration(milliseconds: 120),
              );
              if (!context.mounted) {
                return;
              }
              await showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (editContext) {
                  return _CreatorEntryEditSheet(
                    entry: entry,
                    onSave: (title, description, priority) async {
                      Navigator.of(editContext).maybePop();
                      await updateEntry(
                        entry,
                        title: title,
                        description: description,
                        priority: priority,
                      );
                    },
                  );
                },
              );
            },
"@ + $m.Groups[2].Value
    }
  )
}

# Patch detail sheet constructor and fields.
if ($entry -notmatch "required this.onEdit") {
  $entry = $entry.Replace(
"    required this.onSkip,",
"    required this.onSkip,
    required this.onEdit,"
  )

  $entry = $entry.Replace(
"  final Future<void> Function() onSkip;",
"  final Future<void> Function() onSkip;
  final Future<void> Function() onEdit;"
  )
}

# Add Edit button to detail sheet action row.
if ($entry -notmatch "label: 'Edit'") {
  $entry = $entry.Replace(
"                  children: [
                    Expanded(
                      child: _CreatorDetailActionButton(
                        label: 'Complete',",
"                  children: [
                    Expanded(
                      child: _CreatorDetailActionButton(
                        label: 'Edit',
                        icon: Icons.edit,
                        color: AppColors.neonCyan,
                        onTap: onEdit,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CreatorDetailActionButton(
                        label: 'Complete',"
  )
}

# Add edit sheet class before detail pill.
if ($entry -notmatch "class _CreatorEntryEditSheet") {
  $editSheetClass = @"

class _CreatorEntryEditSheet extends StatefulWidget {
  const _CreatorEntryEditSheet({
    required this.entry,
    required this.onSave,
  });

  final Task entry;
  final Future<void> Function(
    String title,
    String? description,
    int priority,
  ) onSave;

  @override
  State<_CreatorEntryEditSheet> createState() => _CreatorEntryEditSheetState();
}

class _CreatorEntryEditSheetState extends State<_CreatorEntryEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late int _priority;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry.title);
    _descriptionController = TextEditingController(
      text: widget.entry.description ?? '',
    );
    _priority = widget.entry.priority.clamp(1, 5);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Add a title before saving.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSave(
        title,
        _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        _priority,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = 'Creator entry could not be updated. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String kind = (widget.entry.kind ?? 'task').trim().isEmpty
        ? 'task'
        : widget.entry.kind!.trim();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          0,
          14,
          14 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF050D1A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.neonCyan.withValues(alpha: 0.30),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonCyan.withValues(alpha: 0.14),
                blurRadius: 24,
                spreadRadius: -8,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'EDIT CREATOR ENTRY',
                        style: TextStyle(
                          color: AppColors.neonCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                Text(
                  kind.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                _CreatorEditTextField(
                  controller: _titleController,
                  label: 'Title',
                  maxLines: 1,
                ),
                const SizedBox(height: 10),
                _CreatorEditTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                Text(
                  'PRIORITY P' + _priority.toString(),
                  style: const TextStyle(
                    color: AppColors.memoryAmber,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Slider(
                  value: _priority.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: AppColors.memoryAmber,
                  inactiveColor: Colors.white12,
                  label: 'P' + _priority.toString(),
                  onChanged: (value) {
                    setState(() {
                      _priority = value.round().clamp(1, 5);
                    });
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.recallRed,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _saving ? null : _save,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.neonCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.neonCyan.withValues(alpha: 0.34),
                      ),
                    ),
                    child: _saving
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.neonCyan,
                              ),
                            ),
                          )
                        : const Text(
                            'SAVE ENTRY',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.neonCyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatorEditTextField extends StatelessWidget {
  const _CreatorEditTextField({
    required this.controller,
    required this.label,
    required this.maxLines,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.neonCyan.withValues(alpha: 0.18),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.neonCyan.withValues(alpha: 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.neonCyan.withValues(alpha: 0.48),
          ),
        ),
      ),
    );
  }
}

"@

  $entry = $entry.Replace(
    "class _CreatorDetailPill extends StatelessWidget",
    $editSheetClass + "class _CreatorDetailPill extends StatelessWidget"
  )
}

[System.IO.File]::WriteAllText($entryListsPath, $entry, $utf8NoBom)

Write-Host "Formatting changed files..." -ForegroundColor Cyan
dart format $taskProviderPath $entryListsPath

Write-Host "Applying Dart fixes..." -ForegroundColor Cyan
dart fix --apply $taskProviderPath $entryListsPath

Write-Host "Formatting again..." -ForegroundColor Cyan
dart format $taskProviderPath $entryListsPath

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Creator entry editing is now real." -ForegroundColor Green
