$ErrorActionPreference = "Stop"

Write-Host "Patching _taskFromEntity to expose kind and description..." -ForegroundColor Cyan

$file = ".\lib\state\providers\task_provider.dart"

if (-not (Test-Path $file)) {
  throw "Missing file: $file"
}

Copy-Item $file "$file.bak_task_mapping" -Force

$text = Get-Content $file -Raw

$old = @"
Task _taskFromEntity(TaskEntity task) {
  return Task(
    id: task.id,
    title: task.title,
    priority: task.priority,
    difficulty: task.difficulty,
    energyRequired: task.energyRequired,
    scheduledFor: task.scheduledFor,
    goalId: task.goalId,
    subtasks: task.subtasks,
    recurrenceRule: task.recurrenceRule,
  );
}
"@

$new = @"
Task _taskFromEntity(TaskEntity task) {
  return Task(
    id: task.id,
    title: task.title,
    description: task.description,
    kind: task.kind,
    priority: task.priority,
    difficulty: task.difficulty,
    energyRequired: task.energyRequired,
    scheduledFor: task.scheduledFor,
    goalId: task.goalId,
    subtasks: task.subtasks,
    recurrenceRule: task.recurrenceRule,
  );
}
"@

if ($text.Contains($old)) {
  $text = $text.Replace($old, $new)
} elseif ($text -notmatch "description:\s*task\.description") {
  $text = $text.Replace(
    "    title: task.title,",
    "    title: task.title,`r`n    description: task.description,`r`n    kind: task.kind,"
  )
} else {
  Write-Host "_taskFromEntity already includes description and kind." -ForegroundColor Yellow
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($file, $text, $utf8NoBom)

Write-Host "Formatting task provider..." -ForegroundColor Cyan
dart format $file

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Task mapping patched. Creator grouped lists should now receive kind and description." -ForegroundColor Green
