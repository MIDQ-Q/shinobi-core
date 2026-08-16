# ============================================================
#  SPRINT 0 / S0-03: JSON LOADERS & SCHEMA UPDATE
#  Updates Jutsu schema to S0-03 spec, adds robust validation
#  Run: powershell -ExecutionPolicy Bypass -File .\sprint0_s03_json_loaders.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$data = "$root\src\main\resources\data\shinobicore\jutsu"
$ok = 0; $err = 0

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] Created/Updated: $($p.Replace($root, ''))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 0 / S0-03: JSON LOADERS & SCHEMA UPDATE" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. JutsuDefinition.java (S0-03 Schema + Legacy Aliases)
# ================================================================
Write-Host "[1/3] Updating JutsuDefinition.java..." -ForegroundColor White
$contentDef = @'
package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.ElementType;
import com.google.gson.JsonObject;
import java.util.Map;
import java.util.List;

/**
 * S0-03: Technique definition.
 * Contains new S0-03 fields (tier, stamina, cast_time, etc.)
 * Legacy fields are kept for backwards compatibility with existing code.
 */
public record JutsuDefinition(
    // === S0-03 NEW FIELDS ===
    String id,
    String name,
    int tier,
    ElementType element,
    float chakraCost,
    float staminaCost,
    float castTime,
    boolean chargeable,
    float chargeMax,
    Map<String, Integer> requires,
    List<String> tags,
    String visual,
    String sfx,
    boolean requiresTeacher,
    String requiresScroll,
    
    // === LEGACY FIELDS (kept for compilation) ===
    String category,
    String type,
    String behaviorClass,
    JsonObject params,
    float baseDamage,
    float strain,
    int requiredUsesForFullProficiency,
    String requiresDojutsu
) {
    // Aliases for legacy code
    public boolean hasNature() { return element != null; }
    public ElementType nature() { return element; }
    public float baseCost() { return chakraCost; }
    public Map<String, Integer> requirements() { return requires; }
}
'@
Write-File "$java\jutsu\JutsuDefinition.java" $contentDef

# ================================================================
# 2. JutsuRegistry.java (Robust parsing & validation)
# ================================================================
Write-Host "[2/3] Updating JutsuRegistry.java..." -ForegroundColor White
$contentReg = @'
package com.example.shinobicore.jutsu;

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
import java.util.*;

public class JutsuRegistry {
    private static final Map<String, JutsuDefinition> JUTSUS = new LinkedHashMap<>();
    private static int invalidCount = 0;

    public static void reload(ResourceManager manager) {
        JUTSUS.clear();
        invalidCount = 0;
        Map<Identifier, List<Resource>> resources = manager.findAllResources("jutsu",
            id -> id.getNamespace().equals(ShinobiCore.MOD_ID) && id.getPath().endsWith(".json"));
        
        for (Map.Entry<Identifier, List<Resource>> entry : resources.entrySet()) {
            for (Resource resource : entry.getValue()) {
                try (InputStream stream = resource.getInputStream()) {
                    // Skip template files
                    if (entry.getKey().getPath().contains("_template")) continue;

                    JsonObject json = JsonParser.parseReader(
                        new InputStreamReader(stream, StandardCharsets.UTF_8)).getAsJsonObject();
                    
                    JutsuDefinition def = parse(json);
                    if (def == null) {
                        invalidCount++;
                        continue;
                    }
                    
                    if (JUTSUS.containsKey(def.id())) {
                        ShinobiCore.LOGGER.warn("[JutsuRegistry] Duplicate ID: {}", def.id());
                        invalidCount++;
                        continue;
                    }

                    JUTSUS.put(def.id(), def);
                } catch (Exception e) {
                    ShinobiCore.LOGGER.error("[JutsuRegistry] Failed to load jutsu from {}: {}", entry.getKey(), e.getMessage());
                    invalidCount++;
                }
            }
        }
        ShinobiCore.LOGGER.info("[JutsuRegistry] Loaded {} jutsu ({} invalid/skipped)", JUTSUS.size(), invalidCount);
    }

    public static JutsuDefinition get(String id) { return JUTSUS.get(id); }
    public static Collection<JutsuDefinition> getAll() { return JUTSUS.values(); }

    private static JutsuDefinition parse(JsonObject json) {
        if (!json.has("id") || !json.has("name")) {
            ShinobiCore.LOGGER.error("[JutsuRegistry] Missing id or name in JSON");
            return null;
        }

        String id = json.get("id").getAsString();
        String name = json.get("name").getAsString();
        
        // S0-03 Fields (with fallback to legacy names for backwards compatibility)
        int tier = json.has("tier") ? json.get("tier").getAsInt() : 1;
        
        ElementType element = null;
        String elemStr = json.has("element") ? json.get("element").getAsString() : 
                         (json.has("nature") ? json.get("nature").getAsString() : null);
        if (elemStr != null) {
            for (ElementType e : ElementType.values()) {
                if (e.getId().equals(elemStr)) { element = e; break; }
            }
        }
        
        float chakraCost = json.has("chakra_cost") ? json.get("chakra_cost").getAsFloat() : 
                           (json.has("baseCost") ? json.get("baseCost").getAsFloat() : 0f);
        float staminaCost = json.has("stamina_cost") ? json.get("stamina_cost").getAsFloat() : 0f;
        float castTime = json.has("cast_time") ? json.get("cast_time").getAsFloat() : 1.0f;
        boolean chargeable = json.has("chargeable") && json.get("chargeable").getAsBoolean();
        float chargeMax = json.has("charge_max") ? json.get("charge_max").getAsFloat() : 1.0f;
        
        Map<String, Integer> requires = new HashMap<>();
        JsonObject reqObj = json.has("requires") ? json.getAsJsonObject("requires") : 
                            (json.has("requirements") ? json.getAsJsonObject("requirements") : null);
        if (reqObj != null) {
            for (String key : reqObj.keySet()) {
                requires.put(key, reqObj.get(key).getAsInt());
            }
        }
        
        List<String> tags = new ArrayList<>();
        if (json.has("tags") && json.get("tags").isJsonArray()) {
            for (var t : json.getAsJsonArray("tags")) tags.add(t.getAsString());
        }
        
        String visual = json.has("visual") ? json.get("visual").getAsString() : null;
        String sfx = json.has("sfx") ? json.get("sfx").getAsString() : null;
        boolean requiresTeacher = json.has("requires_teacher") && json.get("requires_teacher").getAsBoolean();
        String requiresScroll = json.has("requires_scroll") && !json.get("requires_scroll").isJsonNull() 
                                ? json.get("requires_scroll").getAsString() : null;

        // Legacy fields
        String category = json.has("category") ? json.get("category").getAsString() : "unknown";
        String type = json.has("type") ? json.get("type").getAsString() : "projectile";
        String behaviorClass = json.has("behaviorClass") && !json.get("behaviorClass").isJsonNull() 
                               ? json.get("behaviorClass").getAsString() : null;
        JsonObject params = json.has("params") ? json.getAsJsonObject("params") : new JsonObject();
        float baseDamage = json.has("baseDamage") ? json.get("baseDamage").getAsFloat() : 0f;
        float strain = json.has("strain") ? json.get("strain").getAsFloat() : 0f;
        int reqUses = json.has("requiredUsesForFullProficiency") ? json.get("requiredUsesForFullProficiency").getAsInt() : 50;
        String reqDojutsu = json.has("requiresDojutsu") && !json.get("requiresDojutsu").isJsonNull() 
                             ? json.get("requiresDojutsu").getAsString() : null;

        // === VALIDATION ===
        if (chakraCost < 0 || staminaCost < 0 || baseDamage < 0 || strain < 0) {
            ShinobiCore.LOGGER.error("[JutsuRegistry] Negative cost/damage/strain in {}", id);
            return null;
        }
        if (tier < 1 || tier > 5) {
            ShinobiCore.LOGGER.warn("[JutsuRegistry] Tier {} out of bounds (1-5) for {}", tier, id);
            tier = Math.max(1, Math.min(5, tier));
        }

        return new JutsuDefinition(
            id, name, tier, element, chakraCost, staminaCost, castTime, chargeable, chargeMax,
            requires, tags, visual, sfx, requiresTeacher, requiresScroll,
            category, type, behaviorClass, params, baseDamage, strain, reqUses, reqDojutsu
        );
    }
}
'@
Write-File "$java\jutsu\JutsuRegistry.java" $contentReg

# ================================================================
# 3. Create _template.json for developers
# ================================================================
Write-Host "[3/3] Creating _template.json..." -ForegroundColor White
$template = @'
{
  "id": "shinobicore:template_jutsu",
  "name": "Template Jutsu",
  "tier": 1,
  "element": "fire",
  "chakra_cost": 10.0,
  "stamina_cost": 0.0,
  "cast_time": 0.5,
  "chargeable": false,
  "charge_max": 1.0,
  "requires": {
    "control": 10,
    "nature_fire": 15
  },
  "tags": ["projectile", "fire", "basic"],
  "visual": "fireball",
  "sfx": "shinobicore:fire_cast",
  "requires_teacher": false,
  "requires_scroll": null,
  
  "__comment_legacy": "Fields below are kept for internal behavior logic",
  "category": "elemental_ninjutsu",
  "type": "projectile",
  "behaviorClass": "com.example.shinobicore.jutsu.custom.FireballBehavior",
  "params": { "speed": 1.5, "radius": 1.0 },
  "baseDamage": 5.0,
  "strain": 2.0,
  "requiredUsesForFullProficiency": 50
}
'@
Write-File "$data\_template.json" $template

# ================================================================
# SUMMARY
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  S0-03 COMPLETE: OK=$ok ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Changes:" -ForegroundColor White
Write-Host "    - JutsuDefinition: Added S0-03 fields (tier, stamina, cast_time, etc.)" -ForegroundColor White
Write-Host "    - JutsuRegistry: Added robust try-catch validation (no crashes on bad JSON)" -ForegroundColor White
Write-Host "    - _template.json: Created schema reference for developers" -ForegroundColor White
Write-Host ""

if ($err -gt 0) {
    Write-Host "  [ABORT] Errors detected!" -ForegroundColor Red
    exit 1
}

Write-Host "  Next step: .\gradlew.bat build" -ForegroundColor Yellow
exit 0