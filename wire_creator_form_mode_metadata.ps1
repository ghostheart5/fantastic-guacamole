$ErrorActionPreference = "Stop"

Write-Host "Safely wiring CreatorFormData mode metadata..." -ForegroundColor Cyan

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$modelPath = ".\lib\state\models\creator_form_data.dart"
$formPath = ".\lib\features\creator\widgets\dynamic_form.dart"
$screenPath = ".\lib\features\creator\ui\creator_screen.dart"

if (-not (Test-Path $modelPath)) { throw "Missing file: $modelPath" }
if (-not (Test-Path $formPath)) { throw "Missing file: $formPath" }
if (-not (Test-Path $screenPath)) { throw "Missing file: $screenPath" }

Copy-Item $modelPath "$modelPath.bak_creator_mode" -Force
Copy-Item $formPath "$formPath.bak_creator_mode" -Force
Copy-Item $screenPath "$screenPath.bak_creator_mode" -Force

# ------------------------------------------------------------
# Patch CreatorFormData
# ------------------------------------------------------------
$model = Get-Content $modelPath -Raw

if ($model -notmatch "creatorMode") {
  $model = $model.Replace(
"    this.scheduledFor,
    this.recurrenceRule = RecurrenceRule.none,",
"    this.scheduledFor,
    this.recurrenceRule = RecurrenceRule.none,
    this.creatorMode = 'tasks',"
  )

  $model = $model.Replace(
"  final RecurrenceRule recurrenceRule;",
"  final RecurrenceRule recurrenceRule;
  final String creatorMode;"
  )
}

[System.IO.File]::WriteAllText($modelPath, $model, $utf8NoBom)

# ------------------------------------------------------------
# Patch DynamicForm
# ------------------------------------------------------------
$form = Get-Content $formPath -Raw

if ($form -notmatch "creator_workspace_mode.dart") {
  $form = $form.Replace(
"import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';",
"import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/features/creator/models/creator_workspace_mode.dart';"
  )
}

if ($form -notmatch "workspaceMode = CreatorWorkspaceMode.tasks") {
  $form = $form.Replace(
"  const DynamicForm({super.key, required this.onSubmit});",
"  const DynamicForm({
    super.key,
    required this.onSubmit,
    this.workspaceMode = CreatorWorkspaceMode.tasks,
  });"
  )
}

if ($form -notmatch "final CreatorWorkspaceMode workspaceMode;") {
  $form = $form.Replace(
"  final Future<void> Function(CreatorFormData data) onSubmit;",
"  final Future<void> Function(CreatorFormData data) onSubmit;
  final CreatorWorkspaceMode workspaceMode;"
  )
}

if ($form -notmatch "String get _entryType") {
  $form = $form.Replace(
"  bool _submitting = false;
  String? _errorMessage;",
"  bool _submitting = false;
  String? _errorMessage;

  String get _entryType {
    if (widget.workspaceMode == CreatorWorkspaceMode.tasks) {
      return _selectedType;
    }

    return widget.workspaceMode.label;
  }

  String get _submitLabel {
    switch (widget.workspaceMode) {
      case CreatorWorkspaceMode.tasks:
        return 'FORGE TASK';
      case CreatorWorkspaceMode.goals:
        return 'FORGE GOAL';
      case CreatorWorkspaceMode.milestones:
        return 'FORGE MILESTONE';
      case CreatorWorkspaceMode.plan:
        return 'FORGE PLAN ITEM';
    }
  }"
  )
}

$form = $form.Replace(
"      setState(() => _errorMessage = 'Add a title before creating the task.');",
"      setState(() => _errorMessage = 'Add a title before creating the entry.');"
)

$form = $form.Replace(
"          type: _selectedType,",
"          type: _entryType,"
)

if ($form -notmatch "creatorMode: widget.workspaceMode.name") {
  $form = $form.Replace(
"          scheduledFor: _scheduledFor,
          recurrenceRule: _recurrenceRule,",
"          scheduledFor: _scheduledFor,
          creatorMode: widget.workspaceMode.name,
          recurrenceRule: _recurrenceRule,"
  )
}

$form = $form.Replace(
"                  : const Text(
                      'FORGE TASK',",
"                  : Text(
                      _submitLabel,"
)

$form = $form.Replace(
"                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.memoryAmber,
                      ),",
"                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.memoryAmber,
                      ),"
)

[System.IO.File]::WriteAllText($formPath, $form, $utf8NoBom)

# ------------------------------------------------------------
# Patch CreatorScreen to pass selected mode into DynamicForm
# ------------------------------------------------------------
$screen = Get-Content $screenPath -Raw

if ($screen -notmatch "workspaceMode: _mode") {
  $screen = $screen.Replace(
"                DynamicForm(
                  onSubmit:",
"                DynamicForm(
                  workspaceMode: _mode,
                  onSubmit:"
  )
}

[System.IO.File]::WriteAllText($screenPath, $screen, $utf8NoBom)

Write-Host "Formatting Creator files..." -ForegroundColor Cyan
dart format .\lib\state\models\creator_form_data.dart .\lib\features\creator\widgets\dynamic_form.dart .\lib\features\creator\ui\creator_screen.dart

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Creator mode metadata wiring complete." -ForegroundColor Green
