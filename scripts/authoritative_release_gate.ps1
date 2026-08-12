param(
  [ValidateSet('ValidateContract', 'Finalize', 'VerifyManifest')]
  [string]$Mode = 'ValidateContract',
  [string]$EvidencePath,
  [string]$BinaryPath,
  [string]$CandidateRoot,
  [string]$OutputDirectory,
  [string]$ManifestPath,
  [string]$ExpectedCommit
)

$ErrorActionPreference = 'Stop'
$script:StageNames = @(
  'repositoryIntegrity',
  'formattingAndGeneratedCodeDrift',
  'flutterAnalyzer',
  'securityAndSecretGuards',
  'unitTests',
  'widgetTests',
  'architectureAndBehaviorContracts',
  'fullRegressionWithCoverage',
  'backendAndStagingSecurity',
  'signedCandidateBuild',
  'binaryHashGeneration',
  'deviceIntegrationAndPatrol',
  'maestroSmoke',
  'maestroFullE2E',
  'accessibilityAndVisualReview',
  'monkeyFuzzAndChaos',
  'performanceAndSoak',
  'humanRootTesting',
  'independentReleaseApproval'
)

function Assert-Value {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Get-RepositoryRoot {
  $root = (& git rev-parse --show-toplevel 2>$null)
  Assert-Value ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($root)) 'Not inside a Git repository.'
  return $root.Trim()
}

function Get-ApplicationVersion {
  param([string]$Root)
  $pubspec = Get-Content -Raw -LiteralPath (Join-Path $Root 'pubspec.yaml')
  $match = [regex]::Match($pubspec, '(?m)^version:\s*([^\s]+)\s*$')
  Assert-Value $match.Success 'pubspec.yaml does not contain an application version.'
  return $match.Groups[1].Value
}

function Get-FileHashValue {
  param([string]$Path)
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Assert-Signature {
  param($Signature, [string]$Label, [string]$CommitSha, [string]$BinaryHash)
  Assert-Value ($null -ne $Signature -and $Signature.signed -eq $true) "$Label signature is missing."
  Assert-Value (-not [string]::IsNullOrWhiteSpace([string]$Signature.signer)) "$Label signer is missing."
  Assert-Value (-not [string]::IsNullOrWhiteSpace([string]$Signature.signedAtUtc)) "$Label signedAtUtc is missing."
  Assert-Value ($Signature.commitSha -eq $CommitSha) "$Label signature belongs to a different commit."
  Assert-Value ($Signature.binaryHash -eq $BinaryHash) "$Label signature belongs to a different binary."
}

function Assert-ManifestContract {
  param($Manifest, [string]$ExpectedSha, [string]$ExpectedBinaryHash)

  foreach ($field in @(
    'repository', 'branch', 'commitSha', 'workingTreeStatus',
    'applicationVersion', 'buildFlavor', 'binaryPath', 'binaryHash',
    'backendEnvironment', 'databaseSchemaVersion', 'workflowRunIds',
    'suiteResults', 'passCount', 'failureCount', 'skipCount',
    'quarantinedTests', 'coverage', 'deviceMatrix', 'performanceResults',
    'fuzzSeeds', 'knownDefects', 'humanRootSignOff', 'stagingSignOff',
    'finalVerdict'
  )) {
    Assert-Value ($null -ne $Manifest.PSObject.Properties[$field]) "Manifest field missing: $field"
  }

  Assert-Value ($Manifest.commitSha -eq $ExpectedSha) 'Manifest commit does not match the expected commit.'
  Assert-Value ($Manifest.binaryHash -eq $ExpectedBinaryHash) 'Manifest binary hash does not match the candidate.'
  Assert-Value ($Manifest.workingTreeStatus -eq 'clean') 'Candidate was built from a dirty working tree.'
  Assert-Value ($Manifest.finalVerdict -eq 'PASS') 'Authoritative gate verdict is not PASS.'
  Assert-Value (@($Manifest.suiteResults).Count -eq $script:StageNames.Count) 'A mandatory release stage is missing.'
}

if ($Mode -eq 'ValidateContract') {
  Assert-Value ($script:StageNames.Count -eq 19) 'The gate must define exactly 19 ordered stages.'
  Assert-Value ($script:StageNames[0] -eq 'repositoryIntegrity') 'Repository integrity must be first.'
  Assert-Value ($script:StageNames[9] -eq 'signedCandidateBuild') 'Signed candidate build must be stage 10.'
  Assert-Value ($script:StageNames[10] -eq 'binaryHashGeneration') 'Binary hash generation must follow the build.'
  Assert-Value ($script:StageNames[18] -eq 'independentReleaseApproval') 'Independent approval must be last.'
  Write-Host 'Phase 13 authoritative release-gate contract validation passed.'
  exit 0
}

$root = Get-RepositoryRoot
$actualCommit = (& git -C $root rev-parse HEAD).Trim()
Assert-Value ($LASTEXITCODE -eq 0) 'Unable to resolve repository commit.'

if ($Mode -eq 'Finalize') {
  foreach ($requiredPath in @($EvidencePath, $BinaryPath, $CandidateRoot, $OutputDirectory)) {
    Assert-Value (-not [string]::IsNullOrWhiteSpace($requiredPath)) 'Finalize requires evidence, binary, candidate-root, and output paths.'
  }
  Assert-Value (Test-Path -LiteralPath $EvidencePath -PathType Leaf) 'Evidence JSON does not exist.'
  Assert-Value (Test-Path -LiteralPath $BinaryPath -PathType Leaf) 'Candidate binary does not exist.'
  Assert-Value (Test-Path -LiteralPath $CandidateRoot -PathType Container) 'Candidate artifact root does not exist.'
  $resolvedCandidateRoot = (Resolve-Path -LiteralPath $CandidateRoot).Path.TrimEnd([IO.Path]::DirectorySeparatorChar)
  $resolvedBinaryPath = (Resolve-Path -LiteralPath $BinaryPath).Path
  Assert-Value ($resolvedBinaryPath.StartsWith("$resolvedCandidateRoot$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::OrdinalIgnoreCase)) 'Candidate binary path escapes its downloaded artifact root.'

  $dirty = @(& git -C $root status --porcelain=v1 --untracked-files=all)
  Assert-Value ($dirty.Count -eq 0) 'Refusing to finalize: working tree is dirty.'
  if (-not [string]::IsNullOrWhiteSpace($ExpectedCommit)) {
    Assert-Value ($actualCommit -eq $ExpectedCommit) 'Checked-out commit differs from the requested commit.'
  }

  $evidence = Get-Content -Raw -LiteralPath $EvidencePath | ConvertFrom-Json
  Assert-Value ($evidence.repository -eq 'ghostheart5/fantastic-guacamole') 'Evidence repository is not authoritative.'
  Assert-Value (-not [string]::IsNullOrWhiteSpace([string]$evidence.branch)) 'Evidence branch is missing.'
  Assert-Value (-not [string]::IsNullOrWhiteSpace([string]$evidence.buildFlavor)) 'Build flavor is missing.'
  Assert-Value (-not [string]::IsNullOrWhiteSpace([string]$evidence.backendEnvironment)) 'Backend environment is missing.'
  Assert-Value (-not [string]::IsNullOrWhiteSpace([string]$evidence.databaseSchemaVersion)) 'Database schema version is missing.'
  Assert-Value ($evidence.candidateWorkingTreeStatus -eq 'clean') 'Candidate was built from a dirty working tree.'
  Assert-Value (@($evidence.workflowRunIds.PSObject.Properties).Count -gt 0) 'Workflow run IDs are missing.'
  Assert-Value ($null -ne $evidence.coverage.linePercent) 'Coverage percentage is missing.'
  Assert-Value (-not [string]::IsNullOrWhiteSpace([string]$evidence.coverage.artifact)) 'Coverage artifact is missing.'
  Assert-Value (@($evidence.deviceMatrix).Count -gt 0) 'Device matrix evidence is missing.'
  Assert-Value (@($evidence.performanceResults).Count -gt 0) 'Performance evidence is missing.'
  Assert-Value (@($evidence.fuzzSeeds).Count -gt 0) 'Fuzz seed evidence is missing.'
  Assert-Value (@($evidence.stages).Count -eq $script:StageNames.Count) 'Evidence does not contain all 19 stages.'
  Assert-Value ($evidence.chatIsolationVerified -eq $true) 'Release blocked: chat isolation was not verified.'

  $binaryHash = Get-FileHashValue $BinaryPath
  $previousTime = [DateTimeOffset]::MinValue
  $passCount = 0
  $failureCount = 0
  $skipCount = 0
  for ($index = 0; $index -lt $script:StageNames.Count; $index += 1) {
    $stage = @($evidence.stages)[$index]
    $stageId = $index + 1
    Assert-Value ([int]$stage.stageId -eq $stageId) "Stage order mismatch at stage $stageId."
    Assert-Value ($stage.name -eq $script:StageNames[$index]) "Unexpected stage name at stage $stageId."
    Assert-Value ($stage.status -eq 'pass') "Mandatory stage $stageId did not pass."
    Assert-Value ([int]$stage.passCount -gt 0) "Mandatory stage $stageId has no passing evidence."
    Assert-Value ($stage.commitSha -eq $actualCommit) "Stage $stageId belongs to a different commit."
    Assert-Value (-not [string]::IsNullOrWhiteSpace([string]$stage.completedAtUtc)) "Stage $stageId has no completion time."
    $completedAt = [DateTimeOffset]::Parse([string]$stage.completedAtUtc)
    Assert-Value ($completedAt -ge $previousTime) "Stage $stageId completed out of order."
    $previousTime = $completedAt
    if ($stageId -ge 11) {
      Assert-Value ($stage.binaryHash -eq $binaryHash) "Stage $stageId belongs to a different binary."
    }
    $passCount += [int]$stage.passCount
    $failureCount += [int]$stage.failureCount
    $skipCount += [int]$stage.skipCount
  }

  Assert-Value ($failureCount -eq 0) 'Release evidence contains failures.'
  foreach ($skip in @($evidence.skips)) {
    Assert-Value ($skip.approved -eq $true) 'Release evidence contains an unapproved skip.'
    Assert-Value (-not [string]::IsNullOrWhiteSpace([string]$skip.reason)) 'Approved skip lacks a reason.'
    Assert-Value (-not [string]::IsNullOrWhiteSpace([string]$skip.reviewDate)) 'Approved skip lacks a review date.'
  }
  Assert-Value ($skipCount -eq @($evidence.skips).Count) 'Skip count does not match approved skip records.'

  $now = [DateTimeOffset]::UtcNow
  foreach ($quarantine in @($evidence.quarantinedTests)) {
    Assert-Value (-not [string]::IsNullOrWhiteSpace([string]$quarantine.owner)) 'Quarantine lacks an owner.'
    Assert-Value (-not [string]::IsNullOrWhiteSpace([string]$quarantine.expiryUtc)) 'Quarantine lacks an expiry.'
    Assert-Value ([DateTimeOffset]::Parse([string]$quarantine.expiryUtc) -gt $now) 'Release blocked by an expired quarantine.'
  }
  foreach ($defect in @($evidence.knownDefects)) {
    $open = [string]$defect.status -notin @('resolved', 'closed')
    Assert-Value (-not ($open -and [string]$defect.severity -in @('P0', 'P1'))) 'Release blocked by an open P0 or P1 defect.'
  }

  Assert-Signature $evidence.humanRootSignOff 'Human Root' $actualCommit $binaryHash
  Assert-Signature $evidence.stagingSignOff 'Staging' $actualCommit $binaryHash
  Assert-Signature $evidence.independentReleaseApproval 'Independent release approval' $actualCommit $binaryHash

  $manifestFile = Join-Path $OutputDirectory 'release-gate-manifest.json'
  $hashFile = "$manifestFile.sha256"
  Assert-Value (-not (Test-Path -LiteralPath $manifestFile)) 'Refusing to overwrite an immutable release manifest.'
  Assert-Value (-not (Test-Path -LiteralPath $hashFile)) 'Refusing to overwrite an immutable manifest hash.'

  $candidateDirectory = Join-Path $OutputDirectory 'candidate'
  New-Item -ItemType Directory -Path $candidateDirectory -Force | Out-Null
  $candidatePath = Join-Path $candidateDirectory ([IO.Path]::GetFileName($BinaryPath))
  Assert-Value (-not (Test-Path -LiteralPath $candidatePath)) 'Refusing to overwrite a gated candidate binary.'
  Copy-Item -LiteralPath $BinaryPath -Destination $candidatePath
  Assert-Value ((Get-FileHashValue $candidatePath) -eq $binaryHash) 'Copied candidate hash changed.'

  $manifest = [ordered]@{
    schemaVersion = '1.0.0'
    repository = $evidence.repository
    branch = $evidence.branch
    commitSha = $actualCommit
    workingTreeStatus = $evidence.candidateWorkingTreeStatus
    applicationVersion = Get-ApplicationVersion $root
    buildFlavor = $evidence.buildFlavor
    binaryPath = "candidate/$([IO.Path]::GetFileName($BinaryPath))"
    binaryHash = $binaryHash
    backendEnvironment = $evidence.backendEnvironment
    databaseSchemaVersion = $evidence.databaseSchemaVersion
    workflowRunIds = $evidence.workflowRunIds
    suiteResults = @($evidence.stages)
    passCount = $passCount
    failureCount = $failureCount
    skipCount = $skipCount
    quarantinedTests = @($evidence.quarantinedTests)
    coverage = $evidence.coverage
    deviceMatrix = @($evidence.deviceMatrix)
    performanceResults = @($evidence.performanceResults)
    fuzzSeeds = @($evidence.fuzzSeeds)
    knownDefects = @($evidence.knownDefects)
    humanRootSignOff = $evidence.humanRootSignOff
    stagingSignOff = $evidence.stagingSignOff
    independentReleaseApproval = $evidence.independentReleaseApproval
    chatIsolationVerified = $true
    finalizedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    finalVerdict = 'PASS'
  }
  New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
  $manifestJson = $manifest | ConvertTo-Json -Depth 20
  [IO.File]::WriteAllText($manifestFile, $manifestJson, (New-Object Text.UTF8Encoding($false)))
  $manifestHash = Get-FileHashValue $manifestFile
  Set-Content -LiteralPath $hashFile -Value $manifestHash -Encoding ascii
  Write-Host "Authoritative release manifest finalized: $manifestFile"
  exit 0
}

Assert-Value (-not [string]::IsNullOrWhiteSpace($ManifestPath)) 'VerifyManifest requires ManifestPath.'
Assert-Value (Test-Path -LiteralPath $ManifestPath -PathType Leaf) 'Release manifest does not exist.'
$manifestHashPath = "$ManifestPath.sha256"
Assert-Value (Test-Path -LiteralPath $manifestHashPath -PathType Leaf) 'Manifest hash sidecar does not exist.'
$expectedManifestHash = (Get-Content -Raw -LiteralPath $manifestHashPath).Trim().ToLowerInvariant()
Assert-Value ((Get-FileHashValue $ManifestPath) -eq $expectedManifestHash) 'Immutable manifest hash verification failed.'
$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($BinaryPath)) {
  $BinaryPath = Join-Path (Split-Path -Parent $ManifestPath) ([string]$manifest.binaryPath)
}
Assert-Value (Test-Path -LiteralPath $BinaryPath -PathType Leaf) 'Gated binary does not exist.'
$expectedSha = if ([string]::IsNullOrWhiteSpace($ExpectedCommit)) { $actualCommit } else { $ExpectedCommit }
Assert-ManifestContract $manifest $expectedSha (Get-FileHashValue $BinaryPath)
$dirty = @(& git -C $root status --porcelain=v1 --untracked-files=all)
Assert-Value ($dirty.Count -eq 0) 'Release checkout is dirty.'
Write-Host 'Authoritative release manifest and exact binary verified.'
