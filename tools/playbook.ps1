<#
.SYNOPSIS
  Keeps the ai-playbook repo and the live Claude Code files in sync. Windows PowerShell 5.1 safe.

.DESCRIPTION
  Three-way compare per file: live copy (L), repo copy (R), and the hash recorded at the last sync (S).
    in-sync      L = R
    live-ahead   L changed, R still = S      -> `capture` copies live into the repo
    repo-ahead   R changed, L still = S      -> `install` copies the repo onto the live path
    live-only    file exists only live       -> `capture`
    repo-only    file exists only in the repo-> `install`
    CONFLICT     both changed (or never synced and different) -> nothing moves unless -Force
    UNREADABLE   a read failed (Drive placeholder, lock) -> skipped, never treated as deleted
  Only paths named in tools/manifest.json are touched. `scan` blocks secrets AND sensitive identifiers
  (IP addresses, emails, Azure subscription and tenant ids). It runs before every capture and as the git pre-commit
  hook. Approve a reviewed false positive by adding `<repo path>|<pattern>` to tools/scan-allow.txt.
  Entries of type json-keys (the global settings.json) copy only the named top-level keys, capture-only.

.EXAMPLE
  .\tools\playbook.ps1 status
  .\tools\playbook.ps1 capture -Scope myapp -DryRun
  .\tools\playbook.ps1 install -Scope core
  .\tools\playbook.ps1 scan
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)][ValidateSet('status', 'capture', 'install', 'scan', 'inventory')][string]$Command = 'status',
  [string[]]$Scope,
  [switch]$Force,
  [switch]$DryRun,
  [switch]$All
)
$ErrorActionPreference = 'Stop'
$RepoRoot  = Split-Path -Parent $PSScriptRoot
$StatePath = Join-Path $RepoRoot '.playbook-state.json'
$AllowPath = Join-Path $PSScriptRoot 'scan-allow.txt'
$MaxBytes  = 1500000
$Utf8NoBom = New-Object Text.UTF8Encoding($false)
$script:SkippedBig = New-Object System.Collections.ArrayList

# Never synced, whatever the manifest says. Matched against every path segment.
$GlobalExclude = @('__pycache__', '*.pyc', 'desktop.ini', 'Thumbs.db', '*.bak', '*.bak-*', '*.log', '*.tmp', '~$*',
  '*.zip', '*.tgz', '*.gz', '*.tar', '*.7z', '.two_challenge_state', '.plain_language_state', 'settings.local.json',
  'settings.local.json.*', '.env', '.env.*', '*.pem', '*.key', '*.ppk', '.credentials.json', 'scheduled_tasks.lock',
  '.git', 'node_modules')

# Reported as file:line:name, never with the value.
$Patterns = [ordered]@{
  'private-key'        = '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'github-token'       = '\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}\b|github_pat_[A-Za-z0-9_]{30,}'
  'openai-style-key'   = '\bsk-[A-Za-z0-9_\-]{20,}'
  'aws-access-key'     = '\bAKIA[0-9A-Z]{16}\b'
  'slack-token'        = '\bxox[abprs]-[A-Za-z0-9\-]{10,}'
  'google-api-key'     = '\bAIza[0-9A-Za-z_\-]{35}\b'
  'chat-bot-token'     = '\b\d{8,10}:[A-Za-z0-9_\-]{35}\b'
  'jwt'                = '\beyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.'
  'azure-storage'      = 'AccountKey=[A-Za-z0-9+/=]{20,}'
  'secret-assign'      = '(?i)\b(password|passwd|pwd|secret|api[_-]?key|access[_-]?key|auth[_-]?token|client[_-]?secret)\b["'']?\s*[:=]\s*["'']?[A-Za-z0-9/+_\-\.=]{16,}'
  'ip-address'         = '(?<![\d.])(?!127\.|10\.|192\.168\.|172\.(?:1[6-9]|2\d|3[01])\.|100\.(?:6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.|0\.0\.0\.0|255\.|169\.254\.|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.|168\.63\.129\.16(?![\d.]))(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)(?!\d|\.\d)'
  'email-address'      = '\b(?!noreply@anthropic\.com\b|git@github\.com\b)[A-Za-z0-9._%+\-]+@(?!example\.(com|org)\b)[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}\b'
  'azure-subscription' = '/subscriptions/[0-9a-fA-F]{8}-'
  'azure-tenant'       = '(?i)(tenant|subscription)[^\r\n]{0,40}\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b'
}

function Read-Manifest {
  $m = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $roots = @{}
  foreach ($p in $m.roots.PSObject.Properties) { $roots[$p.Name] = [Environment]::ExpandEnvironmentVariables($p.Value) }
  $shared = @()
  if ($m.PSObject.Properties.Name -contains 'shared') { $shared = @($m.shared) }
  return @{ Roots = $roots; Entries = @($m.entries); Shared = $shared }
}

# Applies an entry's redact rules (regex find/replace) and optional header. The result is what the repo stores.
function Get-RedactRules([string]$name) {
  $f = Join-Path $PSScriptRoot 'redact.local.json'
  if (-not $name -or -not (Test-Path -LiteralPath $f)) { return $null }
  $o = Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($o.PSObject.Properties.Name -notcontains $name) { return $null }
  return @($o.$name)
}

function Get-Redacted([string]$raw, $entry, $rules) {
  $t = $raw
  foreach ($r in @($rules)) { if ($r) { $t = [regex]::Replace($t, [string]$r.find, [string]$r.replace) } }
  if ($entry.header) { $t = [string]$entry.header + "`n`n" + $t }
  return $t
}

function Read-State {
  $h = @{}
  if (Test-Path -LiteralPath $StatePath) {
    $o = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $o.PSObject.Properties) { $h[$p.Name] = [string]$p.Value }
  }
  return $h
}

function Write-State($h) {
  $ordered = [ordered]@{}
  foreach ($k in ($h.Keys | Sort-Object)) { $ordered[$k] = $h[$k] }
  [IO.File]::WriteAllText($StatePath, ($ordered | ConvertTo-Json), $Utf8NoBom)
}

function Test-Excluded([string]$rel, $extra) {
  foreach ($seg in ($rel -split '[\\/]')) {
    foreach ($g in $GlobalExclude) { if ($seg -like $g) { return $true } }
    foreach ($g in @($extra)) { if ($g -and ($seg -like $g)) { return $true } }
  }
  return $false
}

function Get-RepoBase([string]$scope) {
  if ($scope -eq 'core' -or $scope -eq 'ops') { return $scope }
  return "domains/$scope"
}

# SHA-256 of a file; $null if absent; '__UNREADABLE__' if the read failed.
function Get-Hash([string]$p) {
  if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return $null }
  try { return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash } catch { return '__UNREADABLE__' }
}

function Get-TextHash([string]$text) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($Utf8NoBom.GetBytes($text)))).Replace('-', '') } finally { $sha.Dispose() }
}

# The named top-level keys of a JSON file, as stable text. $null if the file is missing or not valid JSON.
function Get-SubsetText([string]$path, $keys) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
  try { $o = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
  $sub = [ordered]@{}
  foreach ($k in $keys) { if ($o.PSObject.Properties.Name -contains $k) { $sub[$k] = $o.$k } }
  return ((ConvertTo-Json -InputObject $sub -Depth 20) + "`n")
}

# Relative paths (forward slashes) an entry covers, from the live side and the repo side.
function Get-EntryFiles($entry, $liveRoot) {
  $rel = ([string]$entry.path).Replace('\', '/')
  $extra = @($entry.exclude)
  $found = @{}
  $liveFull = Join-Path $liveRoot ($rel.Replace('/', '\'))
  $repoFull = Join-Path $RepoRoot ((Get-RepoBase $entry.scope) + '/' + $rel).Replace('/', '\')
  foreach ($b in @($liveFull, $repoFull)) {
    if (Test-Path -LiteralPath $b -PathType Leaf) {
      if (-not (Test-Excluded $rel $extra)) { $found[$rel] = $true }
    }
    elseif (Test-Path -LiteralPath $b -PathType Container) {
      $prefix = $b.TrimEnd('\') + '\'
      Get-ChildItem -LiteralPath $b -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $sub = $_.FullName.Substring($prefix.Length).Replace('\', '/')
        if (Test-Excluded $sub $extra) { return }
        foreach ($g in $extra) { if ($g -and ($sub -like $g)) { return } }
        if ($_.Length -gt $MaxBytes) { [void]$script:SkippedBig.Add($entry.scope + '|' + $rel + '/' + $sub); return }
        $found[$rel + '/' + $sub] = $true
      }
    }
  }
  return @($found.Keys | Sort-Object)
}

function Get-Status($L, $R, $S) {
  if ($L -eq '__UNREADABLE__' -or $R -eq '__UNREADABLE__') { return 'UNREADABLE' }
  if ($L -and $R -and $L -eq $R) { return 'in-sync' }
  if ($L -and -not $R) { if ($S -and $S -eq $L) { return 'repo-deleted' } else { return 'live-only' } }
  if ($R -and -not $L) { if ($S -and $S -eq $R) { return 'live-deleted' } else { return 'repo-only' } }
  if ($S -and $S -eq $R) { return 'live-ahead' }
  if ($S -and $S -eq $L) { return 'repo-ahead' }
  return 'CONFLICT'
}

function Get-Plan {
  $mf = Read-Manifest
  $state = Read-State
  $plan = New-Object System.Collections.ArrayList
  foreach ($e in $mf.Entries) {
    if ($Scope -and ($Scope -notcontains $e.scope)) { continue }
    $liveRoot = $mf.Roots[[string]$e.root]
    if (-not $liveRoot -or -not (Test-Path -LiteralPath $liveRoot)) {
      [void]$plan.Add([pscustomobject]@{ Scope = $e.scope; Rel = [string]$e.path; Status = 'ROOT-MISSING'; Key = $null }); continue
    }
    if ($e.type -eq 'json-keys') {
      $rel = [string]$e.repoPath
      $live = Join-Path $liveRoot ([string]$e.path)
      $repo = Join-Path $RepoRoot ((Get-RepoBase $e.scope) + '/' + $rel).Replace('/', '\')
      $text = Get-SubsetText $live $e.keys
      $L = $null; if ($text) { $L = Get-TextHash $text }
      $R = Get-Hash $repo; $key = $e.scope + '|' + $rel
      $st = Get-Status $L $R $state[$key]
      [void]$plan.Add([pscustomobject]@{ Scope = $e.scope; Rel = $rel; Status = $st; Live = $live; Repo = $repo; Key = $key; L = $L; R = $R; Text = $text; Kind = 'json-keys' })
      continue
    }
    if ($e.type -eq 'redacted') {
      $rel = ([string]$e.path).Replace('\', '/')
      $live = Join-Path $liveRoot ($rel.Replace('/', '\'))
      $repo = Join-Path $RepoRoot ((Get-RepoBase $e.scope) + '/' + $rel).Replace('/', '\')
      $key = $e.scope + '|' + $rel
      $text = $null; $L = $null
      $rules = Get-RedactRules ([string]$e.rules)
      if (-not $rules) {
        # No private rules on this machine: never fall back to copying the file unredacted.
        [void]$plan.Add([pscustomobject]@{ Scope = $e.scope; Rel = $rel; Status = 'NO-RULES'; Key = $null }); continue
      }
      if (Test-Path -LiteralPath $live -PathType Leaf) {
        try { $text = Get-Redacted ([IO.File]::ReadAllText($live, $Utf8NoBom)) $e $rules; $L = Get-TextHash $text } catch { $L = '__UNREADABLE__' }
      }
      $R = Get-Hash $repo
      if (-not $L -and -not $R) { continue }
      [void]$plan.Add([pscustomobject]@{ Scope = $e.scope; Rel = $rel; Status = (Get-Status $L $R $state[$key]); Live = $live; Repo = $repo; Key = $key; L = $L; R = $R; Text = $text; Kind = 'redacted' })
      continue
    }
    foreach ($rel in (Get-EntryFiles $e $liveRoot)) {
      $live = Join-Path $liveRoot ($rel.Replace('/', '\'))
      $repo = Join-Path $RepoRoot ((Get-RepoBase $e.scope) + '/' + $rel).Replace('/', '\')
      $key = $e.scope + '|' + $rel
      $L = Get-Hash $live; $R = Get-Hash $repo
      if (-not $L -and -not $R) { continue }
      [void]$plan.Add([pscustomobject]@{ Scope = $e.scope; Rel = $rel; Status = (Get-Status $L $R $state[$key]); Live = $live; Repo = $repo; Key = $key; L = $L; R = $R; Text = $null; Kind = 'file' })
    }
  }
  # Shared files: one canonical copy in shared/, installed identically into every target.
  if (-not $Scope -or ($Scope -contains 'shared')) {
    foreach ($s in $mf.Shared) {
      $repo = Join-Path $RepoRoot ('shared/' + [string]$s.path).Replace('/', '\')
      foreach ($t in @($s.targets)) {
        $root = $mf.Roots[[string]$t.root]
        if (-not $root -or -not (Test-Path -LiteralPath $root)) { [void]$plan.Add([pscustomobject]@{ Scope = 'shared'; Rel = [string]$s.path; Status = 'ROOT-MISSING'; Key = $null }); continue }
        $live = Join-Path $root (([string]$t.path).Replace('/', '\'))
        $key = 'shared|' + $s.path + '|' + $t.root
        $L = Get-Hash $live; $R = Get-Hash $repo
        if (-not $L -and -not $R) { continue }
        [void]$plan.Add([pscustomobject]@{ Scope = 'shared'; Rel = ([string]$s.path + ' -> ' + $t.root); Status = (Get-Status $L $R $state[$key]); Live = $live; Repo = $repo; Key = $key; L = $L; R = $R; Text = $null; Kind = 'file' })
      }
    }
  }
  return ,@($plan.ToArray())
}

function Test-TextFile([string]$p) {
  try {
    $fs = [IO.File]::OpenRead($p)
    try { $buf = New-Object byte[] 4096; $n = $fs.Read($buf, 0, 4096) } finally { $fs.Dispose() }
    for ($i = 0; $i -lt $n; $i++) { if ($buf[$i] -eq 0) { return $false } }
    return $true
  } catch { return $false }
}

function Read-Allow {
  $a = @{}
  if (Test-Path -LiteralPath $AllowPath) {
    Get-Content -LiteralPath $AllowPath -Encoding UTF8 | ForEach-Object { $t = $_.Trim(); if ($t -and -not $t.StartsWith('#')) { $a[$t] = $true } }
  }
  return $a
}

# Hits for one file as "label:line:pattern". The label is the repo-relative path, so allow entries match the repo.
function Find-Hits([string]$path, [string]$label, $allow) {
  $hits = @()
  if (-not (Test-TextFile $path)) { return $hits }
  $n = 0
  foreach ($line in [IO.File]::ReadLines($path)) {
    $n++
    foreach ($name in $Patterns.Keys) {
      # A four-part version number such as 1.2.3.4 looks like a public IP. Skip the IP rule on lines that name a version.
      if ($name -eq 'ip-address' -and $line -match '(?i)\bversion\b') { continue }
      if ($line -match $Patterns[$name]) {
        if (-not $allow.ContainsKey("$label|$name")) { $hits += "${label}:${n}:$name" }
      }
    }
  }
  return $hits
}

function Invoke-Scan {
  $allow = Read-Allow
  $all = @()
  $root = $RepoRoot.TrimEnd('\') + '\'
  # Scan what git would commit (tracked, staged or untracked-but-not-ignored). Fall back to the folder if git is absent.
  $files = $null
  try {
    $listed = & git -C $RepoRoot ls-files -co --exclude-standard 2>$null
    if ($LASTEXITCODE -eq 0 -and $listed) { $files = @($listed | ForEach-Object { Join-Path $RepoRoot ($_.Replace('/', '\')) } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }) }
  } catch { $files = $null }
  if (-not $files) { $files = @(Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Force | Where-Object { $_.FullName -notmatch '\\\.git\\' } | ForEach-Object { $_.FullName }) }
  foreach ($f in $files) {
    if ((Split-Path $f -Leaf) -eq '.playbook-state.json' -or $f -eq $PSCommandPath -or $f -eq $AllowPath) { continue }
    $label = $f.Substring($root.Length).Replace('\', '/')
    $all += Find-Hits $f $label $allow
  }
  if ($all.Count) {
    Write-Host "SCAN FAILED: $($all.Count) hit(s). Values are not printed. Fix the file, or add 'repo path|pattern' to tools/scan-allow.txt after reviewing it." -ForegroundColor Red
    $all | ForEach-Object { Write-Host "  $_" }
    return 1
  }
  Write-Host 'Scan: clean.' -ForegroundColor Green
  return 0
}

function Copy-One([string]$from, [string]$to) {
  $dir = Split-Path -Parent $to
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  Copy-Item -LiteralPath $from -Destination $to -Force
}

function Invoke-Move([string]$direction) {
  $plan = Get-Plan
  $state = Read-State
  $allow = Read-Allow
  $backupRoot = Join-Path $env:USERPROFILE (".playbook-backup\" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
  $want = if ($direction -eq 'capture') { @('live-only', 'live-ahead') } else { @('repo-only', 'repo-ahead') }
  $moved = 0; $blocked = 0; $conf = 0; $unread = 0
  $root = $RepoRoot.TrimEnd('\') + '\'
  foreach ($i in $plan) {
    if ($i.Status -eq 'UNREADABLE') { Write-Host ("  UNREADABLE {0}|{1}  (skipped; retry once Drive has synced it)" -f $i.Scope, $i.Rel) -ForegroundColor Yellow; $unread++; continue }
    if ($i.Status -eq 'CONFLICT') {
      if (-not $Force) { Write-Host ("  CONFLICT  {0}|{1}  (both sides changed; -Force makes the {2} side win)" -f $i.Scope, $i.Rel, $(if ($direction -eq 'capture') { 'live' } else { 'repo' })) -ForegroundColor Yellow; $conf++; continue }
    } elseif ($want -notcontains $i.Status) { continue }

    if ($direction -eq 'capture') {
      $label = $i.Repo.Substring($root.Length).Replace('\', '/')
      if ($i.Kind -ne 'file') { $tmp = Join-Path $env:TEMP ('pb-' + [guid]::NewGuid().ToString('N') + '.tmp'); [IO.File]::WriteAllText($tmp, $i.Text, $Utf8NoBom); $scanFile = $tmp } else { $scanFile = $i.Live }
      $hits = Find-Hits $scanFile $label $allow
      if ($tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue; $tmp = $null }
      if ($hits.Count) { Write-Host ("  BLOCKED   {0}|{1}  {2}" -f $i.Scope, $i.Rel, (($hits | Select-Object -First 4) -join ', ')) -ForegroundColor Red; $blocked++; continue }
      Write-Host ("  capture   {0}|{1}  [{2}]" -f $i.Scope, $i.Rel, $i.Status)
      if (-not $DryRun) {
        if ($i.Kind -ne 'file') {
          $d = Split-Path -Parent $i.Repo; if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
          [IO.File]::WriteAllText($i.Repo, $i.Text, $Utf8NoBom)
        } else { Copy-One $i.Live $i.Repo }
        $state[$i.Key] = (Get-Hash $i.Repo)
      }
    } else {
      if ($i.Kind -ne 'file') { Write-Host ("  manual    {0}|{1}  stored in reduced form ({2}); never installed over the live file, see docs/RESTORE.md" -f $i.Scope, $i.Rel, $i.Kind); continue }
      Write-Host ("  install   {0}|{1}  [{2}]" -f $i.Scope, $i.Rel, $i.Status)
      if (-not $DryRun) {
        if (Test-Path -LiteralPath $i.Live) { Copy-One $i.Live (Join-Path $backupRoot ((($i.Scope + '\' + $i.Rel.Replace('/', '\')) -replace ' -> ', '__'))) }
        Copy-One $i.Repo $i.Live; $state[$i.Key] = (Get-Hash $i.Live)
      }
    }
    $moved++
  }
  if (-not $DryRun) {
    foreach ($i in $plan) { if ($i.Status -eq 'in-sync') { $state[$i.Key] = $i.L } }
    Write-State $state
  }
  $tag = if ($DryRun) { ' (dry run, nothing written)' } else { '' }
  Write-Host ("{0}: {1} moved, {2} blocked by scan, {3} conflict(s), {4} unreadable{5}" -f $direction, $moved, $blocked, $conf, $unread, $tag)
  if ($script:SkippedBig.Count) { Write-Host ("Skipped {0} file(s) over {1} bytes: {2}" -f $script:SkippedBig.Count, $MaxBytes, (($script:SkippedBig | Select-Object -First 3) -join ', ')) }
  if ($direction -eq 'install' -and $moved -gt 0 -and -not $DryRun) { Write-Host "Overwritten live files were backed up under $backupRoot" }
  if ($direction -eq 'capture' -and $moved -gt 0 -and -not $DryRun) { Write-Host 'Next: review `git status` in the repo, then commit. Push only when you mean to.' }
}

function Get-Desc([string]$file) {
  try { $lines = @(Get-Content -LiteralPath $file -TotalCount 40 -Encoding UTF8) } catch { return '' }
  for ($n = 0; $n -lt $lines.Count; $n++) {
    if ($lines[$n] -match '^description:\s*(.*)$') {
      $v = $Matches[1].Trim()
      if (@('|', '>', '|-', '>-', '') -contains $v) { for ($k = $n + 1; $k -lt $lines.Count; $k++) { $t = $lines[$k].Trim(); if ($t) { $v = $t; break } } }
      $v = ($v.Trim([char[]]@('"', "'"))) -replace '\|', '/'
      if ($v.Length -gt 110) { $v = $v.Substring(0, 107) + '...' }
      return $v
    }
  }
  return ''
}

function Get-SkillLines([string]$dir) {
  $out = @()
  if (-not (Test-Path -LiteralPath $dir)) { return $out }
  foreach ($d in (Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue | Sort-Object Name)) {
    $sk = Join-Path $d.FullName 'SKILL.md'
    if (Test-Path -LiteralPath $sk) { $out += ('| `{0}` | {1} |' -f $d.Name, (Get-Desc $sk)) }
  }
  return $out
}

function Get-HookLines($settingsPath) {
  $out = @()
  if (-not (Test-Path -LiteralPath $settingsPath)) { return $out }
  try { $o = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $out }
  if (-not $o.hooks) { return $out }
  foreach ($ev in $o.hooks.PSObject.Properties) {
    foreach ($grp in @($ev.Value)) {
      $m = if ($grp.matcher) { [string]$grp.matcher } else { '(all)' }
      foreach ($h in @($grp.hooks)) {
        $c = ([string]$h.command) -replace '\s+', ' '
        if ($c -match '([^\s"''/\\]+\.(?:py|ps1|sh|js|vbs))') { $c = $Matches[1] } elseif ($c.Length -gt 50) { $c = $c.Substring(0, 50) }
        $out += ('| {0} | `{1}` | `{2}` |' -f $ev.Name, $m, $c)
      }
    }
  }
  return $out
}

function Get-McpNames($path) {
  if (-not (Test-Path -LiteralPath $path)) { return @() }
  try { $o = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return @() }
  if ($o.mcpServers) { return @($o.mcpServers.PSObject.Properties.Name) }
  return @()
}

# Writes docs/INVENTORY.md: everything installed or defined, names and one-line descriptions only.
function Invoke-Inventory {
  $mf = Read-Manifest
  $home2 = $mf.Roots['home']
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('# Inventory')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('Generated by `tools/playbook.ps1 inventory` on ' + (Get-Date -Format 'yyyy-MM-dd') + '. Do not edit by hand. Names and one-line descriptions only: no settings values, no MCP arguments or environment.')
  [void]$sb.AppendLine('')

  [void]$sb.AppendLine('## 1. Plugins (installed on this PC)')
  [void]$sb.AppendLine('')
  $gs = $null; $gsPath = Join-Path $home2 'settings.json'
  if (Test-Path -LiteralPath $gsPath) { $gs = Get-Content -LiteralPath $gsPath -Raw -Encoding UTF8 | ConvertFrom-Json }
  $ipPath = Join-Path $home2 'plugins\installed_plugins.json'
  $installed = $null; if (Test-Path -LiteralPath $ipPath) { $installed = Get-Content -LiteralPath $ipPath -Raw -Encoding UTF8 | ConvertFrom-Json }
  if ($installed -and $installed.plugins) {
    [void]$sb.AppendLine('| Plugin | Version | Enabled | Skills it provides |')
    [void]$sb.AppendLine('|---|---|---|---|')
    foreach ($p in ($installed.plugins.PSObject.Properties | Sort-Object Name)) {
      $v = @($p.Value)[0]
      $en = 'no'; if ($gs -and $gs.enabledPlugins -and $gs.enabledPlugins.PSObject.Properties.Name -contains $p.Name -and $gs.enabledPlugins.($p.Name)) { $en = 'yes' }
      $names = @()
      if ($v.installPath -and (Test-Path -LiteralPath (Join-Path $v.installPath 'skills'))) { $names = @(Get-ChildItem -LiteralPath (Join-Path $v.installPath 'skills') -Recurse -Filter SKILL.md -File | Where-Object { $_.FullName -notmatch '\\deprecated\\|\\in-progress\\' } | ForEach-Object { $_.Directory.Name } | Sort-Object -Unique) }
      $nm = if ($names.Count) { ($names -join ', ') } else { '(none)' }
      [void]$sb.AppendLine(('| `{0}` | {1} | {2} | {3} |' -f $p.Name, $v.version, $en, $nm))
    }
  } else { [void]$sb.AppendLine('(installed_plugins.json not found)') }
  [void]$sb.AppendLine('')
  if ($gs -and $gs.extraKnownMarketplaces) {
    [void]$sb.AppendLine('Marketplaces: ' + (($gs.extraKnownMarketplaces.PSObject.Properties.Name | Sort-Object) -join ', '))
    [void]$sb.AppendLine('')
  }

  [void]$sb.AppendLine('## 2. Skills synced from the Claude account (not stored in this repo)')
  [void]$sb.AppendLine('')
  foreach ($base in @((Join-Path $home2 'plugins\synced'), (Join-Path $home2 'skills\synced'))) {
    if (-not (Test-Path -LiteralPath $base)) { continue }
    Get-ChildItem -LiteralPath $base -Recurse -Filter SKILL.md -File -ErrorAction SilentlyContinue | ForEach-Object {
      $parts = $_.FullName.Substring($base.Length).TrimStart('\') -split '\\'
      $owner = if ($base -like '*plugins*') { 'plugin ' + $parts[1] } else { 'account skill' }
      [void]$sb.AppendLine(('- `{0}` ({1}): {2}' -f $_.Directory.Name, $owner, (Get-Desc $_.FullName)))
    }
  }
  [void]$sb.AppendLine('')

  [void]$sb.AppendLine('## 3. Global skills in ~/.claude/skills')
  [void]$sb.AppendLine('')
  $ownCore = @{}; foreach ($e in $mf.Entries) { if ($e.scope -eq 'core' -and ([string]$e.path) -like 'skills/*') { $ownCore[([string]$e.path).Substring(7)] = $true } }
  [void]$sb.AppendLine('| Skill | Stored in this repo? | What it does |')
  [void]$sb.AppendLine('|---|---|---|')
  foreach ($d in (Get-ChildItem -LiteralPath (Join-Path $home2 'skills') -Directory | Where-Object { $_.Name -ne 'synced' } | Sort-Object Name)) {
    $sk = Join-Path $d.FullName 'SKILL.md'
    $stored = if ($ownCore.ContainsKey($d.Name)) { 'yes (core/)' } else { 'no (third-party)' }
    [void]$sb.AppendLine(('| `{0}` | {1} | {2} |' -f $d.Name, $stored, $(if (Test-Path -LiteralPath $sk) { Get-Desc $sk } else { '' })))
  }
  [void]$sb.AppendLine('')

  [void]$sb.AppendLine('## 4. Global hooks (settings.base.json)')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('| Event | Matcher | Script |')
  [void]$sb.AppendLine('|---|---|---|')
  Get-HookLines $gsPath | ForEach-Object { [void]$sb.AppendLine($_) }
  [void]$sb.AppendLine('')

  [void]$sb.AppendLine('## 5. Workspaces')
  # Every scope in the manifest except core and ops is a workspace. Its root is the root of its first entry.
  $scopeRoot = [ordered]@{}
  foreach ($e in $mf.Entries) { if ($e.scope -ne 'core' -and $e.scope -ne 'ops' -and -not $scopeRoot.Contains([string]$e.scope)) { $scopeRoot[[string]$e.scope] = [string]$e.root } }
  foreach ($name in @($scopeRoot.Keys)) {
    $root = $mf.Roots[$scopeRoot[$name]]
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('### ' + $name.ToUpper())
    [void]$sb.AppendLine('')
    if (-not $root -or -not (Test-Path -LiteralPath $root)) { [void]$sb.AppendLine('(root not reachable on this machine)'); continue }
    $ag = Join-Path $root '.claude\agents'
    if (Test-Path -LiteralPath $ag) { [void]$sb.AppendLine('**Agents:** ' + ((Get-ChildItem -LiteralPath $ag -Filter *.md -File | ForEach-Object { $_.BaseName }) -join ', ')); [void]$sb.AppendLine('') }
    $mcp = Get-McpNames (Join-Path $root '.mcp.json')
    if ($mcp.Count) { [void]$sb.AppendLine('**MCP servers (names only):** ' + ($mcp -join ', ')); [void]$sb.AppendLine('') }
    $hk = Get-HookLines (Join-Path $root '.claude\settings.json')
    if ($hk.Count) { [void]$sb.AppendLine('| Event | Matcher | Script |'); [void]$sb.AppendLine('|---|---|---|'); $hk | ForEach-Object { [void]$sb.AppendLine($_) }; [void]$sb.AppendLine('') }
    $sl = Get-SkillLines (Join-Path $root '.claude\skills')
    [void]$sb.AppendLine(('**Skills ({0}):**' -f $sl.Count)); [void]$sb.AppendLine('')
    if ($sl.Count) { [void]$sb.AppendLine('| Skill | What it does |'); [void]$sb.AppendLine('|---|---|'); $sl | ForEach-Object { [void]$sb.AppendLine($_) } }
  }
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('## 6. MCP servers on this PC (names only)')
  [void]$sb.AppendLine('')
  $gm = Get-McpNames (Join-Path $home2 '.mcp.json')
  [void]$sb.AppendLine('- Global `.mcp.json`: ' + $(if ($gm.Count) { $gm -join ', ' } else { '(none)' }))
  [void]$sb.AppendLine('- Servers provided by plugins and claude.ai connectors are managed in the Claude app and are not stored in files this tool reads.')
  $docs = Join-Path $RepoRoot 'docs'
  [IO.File]::WriteAllText((Join-Path $docs 'INVENTORY.md'), $sb.ToString(), $Utf8NoBom)
  Write-Host 'Wrote docs/INVENTORY.md'
}

switch ($Command) {
  'inventory' { Invoke-Inventory }
  'scan' { exit (Invoke-Scan) }
  'status' {
    $plan = Get-Plan
    $quiet = @('in-sync')
    if (-not $All) { $quiet += 'live-only' }
    foreach ($i in ($plan | Where-Object { $quiet -notcontains $_.Status } | Sort-Object Scope, Rel)) {
      $c = switch ($i.Status) { 'CONFLICT' { 'Red' } 'ROOT-MISSING' { 'Red' } 'UNREADABLE' { 'Red' } 'live-ahead' { 'Cyan' } default { 'Yellow' } }
      Write-Host ("  {0,-13} {1}|{2}" -f $i.Status, $i.Scope, $i.Rel) -ForegroundColor $c
    }
    Write-Host ''
    ($plan | Group-Object Scope, Status | Sort-Object Name | ForEach-Object { '{0,-24} {1}' -f $_.Name, $_.Count }) | Write-Host
    if ($script:SkippedBig.Count) { Write-Host ("Skipped {0} file(s) over {1} bytes." -f $script:SkippedBig.Count, $MaxBytes) }
    Write-Host 'live-ahead / live-only -> capture.   repo-ahead / repo-only -> install.   CONFLICT -> compare by hand.   (-All lists every file)'
  }
  'capture' { Invoke-Move 'capture' }
  'install' { Invoke-Move 'install' }
}
