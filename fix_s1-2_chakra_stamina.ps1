# ============================================================
#  FIX S1-01/S1-02 REMAINING: Stamina fields, packet, HUD
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$ok = 0; $skip = 0; $err = 0

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] Written: $($p.Replace($root, ''))" -ForegroundColor Green
    $script:ok++
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; $script:err++; return }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $cNorm = $c.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    if ($cNorm.Contains($newNorm)) { Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; $script:skip++; return }
    if (-not $cNorm.Contains($oldNorm)) { Write-Host "[FAIL] pattern not found: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; $script:err++; return }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FIX S1-01/S1-02: STAMINA FIELDS + PACKET + HUD" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. NinjaPlayerData.java - add stamina fields
# ================================================================
Write-Host "[1/5] NinjaPlayerData.java (stamina fields)..." -ForegroundColor White
Patch-File "$java\stat\NinjaPlayerData.java" `
"private float currentChakra = 100f;" `
"private float currentChakra = 100f;
    private float currentStamina = 100f;
    private float maxStamina = 100f;"

# ================================================================
# 2. NinjaPlayerData.java - add stamina getters/setters
# ================================================================
Write-Host "[2/5] NinjaPlayerData.java (stamina getters)..." -ForegroundColor White
Patch-File "$java\stat\NinjaPlayerData.java" `
"public float getCurrentChakra() { return currentChakra; }" `
"public float getCurrentChakra() { return currentChakra; }
    public float getCurrentStamina() { return currentStamina; }
    public void setCurrentStamina(float v) { this.currentStamina = Math.max(0, Math.min(v, maxStamina)); }
    public float getMaxStamina() { return maxStamina; }
    public void setMaxStamina(float v) { this.maxStamina = Math.max(1, v); }"

# ================================================================
# 3. ChakraSyncPacket.java - full rewrite with stamina
# ================================================================
Write-Host "[3/5] ChakraSyncPacket.java (full rewrite)..." -ForegroundColor White
$packetContent = @'
package com.example.shinobicore.network;

import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.network.PacketByteBuf;

public record ChakraSyncPacket(
    float currentChakra,
    float maxChakra,
    float currentStamina,
    float maxStamina,
    float fatigue,
    boolean exhausted,
    boolean meditating,
    int reserveLevel,
    String clanId,
    String affinityId
) {
    public void write(PacketByteBuf buf) {
        buf.writeFloat(currentChakra);
        buf.writeFloat(maxChakra);
        buf.writeFloat(currentStamina);
        buf.writeFloat(maxStamina);
        buf.writeFloat(fatigue);
        buf.writeBoolean(exhausted);
        buf.writeBoolean(meditating);
        buf.writeInt(reserveLevel);
        buf.writeString(clanId != null ? clanId : "");
        buf.writeString(affinityId != null ? affinityId : "");
    }

    public static ChakraSyncPacket read(PacketByteBuf buf) {
        float chakra = buf.readFloat();
        float max = buf.readFloat();
        float stam = buf.readFloat();
        float maxStam = buf.readFloat();
        float fatigue = buf.readFloat();
        boolean exhausted = buf.readBoolean();
        boolean meditating = buf.readBoolean();
        int reserve = buf.readInt();
        String clan = buf.readString();
        String affinity = buf.readString();
        return new ChakraSyncPacket(
                chakra, max, stam, maxStam, fatigue, exhausted, meditating, reserve,
                clan.isEmpty() ? null : clan,
                affinity.isEmpty() ? null : affinity
        );
    }

    public static ChakraSyncPacket fromData(NinjaPlayerData data) {
        return new ChakraSyncPacket(
                data.getCurrentChakra(),
                NinjaFormula.maxChakra(data),
                data.getCurrentStamina(),
                data.getMaxStamina(),
                data.getFatigue(),
                data.isExhausted(),
                data.isMeditating(),
                data.getReserveLevel(),
                data.getClanId(),
                data.getAffinity() != null ? data.getAffinity().getId() : null
        );
    }
}
'@
Write-File "$java\network\ChakraSyncPacket.java" $packetContent

# ================================================================
# 4. ChakraHudRenderer.java - add stamina fields + bar
# ================================================================
Write-Host "[4/5] ChakraHudRenderer.java (stamina bar)..." -ForegroundColor White

# 4a. Add stamina fields
Patch-File "$java\client\ChakraHudRenderer.java" `
"public static boolean exhausted = false;" `
"public static boolean exhausted = false;
    public static float currentStamina = 100f;
    public static float maxStamina = 100f;"

# 4b. Add stamina bar before fatigue bar
Patch-File "$java\client\ChakraHudRenderer.java" `
"if (fatigue > 0)" `
"float stamRatio = maxStamina > 0 ? currentStamina / maxStamina : 0;
        bars.add(new BarSpec(stamRatio, 0xFF44EE44, 0xFF22AA22, stamRatio < 0.25f,
                ""ST"", (int) currentStamina + ""/"" + (int) maxStamina));
        if (fatigue > 0)"

# ================================================================
# 5. ShinobiCoreClient.java - read stamina from packet
# ================================================================
Write-Host "[5/5] ShinobiCoreClient.java (stamina sync)..." -ForegroundColor White
Patch-File "$java\client\ShinobiCoreClient.java" `
"ChakraHudRenderer.fatigue = packet.fatigue();" `
"ChakraHudRenderer.fatigue = packet.fatigue();
                ChakraHudRenderer.currentStamina = packet.currentStamina();
                ChakraHudRenderer.maxStamina = packet.maxStamina();"

# ================================================================
# SUMMARY
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  FIX COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Changes:" -ForegroundColor White
Write-Host "    NinjaPlayerData.java     +currentStamina, +maxStamina, getters" -ForegroundColor White
Write-Host "    ChakraSyncPacket.java    rewritten with stamina fields" -ForegroundColor White
Write-Host "    ChakraHudRenderer.java   +stamina fields, +green ST bar" -ForegroundColor White
Write-Host "    ShinobiCoreClient.java   reads stamina from packet" -ForegroundColor White
Write-Host ""

if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected!" -ForegroundColor Red
    exit 1
}

Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
exit 0