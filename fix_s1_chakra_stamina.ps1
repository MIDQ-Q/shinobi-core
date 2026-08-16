# ============================================================
#  FIX S1-01 & S1-02: CHAKRA LIMIT & STAMINA POOL
#  Safe overwrite for files that failed pattern matching
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$res = "$root\src\main\resources\data\shinobicore"
$ok = 0; $err = 0

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
    if ($cNorm.Contains($newNorm)) { Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; return }
    if (-not $cNorm.Contains($oldNorm)) { Write-Host "[FAIL] pattern not found: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; $script:err++; return }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FIX S1-01 & S1-02: SAFE OVERWRITE MODE" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. ClanDefinition.java - FULL OVERWRITE
# ================================================================
Write-Host "[1/8] ClanDefinition.java..." -ForegroundColor White
Write-File "$java\clan\ClanDefinition.java" @'
package com.example.shinobicore.clan;

import com.example.shinobicore.stat.ElementType;
import java.util.Map;

public record ClanDefinition(
    String id,
    String name,
    ElementType affinity,
    int extraAffinityCount,
    Map<String, Integer> statBonuses,
    Map<String, Integer> natureBonuses,
    Map<String, Float> costMultiplier,
    float fatigueMultiplier,
    float reserveBonus,
    String dojutsuHook,
    int chakraCap
) {
    public boolean hasDojutsu() {
        return dojutsuHook != null && !dojutsuHook.isEmpty();
    }
}
'@

# ================================================================
# 2. ClanRegistry.java - FULL OVERWRITE
# ================================================================
Write-Host "[2/8] ClanRegistry.java..." -ForegroundColor White
Write-File "$java\clan\ClanRegistry.java" @'
package com.example.shinobicore.clan;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.ElementType;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

public class ClanRegistry {
    private static final Map<String, ClanDefinition> CLANS = new HashMap<>();
    private static final Random RANDOM = new Random();

    public static void reload(ResourceManager manager) {
        CLANS.clear();
        Map<Identifier, List<Resource>> resources = manager.findAllResources("clans",
            id -> id.getNamespace().equals(ShinobiCore.MOD_ID) && id.getPath().endsWith(".json"));
        for (Map.Entry<Identifier, List<Resource>> entry : resources.entrySet()) {
            for (Resource resource : entry.getValue()) {
                try (InputStream stream = resource.getInputStream()) {
                    JsonObject json = JsonParser.parseReader(
                        new InputStreamReader(stream, StandardCharsets.UTF_8)).getAsJsonObject();
                    if (!json.has("id")) {
                        String path = id.getPath();
                        String name = path.substring("clans/".length(), path.length() - ".json".length());
                        json.addProperty("id", name);
                    }
                    ClanDefinition def = parse(json);
                    if (def != null) {
                        CLANS.put(def.id(), def);
                        ShinobiCore.LOGGER.info("Loaded clan: {}", def.id());
                    }
                } catch (Exception e) {
                    ShinobiCore.LOGGER.error("Failed to load clan from {}: {}", entry.getKey(), e.getMessage());
                }
            }
        }
        ShinobiCore.LOGGER.info("Loaded {} clans", CLANS.size());
    }

    private static ClanDefinition parse(JsonObject json) {
        String id = json.get("id").getAsString();
        String name = json.has("name") ? json.get("name").getAsString() : id;
        ElementType affinity = null;
        if (json.has("affinity") && !json.get("affinity").isJsonNull()) {
            String affId = json.get("affinity").getAsString();
            for (ElementType e : ElementType.values()) {
                if (e.getId().equals(affId)) { affinity = e; break; }
            }
        }
        int extraAffinityCount = json.has("extraAffinityCount") ? json.get("extraAffinityCount").getAsInt() : 0;
        Map<String, Integer> statBonuses = new HashMap<>();
        if (json.has("statBonuses")) {
            JsonObject obj = json.getAsJsonObject("statBonuses");
            for (String key : obj.keySet()) statBonuses.put(key, obj.get(key).getAsInt());
        }
        Map<String, Integer> natureBonuses = new HashMap<>();
        if (json.has("natureBonuses")) {
            JsonObject obj = json.getAsJsonObject("natureBonuses");
            for (String key : obj.keySet()) natureBonuses.put(key, obj.get(key).getAsInt());
        }
        Map<String, Float> costMultiplier = new HashMap<>();
        if (json.has("costMultiplier")) {
            JsonObject obj = json.getAsJsonObject("costMultiplier");
            for (String key : obj.keySet()) costMultiplier.put(key, obj.get(key).getAsFloat());
        }
        float fatigueMultiplier = json.has("fatigueMultiplier") ? json.get("fatigueMultiplier").getAsFloat() : 1.0f;
        float reserveBonus = json.has("reserveBonus") ? json.get("reserveBonus").getAsFloat() : 0f;
        String dojutsuHook = json.has("dojutsuHook") && !json.get("dojutsuHook").isJsonNull()
                ? json.get("dojutsuHook").getAsString() : null;
        int chakraCap = json.has("chakraCap") ? json.get("chakraCap").getAsInt() : 2000;

        return new ClanDefinition(id, name, affinity, extraAffinityCount,
                statBonuses, natureBonuses, costMultiplier, fatigueMultiplier, reserveBonus, dojutsuHook, chakraCap);
    }

    public static ClanDefinition get(String id) { return CLANS.get(id); }
    public static Collection<ClanDefinition> getAll() { return CLANS.values(); }
    public static ClanDefinition getRandom() {
        if (CLANS.isEmpty()) return null;
        List<ClanDefinition> list = new java.util.ArrayList<>(CLANS.values());
        return list.get(RANDOM.nextInt(list.size()));
    }
}
'@

# ================================================================
# 3. uzumaki.json - FULL OVERWRITE
# ================================================================
Write-Host "[3/8] uzumaki.json..." -ForegroundColor White
Write-File "$res\clans\uzumaki.json" @'
{
  "id": "uzumaki",
  "name": "Uzumaki Clan",
  "affinity": "water",
  "extraAffinityCount": 0,
  "statBonuses": { "control": 5, "ninjutsu": 5 },
  "natureBonuses": { "water": 10 },
  "costMultiplier": {},
  "fatigueMultiplier": 0.85,
  "reserveBonus": 150,
  "dojutsuHook": null,
  "chakraCap": 6000
}
'@

# ================================================================
# 4. NinjaPlayerData.java - Fix remaining patches
# ================================================================
Write-Host "[4/8] NinjaPlayerData.java (remaining patches)..." -ForegroundColor White
# NBT Write patch
Patch-File "$java\stat\NinjaPlayerData.java" `
"nbt.putFloat(""Chakra"", currentChakra);" `
"nbt.putFloat(""Chakra"", currentChakra);`n        nbt.putFloat(""Stamina"", currentStamina);`n        nbt.putFloat(""MaxStamina"", maxStamina);`n        nbt.putFloat(""ModeBuffer"", modeBuffer);"

# NBT Read patch
Patch-File "$java\stat\NinjaPlayerData.java" `
"currentChakra = nbt.getFloat(""Chakra"");" `
"currentChakra = nbt.getFloat(""Chakra"");`n        currentStamina = nbt.contains(""Stamina"") ? nbt.getFloat(""Stamina"") : 100f;`n        maxStamina = nbt.contains(""MaxStamina"") ? nbt.getFloat(""MaxStamina"") : 100f;`n        modeBuffer = nbt.getFloat(""ModeBuffer"");"

# ================================================================
# 5. NinjaFormula.java - FULL OVERWRITE
# ================================================================
Write-Host "[5/8] NinjaFormula.java..." -ForegroundColor White
Write-File "$java\stat\NinjaFormula.java" @'
package com.example.shinobicore.stat;

import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.tree.TreePassives;
import java.util.Map;

public class NinjaFormula {
    private static ModConfig cfg() { return ModConfig.instance; }

    // === S1-01: Chakra Limit with clan cap + mode buffer ===
    public static float maxChakra(NinjaPlayerData data) {
        float cap = cfg().chakra.baseChakra;
        ClanDefinition clan = ClanRegistry.get(data.getClanId());
        if (clan != null && clan.chakraCap() > 0) {
            cap = clan.chakraCap();
        }
        cap += (data.getReserveLevel() - 1) * cfg().chakra.chakraPerReserveLevel;
        cap += data.getModeBuffer();
        return cap;
    }

    // === S1-02: Stamina factor affects chakra regen ===
    public static float regenPerSecond(NinjaPlayerData data) {
        float regen = cfg().chakra.baseRegen
            + data.getReserveLevel() * cfg().chakra.regenPerReserveLevel
            + data.getStatLevel(StatType.CONTROL) * cfg().chakra.regenPerControlLevel;
        if (data.getFatigue() > cfg().fatigue.hardThreshold)
            regen *= cfg().chakra.regenHardFatigueMultiplier;
        if (data.isExhausted())
            regen *= cfg().chakra.regenExhaustedMultiplier;

        float staminaFactor = 0.3f + 0.7f * (data.getCurrentStamina() / Math.max(1f, data.getMaxStamina()));
        regen *= staminaFactor;

        return regen;
    }

    public static float fatigueDecayPerSecond(NinjaPlayerData data) {
        return cfg().fatigue.decayPerSecond;
    }

    public static float characterScore(JutsuDefinition def, NinjaPlayerData data) {
        Map<String, Float> weights = cfg().combat.categoryWeights.get(def.category());
        if (weights == null) weights = cfg().combat.categoryWeights.get("elemental_ninjutsu");
        float score = 0f;
        for (Map.Entry<String, Float> e : weights.entrySet()) {
            score += statValue(e.getKey(), def, data) * e.getValue();
        }
        return Math.max(0f, Math.min(100f, score));
    }

    private static float statValue(String key, JutsuDefinition def, NinjaPlayerData data) {
        if (key.equals("nature")) return def.hasNature() ? data.getNatureLevel(def.nature()) : 0;
        if (key.equals("reserve")) return data.getReserveLevel();
        for (StatType s : StatType.values()) {
            if (s.getId().equals(key)) return data.getStatLevel(s);
        }
        return 0f;
    }

    public static float usageScore(JutsuDefinition def, NinjaPlayerData data) {
        int uses = data.getJutsuUsage(def.id());
        float req = Math.max(1, def.requiredUsesForFullProficiency());
        return Math.min(100f, uses * 100f / req);
    }

    public static float mastery(JutsuDefinition def, NinjaPlayerData data) {
        float m = usageScore(def, data) * cfg().combat.masteryUsageWeight
                + characterScore(def, data) * cfg().combat.masteryStatWeight;
        return Math.max(0f, Math.min(100f, m));
    }

    public static float calculateCost(JutsuDefinition def, NinjaPlayerData data) {
        float cost = def.baseCost();
        float m = mastery(def, data) / 100f;
        float controlRed = data.getStatLevel(StatType.CONTROL) / 100f * cfg().combat.costControlReductionMax;
        float natureRed = 0f;
        if (def.hasNature()) {
            natureRed = data.getNatureLevel(def.nature()) / 100f * cfg().combat.costNatureReductionMax;
            if (data.getAffinity() == def.nature()) cost *= cfg().combat.affinityCostMultiplier;
        }
        float masteryRed = m * cfg().combat.costMasteryReductionMax;
        float totalRed = Math.min(0.8f, controlRed + natureRed + masteryRed);
        cost *= (1f - totalRed);

        ClanDefinition clan = ClanRegistry.get(data.getClanId());
        if (clan != null && def.hasNature()) {
            Float mult = clan.costMultiplier().get(def.nature().getId());
            if (mult != null) cost *= mult;
        }

        float soft = cfg().fatigue.softThreshold;
        if (data.getFatigue() > soft) {
            float over = (data.getFatigue() - soft) / (100f - soft);
            cost *= 1f + over * cfg().fatigue.costPenaltyMax;
        }
        return Math.max(1f, cost);
    }

    public static float damageMultiplier(NinjaPlayerData data, JutsuDefinition def) {
        float m = mastery(def, data) / 100f;
        float mult = cfg().combat.damageBaseMultiplier + m * cfg().combat.damageMasteryScale;
        if (def.hasNature() && data.getAffinity() == def.nature()) mult *= cfg().combat.affinityDamageMultiplier;
        return mult;
    }

    public static boolean checkRequirements(JutsuDefinition def, NinjaPlayerData data) {
        for (Map.Entry<String, Integer> req : def.requirements().entrySet()) {
            String key = req.getKey();
            int required = req.getValue();
            if (key.equals("control")) {
                if (data.getStatLevel(StatType.CONTROL) < required) return false;
            } else if (key.equals("ninjutsu")) {
                if (data.getStatLevel(StatType.NINJUTSU) < required) return false;
            } else if (key.startsWith("nature_")) {
                String natureId = key.substring(7);
                for (ElementType e : ElementType.values()) {
                    if (e.getId().equals(natureId)) {
                        if (data.getNatureLevel(e) < required) return false;
                        break;
                    }
                }
            }
        }
        return true;
    }

    public static float meditationRegenMultiplier() { return cfg().meditation.regenMultiplier; }
    public static float meditationFatigueDecayMultiplier() { return cfg().meditation.fatigueDecayMultiplier; }
    public static int meditationReserveXpPerSecond() { return cfg().meditation.reserveXpPerSecond; }
    public static int meditationControlXpPerSecond() { return cfg().meditation.controlXpPerSecond; }

    public static int xpToNextLevel(int level) {
        return cfg().progression.xpBase + level * cfg().progression.xpPerLevel + level * level * cfg().progression.xpSquared;
    }

    public static int spCostForLevel(int level) {
        return cfg().progression.spBaseCost + (level / 10) * cfg().progression.spExtraCostEvery10;
    }

    public static int maxHealth(int hpLevel) { return 20 + hpLevel * 20; }

    public static float speedMultiplier(int speedLevel, boolean chakraMode) {
        float base = 1.0f + speedLevel * 0.125f;
        if (chakraMode) base *= 2.0f;
        return Math.min(base, chakraMode ? 4.0f : 2.0f);
    }

    public static float jumpMultiplier(int jumpLevel, boolean chakraMode) {
        float base = 1.0f + jumpLevel * 0.125f;
        if (chakraMode) base *= 2.0f;
        return Math.min(base, chakraMode ? 4.0f : 2.0f);
    }

    public static float jumpHorizontalMultiplier(int jumpLevel, boolean chakraMode) {
        if (!chakraMode) return 1.0f + jumpLevel * 0.125f;
        return 2.0f + jumpLevel * 0.5f;
    }

    public static float jumpVerticalMultiplier(int jumpLevel, boolean chakraMode) {
        if (!chakraMode) return 1.0f;
        return 1.5f + jumpLevel * 0.15f;
    }

    public static int bodySpCost() { return cfg().progression.spBaseCost * 2; }

    public static float chakraModeDrainPerSecond(NinjaPlayerData data) {
        float controlReduction = data.getStatLevel(StatType.CONTROL) / 100f * 0.9f;
        return 2.0f * (1.0f - controlReduction);
    }

    public static float chakraModeRegenMultiplier() { return 0.2f; }

    public static boolean addStatXp(NinjaPlayerData data, StatType stat, int amount) {
        int startLevel = data.getStatLevel(stat);
        int currentXp = data.getStatXp(stat) + amount;
        int level = startLevel;
        boolean leveled = false;
        while (level < NinjaPlayerData.MAX_LEVEL && currentXp >= xpToNextLevel(level)) {
            currentXp -= xpToNextLevel(level);
            level++;
            leveled = true;
        }
        data.setStatLevel(stat, level);
        data.setStatXp(stat, currentXp);
        if (leveled) data.addSkillPoints((level - startLevel) * cfg().progression.spPerLevelUp);
        return leveled;
    }

    public static boolean addReserveXp(NinjaPlayerData data, int amount) {
        int startLevel = data.getReserveLevel();
        int currentXp = data.getReserveXp() + amount;
        int level = startLevel;
        boolean leveled = false;
        while (level < NinjaPlayerData.MAX_LEVEL && currentXp >= xpToNextLevel(level)) {
            currentXp -= xpToNextLevel(level);
            level++;
            leveled = true;
        }
        data.setReserveLevel(level);
        data.setReserveXp(currentXp);
        if (leveled) data.addSkillPoints((level - startLevel) * cfg().progression.spPerLevelUp);
        return leveled;
    }

    public static boolean addNatureXp(NinjaPlayerData data, ElementType element, int amount) {
        int startLevel = data.getNatureLevel(element);
        int currentXp = data.getNatureXp(element) + amount;
        int level = startLevel;
        boolean leveled = false;
        while (level < NinjaPlayerData.MAX_LEVEL && currentXp >= xpToNextLevel(level)) {
            currentXp -= xpToNextLevel(level);
            level++;
            leveled = true;
        }
        data.setNatureLevel(element, level);
        data.setNatureXp(element, currentXp);
        if (leveled) data.addSkillPoints((level - startLevel) * cfg().progression.spPerLevelUp);
        return leveled;
    }

    public static boolean grantStatXp(NinjaPlayerData data, StatType stat, int amount) {
        if (!data.tryConsumeXpBudget("stat_" + stat.getId(), amount, cfg().progression.maxXpPerMinute)) return false;
        return addStatXp(data, stat, amount);
    }

    public static boolean grantNatureXp(NinjaPlayerData data, ElementType element, int amount) {
        if (!data.tryConsumeXpBudget("nature_" + element.getId(), amount, cfg().progression.maxXpPerMinute)) return false;
        return addNatureXp(data, element, amount);
    }

    public static boolean grantReserveXp(NinjaPlayerData data, int amount) {
        if (!data.tryConsumeXpBudget("reserve", amount, cfg().progression.maxXpPerMinute)) return false;
        return addReserveXp(data, amount);
    }

    public static boolean grantUsage(NinjaPlayerData data, String jutsuId, int amount) {
        if (!data.tryConsumeXpBudget("usage_" + jutsuId, amount, cfg().progression.maxUsagePerMinute)) return false;
        data.addJutsuUsage(jutsuId, amount);
        return true;
    }

    private static float getClanReserveBonus(String clanId) {
        if (clanId == null || clanId.equals("none")) return 0f;
        ClanDefinition clan = ClanRegistry.get(clanId);
        if (clan == null) return 0f;
        return clan.reserveBonus();
    }
}
'@

# ================================================================
# 6. ChakraHudRenderer.java - Fix stamina bar patch
# ================================================================
Write-Host "[6/8] ChakraHudRenderer.java (stamina bar)..." -ForegroundColor White
Patch-File "$java\client\ChakraHudRenderer.java" `
"bars.add(new BarSpec(chakraRatio, CHAKRA_LIGHT, CHAKRA_DARK, chakraRatio < 0.25f && !exhausted,`n                ""CH"", (int) currentChakra + ""/"" + (int) maxChakra));" `
"bars.add(new BarSpec(chakraRatio, CHAKRA_LIGHT, CHAKRA_DARK, chakraRatio < 0.25f && !exhausted,`n                ""CH"", (int) currentChakra + ""/"" + (int) maxChakra));`n        float stamRatio = maxStamina > 0 ? currentStamina / maxStamina : 0;`n        bars.add(new BarSpec(stamRatio, 0xFF44EE44, 0xFF22AA22, stamRatio < 0.25f,`n                ""ST"", (int) currentStamina + ""/"" + (int) maxStamina));"

# ================================================================
# 7. Update other clan JSONs with chakraCap
# ================================================================
Write-Host "[7/8] Updating other clan JSONs..." -ForegroundColor White

Write-File "$res\clans\uchiha.json" @'
{
  "id": "uchiha",
  "name": "Uchiha Clan",
  "affinity": "fire",
  "extraAffinityCount": 0,
  "statBonuses": { "genjutsu": 5, "perception": 5 },
  "natureBonuses": { "fire": 10 },
  "costMultiplier": { "fire": 0.90 },
  "fatigueMultiplier": 1.0,
  "reserveBonus": 0,
  "dojutsuHook": "sharingan",
  "chakraCap": 2500
}
'@

Write-File "$res\clans\hyuga.json" @'
{
  "id": "hyuga",
  "name": "Hyuga Clan",
  "affinity": "earth",
  "extraAffinityCount": 0,
  "statBonuses": { "taijutsu": 5, "perception": 5 },
  "natureBonuses": { "earth": 5 },
  "costMultiplier": {},
  "fatigueMultiplier": 0.95,
  "reserveBonus": 50,
  "dojutsuHook": "byakugan",
  "chakraCap": 2500
}
'@

Write-File "$res\clans\sarutobi.json" @'
{
  "id": "sarutobi",
  "name": "Sarutobi Clan",
  "affinity": "fire",
  "extraAffinityCount": 1,
  "statBonuses": { "ninjutsu": 5, "control": 3, "perception": 3 },
  "natureBonuses": { "fire": 8, "wind": 5 },
  "costMultiplier": { "fire": 0.95 },
  "fatigueMultiplier": 1.0,
  "reserveBonus": 50,
  "dojutsuHook": null,
  "chakraCap": 2500
}
'@

Write-File "$res\clans\hatake.json" @'
{
  "id": "hatake",
  "name": "Hatake Clan",
  "affinity": "lightning",
  "extraAffinityCount": 1,
  "statBonuses": { "ninjutsu": 5, "taijutsu": 3, "control": 3 },
  "natureBonuses": { "lightning": 8 },
  "costMultiplier": { "lightning": 0.92 },
  "fatigueMultiplier": 1.0,
  "reserveBonus": 30,
  "dojutsuHook": null,
  "chakraCap": 2500
}
'@

Write-File "$res\clans\nara.json" @'
{
  "id": "nara",
  "name": "Nara Clan",
  "affinity": "earth",
  "extraAffinityCount": 0,
  "statBonuses": { "control": 8, "perception": 5 },
  "natureBonuses": { "earth": 5 },
  "costMultiplier": {},
  "fatigueMultiplier": 1.1,
  "reserveBonus": 0,
  "dojutsuHook": null,
  "chakraCap": 2000
}
'@

# ================================================================
# 8. Verify ModConfig baseChakra
# ================================================================
Write-Host "[8/8] Verifying ModConfig baseChakra..." -ForegroundColor White
$mcContent = [System.IO.File]::ReadAllText("$java\config\ModConfig.java", $utf8)
if ($mcContent.Contains("public float baseChakra = 2000f;")) {
    Write-Host "[OK] baseChakra already set to 2000f" -ForegroundColor Green
    $ok++
} elseif ($mcContent.Contains("public float baseChakra = 100f;")) {
    $mcContent = $mcContent.Replace("public float baseChakra = 100f;", "public float baseChakra = 2000f;")
    [System.IO.File]::WriteAllText("$java\config\ModConfig.java", $mcContent, $utf8)
    Write-Host "[OK] baseChakra updated to 2000f" -ForegroundColor Green
    $ok++
} else {
    Write-Host "[WARN] Could not verify baseChakra value" -ForegroundColor Yellow
}

# ================================================================
# SUMMARY
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  FIX COMPLETE: OK=$ok ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""

if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected!" -ForegroundColor Red
    exit 1
}

Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
exit 0