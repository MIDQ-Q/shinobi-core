# ============================================================
#  PHASE 3: СВЯЗЬ УДАРОВ С ЧАКРОЙ И УСТАЛОСТЬЮ
# ============================================================
$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$java = "E:\Games\mod\src\main\java\com\example\shinobicore"
$ok = 0; $skip = 0; $err = 0

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $($p.Replace('E:\Games\mod\src\main\', ''))" -ForegroundColor Green
    $script:ok++
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; $script:err++; return }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    if ($c.Contains($new)) { Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; $script:skip++; return }
    if (-not $c.Contains($old)) { Write-Host "[FAIL] pattern: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; $script:err++; return }
    $c = $c.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host "`n=== PHASE 3: CHAKRA-MELEE INTEGRATION ===`n" -ForegroundColor Cyan

# ================================================================
# 1. NinjaPlayerData.java — chakra combo counter
# ================================================================
Write-Host "[1/4] Patching NinjaPlayerData.java..." -ForegroundColor White

Patch-File "$java\stat\NinjaPlayerData.java" `
    "private long lastDeflectReflectMs = 0;" `
    "private long lastDeflectReflectMs = 0;
    // === PHASE3: Chakra-melee integration ===
    private int chakraComboCounter = 0;
    private long lastChakraHitMs = 0;"

Patch-File "$java\stat\NinjaPlayerData.java" `
    "public long getLastDeflectReflectMs() { return lastDeflectReflectMs; }
    public void setLastDeflectReflectMs(long v) { this.lastDeflectReflectMs = v; }" `
    "public long getLastDeflectReflectMs() { return lastDeflectReflectMs; }
    public void setLastDeflectReflectMs(long v) { this.lastDeflectReflectMs = v; }
    // === PHASE3 ===
    public int getChakraComboCounter() { return chakraComboCounter; }
    public void setChakraComboCounter(int v) { this.chakraComboCounter = v; }
    public void incrementChakraCombo() { this.chakraComboCounter++; }
    public void resetChakraCombo() { this.chakraComboCounter = 0; }
    public long getLastChakraHitMs() { return lastChakraHitMs; }
    public void setLastChakraHitMs(long v) { this.lastChakraHitMs = v; }"

# NBT save/load
Patch-File "$java\stat\NinjaPlayerData.java" `
    "nbt.putString(""KatanaStance"", katanaStanceId);" `
    "nbt.putString(""KatanaStance"", katanaStanceId);
        nbt.putInt(""ChakraComboCounter"", chakraComboCounter);"

Patch-File "$java\stat\NinjaPlayerData.java" `
    "if (nbt.contains(""KatanaStance"")) katanaStanceId = nbt.getString(""KatanaStance"");" `
    "if (nbt.contains(""KatanaStance"")) katanaStanceId = nbt.getString(""KatanaStance"");
        if (nbt.contains(""ChakraComboCounter"")) chakraComboCounter = nbt.getInt(""ChakraComboCounter"");"

# ================================================================
# 2. ModPackets.java — chakra combo scaling в обработчике атак
# ================================================================
Write-Host "[2/4] Patching ModPackets.java (chakra combo scaling)..." -ForegroundColor White

# В обработчике KATANA_ATTACK_ID, после вычисления урона для normal combo
Patch-File "$java\network\ModPackets.java" `
    "float damage = KenjutsuFormulas.computeDamage(tai, stance, chakra, step, data.isExhausted());

                // IAI first-strike bonus" `
    "float damage = KenjutsuFormulas.computeDamage(tai, stance, chakra, step, data.isExhausted());

                // === PHASE3: Chakra combo scaling ===
                if (chakra) {
                    long sinceLastChakraHit = now - data.getLastChakraHitMs();
                    if (sinceLastChakraHit < 3000) {
                        data.incrementChakraCombo();
                    } else {
                        data.resetChakraCombo();
                    }
                    data.setLastChakraHitMs(now);
                    // Each consecutive chakra hit adds +5% damage (max +50%)
                    float comboBonus = Math.min(0.5f, data.getChakraComboCounter() * 0.05f);
                    damage *= (1.0f + comboBonus);
                    if (data.getChakraComboCounter() >= 5 && data.getChakraComboCounter() % 5 == 0) {
                        player.sendMessage(Text.literal(""\u00a7bChakra Combo x"" + data.getChakraComboCounter() + ""!""), true);
                    }
                }

                // IAI first-strike bonus"

# ================================================================
# 3. NinjaTickHandler.java — chakra combo decay
# ================================================================
Write-Host "[3/4] Patching NinjaTickHandler.java (chakra combo decay)..." -ForegroundColor White

Patch-File "$java\event\NinjaTickHandler.java" `
    "// === PHASE_FIX2_TICK: sensory glow + danger sense + rasengan dissipate ===" `
    "// === PHASE3: Chakra combo decay ===
            if (data.getChakraComboCounter() > 0) {
                long sinceLastHit = System.currentTimeMillis() - data.getLastChakraHitMs();
                if (sinceLastHit > 3000) {
                    data.resetChakraCombo();
                }
            }

            // === PHASE_FIX2_TICK: sensory glow + danger sense + rasengan dissipate ==="

# ================================================================
# 4. ChakraHudRenderer.java — индикатор chakra combo
# ================================================================
Write-Host "[4/4] Patching ChakraHudRenderer.java..." -ForegroundColor White

Patch-File "$java\client\ChakraHudRenderer.java" `
    "if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            String st = ClientNinjaState.kenjutsuStance;
            int stColor = st.equals(""seigan"") ? 0xFF66AAFF : st.equals(""iai"") ? 0xFFFFAA00 : 0xFFFF5555;
            context.drawTextWithShadow(client.textRenderer, Text.literal(""["" + st.toUpperCase() + ""]""), 10, y + 10, stColor);
            y += 12;
        }" `
    "if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            String st = ClientNinjaState.kenjutsuStance;
            int stColor = st.equals(""seigan"") ? 0xFF66AAFF : st.equals(""iai"") ? 0xFFFFAA00 : 0xFFFF5555;
            context.drawTextWithShadow(client.textRenderer, Text.literal(""["" + st.toUpperCase() + ""]""), 10, y + 10, stColor);
            y += 12;
            // === PHASE3: Chakra combo indicator ===
            if (ClientNinjaState.chakraMode && comboStep > 0) {
                int chakraComboColor = 0xFF44DDFF;
                context.drawTextWithShadow(client.textRenderer,
                    Text.literal(""\u2726 CHAKRA COMBO x"" + comboStep), 10, y + 10, chakraComboColor);
                y += 12;
            }
        }"

# ================================================================
Write-Host "`n=== PHASE 3 COMPLETE: OK=$ok SKIP=$skip ERR=$err ===`n" -ForegroundColor Green
Write-Host "Next: .\gradlew.bat build" -ForegroundColor Yellow