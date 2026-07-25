$ErrorActionPreference = "Stop"

Write-Host "Finishing Creator scaffold..." -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path ".\lib\features\creator\ui\widgets" | Out-Null
New-Item -ItemType Directory -Force -Path ".\lib\features\creator\models" | Out-Null

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$emptyStatePath = ".\lib\features\creator\ui\widgets\creator_empty_state.dart"
$emptyStateContent = @"
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:flutter/material.dart';

class CreatorEmptyState extends StatelessWidget {
  const CreatorEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.auto_awesome,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.neonViolet, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
"@

[System.IO.File]::WriteAllText($emptyStatePath, $emptyStateContent, $utf8NoBom)

$barrelPath = ".\lib\features\creator\creator.dart"
$barrelContent = @"
export 'models/creator_workspace_mode.dart';
export 'ui/widgets/creator_empty_state.dart';
export 'ui/widgets/creator_mode_selector.dart';
export 'ui/widgets/creator_section_card.dart';
export 'ui/widgets/creator_workspace_header.dart';
"@

[System.IO.File]::WriteAllText($barrelPath, $barrelContent, $utf8NoBom)

Write-Host "Formatting Creator..." -ForegroundColor Cyan
dart format .\lib\features\creator

Write-Host "Analyzing app code..." -ForegroundColor Cyan
flutter analyze lib

Write-Host "Creator scaffold finish complete." -ForegroundColor Green
