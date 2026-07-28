Write-Host 'Running ChronoSpark Unit Tests...'
flutter test test\unit

Write-Host 'Running ChronoSpark Integration Tests...'
flutter test test\integration

Write-Host 'Running ChronoSpark Feature Tests...'
flutter test test\features

Write-Host 'Running ChronoSpark Smoke Tests...'
flutter test test\smoke

Write-Host 'Running Robot Framework Tests...'
robot test\robot

Write-Host 'All tests completed.'
