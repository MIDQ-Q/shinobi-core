$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ============================================================
# 1. PATCH: KatanaDeflectMixin - improve deflect sound
# ============================================================
$kdPath = "E:\Games\mod\src\main\java\com\example\shinobicore\mixin\KatanaDeflectMixin.java"
$kdContent = [System.IO.File]::ReadAllText($kdPath, $utf8)
$sentinel1 = "PHASE_K3_DEFLECT_SOUND"

if ($kdContent.Contains($sentinel1)) {
    Write-Host "[SKIP] KatanaDeflectMixin already improved"
} else {
    # Replace shield block sound with anvil sound for metallic feel
    $kdContent = $kdContent.Replace(
        "player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 1.0f, 1.2f);",
        "player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 1.0f, 1.2f);`n        player.playSound(SoundEvents.BLOCK_ANVIL_LAND, 0.3f, 1.5f); // PHASE_K3_DEFLECT_SOUND"
    )
    Write-Host "[FIX] Improved deflect sound (added metallic clang)"
}

# ============================================================
# 2. PATCH: KenjutsuClientHandler - add Iai stance visual
# ============================================================
$kchPath = "E:\Games\mod\src\main\java\com\example\shinobicore\client\combat\KenjutsuClientHandler.java"
$kchContent = [System.IO.File]::ReadAllText($kchPath, $utf8)
$sentinel2 = "PHASE_K3_IAI_VISUAL"

if ($kchContent.Contains($sentinel2)) {
    Write-Host "[SKIP] KenjutsuClientHandler already improved"
} else {
    # Add Iai stance particles when attacking from Iai stance
    $oldAttack = "KenjutsuAnimations.playSlash(player, comboStep);"
    $newAttack = "KenjutsuAnimations.playSlash(player, comboStep);`n        // PHASE_K3_IAI_VISUAL: Iai stance special particles`n        if (stance.equals(`"iai`") && comboStep == 0) {`n            spawnIaiParticles(player);`n        }"
    $kchContent = $kchContent.Replace($oldAttack, $newAttack)
    
    # Add spawnIaiParticles method
    $kchContent = $kchContent.Replace(
        "private static void playSlashParticles(ClientPlayerEntity player, int step) {",
        "private static void spawnIaiParticles(ClientPlayerEntity player) {`n        MinecraftClient client = MinecraftClient.getInstance();`n        Vec3d look = player.getRotationVector();`n        Vec3d pos = player.getPos().add(0, 1.2, 0);`n        // White flash particles for Iai draw`n        for (int i = 0; i < 15; i++) {`n            client.world.addParticle(ParticleTypes.END_ROD,`n                pos.x + look.x * i * 0.3, pos.y + look.y * i * 0.3, pos.z + look.z * i * 0.3,`n                0, 0.05, 0);`n        }`n    }`n`n    private static void playSlashParticles(ClientPlayerEntity player, int step) {"
    )
    Write-Host "[FIX] Added Iai stance visual"
}

# ============================================================
# 3. PATCH: KenjutsuClientHandler - improve finisher visual
# ============================================================
$kchContent2 = [System.IO.File]::ReadAllText($kchPath, $utf8)
$sentinel3 = "PHASE_K3_FINISHER"

if ($kchContent2.Contains($sentinel3)) {
    Write-Host "[SKIP] Finisher already improved"
} else {
    # Add screen shake and more particles for finisher
    $oldFinisher = "if (comboStep == 3) {`n            TaijutsuSounds.playKickSound();`n            CinematicCamera.addShake(0.12f);`n        }"
    $newFinisher = "if (comboStep == 3) {`n            TaijutsuSounds.playKickSound();`n            CinematicCamera.addShake(0.12f);`n            // PHASE_K3_FINISHER: Extra finisher visual`n            MinecraftClient finishClient = MinecraftClient.getInstance();`n            Vec3d finishPos = player.getPos().add(0, 1.0, 0);`n            for (int i = 0; i < 20; i++) {`n                double angle = (i / 20.0) * Math.PI * 2;`n                finishClient.world.addParticle(ParticleTypes.CRIT,`n                    finishPos.x + Math.cos(angle) * 2.0, finishPos.y, finishPos.z + Math.sin(angle) * 2.0,`n                    Math.cos(angle) * 0.2, 0.1, Math.sin(angle) * 0.2);`n            }`n        }"
    $kchContent2 = $kchContent2.Replace($oldFinisher, $newFinisher)
    [System.IO.File]::WriteAllText($kchPath, $kchContent2, $utf8)
    Write-Host "[FIX] Improved finisher visual"
}

# ============================================================
# 4. PATCH: ShurikenEntity - add throw sound
# ============================================================
$sePath = "E:\Games\mod\src\main\java\com\example\shinobicore\entity\ShurikenEntity.java"
$seContent = [System.IO.File]::ReadAllText($sePath, $utf8)
$sentinel4 = "PHASE_K3_THROW_SOUND"

if ($seContent.Contains($sentinel4)) {
    Write-Host "[SKIP] ShurikenEntity already improved"
} else {
    # Add whoosh sound when shuriken is thrown
    $oldTick = "@Override public void tick() {"
    $newTick = "@Override public void tick() {`n        // PHASE_K3_THROW_SOUND: Play whoosh sound on first tick`n        if (age == 0) {`n            this.playSound(SoundEvents.ENTITY_ARROW_SHOOT, 0.5f, 1.8f);`n        }"
    $seContent = $seContent.Replace($oldTick, $newTick)
    [System.IO.File]::WriteAllText($sePath, $seContent, $utf8)
    Write-Host "[FIX] Added throw sound to ShurikenEntity"
}

Write-Host ""
Write-Host "=== PHASE K3 APPLIED ==="
Write-Host "Run: .\gradlew.bat build"