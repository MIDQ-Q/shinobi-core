$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)

# === 1. Patch TreePassives.java ===
$tpPath = "E:\Games\mod\src\main\java\com\example\shinobicore\tree\TreePassives.java"
$tpContent = [System.IO.File]::ReadAllText($tpPath, $utf8)
$tpSentinel = "PHASE_B_GEN_PASSIVE_DONE"

if ($tpContent.Contains($tpSentinel)) {
    Write-Host "[SKIP] TreePassives already patched for genjutsu"
} else {
    # Add field after kekkeiStun
    $fieldAnchor = "public float kekkeiStun = 0f;"
    if ($tpContent.Contains($fieldAnchor)) {
        $tpContent = $tpContent.Replace($fieldAnchor, $fieldAnchor + "`n        public float genjutsuResist = 0f;")
        Write-Host "[FIX] Added genjutsuResist field to Bonuses"
    } else {
        Write-Host "[ERROR] TreePassives field anchor not found"
        exit 1
    }

    # Add case after kg_lava
    $caseAnchor = 'case "kg_lava" -> { b.kekkeiFire += 0.10f; b.kekkeiEarth += 0.10f; }'
    if ($tpContent.Contains($caseAnchor)) {
        $tpContent = $tpContent.Replace($caseAnchor, $caseAnchor + "`n            case `"gen_resist`" -> b.genjutsuResist += 0.10f;")
        Write-Host "[FIX] Added gen_resist case to apply()"
    } else {
        Write-Host "[ERROR] TreePassives case anchor not found"
        exit 1
    }

    # Add sentinel
    $tpContent = $tpContent + "`n// " + $tpSentinel
    [System.IO.File]::WriteAllText($tpPath, $tpContent, $utf8)
    Write-Host "[OK] TreePassives.java updated"
}

# === 2. Patch GenjutsuBehavior.java to use passive ===
$gbPath = "E:\Games\mod\src\main\java\com\example\shinobicore\jutsu\GenjutsuBehavior.java"
$gbContent = [System.IO.File]::ReadAllText($gbPath, $utf8)
$gbSentinel = "PHASE_B_GEN_PASSIVE_USED"

if ($gbContent.Contains($gbSentinel)) {
    Write-Host "[SKIP] GenjutsuBehavior already uses genjutsu passive"
} else {
    # Add TreePassives import
    $importAnchor = "import com.example.shinobicore.stat.StatType;"
    if ($gbContent.Contains($importAnchor)) {
        $gbContent = $gbContent.Replace($importAnchor, $importAnchor + "`nimport com.example.shinobicore.tree.TreePassives;")
        Write-Host "[FIX] Added TreePassives import to GenjutsuBehavior"
    } else {
        Write-Host "[ERROR] GenjutsuBehavior import anchor not found"
        exit 1
    }

    # Add passive pierce bonus
    $pierceAnchor = "float pierceBonus = Math.max(0, (casterGenjutsu - 20) * 0.005f);"
    if ($gbContent.Contains($pierceAnchor)) {
        $pierceAdd = @"

        // Passive bonus from skill tree
        float passivePierce = TreePassives.collectServer(casterData).genjutsuResist;
        pierceBonus += passivePierce;
"@
        $gbContent = $gbContent.Replace($pierceAnchor, $pierceAnchor + $pierceAdd)
        Write-Host "[FIX] Added passive pierce bonus to calculateResistChance"
    } else {
        Write-Host "[ERROR] GenjutsuBehavior pierce anchor not found"
        exit 1
    }

    # Add sentinel
    $gbContent = $gbContent + "`n// " + $gbSentinel
    [System.IO.File]::WriteAllText($gbPath, $gbContent, $utf8)
    Write-Host "[OK] GenjutsuBehavior.java updated"
}