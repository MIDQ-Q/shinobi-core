# ============================================================
# MASTER SCRIPT: JSON ANIMATIONS INTEGRATION
# Шаги 1-5 (Шаг 0 пропущен, так как ты уже исправил geo файл)
# ============================================================
$ErrorActionPreference = "Stop"
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore\client\anim\json"
$resBase = Join-Path $root "src\main\resources\assets\shinobicore\animations"

Write-Host "=== Integrating JSON Animations ===" -ForegroundColor Cyan

# 1. Create directories
New-Item -ItemType Directory -Force -Path $srcBase | Out-Null
New-Item -ItemType Directory -Force -Path $resBase | Out-Null

# 2. Copy JSON files to resources
$rootFiles = @("shinobi_player_animations.json", "shinobi_player_idle.animation.json")
foreach ($f in $rootFiles) {
    $srcFile = Join-Path $root $f
    if (Test-Path $srcFile) {
        Copy-Item $srcFile -Destination $resBase -Force
        Write-Host "[OK] Copied $f to resources" -ForegroundColor Green
    } else {
        Write-Host "[WARN] $f not found in root, skipping copy." -ForegroundColor Yellow
    }
}

$utf8 = New-Object System.Text.UTF8Encoding($false)

# 3. Create JsonAnimLibrary.java
$libJava = @'
package com.example.shinobicore.client.anim.json;

import com.google.gson.*;
import net.minecraft.client.model.ModelPart;
import net.minecraft.util.math.MathHelper;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class JsonAnimLibrary {
    private static final Map<String, JsonAnim> ANIMS = new HashMap<>();

    public static class JsonAnim {
        public String name;
        public float length;
        public boolean loop;
        public Map<String, BoneAnim> bones = new HashMap<>();
    }

    public static class BoneAnim {
        public List<Keyframe> rotation = new ArrayList<>();
    }

    public static class Keyframe {
        public float time;
        public float x, y, z;
    }

    public static void loadAll() {
        ANIMS.clear();
        String[] files = {"shinobi_player_animations.json", "shinobi_player_idle.animation.json"};
        for (String f : files) {
            try (InputStream is = JsonAnimLibrary.class.getResourceAsStream("/assets/shinobicore/animations/" + f)) {
                if (is != null) {
                    parseFile(is);
                    System.out.println("[ShinobiAnim] Loaded: " + f);
                } else {
                    System.out.println("[ShinobiAnim] NOT FOUND: " + f);
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    private static void parseFile(InputStream is) {
        JsonObject root = JsonParser.parseReader(new InputStreamReader(is, StandardCharsets.UTF_8)).getAsJsonObject();
        JsonObject anims = root.getAsJsonObject("animations");
        if (anims == null) return;
        for (Map.Entry<String, JsonElement> entry : anims.entrySet()) {
            String animName = entry.getKey().trim().replace("animation.shinobi_player.", "");
            JsonObject animObj = entry.getValue().getAsJsonObject();
            JsonAnim anim = new JsonAnim();
            anim.name = animName;
            anim.length = animObj.has("animation_length") ? animObj.get("animation_length").getAsFloat() : 1.0f;
            anim.loop = animObj.has("loop") && animObj.get("loop").getAsBoolean();
            
            JsonObject bones = animObj.getAsJsonObject("bones");
            if (bones != null) {
                for (Map.Entry<String, JsonElement> boneEntry : bones.entrySet()) {
                    String boneName = boneEntry.getKey().trim();
                    JsonElement boneEl = boneEntry.getValue();
                    BoneAnim boneAnim = new BoneAnim();
                    
                    if (boneEl.isJsonArray()) {
                        for (JsonElement kfEl : boneEl.getAsJsonArray()) {
                            JsonObject kf = kfEl.getAsJsonObject();
                            Keyframe k = new Keyframe();
                            k.time = kf.get("time").getAsFloat();
                            JsonArray val = kf.getAsJsonArray("value");
                            k.x = val.get(0).getAsFloat();
                            k.y = val.get(1).getAsFloat();
                            k.z = val.get(2).getAsFloat();
                            boneAnim.rotation.add(k);
                        }
                    } else if (boneEl.isJsonObject()) {
                        JsonObject boneObj = boneEl.getAsJsonObject();
                        if (boneObj.has("rotation")) {
                            JsonElement rotEl = boneObj.get("rotation");
                            if (rotEl.isJsonObject()) {
                                for (Map.Entry<String, JsonElement> timeEntry : rotEl.getAsJsonObject().entrySet()) {
                                    Keyframe k = new Keyframe();
                                    k.time = Float.parseFloat(timeEntry.getKey().trim());
                                    JsonObject kfObj = timeEntry.getValue().getAsJsonObject();
                                    JsonArray vec = kfObj.getAsJsonArray("vector");
                                    k.x = vec.get(0).getAsFloat();
                                    k.y = vec.get(1).getAsFloat();
                                    k.z = vec.get(2).getAsFloat();
                                    boneAnim.rotation.add(k);
                                }
                            }
                        }
                    }
                    boneAnim.rotation.sort(Comparator.comparingDouble(k -> k.time));
                    anim.bones.put(boneName, boneAnim);
                }
            }
            ANIMS.put(animName, anim);
        }
    }

    public static JsonAnim get(String name) {
        return ANIMS.get(name);
    }

    public static void applyAnim(JsonAnim anim, float timeSec, Map<String, ModelPart> parts) {
        if (anim == null) return;
        float t = timeSec;
        if (anim.loop) {
            t = t % anim.length;
        } else {
            t = MathHelper.clamp(t, 0, anim.length);
        }
        
        for (Map.Entry<String, BoneAnim> entry : anim.bones.entrySet()) {
            ModelPart part = parts.get(entry.getKey());
            if (part == null) continue;
            
            BoneAnim bone = entry.getValue();
            if (bone.rotation.isEmpty()) continue;
            
            Keyframe prev = bone.rotation.get(0);
            Keyframe next = bone.rotation.get(bone.rotation.size() - 1);
            
            for (int i = 0; i < bone.rotation.size() - 1; i++) {
                if (t >= bone.rotation.get(i).time && t <= bone.rotation.get(i+1).time) {
                    prev = bone.rotation.get(i);
                    next = bone.rotation.get(i+1);
                    break;
                }
            }
            
            float dt = next.time - prev.time;
            float progress = (dt > 0) ? (t - prev.time) / dt : 0;
            progress = MathHelper.clamp(progress, 0, 1);
            float s = progress * progress * (3 - 2 * progress); // smoothstep
            
            float rx = prev.x + (next.x - prev.x) * s;
            float ry = prev.y + (next.y - prev.y) * s;
            float rz = prev.z + (next.z - prev.z) * s;
            
            part.pitch = (float) Math.toRadians(rx);
            part.yaw = (float) Math.toRadians(ry);
            part.roll = (float) Math.toRadians(rz);
        }
    }
}
'@
[System.IO.File]::WriteAllText((Join-Path $srcBase "JsonAnimLibrary.java"), $libJava, $utf8)
Write-Host "[OK] Created JsonAnimLibrary.java" -ForegroundColor Green

# 4. Create PlayerJsonAnimState.java
$stateJava = @'
package com.example.shinobicore.client.anim.json;

import net.minecraft.client.model.ModelPart;
import java.util.Map;

public class PlayerJsonAnimState {
    private static String currentAnim = "idle";
    private static boolean oneShot = false;
    private static long startTimeMs = 0;
    private static boolean active = false;

    public static void play(String animName, boolean isOneShot) {
        currentAnim = animName;
        oneShot = isOneShot;
        startTimeMs = System.currentTimeMillis();
        active = true;
    }

    public static void stop() {
        active = false;
        currentAnim = "idle";
        oneShot = false;
        startTimeMs = System.currentTimeMillis();
    }

    public static boolean isActive() {
        return active;
    }

    public static void tickAndApply(Map<String, ModelPart> parts, boolean isMoving, boolean isSprinting, boolean isChakra, boolean isSliding, boolean isRolling) {
        if (!active) {
            if (isSliding) currentAnim = "slide";
            else if (isRolling) currentAnim = "roll";
            else if (isSprinting && isChakra) currentAnim = "naruto_run";
            else if (isSprinting) currentAnim = "run";
            else if (isMoving) currentAnim = "walk";
            else currentAnim = "idle";
            
            if (startTimeMs == 0) startTimeMs = System.currentTimeMillis();
        }

        JsonAnimLibrary.JsonAnim anim = JsonAnimLibrary.get(currentAnim);
        if (anim == null) {
            anim = JsonAnimLibrary.get("idle");
        }
        if (anim == null) return;

        float timeSec = (System.currentTimeMillis() - startTimeMs) / 1000f;
        
        if (oneShot && timeSec >= anim.length) {
            active = false;
            startTimeMs = System.currentTimeMillis();
            return;
        }

        JsonAnimLibrary.applyAnim(anim, timeSec, parts);
    }
}
'@
[System.IO.File]::WriteAllText((Join-Path $srcBase "PlayerJsonAnimState.java"), $stateJava, $utf8)
Write-Host "[OK] Created PlayerJsonAnimState.java" -ForegroundColor Green

# 5. Create PlayerJsonAnimOverride.java
$overrideJava = @'
package com.example.shinobicore.client.anim.json;

import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.ClientNinjaStateHolder;
import com.example.shinobicore.client.ChakraHudRenderer;
import java.util.HashMap;
import java.util.Map;

public class PlayerJsonAnimOverride {
    public static void apply(AbstractClientPlayerEntity player, BipedEntityModel<?> model, float limbAngle, float limbDistance) {
        Map<String, ModelPart> parts = new HashMap<>();
        parts.put("body", model.body);
        parts.put("head", model.head);
        parts.put("rightArm", model.rightArm);
        parts.put("leftArm", model.leftArm);
        parts.put("rightLeg", model.rightLeg);
        parts.put("leftLeg", model.leftLeg);
        
        boolean isMoving = limbDistance > 0.1f;
        boolean isSprinting = player.isSprinting();
        boolean isChakra = ClientNinjaStateHolder.get().isChakraMode() && ChakraHudRenderer.currentChakra > 0;
        boolean isSliding = ParkourManager.isSliding();
        boolean isRolling = ParkourManager.isRolling();
        
        PlayerJsonAnimState.tickAndApply(parts, isMoving, isSprinting, isChakra, isSliding, isRolling);
    }
}
'@
[System.IO.File]::WriteAllText((Join-Path $srcBase "PlayerJsonAnimOverride.java"), $overrideJava, $utf8)
Write-Host "[OK] Created PlayerJsonAnimOverride.java" -ForegroundColor Green

# 6. Patch PlayerAnimationOrchestrator.java
$orchPath = Join-Path $root "src\main\java\com\example\shinobicore\client\anim\PlayerAnimationOrchestrator.java"
if (Test-Path $orchPath) {
    $orchContent = [System.IO.File]::ReadAllText($orchPath, $utf8)
    $target = "// Idle poses`nif (!TaijutsuAnimations.isAttacking(player) && !TaijutsuAnimations.isKicking(player)) {"
    $replacement = "// JSON Animation Override`ncom.example.shinobicore.client.anim.json.PlayerJsonAnimOverride.apply(player, model, limbAngle, limbDistance);`n`n// Idle poses`nif (!TaijutsuAnimations.isAttacking(player) && !TaijutsuAnimations.isKicking(player)) {"
    
    if ($orchContent -notmatch "PlayerJsonAnimOverride\.apply") {
        $orchContent = $orchContent.Replace($target, $replacement)
        [System.IO.File]::WriteAllText($orchPath, $orchContent, $utf8)
        Write-Host "[OK] Patched PlayerAnimationOrchestrator.java" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] PlayerAnimationOrchestrator.java already patched" -ForegroundColor Yellow
    }
}

# 7. Patch ShinobiCoreClient.java
$clientPath = Join-Path $root "src\main\java\com\example\shinobicore\client\ShinobiCoreClient.java"
if (Test-Path $clientPath) {
    $clientContent = [System.IO.File]::ReadAllText($clientPath, $utf8)
    $target = "KeyBindings.register();"
    $replacement = "KeyBindings.register();`ncom.example.shinobicore.client.anim.json.JsonAnimLibrary.loadAll();"
    
    if ($clientContent -notmatch "JsonAnimLibrary\.loadAll") {
        $clientContent = $clientContent.Replace($target, $replacement)
        [System.IO.File]::WriteAllText($clientPath, $clientContent, $utf8)
        Write-Host "[OK] Patched ShinobiCoreClient.java" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] ShinobiCoreClient.java already patched" -ForegroundColor Yellow
    }
}

# 8. Build
Write-Host "`n--- Building ---" -ForegroundColor Yellow
Push-Location $root
try {
    $out = & cmd /c "gradlew.bat build 2>&1" | Out-String
    if ($out -match "BUILD SUCCESSFUL") {
        Write-Host "[PASS] BUILD SUCCESSFUL" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Build errors:" -ForegroundColor Red
        ($out -split "`n") | Where-Object { $_ -match "error:" } | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally { Pop-Location }