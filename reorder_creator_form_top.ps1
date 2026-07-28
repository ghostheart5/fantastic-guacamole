$ErrorActionPreference = "Stop"

Write-Host "Reordering Creator screen so the form is near the top..." -ForegroundColor Cyan

$file = ".\lib\features\creator\ui\creator_screen.dart"

if (-not (Test-Path $file)) {
  throw "Missing file: $file"
}

Copy-Item $file "$file.bak_creator_reorder_form_top" -Force

$text = Get-Content $file -Raw

$oldBlock = @"
                CreatorUnifiedWorkbench(
                  selectedMode: _mode,
                  onModeChanged: (mode) {
                    setState(() {
                      _mode = mode;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DynamicForm(
                  workspaceMode: _mode,
                  onSubmit: (data) async {
                    await ref.read(creatorActionsProvider).createEntry(data);
                    await ref
                        .read(localMetricsAccumulatorProvider)
                        .recordTaskCreated();
                    ref.invalidate(tasksProvider);
                    ref.invalidate(goalProgressProvider);
                    ref
                        .read(tutorialControllerProvider)
                        .updateState('has_created_task', true);

                    if (context.mounted) {
                      final ScaffoldMessengerState messenger =
                          ScaffoldMessenger.of(context);
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(' entry saved.'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                    }
                  },
                ),
"@

$newBlock = @"
                DynamicForm(
                  workspaceMode: _mode,
                  onSubmit: (data) async {
                    await ref.read(creatorActionsProvider).createEntry(data);
                    await ref
                        .read(localMetricsAccumulatorProvider)
                        .recordTaskCreated();
                    ref.invalidate(tasksProvider);
                    ref.invalidate(goalProgressProvider);
                    ref
                        .read(tutorialControllerProvider)
                        .updateState('has_created_task', true);

                    if (context.mounted) {
                      final ScaffoldMessengerState messenger =
                          ScaffoldMessenger.of(context);
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text('${_mode.name} entry saved.'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                    }
                  },
                ),
                const SizedBox(height: 16),
                CreatorUnifiedWorkbench(
                  selectedMode: _mode,
                  onModeChanged: (mode) {
                    setState(() {
                      _mode = mode;
                    });
                  },
                ),
"@

if ($text.Contains($oldBlock)) {
  $text = $text.Replace($oldBlock, $newBlock)
} else {
  throw "Could not find exact CreatorUnifiedWorkbench + DynamicForm block. No changes made."
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($file, $text, $utf8NoBom)

Write-Host "Formatting Creator screen..." -ForegroundColor Cyan
dart format $file

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Creator form moved near the top." -ForegroundColor Green
