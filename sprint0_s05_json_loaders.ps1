# ============================================================
#  SPRINT 0 / S0-05: JSON CLAN LOADERS
#  Adds branches, starting_jutsu, visual to clan schema
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
#  Run: powershell -ExecutionPolicy Bypass -File .\sprint0_s05_json_loaders.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$res = "$root\src\main\resources\data\shinobicore\clans"
$ok = 0; $skip = 0; $err = 0

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $($p.Replace($root, ''))" -ForegroundColor Green
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
Write-Host "  SPRINT 0 / S0-05: JSON CLAN LOADERS" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. ClanDefinition.java - add branches, startingJutsu, visual
# ================================================================
Write-Host "[1/5] ClanDefinition.java..." -ForegroundColor White
$contentDef = @'
package com.example.shinobicore.clan;

import com.example.shinobicore.stat.ElementType;
import java.util.List;
import java.util.Map;

/**
* S0-05: Clan definition with full JSON schema.
* New fields: branches, startingJutsu, visual.
*/
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
    float chakraCap,
    String dojutsuHook,
    // S0-05: New fields
    List<String> branches,
    List<String> startingJutsu,
    String visual
) {
    public boolean hasDojutsu() {
        return dojutsuHook != null && !dojutsuHook.isEmpty();
    }
    public boolean hasBranchAccess(String branchId) {
        return branches == null || branches.isEmpty() || branches.contains(branchId);
    }
    public boolean hasStartingJutsu(String jutsuId) {
        return startingJutsu != null && startingJutsu.contains(jutsuId);
    }
}
'@
Write-File "$java\clan\ClanDefinition.java" $contentDef

# ================================================================
# 2. ClanRegistry.java - parse new fields
# ================================================================
Write-Host "[2/5] ClanRegistry.java..." -ForegroundColor White
$contentReg = @'
package com.example.shinobicore.clan;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.ElementType;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

/**
* S0-05: Clan registry with full JSON parsing.
* Reads from data/shinobicore/clans/*.json (datapack-compatible).
*/
public class ClanRegistry {
    private static final Map<String, ClanDefinition> CLANS = new HashMap<>();
    private static final Random RANDOM = new Random();

    public static void reload(ResourceManager manager) {
        CLANS.clear();
        Map<Identifier, List<Resource>> resources = manager.findAllResources("clans",
            id -> id.getNamespace().equals(ShinobiCore.MOD_ID) && id.getPath().endsWith(".json")
        );
        int invalidCount = 0;
        for (Map.Entry<Identifier, List<Resource>> entry : resources.entrySet()) {
            Identifier id = entry.getKey();
            List<Resource> resourceList = entry.getValue();
            if (resourceList.isEmpty()) continue;
            Resource resource = resourceList.get(0);
            try (InputStream stream = resource.getInputStream()) {
                JsonObject json = JsonParser.parseReader(new InputStreamReader(stream)).getAsJsonObject();
                if (!json.has("id")) {
                    String path = id.getPath();
                    String name = path.substring("clans/".length(), path.length() - ".json".length());
                    json.addProperty("id", name);
                }
                ClanDefinition def = parse(json);
                if (def != null) {
                    if (CLANS.containsKey(def.id())) {
                        ShinobiCore.LOGGER.warn("[ClanRegistry] Duplicate clan ID: {}", def.id());
                        invalidCount++;
                        continue;
                    }
                    CLANS.put(def.id(), def);
                    ShinobiCore.LOGGER.info("[ClanRegistry] Loaded clan: {}", def.id());
                } else {
                    invalidCount++;
                }
            } catch (Exception e) {
                ShinobiCore.LOGGER.error("[ClanRegistry] Failed to load clan from {}: {}", id, e.getMessage());
                invalidCount++;
            }
        }
        ShinobiCore.LOGGER.info("[ClanRegistry] Loaded {} clans ({} invalid/skipped)", CLANS.size(), invalidCount);
    }

    private static ClanDefinition parse(JsonObject json) {
        if (!json.has("id")) {
            ShinobiCore.LOGGER.error("[ClanRegistry] Missing id in clan JSON");
            return null;
        }
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
        float chakraCap = json.has("chakra_cap") ? json.get("chakra_cap").getAsFloat() : 0f;

        String dojutsuHook = json.has("dojutsuHook") && !json.get("dojutsuHook").isJsonNull()
                ? json.get("dojutsuHook").getAsString() : null;

        // S0-05: New fields
        List<String> branches = new ArrayList<>();
        if (json.has("branches") && json.get("branches").isJsonArray()) {
            JsonArray arr = json.getAsJsonArray("branches");
            for (int i = 0; i < arr.size(); i++) branches.add(arr.get(i).getAsString());
        }

        List<String> startingJutsu = new ArrayList<>();
        if (json.has("starting_jutsu") && json.get("starting_jutsu").isJsonArray()) {
            JsonArray arr = json.getAsJsonArray("starting_jutsu");
            for (int i = 0; i < arr.size(); i++) startingJutsu.add(arr.get(i).getAsString());
        }

        String visual = json.has("visual") && !json.get("visual").isJsonNull()
                ? json.get("visual").getAsString() : null;

        // Validation
        if (chakraCap < 0) {
            ShinobiCore.LOGGER.error("[ClanRegistry] Negative chakra_cap in clan {}", id);
            return null;
        }

        return new ClanDefinition(id, name, affinity, extraAffinityCount,
                statBonuses, natureBonuses, costMultiplier, fatigueMultiplier,
                reserveBonus, chakraCap, dojutsuHook,
                branches, startingJutsu, visual);
    }

    public static ClanDefinition get(String id) { return CLANS.get(id); }
    public static Collection<ClanDefinition> getAll() { return CLANS.values(); }

    public static ClanDefinition getRandom() {
        if (CLANS.isEmpty()) return null;
        List<ClanDefinition> list = new ArrayList<>(CLANS.values());
        return list.get(RANDOM.nextInt(list.size()));
    }

    public static boolean exists(String id) { return CLANS.containsKey(id); }
}
'@
Write-File "$java\clan\ClanRegistry.java" $contentReg

# ================================================================
# 3. NinjaPlayerData.java - apply starting jutsu on clan assign
# ================================================================
Write-Host "[3/5] Patching NinjaPlayerData.java..." -ForegroundColor White
$oldApply = @"
                appliedClanNatureBonuses.put(key, bonus);
                break;
            }
        }
    }
}
"@
$newApply = @"
                appliedClanNatureBonuses.put(key, bonus);
                break;
            }
        }
    }
    // S0-05: Apply starting jutsu
    if (clan.startingJutsu() != null) {
        for (String jutsuId : clan.startingJutsu()) {
            if (!learnedJutsus.contains(jutsuId)) {
                learnedJutsus.add(jutsuId);
                statsDirty = true;
            }
        }
    }
}
"@
Patch-File "$java\stat\NinjaPlayerData.java" $oldApply $newApply

# ================================================================
# 4. Update clan JSONs with new fields
# ================================================================
Write-Host "[4/5] Updating clan JSONs..." -ForegroundColor White

$uzumaki = @'
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
  "chakra_cap": 6000,
  "dojutsuHook": null,
  "branches": ["uzumaki"],
  "starting_jutsu": ["shinobicore:water_release_water_bullet"],
  "visual": "uzumaki_spiral"
}
'@
Write-File "$res\uzumaki.json" $uzumaki

$uchiha = @'
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
  "chakra_cap": 2500,
  "dojutsuHook": "sharingan",
  "branches": ["uchiha"],
  "starting_jutsu": ["shinobicore:fire_release_flame_bullet"],
  "visual": "uchiha_fan"
}
'@
Write-File "$res\uchiha.json" $uchiha

$hyuga = @'
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
  "chakra_cap": 2500,
  "dojutsuHook": "byakugan",
  "branches": ["hyuga"],
  "starting_jutsu": [],
  "visual": "hyuga_circle"
}
'@
Write-File "$res\hyuga.json" $hyuga

$sarutobi = @'
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
  "chakra_cap": 2500,
  "dojutsuHook": null,
  "branches": ["sarutobi"],
  "starting_jutsu": ["shinobicore:fire_release_flame_bullet"],
  "visual": "sarutobi_monkey"
}
'@
Write-File "$res\sarutobi.json" $sarutobi

$hatake = @'
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
  "chakra_cap": 2500,
  "dojutsuHook": null,
  "branches": ["hatake"],
  "starting_jutsu": ["shinobicore:lightning_release_shock"],
  "visual": "hatake_fang"
}
'@
Write-File "$res\hatake.json" $hatake

$nara = @'
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
  "chakra_cap": 2000,
  "dojutsuHook": null,
  "branches": ["nara"],
  "starting_jutsu": [],
  "visual": "nara_shadow"
}
'@
Write-File "$res\nara.json" $nara

# ================================================================
# 5. Template clan JSON
# ================================================================
Write-Host "[5/5] Creating _template_clan.json..." -ForegroundColor White
$template = @'
{
  "__comment": "S0-05: Template for new clans. Copy to data/shinobicore/clans/<id>.json",
  "id": "my_clan",
  "name": "My Clan",
  "affinity": "fire",
  "extraAffinityCount": 0,
  "statBonuses": { "ninjutsu": 5 },
  "natureBonuses": { "fire": 10 },
  "costMultiplier": { "fire": 0.90 },
  "fatigueMultiplier": 1.0,
  "reserveBonus": 50,
  "chakra_cap": 3000,
  "dojutsuHook": null,
  "branches": ["my_clan_branch"],
  "starting_jutsu": ["shinobicore:fire_release_flame_bullet"],
  "visual": "my_clan_visual"
}
'@
Write-File "$res\_template_clan.json" $template

# ================================================================
# SUMMARY & EXIT CODE
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  S0-05 COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Changes:" -ForegroundColor White
Write-Host "    - ClanDefinition: +branches, +startingJutsu, +visual" -ForegroundColor White
Write-Host "    - ClanRegistry: full JSON parsing with validation" -ForegroundColor White
Write-Host "    - NinjaPlayerData: starting jutsu applied on clan assign" -ForegroundColor White
Write-Host "    - All 6 clan JSONs updated with new fields" -ForegroundColor White
Write-Host "    - _template_clan.json created for datapack authors" -ForegroundColor White
Write-Host ""

if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected!" -ForegroundColor Red
    exit 1
}

Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
Write-Host "  Then: sprint0_s06_network.ps1" -ForegroundColor Yellow
exit 0