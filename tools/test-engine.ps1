<#
.SYNOPSIS
  Behaviour test for the sync engine tools/playbook.ps1. Exits 1 on any FAIL.

.DESCRIPTION
  Builds a throwaway sandbox under the system temp folder (its own copy of the engine, a manifest, two fake roots,
  a fake home), runs the engine as a child process under the same PowerShell host that runs this script, and checks
  each behaviour: first capture, one-sided edits, both-sided conflict, baseline, status -Strict, restore of an
  absent live copy, and an old one-hash state file. Never touches the real manifest, repo state or home folder.
  The conflict check is also run against a mutated copy of the engine (the conflict guard removed); that run must
  turn the assertion red, which shows the assertion can fail.

  Run it under both hosts:
    powershell -NoProfile -File tools\test-engine.ps1
    pwsh -NoProfile -File tools\test-engine.ps1
  -Engine <path> tests another copy of the engine (for example an older one).
#>
[CmdletBinding()]
param([string]$Engine)

Set-StrictMode -Version Latest
if (-not $Engine) { $Engine = Join-Path $PSScriptRoot 'playbook.ps1' }
$ErrorActionPreference = 'Continue'

$Utf8NoBom  = New-Object Text.UTF8Encoding($false)
$HostExe    = (Get-Process -Id $PID).Path
$Top        = Join-Path ([IO.Path]::GetTempPath()) ('playbook-engine-test-' + [guid]::NewGuid().ToString('N'))
$script:Pass = 0
$script:Fail = 0
$script:N    = 0

function Check([string]$name, [bool]$ok, [string]$detail) {
  if ($ok) { $script:Pass++; Write-Host ('PASS  ' + $name) }
  else { $script:Fail++; Write-Host ('FAIL  ' + $name + $(if ($detail) { '   <- ' + $detail } else { '' })) }
}

function Set-Text([string]$path, [string]$text) {
  $d = Split-Path -Parent $path
  if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
  [IO.File]::WriteAllText($path, $text, $Utf8NoBom)
}
function Get-Text([string]$path) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
  return [IO.File]::ReadAllText($path, $Utf8NoBom)
}
function Get-Sha([string]$path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }

# Entries are ordered hashtables; root 'a' is the fake live root.
function New-Entry([string]$scope, [string]$path, [hashtable]$extra) {
  $e = [ordered]@{ scope = $scope; root = 'a'; path = $path }
  # GetEnumerator, not .Keys: an entry key named 'keys' would shadow the Keys property of a hashtable.
  if ($extra) { foreach ($kv in $extra.GetEnumerator()) { $e[$kv.Key] = $kv.Value } }
  return $e
}

function New-Sandbox($entries, [string]$engineText) {
  $script:N++
  $dir   = Join-Path $Top ('sb' + $script:N)
  $repo  = Join-Path $dir 'repo'
  $tools = Join-Path $repo 'tools'
  $live  = Join-Path $dir 'rootA'
  $home2 = Join-Path $dir 'home'
  foreach ($d in @($tools, $live, $home2)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
  $eng = Join-Path $tools 'playbook.ps1'
  [IO.File]::WriteAllText($eng, $engineText, $Utf8NoBom)
  $mf = [ordered]@{ roots = [ordered]@{ a = $live }; shared = @(); entries = @($entries) }
  [IO.File]::WriteAllText((Join-Path $tools 'manifest.json'), (ConvertTo-Json -InputObject $mf -Depth 6), $Utf8NoBom)
  return @{ Dir = $dir; Repo = $repo; Tools = $tools; A = $live; Home = $home2; Engine = $eng; State = (Join-Path $repo '.playbook-state.json') }
}

function Get-RepoFile($sb, [string]$scope, [string]$rel) { return (Join-Path (Join-Path (Join-Path $sb.Repo 'domains') $scope) $rel) }
function Get-LiveFile($sb, [string]$rel) { return (Join-Path $sb.A $rel) }

# Runs the engine in a child process of this same host. USERPROFILE points at the sandbox so install backups
# land there. Returns .Out (all output text) and .Code (exit code).
function Invoke-Engine($sb, [string[]]$EngineArgs) {
  $old = $env:USERPROFILE
  $env:USERPROFILE = $sb.Home
  try {
    $out = (& $HostExe -NoProfile -ExecutionPolicy Bypass -File $sb.Engine @EngineArgs 2>&1 | Out-String)
    $code = $LASTEXITCODE
  }
  finally { $env:USERPROFILE = $old }
  return [pscustomobject]@{ Out = $out; Code = $code }
}

# The status word of one scope, read from the summary lines ("<scope>, <status>   <count>"). In-sync entries are
# not listed individually, so the summary is the only place every status shows up. Anything but exactly one line
# for the scope returns NONE(n) so a failed run cannot pass as a status.
function Get-Word($sb, [string]$scope) {
  $r = Invoke-Engine $sb @('status')
  $m = [regex]::Matches($r.Out, '(?m)^' + [regex]::Escape($scope) + ', (\S+)\s+\d+\s*$')
  if ($m.Count -ne 1) { return ('NONE(' + $m.Count + ')') }
  return $m[0].Groups[1].Value
}

# New sandbox with one plain entry, a live file, and one capture so the pair is in-sync and recorded.
function New-Synced([string]$scope, [string]$text, [string]$engineText) {
  $sb = New-Sandbox @((New-Entry $scope 'f.txt' $null)) $engineText
  Set-Text (Get-LiveFile $sb 'f.txt') $text
  [void](Invoke-Engine $sb @('capture'))
  return $sb
}

# Both sides edited -> CONFLICT. Returns the status word and whether capture and install (no -Force) left both
# files byte-identical to what was planted.
function Test-ConflictMovesNothing([string]$scope, [string]$engineText) {
  $sb = New-Synced $scope 'base' $engineText
  Set-Text (Get-LiveFile $sb 'f.txt') 'live-side'
  Set-Text (Get-RepoFile $sb $scope 'f.txt') 'repo-side'
  $word = Get-Word $sb $scope
  [void](Invoke-Engine $sb @('capture'))
  [void](Invoke-Engine $sb @('install'))
  $unmoved = ((Get-Text (Get-LiveFile $sb 'f.txt')) -eq 'live-side') -and ((Get-Text (Get-RepoFile $sb $scope 'f.txt')) -eq 'repo-side')
  return @{ Word = $word; Unmoved = $unmoved; Sb = $sb }
}

try {
  New-Item -ItemType Directory -Force -Path $Top | Out-Null
  if (-not (Test-Path -LiteralPath $Engine -PathType Leaf)) { Write-Host ('FAIL  engine not found: ' + $Engine); exit 1 }
  $EngineText = [IO.File]::ReadAllText($Engine, $Utf8NoBom)
  Write-Host ('Host: {0} (PowerShell {1})' -f (Split-Path -Leaf $HostExe), $PSVersionTable.PSVersion)
  Write-Host ''

  # 1. First capture.
  $sb = New-Sandbox @((New-Entry 'c1' 'f.txt' $null)) $EngineText
  Set-Text (Get-LiveFile $sb 'f.txt') 'v1'
  Check 'first capture: before, status is live-only' ((Get-Word $sb 'c1') -eq 'live-only') (Get-Word $sb 'c1')
  $r = Invoke-Engine $sb @('capture')
  Check 'first capture: exit code 0' ($r.Code -eq 0) ('exit ' + $r.Code)
  Check 'first capture: repo copy holds the live content' ((Get-Text (Get-RepoFile $sb 'c1' 'f.txt')) -eq 'v1')
  Check 'first capture: status is in-sync afterwards' ((Get-Word $sb 'c1') -eq 'in-sync') (Get-Word $sb 'c1')
  $stateObj = $null
  if (Test-Path -LiteralPath $sb.State) { $stateObj = (Get-Content -LiteralPath $sb.State -Raw -Encoding UTF8 | ConvertFrom-Json) }
  $stored = $null
  if ($stateObj) { $stored = $stateObj.'c1|f.txt' }
  Check 'first capture: state file stores one hash string per entry (old format kept)' (($stored -is [string]) -and ($stored -match '^[0-9A-Fa-f]{64}$')) ('stored: ' + $stored)

  # 2. One-sided live edit.
  $sb = New-Synced 'c2' 'v1' $EngineText
  Set-Text (Get-LiveFile $sb 'f.txt') 'v2-live'
  Check 'live edit: status is live-ahead' ((Get-Word $sb 'c2') -eq 'live-ahead') (Get-Word $sb 'c2')
  [void](Invoke-Engine $sb @('capture'))
  Check 'live edit: capture moves it into the repo' ((Get-Text (Get-RepoFile $sb 'c2' 'f.txt')) -eq 'v2-live')
  Check 'live edit: status is in-sync afterwards' ((Get-Word $sb 'c2') -eq 'in-sync') (Get-Word $sb 'c2')

  # 3. One-sided repo edit.
  $sb = New-Synced 'c3' 'v1' $EngineText
  Set-Text (Get-RepoFile $sb 'c3' 'f.txt') 'v2-repo'
  Check 'repo edit: status is repo-ahead' ((Get-Word $sb 'c3') -eq 'repo-ahead') (Get-Word $sb 'c3')
  [void](Invoke-Engine $sb @('install'))
  Check 'repo edit: install moves it onto the live path' ((Get-Text (Get-LiveFile $sb 'f.txt')) -eq 'v2-repo')
  Check 'repo edit: status is in-sync afterwards' ((Get-Word $sb 'c3') -eq 'in-sync') (Get-Word $sb 'c3')

  # 4. Edit on both sides: CONFLICT, nothing moves without -Force.
  $t = Test-ConflictMovesNothing 'c4' $EngineText
  Check 'conflict: status is CONFLICT' ($t.Word -eq 'CONFLICT') $t.Word
  Check 'conflict: capture and install without -Force move no bytes' $t.Unmoved 'a file changed'
  [void](Invoke-Engine $t.Sb @('capture', '-Force'))
  Check 'conflict: capture -Force makes the live side win' ((Get-Text (Get-RepoFile $t.Sb 'c4' 'f.txt')) -eq 'live-side')
  $t2 = Test-ConflictMovesNothing 'c4b' $EngineText
  [void](Invoke-Engine $t2.Sb @('install', '-Force'))
  Check 'conflict: install -Force makes the repo side win' ((Get-Text (Get-LiveFile $t2.Sb 'f.txt')) -eq 'repo-side')

  # 4m. Mutation: take the conflict guard out of a copy of the engine. The same assertion must now go red.
  $guard = 'if (-not $Force) { Write-Host ("  CONFLICT'
  $mutated = $EngineText.Replace($guard, 'if ($false) { Write-Host ("  CONFLICT')
  Check 'mutation: the conflict guard was found and removed in the engine copy' ($mutated -ne $EngineText) 'guard text not found'
  if ($mutated -ne $EngineText) {
    $tm = Test-ConflictMovesNothing 'c4m' $mutated
    Check 'mutation: with the guard removed the moves-nothing assertion goes red (bytes moved)' (-not $tm.Unmoved) 'files did not move, so the assertion cannot catch a broken guard'
  }

  # 5. Baseline: planted differing pair.
  $sb = New-Sandbox @((New-Entry 'c5' 'f.txt' $null)) $EngineText
  Set-Text (Get-LiveFile $sb 'f.txt') 'linux-variant'
  Set-Text (Get-RepoFile $sb 'c5' 'f.txt') 'windows-original'
  Check 'baseline: planted differing pair reads CONFLICT' ((Get-Word $sb 'c5') -eq 'CONFLICT') (Get-Word $sb 'c5')
  $r = Invoke-Engine $sb @('baseline')
  Check 'baseline: without -Scope it exits 1 and says so' (($r.Code -eq 1) -and ($r.Out -match 'needs -Scope')) ('exit ' + $r.Code)
  Check 'baseline: without -Scope nothing is recorded' ((Get-Word $sb 'c5') -eq 'CONFLICT') (Get-Word $sb 'c5')
  $r = Invoke-Engine $sb @('baseline', '-Scope', 'c5', '-DryRun')
  Check 'baseline -DryRun: exits 0, names the entry, records nothing' (($r.Code -eq 0) -and ($r.Out -match 'baseline\s+c5\|f\.txt') -and ((Get-Word $sb 'c5') -eq 'CONFLICT')) ('exit ' + $r.Code + ' word ' + (Get-Word $sb 'c5'))
  Check 'baseline -DryRun: no state file written' (-not (Test-Path -LiteralPath $sb.State))
  $r = Invoke-Engine $sb @('baseline', '-Scope', 'c5')
  Check 'baseline: exits 0' ($r.Code -eq 0) ('exit ' + $r.Code)
  Check 'baseline: status reads in-sync' ((Get-Word $sb 'c5') -eq 'in-sync') (Get-Word $sb 'c5')
  Check 'baseline: copied nothing (both files unchanged)' (((Get-Text (Get-LiveFile $sb 'f.txt')) -eq 'linux-variant') -and ((Get-Text (Get-RepoFile $sb 'c5' 'f.txt')) -eq 'windows-original'))
  $stateObj = $null
  if (Test-Path -LiteralPath $sb.State) { $stateObj = (Get-Content -LiteralPath $sb.State -Raw -Encoding UTF8 | ConvertFrom-Json) }
  $entry5 = $null
  if ($stateObj) { $entry5 = $stateObj.'c5|f.txt' }
  Check 'baseline: state holds two hashes (live and repo)' (($null -ne $entry5) -and ($entry5.live -eq (Get-Sha (Get-LiveFile $sb 'f.txt'))) -and ($entry5.repo -eq (Get-Sha (Get-RepoFile $sb 'c5' 'f.txt')))) 'no two-hash entry in the state file'
  [void](Invoke-Engine $sb @('capture', '-Scope', 'c5'))
  [void](Invoke-Engine $sb @('install', '-Scope', 'c5'))
  Check 'baseline: a later capture and install keep it in-sync and move nothing' (((Get-Word $sb 'c5') -eq 'in-sync') -and ((Get-Text (Get-LiveFile $sb 'f.txt')) -eq 'linux-variant') -and ((Get-Text (Get-RepoFile $sb 'c5' 'f.txt')) -eq 'windows-original')) (Get-Word $sb 'c5')
  Set-Text (Get-LiveFile $sb 'f.txt') 'linux-variant-edited'
  Check 'baseline: a live edit afterwards reads CONFLICT again' ((Get-Word $sb 'c5') -eq 'CONFLICT') (Get-Word $sb 'c5')
  [void](Invoke-Engine $sb @('capture', '-Scope', 'c5'))
  Check 'baseline: that conflict moves nothing without -Force' ((Get-Text (Get-RepoFile $sb 'c5' 'f.txt')) -eq 'windows-original')
  # Repo-side change after a baseline.
  $sb = New-Sandbox @((New-Entry 'c5r' 'f.txt' $null)) $EngineText
  Set-Text (Get-LiveFile $sb 'f.txt') 'linux-variant'
  Set-Text (Get-RepoFile $sb 'c5r' 'f.txt') 'windows-original'
  [void](Invoke-Engine $sb @('baseline', '-Scope', 'c5r'))
  Set-Text (Get-RepoFile $sb 'c5r' 'f.txt') 'windows-edited'
  Check 'baseline: a repo edit afterwards reads CONFLICT again' ((Get-Word $sb 'c5r') -eq 'CONFLICT') (Get-Word $sb 'c5r')

  # 6. Old state file (one hash per entry, plus one baselined object) still loads and behaves as before.
  # c6a: live changed, repo = recorded. c6b: repo changed, live = recorded. c6c: baselined pair.
  $entries = @((New-Entry 'c6a' 'a.txt' $null), (New-Entry 'c6b' 'b.txt' $null), (New-Entry 'c6c' 'c.txt' $null))
  $sb = New-Sandbox $entries $EngineText
  Set-Text (Get-RepoFile $sb 'c6a' 'a.txt') 'old'; Set-Text (Get-LiveFile $sb 'a.txt') 'new'
  Set-Text (Get-LiveFile $sb 'b.txt') 'old';       Set-Text (Get-RepoFile $sb 'c6b' 'b.txt') 'new'
  Set-Text (Get-LiveFile $sb 'c.txt') 'lx';        Set-Text (Get-RepoFile $sb 'c6c' 'c.txt') 'ry'
  $shaOldA = Get-Sha (Get-RepoFile $sb 'c6a' 'a.txt')
  $shaOldB = Get-Sha (Get-LiveFile $sb 'b.txt')
  $json = '{ "c6a|a.txt": "' + $shaOldA + '", "c6b|b.txt": "' + $shaOldB + '", "c6c|c.txt": { "live": "' + (Get-Sha (Get-LiveFile $sb 'c.txt')) + '", "repo": "' + (Get-Sha (Get-RepoFile $sb 'c6c' 'c.txt')) + '" } }'
  Set-Text $sb.State $json
  Check 'old state file: one-hash entry, live changed -> live-ahead' ((Get-Word $sb 'c6a') -eq 'live-ahead') (Get-Word $sb 'c6a')
  Check 'old state file: one-hash entry, repo changed -> repo-ahead' ((Get-Word $sb 'c6b') -eq 'repo-ahead') (Get-Word $sb 'c6b')
  Check 'old state file: mixed with a baselined object entry -> in-sync' ((Get-Word $sb 'c6c') -eq 'in-sync') (Get-Word $sb 'c6c')
  [void](Invoke-Engine $sb @('capture', '-Scope', 'c6a'))
  Check 'old state file: capture works and rewrites the file without losing the baselined entry' (((Get-Text (Get-RepoFile $sb 'c6a' 'a.txt')) -eq 'new') -and ((Get-Word $sb 'c6c') -eq 'in-sync') -and ((Get-Word $sb 'c6a') -eq 'in-sync'))

  # 7. Baseline skips captureOnly, json-keys and redacted entries.
  $entries = @(
    (New-Entry 'c7a' 'f.txt' @{ captureOnly = $true }),
    (New-Entry 'c7b' 'x.json' @{ type = 'json-keys'; repoPath = 'x.json'; keys = @('a') }),
    (New-Entry 'c7c' 'r.txt' @{ type = 'redacted'; rules = 'r1' })
  )
  $sb = New-Sandbox $entries $EngineText
  Set-Text (Join-Path $sb.Tools 'redact.local.json') '{ "r1": [ { "find": "zzz", "replace": "yyy" } ] }'
  Set-Text (Get-LiveFile $sb 'f.txt') 'live-a';              Set-Text (Get-RepoFile $sb 'c7a' 'f.txt') 'repo-a'
  Set-Text (Get-LiveFile $sb 'x.json') '{ "a": 1, "b": 2 }'; Set-Text (Get-RepoFile $sb 'c7b' 'x.json') '{ }'
  Set-Text (Get-LiveFile $sb 'r.txt') 'hello zzz';           Set-Text (Get-RepoFile $sb 'c7c' 'r.txt') 'other'
  foreach ($sc in @('c7a', 'c7b', 'c7c')) {
    Check ('baseline skip: planted ' + $sc + ' differs (CONFLICT) before') ((Get-Word $sb $sc) -eq 'CONFLICT') (Get-Word $sb $sc)
    $r = Invoke-Engine $sb @('baseline', '-Scope', $sc)
    Check ('baseline skip: ' + $sc + ' is skipped with a reason and stays CONFLICT') (($r.Out -match 'skip\s+' + $sc) -and ($r.Out -match '0 recorded') -and ((Get-Word $sb $sc) -eq 'CONFLICT')) ($r.Out.Trim())
  }

  # 8. status -Strict.
  $entries = @((New-Entry 's8a' 'a.txt' $null), (New-Entry 's8b' 'b.txt' $null))
  $sb = New-Sandbox $entries $EngineText
  Set-Text (Get-LiveFile $sb 'a.txt') 'a'
  [void](Invoke-Engine $sb @('capture', '-Scope', 's8a'))
  Set-Text (Get-LiveFile $sb 'b.txt') 'b'   # s8b stays live-only
  $r0 = Invoke-Engine $sb @('status')
  Check 'strict: plain status keeps exit 0 when something is not in-sync' (($r0.Code -eq 0) -and ($r0.Out -match 's8b, live-only')) ('exit ' + $r0.Code)
  $r1 = Invoke-Engine $sb @('status', '-Strict')
  Check 'strict: -Strict exits 1 when an entry is not in-sync' (($r1.Code -eq 1) -and ($r1.Out -match 's8b, live-only')) ('exit ' + $r1.Code)
  [void](Invoke-Engine $sb @('capture', '-Scope', 's8b'))
  $r2 = Invoke-Engine $sb @('status', '-Strict')
  Check 'strict: -Strict exits 0 when every entry is in-sync' (($r2.Code -eq 0) -and ($r2.Out -match 's8a, in-sync') -and ($r2.Out -match 's8b, in-sync')) ('exit ' + $r2.Code)
  Set-Text (Get-LiveFile $sb 'a.txt') 'a-live'
  Set-Text (Get-RepoFile $sb 's8a' 'a.txt') 'a-repo'
  $r3 = Invoke-Engine $sb @('status', '-Strict')
  Check 'strict: -Strict exits 1 on a CONFLICT' (($r3.Code -eq 1) -and ($r3.Out -match 's8a, CONFLICT')) ('exit ' + $r3.Code)

  # 9. Absent live copy: install restores it (plain entries only).
  $sb = New-Synced 'c9' 'v1' $EngineText
  Remove-Item -LiteralPath (Get-LiveFile $sb 'f.txt') -Force
  Check 'restore: synced file deleted live reads live-deleted' ((Get-Word $sb 'c9') -eq 'live-deleted') (Get-Word $sb 'c9')
  $r = Invoke-Engine $sb @('install', '-DryRun')
  Check 'restore: install -DryRun names the file and writes nothing' (($r.Out -match 'install\s+c9\|f\.txt') -and -not (Test-Path -LiteralPath (Get-LiveFile $sb 'f.txt')))
  $r = Invoke-Engine $sb @('install')
  Check 'restore: install puts the repo copy back live' ((Get-Text (Get-LiveFile $sb 'f.txt')) -eq 'v1') ($r.Out.Trim())
  Check 'restore: status is in-sync afterwards' ((Get-Word $sb 'c9') -eq 'in-sync') (Get-Word $sb 'c9')

  $sb = New-Sandbox @((New-Entry 'c9b' 'f.txt' $null)) $EngineText
  Set-Text (Get-RepoFile $sb 'c9b' 'f.txt') 'only-in-repo'
  Check 'restore: never-synced repo-only file reads repo-only' ((Get-Word $sb 'c9b') -eq 'repo-only') (Get-Word $sb 'c9b')
  [void](Invoke-Engine $sb @('install'))
  Check 'restore: install restores a repo-only file live' ((Get-Text (Get-LiveFile $sb 'f.txt')) -eq 'only-in-repo')

  $sb = New-Sandbox @((New-Entry 'c9c' 'f.txt' @{ captureOnly = $true })) $EngineText
  Set-Text (Get-LiveFile $sb 'f.txt') 'mem'
  [void](Invoke-Engine $sb @('capture'))
  Remove-Item -LiteralPath (Get-LiveFile $sb 'f.txt') -Force
  Check 'restore: captureOnly entry deleted live reads live-deleted' ((Get-Word $sb 'c9c') -eq 'live-deleted') (Get-Word $sb 'c9c')
  [void](Invoke-Engine $sb @('install'))
  Check 'restore: captureOnly entry is never restored' (-not (Test-Path -LiteralPath (Get-LiveFile $sb 'f.txt')))

  $entries = @(
    (New-Entry 'c9d' 'r.txt' @{ type = 'redacted'; rules = 'r1' }),
    (New-Entry 'c9e' 'x.json' @{ type = 'json-keys'; repoPath = 'x.json'; keys = @('a') })
  )
  $sb = New-Sandbox $entries $EngineText
  Set-Text (Join-Path $sb.Tools 'redact.local.json') '{ "r1": [ { "find": "zzz", "replace": "yyy" } ] }'
  Set-Text (Get-RepoFile $sb 'c9d' 'r.txt') 'redacted-copy'
  Set-Text (Get-RepoFile $sb 'c9e' 'x.json') '{ "a": 1 }'
  Set-Text $sb.State ('{ "c9d|r.txt": "' + (Get-Sha (Get-RepoFile $sb 'c9d' 'r.txt')) + '", "c9e|x.json": "' + (Get-Sha (Get-RepoFile $sb 'c9e' 'x.json')) + '" }')
  Check 'restore: redacted and json-keys entries with a missing live file read live-deleted' (((Get-Word $sb 'c9d') -eq 'live-deleted') -and ((Get-Word $sb 'c9e') -eq 'live-deleted')) ((Get-Word $sb 'c9d') + ' / ' + (Get-Word $sb 'c9e'))
  [void](Invoke-Engine $sb @('install'))
  Check 'restore: redacted and json-keys entries are never restored' ((-not (Test-Path -LiteralPath (Get-LiveFile $sb 'r.txt'))) -and (-not (Test-Path -LiteralPath (Get-LiveFile $sb 'x.json'))))
}
finally {
  Remove-Item -LiteralPath $Top -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($script:Fail -gt 0) {
  Write-Host ('RESULT: {0} FAIL, {1} PASS' -f $script:Fail, $script:Pass) -ForegroundColor Red
  exit 1
}
Write-Host ('RESULT: all {0} checks PASS' -f $script:Pass) -ForegroundColor Green
exit 0
