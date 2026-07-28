# ChronoSpark Test Scaffold Builder
# Creates full test folder structure + boilerplate test files

$root = "C:\Users\keegan radetski\fantastic-guacamole"
$testRoot = "$root\test"

Write-Host "Building ChronoSpark test scaffolding..."

# --- Base folders ---
$folders = @(
    "$testRoot\unit",
    "$testRoot\integration",
    "$testRoot\smoke",
    "$testRoot\robot",
    "$testRoot\utils",
    "$testRoot\mocks",
    "$testRoot\features"
)

foreach ($f in $folders) {
    if (!(Test-Path $f)) {
        New-Item -ItemType Directory -Path $f | Out-Null
        Write-Host "Created: $f"
    }
}

# --- Feature folders ---
$features = @(
    "timeline",
    "tasks",
    "daily_plan",
    "scheduler",
    "sync",
    "storage",
    "settings",
    "ui",
    "auth"
)

foreach ($feature in $features) {
    $featurePath = "$testRoot\features\$feature"
    if (!(Test-Path $featurePath)) {
        New-Item -ItemType Directory -Path $featurePath | Out-Null
        Write-Host "Created feature folder: $featurePath"
    }

    # Subfolders inside each feature
    $sub = @("unit", "integration", "robot")
    foreach ($s in $sub) {
        $subPath = "$featurePath\$s"
        if (!(Test-Path $subPath)) {
            New-Item -ItemType Directory -Path $subPath | Out-Null
            Write-Host "Created: $subPath"
        }
    }
}

# --- Boilerplate test file generator ---
function New-TestFile {
    param(
        [string]$path,
        [string]$content
    )
    if (!(Test-Path $path)) {
        $content | Out-File $path -Encoding utf8
        Write-Host "Created file: $path"
    }
}

# --- Unit test boilerplate ---
$unitBoiler = @"
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChronoSpark Unit Test', () {
    test('placeholder', () {
      expect(true, true);
    });
  });
}
"@

# --- Integration test boilerplate ---
$integrationBoiler = @"
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChronoSpark Integration Test', () {
    testWidgets('placeholder widget test', (tester) async {
      expect(true, true);
    });
  });
}
"@

# --- Smoke test boilerplate ---
$smokeBoiler = @"
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ChronoSpark Smoke Test', () {
    expect(true, true);
  });
}
"@

# --- Robot Framework boilerplate ---
$robotBoiler = @"
*** Settings ***
Library           SeleniumLibrary

*** Test Cases ***
ChronoSpark Smoke Robot Test
    Log    Robot test placeholder
"@

# --- Create root-level test files ---
New-TestFile "$testRoot\smoke\smoke_test.dart" $smokeBoiler
New-TestFile "$testRoot\robot\smoke.robot" $robotBoiler
New-TestFile "$testRoot\unit\base_unit_test.dart" $unitBoiler
New-TestFile "$testRoot\integration\base_integration_test.dart" $integrationBoiler

# --- Create feature test files ---
foreach ($feature in $features) {
    $base = "$testRoot\features\$feature"

    New-TestFile "$base\unit\${feature}_unit_test.dart" $unitBoiler
    New-TestFile "$base\integration\${feature}_integration_test.dart" $integrationBoiler
    New-TestFile "$base\robot\${feature}_robot.robot" $robotBoiler
}

Write-Host "ChronoSpark test scaffold complete."
