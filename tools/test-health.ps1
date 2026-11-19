<#
.SYNOPSIS
  Mutation test for tools/health.ps1. Exits 1 if health.ps1 misses any planted defect.

.DESCRIPTION
  Copies the repository (files git tracks, plus untracked files git does not ignore; never .git or
  machine-local files) to a temporary folder, turns the copy into a throwaway git repo, and runs the
  copy's health.ps1 for a baseline. It then plants ONE defect at a time, runs health.ps1 again, and
  removes the defect. A check that cannot go red is not evidence, so each case must make health.ps1
  go red in a way the baseline did not.

  The baseline is deliberately tolerant: while files are still being written, health.ps1 may already
  fail on the real repository (missing required files, README not yet listing a new template). So
  this test does not require a green baseline. A case passes only when, after the defect is planted,
  health.ps1 (a) exits non-zero and (b) prints a detail line naming the planted defect that the
  baseline run did not print. The failure counts before and after are shown for information.

  Planted defects: a skill folder with no SKILL.md; a SKILL.md whose name differs from its folder;
  a template file README does not mention; a wrong stated count in README; a non-ASCII byte in a
  tracked file; a byte order mark in a tracked file.

  Needs git on PATH (the copy must be a git repo so health.ps1 can list tracked files). Windows
  PowerShell 5.1 safe. Scratch lives under $env:TEMP and is removed at the end.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$tmp  = Join-Path $env:TEMP ('playbook-health-test-' + [guid]::NewGuid().ToString('N'))
$utf8 = New-Object Text.UTF8Encoding($false)

function Invoke-Health {
  # Runs the copy's health.ps1. Returns the exit code, the output lines and the failed count.
  param([string]$Root)
  $ErrorActionPreference = 'Continue'
  $out = (& powershell -NoProfile -File (Join-Path $Root 'tools\health.ps1') 2>&1 | Out-String)
  $code = $LASTEXITCODE
  $lines = @(($out -split "`r?`n") | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ -match '\S' })
  $failed = -1
  if ($out -match 'failed (\d+)') { $failed = [int]$Matches[1] }
  return @{ Code = $code; Lines = $lines; Failed = $failed }
}

function Sync-Index {
  # Makes the planted state visible to git ls-files in the copy. git may warn on stderr (line endings).
  $ErrorActionPreference = 'Continue'
  & git -C $tmp add -A 2>&1 | Out-Null
}

# Undo log: files created by a case (deleted afterwards) and files modified (restored afterwards).
$script:Created = @()
$script:Saved = @{}

function Add-PlantedFile {
  param([string]$Rel, [string]$Text)
  $full = Join-Path $tmp $Rel.Replace('/', '\')
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $full) | Out-Null
  [IO.File]::WriteAllText($full, $Text, $utf8)
  $script:Created += $full
}

function Edit-PlantedFile {
  # Replaces a file's bytes by Transform(bytes), remembering the original so it can be restored.
  param([string]$Rel, [scriptblock]$Transform)
  $full = Join-Path $tmp $Rel.Replace('/', '\')
  if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw ('cannot plant: {0} does not exist in the copy' -f $Rel) }
  $orig = [IO.File]::ReadAllBytes($full)
  if (-not $script:Saved.ContainsKey($full)) { $script:Saved[$full] = $orig }
  [IO.File]::WriteAllBytes($full, [byte[]](& $Transform $orig))
}

function Reset-Plants {
  foreach ($k in @($script:Saved.Keys)) { [IO.File]::WriteAllBytes($k, $script:Saved[$k]) }
  foreach ($f in $script:Created) { Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction SilentlyContinue }
  # Remove folders that a case created and left empty.
  foreach ($f in $script:Created) {
    $d = Split-Path -Parent $f
    while ($d -and $d.Length -gt $tmp.Length -and (Test-Path -LiteralPath $d) -and @(Get-ChildItem -LiteralPath $d -Force).Count -eq 0) {
      Remove-Item -LiteralPath $d -Force; $d = Split-Path -Parent $d
    }
  }
  $script:Created = @(); $script:Saved = @{}
  Sync-Index
}

# Each case: Plant makes the defect; Token must appear in a detail line that the baseline lacks.
$cases = @(
  @{ Name = 'skill folder with no SKILL.md'
     Token = 'zz-plant-nofile: no SKILL.md'
     Plant = { Add-PlantedFile 'shared/skills/zz-plant-nofile/notes.txt' "no skill file here`n" } },
  @{ Name = 'SKILL.md whose name differs from its folder'
     Token = 'zz-plant-name: name'
     Plant = { Add-PlantedFile 'shared/skills/zz-plant-name/SKILL.md' "---`nname: some-other-name`ndescription: A planted skill.`n---`nBody.`n" } },
  @{ Name = 'template file not mentioned in README'
     Token = 'zz-plant-template.md'
     Plant = { Add-PlantedFile 'templates/zz-plant-template.md' "# Planted template`n" } },
  @{ Name = 'wrong stated count in README'
     Token = '99 shared skills'
     Plant = { Edit-PlantedFile 'README.md' { param($b) $add = $utf8.GetBytes("`nThis repository ships 99 shared skills.`n"); $b + $add } } },
  @{ Name = 'non-ASCII byte in a tracked file'
     Token = 'non-ASCII: docs/DESIGN.md'
     Plant = { Edit-PlantedFile 'docs/DESIGN.md' { param($b) $b + [byte[]](0x63, 0x61, 0x66, 0xC3, 0xA9, 0x0A) } } },
  @{ Name = 'byte order mark in a tracked file'
     Token = 'BOM: docs/RESTORE.md'
     Plant = { Edit-PlantedFile 'docs/RESTORE.md' { param($b) [byte[]](0xEF, 0xBB, 0xBF) + $b } } }
)

$results = @()
try {
  # Copy: tracked files plus untracked files that are not ignored (so work in progress is tested).
  $listed = @(& git -C $repo ls-files --cached --others --exclude-standard 2>$null)
  $copied = 0
  if ($LASTEXITCODE -eq 0 -and $listed.Count -gt 0) {
    foreach ($rel in ($listed | Sort-Object -Unique)) {
      $src = Join-Path $repo $rel.Replace('/', '\')
      if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { continue }
      $dst = Join-Path $tmp $rel.Replace('/', '\')
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
      Copy-Item -LiteralPath $src -Destination $dst -Force
      $copied++
    }
  }
  else {
    # git cannot list files: plain copy without .git. Ignored machine files are skipped by name.
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    Get-ChildItem -LiteralPath $repo -Force | Where-Object { $_.Name -ne '.git' } | ForEach-Object {
      Copy-Item -LiteralPath $_.FullName -Destination $tmp -Recurse -Force
    }
    Get-ChildItem -LiteralPath $tmp -Recurse -Force -File | Where-Object { $_.Name -like '*.local.json' -or $_.Name -eq '.playbook-state.json' } | Remove-Item -Force
    $copied = @(Get-ChildItem -LiteralPath $tmp -Recurse -File -Force).Count
  }
  $ErrorActionPreference = 'Continue'
  & git -C $tmp init -q 2>&1 | Out-Null
  $ErrorActionPreference = 'Stop'
  Sync-Index
  Write-Host ('Copied {0} files to a throwaway repo.' -f $copied)

  $base = Invoke-Health $tmp
  if ($base.Failed -lt 0) { Write-Host 'FAIL: baseline health.ps1 produced no summary line'; $base.Lines | ForEach-Object { Write-Host "  $_" }; exit 1 }
  Write-Host ('Baseline: health.ps1 exit {0}, {1} failed check(s). A red baseline is allowed; only the change is judged.' -f $base.Code, $base.Failed)
  $baseSet = @{}
  foreach ($l in $base.Lines) { $baseSet[$l.Trim()] = $true }

  foreach ($c in $cases) {
    $state = 'FAIL'; $why = ''
    try {
      & $c.Plant
      Sync-Index
      # A token already in the baseline output would make the case prove nothing.
      $preexisting = @($base.Lines | Where-Object { $_.Contains($c.Token) })
      $after = Invoke-Health $tmp
      $newLines = @($after.Lines | Where-Object { -not $baseSet.ContainsKey($_.Trim()) })
      $named = @($newLines | Where-Object { $_.Contains($c.Token) })
      if ($preexisting.Count) { $why = 'the baseline already reported this token, so the case proves nothing' }
      elseif ($after.Code -eq 0) { $why = 'health.ps1 still exited 0 with the defect planted' }
      elseif ($named.Count -eq 0) { $why = ('health.ps1 exited {0} but printed no new line naming "{1}"' -f $after.Code, $c.Token) }
      else { $state = 'PASS'; $why = ('exit {0}, failed checks {1} -> {2}' -f $after.Code, $base.Failed, $after.Failed) }
    }
    catch { $why = ('test error: {0}' -f $_.Exception.Message) }
    finally { Reset-Plants }
    $results += @{ Name = $c.Name; State = $state }
    Write-Host ('[{0}] {1} ({2})' -f $state, $c.Name, $why) -ForegroundColor $(if ($state -eq 'PASS') { 'Green' } else { 'Red' })
  }

  # Sanity: after all plants are removed the copy must behave like the baseline again.
  $again = Invoke-Health $tmp
  $restored = ($again.Code -eq $base.Code -and $again.Failed -eq $base.Failed)
  $state = if ($restored) { 'PASS' } else { 'FAIL' }
  $results += @{ Name = 'copy restored to baseline after all cases'; State = $state }
  Write-Host ('[{0}] copy restored to baseline after all cases (exit {1}, failed {2})' -f $state, $again.Code, $again.Failed) -ForegroundColor $(if ($restored) { 'Green' } else { 'Red' })
}
finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

$bad = @($results | Where-Object { $_.State -ne 'PASS' }).Count
Write-Host ''
if ($bad -gt 0 -or $results.Count -eq 0) { Write-Host ('FAIL: {0} of {1} cases failed' -f $bad, $results.Count) -ForegroundColor Red; exit 1 }
Write-Host ('PASS: {0} of {0} planted defects were caught' -f ($results.Count - 1)) -ForegroundColor Green
exit 0
