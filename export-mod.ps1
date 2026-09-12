param(
    [string]$Root = 'E:\Games\mod',
    [string]$Out = 'mod_project.md',
    [long]$MaxFileSize = 1MB
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Root)) {
    throw "Project folder not found: $Root"
}

$rootItem = Get-Item -LiteralPath $Root
if (-not $rootItem.PSIsContainer) {
    throw "Path is not a directory: $Root"
}

$rootFull = $rootItem.FullName
if (-not $rootFull.EndsWith('\')) { $rootFull += '\' }

$outFull = [IO.Path]::GetFullPath($Out)
$outDir = [IO.Path]::GetDirectoryName($outFull)
if ($outDir -and -not (Test-Path -LiteralPath $outDir -PathType Container)) {
    [IO.Directory]::CreateDirectory($outDir) | Out-Null
}

$script:rootFull = $rootFull
$script:outFull = $outFull
$script:MaxFileSize = $MaxFileSize
$script:includedCount = 0
$script:skippedCount = 0
$script:includedBytes = 0

$script:excludeDirs = @(
    '.git', '.gradle', '.idea', '.vscode', 'build', 'run', 'runs', 'out',
    'bin', 'obj', 'node_modules', 'logs', 'caches', 'daemon', '.kotlin',
    '.cache', 'eclipse', '.settings', '.classpath', '.project'
)

$script:binaryExtensions = @(
    '.jar', '.zip', '.7z', '.rar', '.gz', '.tar', '.class', '.exe', '.dll',
    '.so', '.dylib', '.bin', '.dat', '.mca', '.mcr', '.nbt', '.schematic',
    '.schem', '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.ico', '.webp',
    '.tga', '.ogg', '.mp3', '.wav', '.flac', '.ttf', '.otf', '.woff',
    '.woff2', '.pdf', '.psd', '.kra', '.blend', '.fbx', '.glb',
    '.keystore', '.jks', '.p12', '.pdb', '.ilk', '.exp', '.lib', '.o',
    '.a', '.db', '.sqlite', '.pack', '.idx'
)

$script:languageMap = @{
    '.java' = 'java'
    '.kt' = 'kotlin'
    '.kts' = 'kotlin'
    '.gradle' = 'groovy'
    '.groovy' = 'groovy'
    '.json' = 'json'
    '.json5' = 'json5'
    '.mcmeta' = 'json'
    '.lang' = 'properties'
    '.properties' = 'properties'
    '.toml' = 'toml'
    '.cfg' = 'ini'
    '.ini' = 'ini'
    '.xml' = 'xml'
    '.yml' = 'yaml'
    '.yaml' = 'yaml'
    '.md' = 'markdown'
    '.markdown' = 'markdown'
    '.txt' = 'text'
    '.mcfunction' = 'mcfunction'
    '.snbt' = 'text'
    '.accesswidener' = 'text'
    '.js' = 'javascript'
    '.ts' = 'typescript'
    '.py' = 'python'
    '.sh' = 'bash'
    '.bat' = 'batch'
    '.cmd' = 'batch'
    '.ps1' = 'powershell'
    '.c' = 'c'
    '.h' = 'c'
    '.cpp' = 'cpp'
    '.hpp' = 'cpp'
    '.glsl' = 'glsl'
    '.vsh' = 'glsl'
    '.fsh' = 'glsl'
    '.gitignore' = 'gitignore'
}

$bodyTemp = [IO.Path]::GetTempFileName()
$skipTemp = [IO.Path]::GetTempFileName()

$script:swBody = New-Object IO.StreamWriter($bodyTemp, $false, (New-Object Text.UTF8Encoding($false)))
$script:swSkip = New-Object IO.StreamWriter($skipTemp, $false, (New-Object Text.UTF8Encoding($false)))

function Get-RelativePath([string]$Path) {
    if ($Path.StartsWith($script:rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        $rel = $Path.Substring($script:rootFull.Length)
    } else {
        $rel = $Path
    }
    return $rel.Replace('\', '/')
}

function Get-Language([string]$Extension) {
    $ext = $Extension.ToLowerInvariant()
    if ($script:languageMap.ContainsKey($ext)) { return $script:languageMap[$ext] }
    return 'text'
}

function Get-Fence([string]$Text) {
    if ($Text -notmatch '```') { return '```' }
    $max = 2
    foreach ($m in [regex]::Matches($Text, '`{3,}')) {
        if ($m.Length -gt $max) { $max = $m.Length }
    }
    return ('`' * ($max + 1))
}

function Get-SafeText([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -eq 0) { return '' }

    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
    }

    if ($bytes.Length -ge 2) {
        if ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
            return [Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2)
        }
        if ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
            return [Text.Encoding]::BigEndianUnicode.GetString($bytes, 2, $bytes.Length - 2)
        }
    }

    $limit = [Math]::Min(4096, $bytes.Length)
    $nulCount = 0
    for ($i = 0; $i -lt $limit; $i++) {
        if ($bytes[$i] -eq 0) { $nulCount++ }
    }

    if ($nulCount -gt 0) {
        $pairs = [Math]::Floor($limit / 2)
        if ($pairs -gt 0) {
            $evenNull = 0
            $oddNull = 0
            for ($i = 0; $i -lt $pairs; $i++) {
                if ($bytes[2 * $i] -eq 0) { $evenNull++ }
                if ($bytes[2 * $i + 1] -eq 0) { $oddNull++ }
            }
            if (($oddNull / $pairs) -gt 0.5) { return [Text.Encoding]::Unicode.GetString($bytes) }
            if (($evenNull / $pairs) -gt 0.5) { return [Text.Encoding]::BigEndianUnicode.GetString($bytes) }
        }
        return $null
    }

    $utf8Strict = New-Object Text.UTF8Encoding($false, $true)
    try {
        return $utf8Strict.GetString($bytes)
    } catch {
        return [Text.Encoding]::Default.GetString($bytes)
    }
}

function Add-FilesFromDir([string]$Dir) {
    foreach ($item in Get-ChildItem -LiteralPath $Dir -Force -ErrorAction SilentlyContinue) {
        if ($item.PSIsContainer) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }

            if ($script:excludeDirs -contains $item.Name) {
                $rel = Get-RelativePath $item.FullName
                $script:swSkip.WriteLine("- Excluded folder: $rel")
                $script:skippedCount++
                continue
            }

            Add-FilesFromDir $item.FullName
            continue
        }

        if ($item.FullName -eq $script:outFull) { continue }

        $rel = Get-RelativePath $item.FullName

        if ($item.Length -gt $script:MaxFileSize) {
            $script:swSkip.WriteLine("- Too large: $rel ($($item.Length) bytes)")
            $script:skippedCount++
            continue
        }

        if ($script:binaryExtensions -contains $item.Extension.ToLowerInvariant()) {
            $script:swSkip.WriteLine("- Binary extension: $rel")
            $script:skippedCount++
            continue
        }

        try {
            $content = Get-SafeText $item.FullName
        } catch {
            $script:swSkip.WriteLine("- Read error: $rel ($($_.Exception.Message))")
            $script:skippedCount++
            continue
        }

        if ($null -eq $content) {
            $script:swSkip.WriteLine("- Looks like binary: $rel")
            $script:skippedCount++
            continue
        }

        $content = $content.Replace([string][char]0, '')
        $lang = Get-Language $item.Extension
        $fence = Get-Fence $content

        $script:swBody.WriteLine("### $rel")
        $script:swBody.WriteLine("")
        $script:swBody.WriteLine("- Size: $($item.Length) bytes")
        $script:swBody.WriteLine("")
        $script:swBody.WriteLine("$fence$lang")
        if ($content.Length -gt 0) {
            $script:swBody.WriteLine($content.TrimEnd([char]13, [char]10))
        }
        $script:swBody.WriteLine($fence)
        $script:swBody.WriteLine("")

        $script:includedCount++
        $script:includedBytes += $item.Length
    }
}

try {
    Add-FilesFromDir $rootFull
} finally {
    $script:swBody.Flush()
    $script:swSkip.Flush()
    $script:swBody.Close()
    $script:swSkip.Close()
}

$swOut = New-Object IO.StreamWriter($outFull, $false, (New-Object Text.UTF8Encoding($false)))
try {
    $trimmedRoot = $rootFull.TrimEnd('\')
    $projectName = [IO.Path]::GetFileName($trimmedRoot)
    if ([string]::IsNullOrWhiteSpace($projectName)) { $projectName = $rootFull }

    $swOut.WriteLine("# Project: $projectName")
    $swOut.WriteLine("")
    $swOut.WriteLine("- Path: $rootFull")
    $swOut.WriteLine("- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $swOut.WriteLine("- Included files: $($script:includedCount)")
    $swOut.WriteLine("- Skipped objects: $($script:skippedCount)")
    $swOut.WriteLine("- Included size: $([Math]::Round($script:includedBytes / 1KB, 2)) KB")
    $swOut.WriteLine("")
    $swOut.WriteLine("## Project files")
    $swOut.WriteLine("")

    $srBody = New-Object IO.StreamReader($bodyTemp, [Text.Encoding]::UTF8)
    while (($line = $srBody.ReadLine()) -ne $null) {
        $swOut.WriteLine($line)
    }
    $srBody.Close()

    $swOut.WriteLine("## Skipped files and folders")
    $swOut.WriteLine("")
    if ($script:skippedCount -eq 0) {
        $swOut.WriteLine("No skipped files.")
    } else {
        $srSkip = New-Object IO.StreamReader($skipTemp, [Text.Encoding]::UTF8)
        while (($line = $srSkip.ReadLine()) -ne $null) {
            $swOut.WriteLine($line)
        }
        $srSkip.Close()
    }
} finally {
    $swOut.Close()
    Remove-Item $bodyTemp, $skipTemp -Force -ErrorAction SilentlyContinue
}

Write-Host "Done: $outFull"
Write-Host "Included files: $($script:includedCount), skipped: $($script:skippedCount)"