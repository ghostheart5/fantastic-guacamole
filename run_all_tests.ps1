Write-Host 'Running ChronoSpark Unit Tests...'
flutter test test\unit

Write-Host 'Running ChronoSpark Integration Tests...'
flutter test test\integration

Write-Host 'Running ChronoSpark Feature Tests...'
flutter test test\features

Write-Host 'Running ChronoSpark Smoke Tests...'
flutter test test\smoke

if (Get-Command robot -ErrorAction SilentlyContinue) {
	Write-Host 'Running Robot Framework Tests...'
	robot test\robot
} else {
	Write-Host 'Skipping Robot Framework Tests (robot command not found).'
}

Write-Host 'All tests completed.'
