# ============================================================
#  SPRINT 1 / S1-08: PASSIVE XP DRIFT
#  Small passive XP gain every minute with daily cap
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
#  Run: powershell -ExecutionPolicy Bypass -File .\sprint1_s08_passive_drift.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = Join-Path $root "src\main\java\com\example\shinobicore"
$ok = 0; $skip = 0; $err = 0

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; $script:err++; return }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $cNorm = $c.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    if ($cNorm.Contains($newNorm)) { Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; $script:skip++; return }
    if (-not $cNorm.Contains($oldNorm)) { Write-Host "[FAIL] pattern: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; $script:err++; return }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 1 / S1-08: PASSIVE XP DRIFT" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. ModConfig.java - add PassiveDrift config section
# ================================================================
Write-Host "[1/8] ModConfig.java (PassiveDrift field)..." -ForegroundColor White
Patch-File (Join-Path $java "config\ModConfig.java") `
    "public Stamina stamina = new Stamina();" `
    "public Stamina stamina = new Stamina();`n    public PassiveDrift passiveDrift = new PassiveDrift();"

# ================================================================
# 2. ModConfig.java - add PassiveDrift class
# ================================================================
Write-Host "[2/8] ModConfig.java (PassiveDrift class)..." -ForegroundColor White
Patch-File (Join-Path $java "config\ModConfig.java") `
    "public static class Stamina {`n        public float baseStamina = 100f;`n        public float baseRegen = 5.0f;`n        public float sprintCostPerSecond = 2.0f;`n    }" `
    "public static class Stamina {`n        public float baseStamina = 100f;`n        public float baseRegen = 5.0f;`n        public float sprintCostPerSecond = 2.0f;`n    }`n`n    public static class PassiveDrift {`n        public int xpPerMinute = 5;`n        public int dailyXpCap = 500;`n        public float diminishingThreshold = 0.5f;`n        public float controlXpRatio = 0.2f;`n    }"

# ================================================================
# 3. NinjaPlayerData.java - add passive drift fields
# ================================================================
Write-Host "[3/8] NinjaPlayerData.java (passive drift fields)..." -ForegroundColor White
Patch-File (Join-Path $java "stat\NinjaPlayerData.java") `
    "private boolean lastDangerState = false;" `
    "private boolean lastDangerState = false;`n    // === S1-08: PASSIVE DRIFT ===`n    private int passiveXpToday = 0;`n    private long lastPassiveDay = 0;`n    private long lastPassiveXpTimeMs = 0;"

# ================================================================
# 4. NinjaPlayerData.java - add passive drift methods
# ================================================================
Write-Host "[4/8] NinjaPlayerData.java (passive drift methods)..." -ForegroundColor White
Patch-File (Join-Path $java "stat\NinjaPlayerData.java") `
    "public boolean getLastDangerState() { return lastDangerState; }`n    public void setLastDangerState(boolean v) { this.lastDangerState = v; }" `
    "public boolean getLastDangerState() { return lastDangerState; }`n    public void setLastDangerState(boolean v) { this.lastDangerState = v; }`n    // === S1-08: PASSIVE DRIFT ===`n    public long getLastPassiveXpTimeMs() { return lastPassiveXpTimeMs; }`n    public void setLastPassiveXpTimeMs(long v) { this.lastPassiveXpTimeMs = v; }`n    public int consumePassiveXpBudget(int amount, int dailyCap, float diminishingThreshold) {`n        long currentDay = System.currentTimeMillis() / 86400000L;`n        if (currentDay != lastPassiveDay) {`n            passiveXpToday = 0;`n            lastPassiveDay = currentDay;`n        }`n        if (passiveXpToday >= dailyCap) return 0;`n        float factor = 1.0f;`n        if ((float)passiveXpToday / dailyCap >= diminishingThreshold) {`n            factor = 0.5f;`n        }`n        int actual = (int)(amount * factor);`n        actual = Math.min(actual, dailyCap - passiveXpToday);`n        if (actual > 0) {`n            passiveXpToday += actual;`n            statsDirty = true;`n        }`n        return actual;`n    }"

# ================================================================
# 5. NinjaPlayerData.java - NBT write
# ================================================================
Write-Host "[5/8] NinjaPlayerData.java (NBT write)..." -ForegroundColor White
Patch-File (Join-Path $java "stat\NinjaPlayerData.java") `
    'nbt.putBoolean("RasenganReady", rasenganReady);' `
    'nbt.putBoolean("RasenganReady", rasenganReady);
nbt.putInt("PassiveXpToday", passiveXpToday);
nbt.putLong("LastPassiveDay", lastPassiveDay);
nbt.putLong("LastPassiveXpTimeMs", lastPassiveXpTimeMs);'

# ================================================================
# 6. NinjaPlayerData.java - NBT read
# ================================================================
Write-Host "[6/8] NinjaPlayerData.java (NBT read)..." -ForegroundColor White
Patch-File (Join-Path $java "stat\NinjaPlayerData.java") `
    'rasenganReady = nbt.getBoolean("RasenganReady");' `
    'rasenganReady = nbt.getBoolean("RasenganReady");
passiveXpToday = nbt.getInt("PassiveXpToday");
lastPassiveDay = nbt.getLong("LastPassiveDay");
lastPassiveXpTimeMs = nbt.getLong("LastPassiveXpTimeMs");
long currentDayCheck = System.currentTimeMillis() / 86400000L;
if (currentDayCheck != lastPassiveDay) {
    passiveXpToday = 0;
    lastPassiveDay = currentDayCheck;
}'

# ================================================================
# 7. NinjaFormula.java - add grantPassiveXp method
# ================================================================
Write-Host "[7/8] NinjaFormula.java (grantPassiveXp)..." -ForegroundColor White
Patch-File (Join-Path $java "stat\NinjaFormula.java") `
    "private static float getClanReserveBonus(String clanId) {`n        if (clanId == null || clanId.equals(""none"")) return 0f;`n        ClanDefinition clan = ClanRegistry.get(clanId);`n        if (clan == null) return 0f;`n        return clan.reserveBonus();`n    }" `
    "private static float getClanReserveBonus(String clanId) {`n        if (clanId == null || clanId.equals(""none"")) return 0f;`n        ClanDefinition clan = ClanRegistry.get(clanId);`n        if (clan == null) return 0f;`n        return clan.reserveBonus();`n    }`n`n    // === S1-08: PASSIVE XP DRIFT ===`n    public static void grantPassiveXp(NinjaPlayerData data) {`n        long now = System.currentTimeMillis();`n        if (now - data.getLastPassiveXpTimeMs() < 60000) return;`n        data.setLastPassiveXpTimeMs(now);`n        int xpPerMinute = cfg().passiveDrift.xpPerMinute;`n        int dailyCap = cfg().passiveDrift.dailyXpCap;`n        float diminishingThreshold = cfg().passiveDrift.diminishingThreshold;`n        int xp = data.consumePassiveXpBudget(xpPerMinute, dailyCap, diminishingThreshold);`n        if (xp <= 0) return;`n        float controlRatio = cfg().passiveDrift.controlXpRatio;`n        int controlXp = Math.max(1, (int)(xp * controlRatio));`n        int reserveXp = xp - controlXp;`n        if (reserveXp > 0) addReserveXp(data, reserveXp);`n        if (controlXp > 0) addStatXp(data, StatType.CONTROL, controlXp);`n    }"

# ================================================================
# 8. NinjaTickHandler.java - call grantPassiveXp
# ================================================================
Write-Host "[8/8] NinjaTickHandler.java (call grantPassiveXp)..." -ForegroundColor White
Patch-File (Join-Path $java "event\NinjaTickHandler.java") `
    "ShinobiCore.sendChakraSync(player);`n        if (data.consumeStatsDirty()) {" `
    "// === S1-08: PASSIVE XP DRIFT ===`n        NinjaFormula.grantPassiveXp(data);`n        ShinobiCore.sendChakraSync(player);`n        if (data.consumeStatsDirty()) {"

# ================================================================
# SUMMARY
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  S1-08 COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Changes:" -ForegroundColor White
Write-Host "    ModConfig.java        +PassiveDrift section" -ForegroundColor White
Write-Host "      xpPerMinute: 5 (XP every minute)" -ForegroundColor White
Write-Host "      dailyXpCap: 500 (max passive XP per day)" -ForegroundColor White
Write-Host "      diminishingThreshold: 0.5 (50% cap -> 0.5x factor)" -ForegroundColor White
Write-Host "      controlXpRatio: 0.2 (20% to control, 80% to reserve)" -ForegroundColor White
Write-Host "    NinjaPlayerData.java  +passiveXpToday, +lastPassiveDay," -ForegroundColor White
Write-Host "      +lastPassiveXpTimeMs, +consumePassiveXpBudget(), NBT" -ForegroundColor White
Write-Host "    NinjaFormula.java     +grantPassiveXp() method" -ForegroundColor White
Write-Host "    NinjaTickHandler.java  calls grantPassiveXp every tick" -ForegroundColor White
Write-Host ""
Write-Host "  Logic:" -ForegroundColor White
Write-Host "    - Every 60s: 5 XP (80% reserve, 20% control)" -ForegroundColor White
Write-Host "    - After 250 XP (50% of 500 cap): XP halved" -ForegroundColor White
Write-Host "    - Daily cap: 500 XP (resets at midnight UTC)" -ForegroundColor White
Write-Host "    - Level-ups grant SP as usual" -ForegroundColor White
Write-Host ""
if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected!" -ForegroundColor Red
    exit 1
}
Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
Write-Host "  Then: sprint1_s09_early_late_balance.ps1" -ForegroundColor Yellow
exit 0