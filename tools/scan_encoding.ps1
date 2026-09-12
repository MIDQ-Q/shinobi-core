#Requires -Version 5.1
<#
  tools/scan_encoding.ps1 — поиск битой кодировки в исходниках.
  Exit code 1, если найдены проблемы (для использования в CI / build.ps1).

  Что ищет:
    1. BROKEN_COLORCODE : последовательность "В§" (U+0412 U+00A7) вместо "§"
    2. BROKEN_CYRILLIC  : сегменты, которые после cp1251->utf-8 дают валидную
                          кириллицу (признак двойной кодировки)
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Quiet,
    [switch]$Strict
)
$ErrorActionPreference = 'Stop'

$CH_SECTION = [string][char]0x00A7
$CH_VE      = [string][char]0x0412
$MOJI_COLOR = $CH_VE + $CH_SECTION

$utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
$cp1251Strict = [System.Text.Encoding]::GetEncoding(
    1251,
    (New-Object System.Text.EncoderExceptionFallback),
    (New-Object System.Text.DecoderExceptionFallback))

$runPattern = '[\u0080-\u04FF\u0530-\u058F\u00A0-\u00FF' +
              '\u0192\u02DC\u2010-\u2027\u2030-\u203A\u20AC\u2116\u2122' +
              '\u2190-\u21FF\u2500-\u259F\u25A0-\u25FF\u2700-\u27BF]{2,}'

$targets = @(
    (Join-Path $ProjectRoot 'src\main\java'),
    (Join-Path $ProjectRoot 'src\main\resources')
)

$totalColor = 0
$totalCyr   = 0
$badFiles    = New-Object System.Collections.ArrayList

foreach ($root in $targets) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    Get-ChildItem -LiteralPath $root -Recurse -Include '*.java','*.json' -File | ForEach-Object {
        $text = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
        $colorHits = ([regex]::Matches($text, [regex]::Escape($MOJI_COLOR))).Count
        $cyrHits = 0
        foreach ($m in [regex]::Matches($text, $runPattern)) {
            try {
                $bytes = $cp1251Strict.GetBytes($m.Value)
                if ($bytes.Length -ge 2 -and $bytes[0] -ge 0xC2) {
                    $cand = $utf8Strict.GetString($bytes)
                    if ($cand -ne $m.Value) {
                        $c  = ([regex]::Matches($cand, '[\u0410-\u044F\u0401\u0451]')).Count
                        $sy = ([regex]::Matches($cand, '[\u2190-\u21FF\u2500-\u259F\u25A0-\u25FF\u2700-\u27BF]')).Count
                        $la = ([regex]::Matches($cand, '[A-Za-z]')).Count
                        if (($c -ge 1 -or $sy -ge 1) -and $la -eq 0) { $cyrHits++ }
                    }
                }
            } catch { }
        }
        if ($colorHits -gt 0 -or $cyrHits -gt 0) {
            [void]$badFiles.Add([pscustomobject]@{
                File  = $_.FullName.Substring($ProjectRoot.Length).TrimStart('\','/')
                Color = $colorHits
                Cyr   = $cyrHits
            })
            $totalColor += $colorHits
            $totalCyr   += $cyrHits
        }
    }
}

if ($badFiles.Count -gt 0) {
    if (-not $Quiet) {
        Write-Host ''
        if ($totalColor -gt 0) {
            Write-Host 'ENCODING: CRITICAL (битые цветовые коды — видны игроку):' -ForegroundColor Red
        } elseif ($totalCyr -gt 0) {
            Write-Host 'ENCODING: WARNING (могибаке кириллицы в комментариях):' -ForegroundColor Yellow
        }
        $badFiles | Format-Table -AutoSize | Out-String | Write-Host
        Write-Host ("  broken color codes : {0}  (CRITICAL)" -f $totalColor)
        Write-Host ("  broken cyrillic seg: {0}  (warning, только комментарии)" -f $totalCyr)
        Write-Host ''
        if ($totalCyr -gt 0 -and $totalColor -eq 0) {
            Write-Host '  Починить:  .\ShinobiCore_Sprint1_MasterFix.ps1 -Phase 3 -FixCyrillic' -ForegroundColor DarkGray
        }
        Write-Host ''
    }
    if ($totalColor -gt 0) { exit 1 }
    if ($Strict -and $totalCyr -gt 0) { exit 1 }
    exit 0
}
if (-not $Quiet) { Write-Host 'Encoding check: OK' -ForegroundColor Green }
exit 0