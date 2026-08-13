$utf8 = New-Object System.Text.UTF8Encoding($false)

# === [1] tree.json: запятая после forb_edo + валидация ===
$file = "E:\Games\mod\src\main\resources\data\shinobicore\skill_tree\tree.json"
$c = [System.IO.File]::ReadAllText($file, $utf8).Replace("`r`n", "`n")
$bad = "}`n    {""id"":""shuriken_accuracy"""
if ($c.Contains($bad)) {
    $c = $c.Replace($bad, "},`n    {""id"":""shuriken_accuracy""")
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[OK] tree.json: comma restored" -ForegroundColor Green
} else {
    Write-Host "[SKIP] comma marker not found" -ForegroundColor Yellow
}
try {
    $p = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host ("[OK] JSON VALID: {0} nodes, {1} branches" -f $p.nodes.Count, $p.branches.PSObject.Properties.Count) -ForegroundColor Green
} catch {
    Write-Host "[FAIL] JSON INVALID: $($_.Exception.Message)" -ForegroundColor Red
}

# === [2] ShurikenEntity: исчезает при попадании в блок (regex-замена блока) ===
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\entity\ShurikenEntity.java"
$c = [System.IO.File]::ReadAllText($file, $utf8).Replace("`r`n", "`n")
$pattern = "(?s)if \(blockHit\.getType\(\) == HitResult\.Type\.BLOCK\) \{.*?\n        \}"
$good = @'
if (blockHit.getType() == HitResult.Type.BLOCK) {
            if (this.getWorld() instanceof ServerWorld swHit) {
                swHit.spawnParticles(ParticleTypes.POOF, this.getX(), this.getY(), this.getZ(), 4, 0.1, 0.1, 0.1, 0.02);
            }
            this.playSound(SoundEvents.BLOCK_WOOD_HIT, 0.5f, 1.4f);
            this.discard();
            return;
        }
'@
$good = $good.Replace("`r`n", "`n")
$m = [regex]::Match($c, $pattern)
if ($m.Success) {
    $c = $c.Substring(0, $m.Index) + $good + $c.Substring($m.Index + $m.Length)
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[OK] ShurikenEntity: discard on block hit" -ForegroundColor Green
} else {
    Write-Host "[SKIP] shuriken block not found" -ForegroundColor Yellow
}

Write-Host "`n=== BUILD ===" -ForegroundColor Cyan
& "E:\Games\mod\gradlew.bat" build