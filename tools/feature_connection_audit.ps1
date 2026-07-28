$ErrorActionPreference = 'Stop'

$ReportPath = '.\feature_connection_audit.txt'

"===== CHRONOSPARK FEATURE CONNECTION AUDIT =====" | Set-Content $ReportPath
"Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content $ReportPath
"" | Add-Content $ReportPath

"===== CONNECTION SURFACES =====" | Add-Content $ReportPath

Get-ChildItem .\lib -Recurse -Filter *.dart |
	Select-String `
		"AppView.|Provider<|NotifierProvider|StateNotifierProvider|ConsumerWidget|ConsumerStatefulWidget|trajectorySummaryProvider|appFlowProvider" |
	Select-Object Path, LineNumber, Line |
	ForEach-Object {
		"{0}:{1}: {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim()
	} | Add-Content $ReportPath

"" | Add-Content $ReportPath
"===== ROUTE METHODS =====" | Add-Content $ReportPath

$ExpectedRoutes = @(
	"toNexus",
	"toCoach",
	"toSmartCoach",
	"toCreator",
	"toTimeline",
	"toProfile",
	"toProgression",
	"toTrajectoryEngine",
	"toConsole",
	"toSettings"
)

$ControllerPath = '.\lib\state\controllers\app_flow_controller.dart'

if (-not (Test-Path $ControllerPath)) {
	"[FAIL] Missing controller file: $ControllerPath" | Add-Content $ReportPath
	throw "Missing required file: $ControllerPath"
}

$ControllerText = Get-Content $ControllerPath -Raw

foreach ($Route in $ExpectedRoutes) {
	$Pattern = "void\s+$Route\s*\(\)"
	if ($ControllerText -match $Pattern) {
		"[PASS] $Route" | Add-Content $ReportPath
	} else {
		"[MISSING] $Route" | Add-Content $ReportPath
	}
}

if ($ControllerText -match 'void\s+toTrajectoryEngine\s*\(\)') {
	"[PASS] Explicit check: void toTrajectoryEngine() exists in $ControllerPath" | Add-Content $ReportPath
} else {
	"[MISSING] Explicit check failed: void toTrajectoryEngine() not found in $ControllerPath" | Add-Content $ReportPath
}

"" | Add-Content $ReportPath
"===== SUMMARY =====" | Add-Content $ReportPath
"Trajectory Engine route audit complete." | Add-Content $ReportPath

Write-Host ""
Write-Host "Audit complete."
Write-Host "Open: $ReportPath"

