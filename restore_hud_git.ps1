$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$repo = "E:\Games\mod"
$rel = "src/main/java/com/example/shinobicore/client/ChakraHudRenderer.java"

# ============ 1. Restore original ChakraHudRenderer from git HEAD ============
$original = & git -C $repo show "HEAD:$rel" 2>$null
if ($null -eq $original) {
    Write-Host "[ERROR] git show failed - original not in git history"
    exit 1
}
$text = @($original) -join "`n"
[System.IO.File]::WriteAllText("$repo\src\main\java\com\example\shinobicore\client\ChakraHudRenderer.java", $text, $utf8)
Write-Host "[OK] ChakraHudRenderer.java restored from git HEAD (original with jutsu layouts)"

# ============ 2. Delete JutsuSlotHud (4 squares) ============
$slot = "$repo\src\main\java\com\example\shinobicore\client\JutsuSlotHud.java"
if (Test-Path $slot) {
    Remove-Item $slot -Force
    Write-Host "[OK] JutsuSlotHud.java deleted"
}

# ============ 3. Fix ShinobiCoreClient registrations ============
$scc = "$repo\src\main\java\com\example\shinobicore\client\ShinobiCoreClient.java"
$c = [System.IO.File]::ReadAllText($scc, $utf8)

# remove JutsuSlotHud lines completely
$lines = $c -split "`n" | Where-Object { $_ -notmatch "JutsuSlotHud" }
$c = $lines -join "`n"

# restore original HUD registration (method reference)
$c = $c.Replace(
    "com.example.shinobicore.client.ChakraHudRenderer.register(); // PHASE_H_HUD",
    "HudRenderCallback.EVENT.register(ChakraHudRenderer::render);")

# ensure import exists
if (-not $c.Contains("import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;")) {
    $c = $c.Replace("import net.fabricmc.api.ClientModInitializer;",
        "import net.fabricmc.api.ClientModInitializer;`nimport net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;")
}

[System.IO.File]::WriteAllText($scc, $c, $utf8)
Write-Host "[OK] ShinobiCoreClient: original HUD registration restored, JutsuSlotHud removed"

Write-Host "=== ORIGINAL HUD RESTORED ==="