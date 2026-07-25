$ErrorActionPreference = "Stop"

Write-Host "Repairing DynamicForm mode-aware wiring cleanly..." -ForegroundColor Cyan

$formPath = ".\lib\features\creator\widgets\dynamic_form.dart"
$backupPath = ".\lib\features\creator\widgets\dynamic_form.dart.bak_mode"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path $backupPath)) {
  throw "Missing backup file: $backupPath"
}

Copy-Item $backupPath $formPath -Force
Write-Host "Restored DynamicForm from backup." -ForegroundColor Green

$form = Get-Content $formPath -Raw

# Clean any pasted HTML artifacts if they exist.
$form = $form.Replace("<br>", "")
$form = $form.Replace("&gt;", ">")
$form = $form.Replace("&lt;", "<")
$form = $form.Replace("�", "-")
$form = $form.Replace("?", "-")

# Add CreatorWorkspaceMode import.
if ($form -notmatch "creator_workspace_mode.dart") {
  $form = $form -replace `
    "import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';", `
    "import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';`r`nimport 'package:fantastic_guacamole/features/creator/models/creator_workspace_mode.dart';"
}

# Add workspaceMode to constructor.
$form = $form -replace `
  "const DynamicForm\(\{super\.key, required this\.onSubmit\}\);", `
  "const DynamicForm({super.key, required this.onSubmit, this.workspaceMode = CreatorWorkspaceMode.tasks});"

# Add workspaceMode field.
$form = $form -replace `
  "final Future<void> Function\(CreatorFormData data\) onSubmit;", `
  "final Future<void> Function(CreatorFormData data) onSubmit;`r`n  final CreatorWorkspaceMode workspaceMode;"

# Make validation language generic.
$form = $form -replace `
  "setState\(\(\) => _errorMessage = 'Add a title before creating the task\.'\);", `
  "setState(() => _errorMessage = 'Add a title before creating the entry.');"

# Route created type through mode-aware getter.
$form = $form -replace "type: _selectedType,", "type: _entryType,"

# Fix save failure wording if corrupted.
$form = $form -replace `
  "'The task could not be saved\.[^']*retry\.';", `
  "'The entry could not be saved. Your entry is still here. Retry.';"

# Make labels mode-aware.
$form = $form -replace `
  "_sectionLabel\('ENTRY DETAILS', AppColors\.memoryAmber\),", `
  "_sectionLabel(_sectionTitle, AppColors.memoryAmber),"

$form = $form -replace `
  "_buildTextField\(_titleController, 'Title \*', maxLines: 1\),", `
  "_buildTextField(_titleController, _titleHint, maxLines: 1),"

# Make submit button label mode-aware.
$form = [System.Text.RegularExpressions.Regex]::Replace(
  $form,
  ": const Text\(\s*'FORGE TASK',",
  ": Text(`r`n                      _submitLabel,",
  [System.Text.RegularExpressions.RegexOptions]::Singleline
)

# Insert helper getters ONLY inside _DynamicFormState before its build method.
if ($form -notmatch "String get _modeLabel") {
  $helperBlock = @"

  String get _modeLabel {
    switch (widget.workspaceMode) {
      case CreatorWorkspaceMode.tasks:
        return 'Task';
      case CreatorWorkspaceMode.goals:
        return 'Goal';
      case CreatorWorkspaceMode.milestones:
        return 'Milestone';
      case CreatorWorkspaceMode.plan:
        return 'Plan';
    }
  }

  String get _entryType {
    if (widget.workspaceMode == CreatorWorkspaceMode.tasks) {
      return _selectedType;
    }

    return _modeLabel;
  }

  String get _sectionTitle {
    return '${_modeLabel.toUpperCase()} DETAILS';
  }

  String get _titleHint {
    return '${_modeLabel} title *';
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
  }
"@

  $stateIndex = $form.IndexOf("class _DynamicFormState")
  if ($stateIndex -lt 0) {
    throw "Could not find _DynamicFormState."
  }

  $markerCrlf = "  @override`r`n  Widget build(BuildContext context) {"
  $markerLf = "  @override`n  Widget build(BuildContext context) {"

  $buildIndex = $form.IndexOf($markerCrlf, $stateIndex)

  if ($buildIndex -lt 0) {
    $buildIndex = $form.IndexOf($markerLf, $stateIndex)
  }

  if ($buildIndex -lt 0) {
    throw "Could not find _DynamicFormState build method."
  }

  $form = $form.Insert($buildIndex, $helperBlock + "`r`n")
}

[System.IO.File]::WriteAllText($formPath, $form, $utf8NoBom)

Write-Host "Formatting Creator files..." -ForegroundColor Cyan
dart format .\lib\features\creator

Write-Host "Running Dart fixes..." -ForegroundColor Cyan
dart fix --apply .\lib\features\creator

Write-Host "Formatting again..." -ForegroundColor Cyan
dart format .\lib\features\creator

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "DynamicForm mode-aware repair complete." -ForegroundColor Green
