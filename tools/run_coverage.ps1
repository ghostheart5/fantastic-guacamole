flutter test --coverage
if (Test-Path coverage\lcov.info) { Write-Host 'Coverage file created: coverage\lcov.info' } else { Write-Host 'Coverage file missing' }

