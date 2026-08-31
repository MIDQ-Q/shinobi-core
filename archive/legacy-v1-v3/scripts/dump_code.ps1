$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$output = "$root\dump_code.txt"

Write-Host "=== ShinobiCore Code Dump ==="
Write-Host "Scanning project..."

$sb = New-Object System.Text.StringBuilder

# Header
[void]$sb.AppendLine("=" * 80)
[void]$sb.AppendLine("SHINOBICORE MOD - FULL CODE DUMP")
[void]$sb.AppendLine("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
[void]$sb.AppendLine("Project: E:\Games\mod")
[void]$sb.AppendLine("=" * 80)
[void]$sb.AppendLine("")

# Function to append file with header
function Add-File($path, $relPath) {
    if (Test-Path $path) {
        [void]$sb.AppendLine("-" * 80)
        [void]$sb.AppendLine("FILE: " + $relPath)
        [void]$sb.AppendLine("-" * 80)
        try {
            $content = [System.IO.File]::ReadAllText($path, $utf8)
            [void]$sb.AppendLine($content)
        } catch {
            [void]$sb.AppendLine("[ERROR: Could not read file]")
        }
        [void]$sb.AppendLine("")
        return $true
    }
    return $false
}

# ============ 1. Build files ============
[void]$sb.AppendLine("")
[void]$sb.AppendLine("#" * 80)
[void]$sb.AppendLine("# SECTION 1: BUILD CONFIGURATION")
[void]$sb.AppendLine("#" * 80)

Add-File "$root\build.gradle" "build.gradle"
Add-File "$root\gradle.properties" "gradle.properties"
Add-File "$root\settings.gradle" "settings.gradle"
Add-File "$root\src\main\resources\fabric.mod.json" "src/main/resources/fabric.mod.json"
Add-File "$root\src\main\resources\shinobicore.mixins.json" "src/main/resources/shinobicore.mixins.json"

# ============ 2. Java source files ============
[void]$sb.AppendLine("")
[void]$sb.AppendLine("#" * 80)
[void]$sb.AppendLine("# SECTION 2: JAVA SOURCE CODE")
[void]$sb.AppendLine("#" * 80)

$javaBase = "$root\src\main\java"
$javaFiles = Get-ChildItem -Path $javaBase -Recurse -Filter "*.java" | Sort-Object FullName
Write-Host ("Found " + $javaFiles.Count + " Java files")

foreach ($f in $javaFiles) {
    $relPath = $f.FullName.Replace($javaBase + "\", "").Replace("\", "/")
    Add-File $f.FullName ("src/main/java/" + $relPath)
}

# ============ 3. Resource files (JSON) ============
[void]$sb.AppendLine("")
[void]$sb.AppendLine("#" * 80)
[void]$sb.AppendLine("# SECTION 3: RESOURCE FILES - JSON")
[void]$sb.AppendLine("#" * 80)

$resBase = "$root\src\main\resources\data\shinobicore"
$jsonFiles = Get-ChildItem -Path $resBase -Recurse -Filter "*.json" | Sort-Object FullName
Write-Host ("Found " + $jsonFiles.Count + " JSON files")

foreach ($f in $jsonFiles) {
    $relPath = $f.FullName.Replace($resBase + "\", "").Replace("\", "/")
    Add-File $f.FullName ("src/main/resources/data/shinobicore/" + $relPath)
}

# ============ 4. Documentation ============
[void]$sb.AppendLine("")
[void]$sb.AppendLine("#" * 80)
[void]$sb.AppendLine("# SECTION 4: DOCUMENTATION")
[void]$sb.AppendLine("#" * 80)

$docFiles = @("README.md", "ARCHITECTURE.md", "CHANGELOG.md", "ROADMAP.md", "SUMMARY.txt")
foreach ($doc in $docFiles) {
    $path = "$root\$doc"
    if (Test-Path $path) {
        Add-File $path $doc
    }
}

# ============ 5. PowerShell scripts ============
[void]$sb.AppendLine("")
[void]$sb.AppendLine("#" * 80)
[void]$sb.AppendLine("# SECTION 5: POWERSHELL SCRIPTS")
[void]$sb.AppendLine("#" * 80)

$psFiles = Get-ChildItem -Path $root -Filter "*.ps1" -File | Where-Object { $_.Name -ne "dump_code.ps1" } | Sort-Object Name
Write-Host ("Found " + $psFiles.Count + " PowerShell scripts")

foreach ($f in $psFiles) {
    Add-File $f.FullName $f.Name
}

# ============ 6. Statistics ============
[void]$sb.AppendLine("")
[void]$sb.AppendLine("#" * 80)
[void]$sb.AppendLine("# STATISTICS")
[void]$sb.AppendLine("#" * 80)
[void]$sb.AppendLine("Java files: " + $javaFiles.Count)
[void]$sb.AppendLine("JSON files: " + $jsonFiles.Count)
[void]$sb.AppendLine("PowerShell scripts: " + $psFiles.Count)

$totalJavaLines = ($javaFiles | ForEach-Object { (Get-Content $_.FullName -Encoding UTF8).Count } | Measure-Object -Sum).Sum
$totalJsonLines = ($jsonFiles | ForEach-Object { (Get-Content $_.FullName -Encoding UTF8).Count } | Measure-Object -Sum).Sum

[void]$sb.AppendLine("Total Java lines: " + $totalJavaLines)
[void]$sb.AppendLine("Total JSON lines: " + $totalJsonLines)
[void]$sb.AppendLine("Total lines in dump: " + $sb.ToString().Split("`n").Count)

# Write output
[System.IO.File]::WriteAllText($output, $sb.ToString(), $utf8)

$size = (Get-Item $output).Length / 1MB
$totalFiles = $javaFiles.Count + $jsonFiles.Count + $psFiles.Count + $docFiles.Count

Write-Host ""
Write-Host "=================================================================="
Write-Host "           CODE DUMP CREATED SUCCESSFULLY"
Write-Host "=================================================================="
Write-Host ""
Write-Host "Output file: $output"
Write-Host ("Size: " + [math]::Round($size, 2) + " MB")
Write-Host ("Total files: " + $totalFiles)
Write-Host ("Total lines: " + $sb.ToString().Split("`n").Count)
Write-Host ""
Write-Host "Contents:"
Write-Host "  Section 1: Build configuration"
Write-Host ("  Section 2: Java source - " + $javaFiles.Count + " files")
Write-Host ("  Section 3: JSON resources - " + $jsonFiles.Count + " files")
Write-Host ("  Section 4: Documentation - " + $docFiles.Count + " files")
Write-Host ("  Section 5: PowerShell scripts - " + $psFiles.Count + " files")
Write-Host "  Statistics summary"
Write-Host ""