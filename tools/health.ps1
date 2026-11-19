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
    7. Every folder under shared/skills has a SKILL.md with a matching name and a description.
    8. README.md mentions every skill folder and every file under templates/ and docs/.
    9. Counts stated in README.md ("N shared skills", "N skills", "N templates") match the disk.
   10. tools/check-templates.ps1 works: it finds markers in templates/ and none in a clean file.
   11. tools/test-engine.ps1, when present, exits 0.
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
  'templates/global-CLAUDE.md', 'templates/workspace-CLAUDE.md', 'templates/manifest.example.json',
  'tools/check-templates.ps1', 'tools/test-health.ps1', 'tools/test-engine.ps1',
  'docs/LOADING.md', 'docs/SKILLS.md', 'docs/MEMORY.md',
  'templates/working-reference.md', 'templates/gotchas-template.md', 'examples/filled-global-CLAUDE.md',
  'shared/skills/end-of-session/SKILL.md', 'shared/skills/session-start/SKILL.md',
  'shared/skills/pre-close-verification/SKILL.md', 'shared/skills/branch-hygiene/SKILL.md',
  'shared/skills/directional-prompting/SKILL.md', 'shared/skills/prod-deploy/SKILL.md')
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

# 7. Every skill folder has a SKILL.md with a matching name and a description
function Get-SkillFrontmatter {
  # Reads the YAML frontmatter of a SKILL.md. Returns Ok, Error, Name, Description.
  param([string]$File)
  $text = [IO.File]::ReadAllText($File, (New-Object Text.UTF8Encoding($false))).TrimStart([char]0xFEFF)
  $lines = $text -split "`r?`n"
  $r = @{ Ok = $false; Error = ''; Name = ''; Description = '' }
  if ($lines.Count -lt 2 -or $lines[0].TrimEnd() -ne '---') { $r.Error = 'no frontmatter (first line is not ---)'; return $r }
  $end = -1
  for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].TrimEnd() -eq '---') { $end = $i; break } }
  if ($end -lt 0) { $r.Error = 'frontmatter is not closed with ---'; return $r }
  for ($i = 1; $i -lt $end; $i++) {
    $line = $lines[$i]
    if ($line -match '^name:\s*(.*?)\s*$') {
      $r.Name = ($Matches[1] -replace '^([''"])(.*)\1$', '$2')
    }
    elseif ($line -match '^description:\s*(.*?)\s*$') {
      $val = $Matches[1]
      if ($val -eq '' -or $val -match '^[>|][+-]?$') {
        # Folded or literal block (or a plain value continued on indented lines): join the indented lines.
        $parts = @()
        for ($j = $i + 1; $j -lt $end -and $lines[$j] -match '^\s'; $j++) { if ($lines[$j].Trim() -ne '') { $parts += $lines[$j].Trim() } }
        $val = $parts -join ' '
      }
      else { $val = ($val -replace '^([''"])(.*)\1$', '$2') }
      $r.Description = $val
    }
  }
  $r.Ok = $true
  return $r
}

$skillsDir = Join-Path $repo 'shared\skills'
$skillFolders = @()
if (Test-Path -LiteralPath $skillsDir -PathType Container) { $skillFolders = @(Get-ChildItem -LiteralPath $skillsDir -Directory) }
if ($skillFolders.Count -eq 0) { Write-Check 'SKIP' 'Skill folders have a valid SKILL.md' @('no folders under shared/skills') }
else {
  $skillProblems = @()
  foreach ($d in $skillFolders) {
    $sf = Join-Path $d.FullName 'SKILL.md'
    if (-not (Test-Path -LiteralPath $sf -PathType Leaf)) { $skillProblems += ('{0}: no SKILL.md' -f $d.Name); continue }
    $fm = Get-SkillFrontmatter -File $sf
    if (-not $fm.Ok) { $skillProblems += ('{0}: {1}' -f $d.Name, $fm.Error); continue }
    if ($fm.Name -ne $d.Name) { $skillProblems += ("{0}: name '{1}' does not match the folder name" -f $d.Name, $fm.Name) }
    if ([string]::IsNullOrWhiteSpace($fm.Description)) { $skillProblems += ('{0}: description is missing or empty' -f $d.Name) }
  }
  Write-Check ($(if ($skillProblems.Count) { 'FAIL' } else { 'PASS' })) ('Skill folders have a valid SKILL.md ({0} folders)' -f $skillFolders.Count) $skillProblems
}

# 8. README mentions every skill folder and every file under templates/ and docs/
$readmePath = Join-Path $repo 'README.md'
$readme = ''
if (Test-Path -LiteralPath $readmePath -PathType Leaf) { $readme = [IO.File]::ReadAllText($readmePath, (New-Object Text.UTF8Encoding($false))) }
if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) { Write-Check 'SKIP' 'README mentions every skill, template and doc' @('README.md is missing') }
else {
  $unmentioned = @()
  foreach ($d in $skillFolders) {
    if ($readme.IndexOf($d.Name, [StringComparison]::Ordinal) -lt 0) { $unmentioned += ('README.md does not mention skill folder {0}' -f $d.Name) }
  }
  $listed = 0
  foreach ($sub in @('templates', 'docs')) {
    $dir = Join-Path $repo $sub
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -File -Recurse)) {
      $listed++
      if ($readme.IndexOf($f.Name, [StringComparison]::Ordinal) -lt 0) { $unmentioned += ('README.md does not mention {0}/{1}' -f $sub, $f.Name) }
    }
  }
  Write-Check ($(if ($unmentioned.Count) { 'FAIL' } else { 'PASS' })) ('README mentions every skill, template and doc ({0} skills, {1} files)' -f $skillFolders.Count, $listed) $unmentioned
}

# 9. Counts stated in README.md match the disk
if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) { Write-Check 'SKIP' 'Counts stated in README match the disk' @('README.md is missing') }
else {
  $tplDir = Join-Path $repo 'templates'
  $tplCount = 0
  if (Test-Path -LiteralPath $tplDir -PathType Container) { $tplCount = @(Get-ChildItem -LiteralPath $tplDir -File -Recurse).Count }
  $phrases = @([regex]::Matches($readme, '(?i)\b(\d+)\s+(shared\s+skills?|skills?|templates?)\b'))
  if ($phrases.Count -eq 0) { Write-Check 'SKIP' 'Counts stated in README match the disk' @('README.md states no "N shared skills", "N skills" or "N templates" count, so there is nothing to compare') }
  else {
    $wrong = @()
    foreach ($m in $phrases) {
      $stated = [int]$m.Groups[1].Value
      $kind = $m.Groups[2].Value.ToLower()
      $actual = if ($kind -like '*skill*') { $skillFolders.Count } else { $tplCount }
      if ($stated -ne $actual) { $wrong += ('README says "{0}", disk has {1}' -f $m.Value, $actual) }
    }
    Write-Check ($(if ($wrong.Count) { 'FAIL' } else { 'PASS' })) ('Counts stated in README match the disk ({0} stated)' -f $phrases.Count) $wrong
  }
}

# 10. The template checker works: it finds markers in the shipped (blank) templates, none in a clean file.
#     The shipped templates are blanks, so they SHOULD still contain <<FILL ...>> markers. Finding at
#     least one proves the checker can go red; a clean temp file proves it can also go green.
$checker = Join-Path $repo 'tools\check-templates.ps1'
if (-not (Test-Path -LiteralPath $checker -PathType Leaf)) { Write-Check 'SKIP' 'Template checker finds markers and clears a clean file' @('tools/check-templates.ps1 is missing') }
elseif (-not (Test-Path -LiteralPath (Join-Path $repo 'templates') -PathType Container)) { Write-Check 'SKIP' 'Template checker finds markers and clears a clean file' @('templates/ is missing') }
else {
  $problems = @()
  $out1 = (& powershell -NoProfile -File $checker -Path (Join-Path $repo 'templates') 2>&1 | Out-String)
  $code1 = $LASTEXITCODE
  if ($code1 -ne 1) { $problems += ('against templates/ it exited {0}, expected 1' -f $code1) }
  if ($out1 -notmatch '(?m)^([1-9]\d*) markers? in ') { $problems += 'against templates/ it did not report at least one marker' }
  $clean = Join-Path $env:TEMP ('playbook-clean-' + [guid]::NewGuid().ToString('N') + '.md')
  try {
    [IO.File]::WriteAllText($clean, "# A file with no markers`nNothing to fill here.`n", (New-Object Text.UTF8Encoding($false)))
    $out2 = (& powershell -NoProfile -File $checker -Path $clean 2>&1 | Out-String)
    $code2 = $LASTEXITCODE
    if ($code2 -ne 0) { $problems += ('against a marker-free file it exited {0}, expected 0' -f $code2) }
    if ($out2 -notmatch '(?m)^0 markers in ') { $problems += 'against a marker-free file it did not report "0 markers"' }
  }
  finally { Remove-Item -LiteralPath $clean -Force -ErrorAction SilentlyContinue }
  Write-Check ($(if ($problems.Count) { 'FAIL' } else { 'PASS' })) 'Template checker finds markers and clears a clean file' $problems
}

# 11. Engine tests, when the file exists (written separately; absent means SKIP, not PASS)
$engineTest = Join-Path $repo 'tools\test-engine.ps1'
if (-not (Test-Path -LiteralPath $engineTest -PathType Leaf)) { Write-Check 'SKIP' 'Engine tests (tools/test-engine.ps1)' @('tools/test-engine.ps1 does not exist yet') }
else {
  $engOut = (& powershell -NoProfile -File $engineTest 2>&1 | Out-String)
  $engCode = $LASTEXITCODE
  if ($engCode -eq 0) { Write-Check 'PASS' 'Engine tests (tools/test-engine.ps1)' }
  else { Write-Check 'FAIL' 'Engine tests (tools/test-engine.ps1)' (@('exit code ' + $engCode) + @(($engOut -split "`r?`n") | Where-Object { $_ -match '\S' } | Select-Object -Last 15)) }
}

Write-Host ''
Write-Host ('Passed {0}, failed {1}, skipped {2} (skipped is not a pass).' -f $script:Passed, $script:Failed, $script:Skipped)
if ($script:Failed -gt 0) { exit 1 }
exit 0
