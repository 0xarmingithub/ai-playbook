<#
.SYNOPSIS
  Checks this repository against its own invariants. Exits non-zero on any FAIL.

.DESCRIPTION
  Run after every change to this repository. Each check either passes, fails, or reports SKIP
  when it cannot run here. SKIP is never counted as a pass. Windows PowerShell 5.1 safe, and it
  never needs a path outside this repository, so it passes on a fresh clone.

  Checks:
    1. Every JSON file under tools/ and templates/ parses (an invalid escape here once broke status).
    2. Every tracked file is ASCII-only and has no byte order mark.
    3. The required documents and tools are present.
    4. Machine-local files are git-ignored and not tracked.
    5. The sensitive-data scan is clean on this repository.
    6. The mutation test of the scan passes (tools/test-scan.ps1).
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$script:Failed = 0
$script:Passed = 0
$script:Skipped = 0

function Write-Check {
  param([string]$State, [string]$Name, [string[]]$Detail = @())
  $color = switch ($State) { 'PASS' { 'Green' } 'FAIL' { 'Red' } default { 'Yellow' } }
  Write-Host ('[{0}] {1}' -f $State, $Name) -ForegroundColor $color
  foreach ($d in $Detail) { Write-Host ('       {0}' -f $d) }
  switch ($State) { 'PASS' { $script:Passed++ } 'FAIL' { $script:Failed++ } default { $script:Skipped++ } }
}

function Get-Tracked {
  # Returns the tracked file list, or $null when git cannot list it.
  try {
    $listed = & git -C $repo ls-files 2>$null
    if ($LASTEXITCODE -eq 0 -and $listed) { return @($listed) }
  } catch { }
  return $null
}

# 1. JSON parses
$jsonFiles = @(Get-ChildItem -LiteralPath (Join-Path $repo 'tools'), (Join-Path $repo 'templates') -Filter *.json -File -Recurse)
$badJson = @()
foreach ($f in $jsonFiles) {
  try { [void]([IO.File]::ReadAllText($f.FullName, (New-Object Text.UTF8Encoding($false))) | ConvertFrom-Json) }
  catch { $badJson += ('{0}: {1}' -f $f.FullName.Substring($repo.Length + 1), $_.Exception.Message.Split("`n")[0]) }
}
if ($jsonFiles.Count -eq 0) { Write-Check 'SKIP' 'JSON parses' @('no JSON files found under tools/ or templates/') }
else { Write-Check ($(if ($badJson.Count) { 'FAIL' } else { 'PASS' })) ('JSON parses ({0} files)' -f $jsonFiles.Count) $badJson }

# 2. ASCII only, no BOM, for tracked files
$tracked = Get-Tracked
if ($null -eq $tracked) { Write-Check 'SKIP' 'Tracked files are ASCII only with no BOM' @('git cannot list tracked files here') }
else {
  $nonAscii = @(); $boms = @()
  foreach ($rel in $tracked) {
    $path = Join-Path $repo ($rel.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $boms += $rel }
    $n = 0
    foreach ($b in $bytes) { if ($b -gt 0x7F) { $n++ } }
    if ($n -gt 0) { $nonAscii += ('{0} ({1} non-ASCII bytes)' -f $rel, $n) }
  }
  $detail = @($nonAscii | ForEach-Object { 'non-ASCII: ' + $_ }) + @($boms | ForEach-Object { 'BOM: ' + $_ })
  Write-Check ($(if ($detail.Count) { 'FAIL' } else { 'PASS' })) ('Tracked files are ASCII only with no BOM ({0} files)' -f $tracked.Count) $detail
}

# 3. Required documents and tools
$required = @('README.md', 'LICENSE', 'docs/DESIGN.md', 'docs/SHARING.md', 'docs/THIRD-PARTY.md', 'docs/RESTORE.md',
  'tools/playbook.ps1', 'tools/scan-allow.txt', 'tools/manifest.json', 'tools/test-scan.ps1', 'tools/health.ps1',
  'templates/global-CLAUDE.md', 'templates/workspace-CLAUDE.md', 'templates/manifest.example.json')
$missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $repo ($_.Replace('/', '\'))) -PathType Leaf) })
Write-Check ($(if ($missing.Count) { 'FAIL' } else { 'PASS' })) ('Required files present ({0})' -f $required.Count) ($missing | ForEach-Object { 'missing: ' + $_ })

# 4. Machine-local files are ignored and not tracked
if ($null -eq $tracked) { Write-Check 'SKIP' 'Machine-local files are ignored and not tracked' @('git cannot list tracked files here') }
else {
  $leaks = @($tracked | Where-Object { $_ -like 'tools/*.local.json' -or $_ -eq '.playbook-state.json' })
  $unignored = @()
  foreach ($probe in @('tools/redact.local.json', '.playbook-state.json')) {
    & git -C $repo check-ignore -q -- $probe 2>$null
    if ($LASTEXITCODE -ne 0) { $unignored += $probe }
  }
  $detail = @($leaks | ForEach-Object { 'tracked: ' + $_ }) + @($unignored | ForEach-Object { 'not git-ignored: ' + $_ })
  Write-Check ($(if ($detail.Count) { 'FAIL' } else { 'PASS' })) 'Machine-local files are ignored and not tracked' $detail
}

# 5. Sensitive-data scan on this repository
$scanOut = (& powershell -NoProfile -File (Join-Path $repo 'tools\playbook.ps1') scan 2>&1 | Out-String)
if ($scanOut -match 'Scan: clean') { Write-Check 'PASS' 'Sensitive-data scan is clean' }
else { Write-Check 'FAIL' 'Sensitive-data scan is clean' @(($scanOut -split "`r?`n") | Where-Object { $_ -match '^\s+\S+:\d+:' }) }

# 6. Mutation test of the scan
$mutOut = (& powershell -NoProfile -File (Join-Path $repo 'tools\test-scan.ps1') 2>&1 | Out-String)
if ($LASTEXITCODE -eq 0 -and $mutOut -match 'PASS:') { Write-Check 'PASS' 'Scan mutation test (planted values)' }
else { Write-Check 'FAIL' 'Scan mutation test (planted values)' @(($mutOut -split "`r?`n") | Where-Object { $_ -match '\S' }) }

Write-Host ''
Write-Host ('Passed {0}, failed {1}, skipped {2} (skipped is not a pass).' -f $script:Passed, $script:Failed, $script:Skipped)
if ($script:Failed -gt 0) { exit 1 }
exit 0
