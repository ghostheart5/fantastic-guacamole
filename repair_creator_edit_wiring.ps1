$ErrorActionPreference = "Stop"

Write-Host "Repairing Creator edit wiring..." -ForegroundColor Cyan

$file = ".\lib\features\creator\ui\widgets\creator_entry_lists.dart"

if (-not (Test-Path $file)) {
  throw "Missing file: $file"
}

Copy-Item $file "$file.bak_edit_wiring_fix" -Force

$text = Get-Content $file -Raw

# ------------------------------------------------------------
# Add openEditSheet helper if missing
# ------------------------------------------------------------
if ($text -notmatch "Future<void> openEditSheet\(Task entry\)") {
  $marker = "    void openEntry(Task entry) {"

  $helper = @"
    Future<void> openEditSheet(Task entry) async {
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
    }

"@

  if (-not $text.Contains($marker)) {
    throw "Could not find openEntry insertion point."
  }

  $text = $text.Replace($marker, $helper + $marker)
}

# ------------------------------------------------------------
# Pass onEdit into every CreatorEntryGroup call
# ------------------------------------------------------------
$text = [System.Text.RegularExpressions.Regex]::Replace(
  $text,
  "onSkip: skipEntry,\s*\)",
  "onSkip: skipEntry,`r`n                onEdit: openEditSheet,`r`n              )"
)

# ------------------------------------------------------------
# Add onEdit to _CreatorEntryGroup constructor and fields
# ------------------------------------------------------------
if ($text -match "class _CreatorEntryGroup" -and $text -notmatch "final ValueChanged<Task> onEdit;") {
  $text = $text.Replace(
"    required this.onOpen,
    required this.onComplete,",
"    required this.onOpen,
    required this.onEdit,
    required this.onComplete,"
  )

  $text = $text.Replace(
"  final ValueChanged<Task> onOpen;
  final ValueChanged<Task> onComplete;",
"  final ValueChanged<Task> onOpen;
  final ValueChanged<Task> onEdit;
  final ValueChanged<Task> onComplete;"
  )
}

# ------------------------------------------------------------
# Pass onEdit into _CreatorEntryTile calls
# ------------------------------------------------------------
$text = [System.Text.RegularExpressions.Regex]::Replace(
  $text,
  "onOpen: \(\) => onOpen\(entry\),\s*onComplete:",
  "onOpen: () => onOpen(entry),`r`n                        onEdit: () => onEdit(entry),`r`n                        onComplete:"
)

# ------------------------------------------------------------
# Add onEdit to _CreatorEntryTile constructor and fields
# ------------------------------------------------------------
if ($text -match "class _CreatorEntryTile" -and $text -notmatch "final VoidCallback onEdit;") {
  $text = $text.Replace(
"    required this.onOpen,
    required this.onComplete,",
"    required this.onOpen,
    required this.onEdit,
    required this.onComplete,"
  )

  $text = $text.Replace(
"  final VoidCallback onOpen;
  final VoidCallback onComplete;",
"  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onComplete;"
  )
}

# ------------------------------------------------------------
# Add edit action button to each tile if not present
# ------------------------------------------------------------
if ($text -notmatch "tooltip: 'Edit'") {
  $text = $text.Replace(
"              const Spacer(),
              _CreatorTileAction(
                icon: Icons.check,",
"              const Spacer(),
              _CreatorTileAction(
                icon: Icons.edit,
                tooltip: 'Edit',
                color: AppColors.neonCyan,
                onTap: onEdit,
              ),
              const SizedBox(width: 6),
              _CreatorTileAction(
                icon: Icons.check,"
  )
}

# ------------------------------------------------------------
# Add onEdit field to detail sheet if constructor has it but field missing
# ------------------------------------------------------------
if ($text -match "class _CreatorEntryDetailSheet" -and $text -notmatch "final Future<void> Function\(\) onEdit;") {
  $text = $text.Replace(
"  final Future<void> Function() onSkip;",
"  final Future<void> Function() onSkip;
  final Future<void> Function() onEdit;"
  )
}

# ------------------------------------------------------------
# Ensure detail sheet call has onEdit argument.
# ------------------------------------------------------------
if ($text -match "_CreatorEntryDetailSheet\(" -and $text -notmatch "onEdit: openEditSheet") {
  $text = [System.Text.RegularExpressions.Regex]::Replace(
    $text,
    "onSkip: \(\) async \{([\s\S]*?)await skipEntry\(entry\);\s*\},",
    "onSkip: () async {`r`n              `$1await skipEntry(entry);`r`n            },`r`n            onEdit: () async {`r`n              Navigator.of(sheetContext).maybePop();`r`n              await Future<void>.delayed(const Duration(milliseconds: 120));`r`n              if (!context.mounted) {`r`n                return;`r`n              }`r`n              await openEditSheet(entry);`r`n            },"
  )
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($file, $text, $utf8NoBom)

Write-Host "Formatting Creator entry lists..." -ForegroundColor Cyan
dart format $file

Write-Host "Applying Dart fixes..." -ForegroundColor Cyan
dart fix --apply $file

Write-Host "Formatting again..." -ForegroundColor Cyan
dart format $file

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Creator edit wiring repaired." -ForegroundColor Green
