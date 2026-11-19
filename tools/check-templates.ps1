<#
.SYNOPSIS
  Lists unfilled <<FILL ...>> markers in a file or folder. Exits 1 while any remain.

.DESCRIPTION
  Scans every text file under -Path (a file, or a folder searched recursively; default: this
  repository's templates/ folder) for markers of the form <<FILL ...>>. A marker is the text from
  <<FILL up to the next >> on the same line; a <<FILL with no closing >> on its line counts too.
  Every match is listed as: file, line number, marker text trimmed to 80 characters. The last line
  is always a count, including "0 markers" for a file that has none.

  The scan is plain text and deliberately simple: it does not know about HTML comments, code
  fences or examples, so any <<FILL inside a file counts. A marker that spans two lines is not
  matched as one marker; its first line is still listed if it has no closing >>.

  Exit codes: 0 no markers (or -ListOnly), 1 markers remain, 2 the path does not exist.
  Windows PowerShell 5.1 safe. Writes nothing; needs no path outside -Path.

.PARAMETER Path
  File or folder to scan. Default: templates/ next to tools/.

.PARAMETER ListOnly
  Print the list and the count, but exit 0 even when markers remain.
#>
[CmdletBinding()]
param(
  [string]$Path,
  [switch]$ListOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Path) { $Path = Join-Path (Split-Path -Parent $PSScriptRoot) 'templates' }
if (-not (Test-Path -LiteralPath $Path)) {
  Write-Host ('Path not found: {0}' -f $Path)
  exit 2
}

$item = Get-Item -LiteralPath $Path
$base = $null
if ($item.PSIsContainer) {
  $base = $item.FullName.TrimEnd('\', '/')
  $files = @(Get-ChildItem -LiteralPath $item.FullName -File -Recurse -Force |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' })
}
else {
  $files = @($item)
}

$utf8 = New-Object Text.UTF8Encoding($false)
$found = 0
$filesWith = 0
foreach ($f in $files) {
  $lines = [IO.File]::ReadAllText($f.FullName, $utf8) -split "`r?`n"
  $hitHere = 0
  for ($i = 0; $i -lt $lines.Count; $i++) {
    foreach ($m in [regex]::Matches($lines[$i], '<<FILL.*?(>>|$)')) {
      $text = $m.Value.Trim()
      if ($text.Length -gt 80) { $text = $text.Substring(0, 80) }
      $label = $f.Name
      if ($base -and $f.FullName.Length -gt $base.Length) { $label = $f.FullName.Substring($base.Length + 1).Replace('\', '/') }
      Write-Host ('{0}:{1}: {2}' -f $label, ($i + 1), $text)
      $found++; $hitHere++
    }
  }
  if ($hitHere -gt 0) { $filesWith++ }
}

$noun = if ($found -eq 1) { 'marker' } else { 'markers' }
Write-Host ('{0} {1} in {2} of {3} files' -f $found, $noun, $filesWith, $files.Count)
if ($found -gt 0 -and -not $ListOnly) { exit 1 }
exit 0
