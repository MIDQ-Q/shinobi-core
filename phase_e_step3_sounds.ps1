$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)

# === 1. Add genjutsu sounds to sounds.json ===
$soundsPath = "E:\Games\mod\src\main\resources\assets\shinobicore\sounds.json"
$soundsContent = [System.IO.File]::ReadAllText($soundsPath, $utf8)
$sentinel1 = "PHASE_E_GEN_SOUNDS_REGISTERED"

if ($soundsContent.Contains($sentinel1)) {
    Write-Host "[SKIP] Genjutsu sounds already registered"
} else {
    $newSounds = @'
,
"genjutsu_cast": {
    "subtitle": "Genjutsu cast",
    "sounds": [
        {"name": "minecraft:entity/enderman/stare", "volume": 0.5, "pitch": 0.6},
        {"name": "minecraft:entity/illusioner/cast_spell", "volume": 0.7, "pitch": 0.8}
    ]
},
"genjutsu_ambient": {
    "subtitle": "Genjutsu whispers",
    "sounds": [
        {"name": "minecraft:ambient/cave/cave8", "volume": 0.15, "pitch": 0.4},
        {"name": "minecraft:entity/wandering_trader/disappeared", "volume": 0.2, "pitch": 0.5}
    ]
},
"genjutsu_resist": {
    "subtitle": "Genjutsu resisted",
    "sounds": [
        {"name": "minecraft:entity/enderman/teleport", "volume": 0.4, "pitch": 1.5}
    ]
}
'@
    
    # Insert before the final closing brace
    $lastBrace = $soundsContent.LastIndexOf("}")
    if ($lastBrace -ge 0) {
        $soundsContent = $soundsContent.Substring(0, $lastBrace) + $newSounds + "`n}`n// " + $sentinel1
        [System.IO.File]::WriteAllText($soundsPath, $soundsContent, $utf8)
        Write-Host "[FIX] Added genjutsu sounds to sounds.json"
    } else {
        Write-Host "[ERROR] Could not find closing brace in sounds.json"
        exit 1
    }
}

# === 2. Add genjutsu cast sound to GenjutsuBehavior.java ===
$gbPath = "E:\Games\mod\src\main\java\com\example\shinobicore\jutsu\GenjutsuBehavior.java"
$gbContent = [System.IO.File]::ReadAllText($gbPath, $utf8)
$sentinel2 = "PHASE_E_GEN_CAST_SOUND"

if ($gbContent.Contains($sentinel2)) {
    Write-Host "[SKIP] GenjutsuBehavior already has cast sound"
} else {
    # Add SoundEvent import
    $importAnchor = "import net.minecraft.server.world.ServerWorld;"
    if ($gbContent.Contains($importAnchor)) {
        $gbContent = $gbContent.Replace($importAnchor, $importAnchor + "`nimport net.minecraft.sound.SoundEvent;`nimport net.minecraft.sound.SoundCategory;`nimport net.minecraft.util.Identifier;")
        Write-Host "[FIX] Added sound imports to GenjutsuBehavior"
    } else {
        Write-Host "[WARN] Could not find ServerWorld import anchor"
    }

    # Add sound play after successful cast (before return true)
    $successAnchor = 'player.sendMessage(Text.literal("\u00a7aGenjutsu applied to " + targetName + "!"), false);'
    if ($gbContent.Contains($successAnchor)) {
        $soundCode = @"

        // Play genjutsu cast sound for nearby players // PHASE_E_GEN_CAST_SOUND
        SoundEvent genCastSound = SoundEvent.of(new Identifier("shinobicore", "genjutsu_cast"));
        serverWorld.playSound(null, player.getBlockPos(), genCastSound, SoundCategory.PLAYERS, 1.0f, 0.7f);
"@
        $gbContent = $gbContent.Replace($successAnchor, $successAnchor + $soundCode)
        Write-Host "[FIX] Added genjutsu cast sound to successful cast"
    } else {
        Write-Host "[WARN] Could not find success message anchor"
    }

    # Add resist sound
    $resistAnchor = 'player.sendMessage(Text.literal("\u00a7e" + targetName + " resisted the genjutsu!"), false);'
    if ($gbContent.Contains($resistAnchor)) {
        $resistCode = @"

        // Play resist sound // PHASE_E_GEN_RESIST_SOUND
        SoundEvent resistSound = SoundEvent.of(new Identifier("shinobicore", "genjutsu_resist"));
        serverWorld.playSound(null, player.getBlockPos(), resistSound, SoundCategory.PLAYERS, 0.8f, 1.5f);
"@
        $gbContent = $gbContent.Replace($resistAnchor, $resistAnchor + $resistCode)
        Write-Host "[FIX] Added genjutsu resist sound"
    } else {
        Write-Host "[WARN] Could not find resist message anchor"
    }

    [System.IO.File]::WriteAllText($gbPath, $gbContent, $utf8)
    Write-Host "[OK] GenjutsuBehavior.java updated"
}

# === 3. Add ambient sound to GenjutsuAuraEffect.java ===
$gaePath = "E:\Games\mod\src\main\java\com\example\shinobicore\jutsu\GenjutsuAuraEffect.java"
$gaeContent = [System.IO.File]::ReadAllText($gaePath, $utf8)
$sentinel3 = "PHASE_E_GEN_AMBIENT_SOUND"

if ($gaeContent.Contains($sentinel3)) {
    Write-Host "[SKIP] GenjutsuAuraEffect already has ambient sound"
} else {
    # Add imports
    $gaeContent = $gaeContent.Replace(
        "import net.minecraft.util.math.Vec3d;",
        "import net.minecraft.util.math.Vec3d;`nimport net.minecraft.sound.SoundEvent;`nimport net.minecraft.sound.SoundCategory;`nimport net.minecraft.util.Identifier;"
    )

    # Add ambient sound every 30 ticks
    $witchBlock = @"
        // Witch particles near the head (mental effect indicator)
        if (tickCounter % 15 == 0) {
            world.spawnParticles(ParticleTypes.WITCH,
                pos.x,
                pos.y + height * 0.85,
                pos.z,
                2, 0.3, 0.2, 0.3, 0.02);
        }
"@

    $witchWithSound = @"
        // Witch particles near the head (mental effect indicator)
        if (tickCounter % 15 == 0) {
            world.spawnParticles(ParticleTypes.WITCH,
                pos.x,
                pos.y + height * 0.85,
                pos.z,
                2, 0.3, 0.2, 0.3, 0.02);
        }

        // Ambient genjutsu sound every 30 ticks (eerie whispers) // PHASE_E_GEN_AMBIENT_SOUND
        if (tickCounter % 30 == 0) {
            SoundEvent ambientSound = SoundEvent.of(new Identifier("shinobicore", "genjutsu_ambient"));
            world.playSound(null, entity.getBlockPos(), ambientSound, SoundCategory.HOSTILE, 0.3f, 0.5f);
        }
"@

    if ($gaeContent.Contains($witchBlock)) {
        $gaeContent = $gaeContent.Replace($witchBlock, $witchWithSound)
        [System.IO.File]::WriteAllText($gaePath, $gaeContent, $utf8)
        Write-Host "[FIX] Added ambient sound to GenjutsuAuraEffect"
    } else {
        Write-Host "[ERROR] Could not find witch particle block"
        exit 1
    }
    Write-Host "[OK] GenjutsuAuraEffect.java updated"
}

Write-Host ""
Write-Host "=== PHASE E STEP 3 APPLIED ==="
Write-Host "Run: .\gradlew.bat build"