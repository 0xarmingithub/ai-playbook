<#
.SYNOPSIS
  Mutation test for the scan in tools/playbook.ps1. Exits non-zero on any mismatch.

.DESCRIPTION
  Copies the repository (without .git) to a temporary folder, writes known values into one
  folder there, runs the scan on the copy, and checks each file against what it should report:
  a planted secret or identifier must be reported with its rule name, and a clean line must not
  be reported. A check that cannot go red is not evidence, so this script fails when the scan
  misses a planted value or flags a clean one. The planted values are built from pieces, so this
  file itself contains no value the scan would match.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$tmp  = Join-Path $env:TEMP ('playbook-scan-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null

# Expect = the rule name that must be reported for the file, or '' when the file must be clean.
$cases = @(
  @{ File = 'p1-token.md';        Text = ('token ghp_' + ('Q' * 36));                                  Expect = 'github-token' },
  @{ File = 'p2-public-ip.md';    Text = ('host ' + '8.8.8' + '.8 is up');                             Expect = 'ip-address' },
  @{ File = 'p3-email.md';        Text = ('contact jane.doe' + '@acme-corp.io');                       Expect = 'email-address' },
  @{ File = 'p4-subscription.md'; Text = ('path /subscr' + 'iptions/12345678-1234-' + '1234-1234-123456789abc/x'); Expect = 'azure-subscription' },
  @{ File = 'p5-tenant.json';     Text = ('{ "tenantId": "12345678-1234-' + '1234-1234-123456789abc" }'); Expect = 'azure-tenant' },
  @{ File = 'n1-version.md';      Text = 'Version 1.2.3.4 released';                                    Expect = '' },
  @{ File = 'n2-wire-server.md';  Text = 'wireserver 168.63.129.16 agent';                             Expect = '' },
  @{ File = 'n3-doc-range.md';    Text = 'example address 203.0.113.5';                                Expect = '' },
  @{ File = 'n4-clean.md';        Text = 'clean line only';                                            Expect = '' }
)

try {
  Get-ChildItem -LiteralPath $repo -Force | Where-Object { $_.Name -ne '.git' } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $tmp -Recurse -Force
  }
  $folder = 'mutation-probe'
  New-Item -ItemType Directory -Path (Join-Path $tmp $folder) | Out-Null
  foreach ($c in $cases) {
    [IO.File]::WriteAllText((Join-Path $tmp (Join-Path $folder $c.File)), ($c.Text + "`n"), (New-Object Text.UTF8Encoding($false)))
  }

  $out = (& powershell -NoProfile -File (Join-Path $tmp 'tools\playbook.ps1') scan 2>&1 | Out-String)
  if ($out -notmatch 'SCAN FAILED|Scan: clean') { Write-Host 'FAIL: the scan produced no verdict'; exit 1 }

  # Hit lines look like: mutation-probe/p1-token.md:1:github-token. A file can carry several rules.
  $hits = @{}
  foreach ($m in [regex]::Matches($out, '(?m)^\s+(\S+):(\d+):([a-z-]+)\s*$')) {
    $label = $m.Groups[1].Value
    if (-not $hits.ContainsKey($label)) { $hits[$label] = @() }
    $hits[$label] += $m.Groups[3].Value
  }

  # A planted file passes when its expected rule is reported. A clean file passes only when nothing is reported.
  $failures = @()
  foreach ($c in $cases) {
    $label = "$folder/$($c.File)"
    $got = @(if ($hits.ContainsKey($label)) { $hits[$label] } else { @() })
    if ($c.Expect -eq '') {
      if ($got.Count) { $failures += ('{0}: expected clean, got [{1}]' -f $label, ($got -join ', ')) }
    }
    elseif ($got -notcontains $c.Expect) {
      $failures += ('{0}: expected [{1}], got [{2}]' -f $label, $c.Expect, ($got -join ', '))
    }
  }

  if ($failures.Count) {
    Write-Host ('FAIL: {0} of {1} planted cases did not match' -f $failures.Count, $cases.Count) -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  $_" }
    exit 1
  }
  Write-Host ('PASS: {0} of {0} planted cases matched' -f $cases.Count) -ForegroundColor Green
  exit 0
}
finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
