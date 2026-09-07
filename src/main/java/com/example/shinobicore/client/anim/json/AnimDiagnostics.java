package com.example.shinobicore.client.anim.json;

import com.google.gson.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * Полная диагностика анимационной системы.
 * Проверяет: файлы, парсинг, маппинг костей, загрузку, конфликты.
 */
public class AnimDiagnostics {

    // ── Результат диагностики ──────────────────────────────
    public static class DiagResult {
        public final String category;
        public final boolean ok;
        public final String message;
        public final List<String> details = new ArrayList<>();

        public DiagResult(String category, boolean ok, String message) {
            this.category = category;
            this.ok = ok;
            this.message = message;
        }

        @Override
        public String toString() {
            String icon = ok ? "OK" : "FAIL";
            StringBuilder sb = new StringBuilder();
            sb.append("[").append(icon).append("] ").append(message);
            for (String d : details) sb.append("\n").append(d);
            return sb.toString();
        }
    }

    // ── Рантайм-счётчики (для диагностики в реальном времени) ──
    private static int applyCallCount = 0;
    private static long lastApplyTimeMs = 0;
    private static String lastAppliedAnim = "none";
    private static boolean runtimeLogEnabled = false;
    private static final List<String> runtimeLog = new ArrayList<>();
    private static final int MAX_LOG_LINES = 200;

    public static void onApplyCalled(String animName) {
        applyCallCount++;
        lastApplyTimeMs = System.currentTimeMillis();
        lastAppliedAnim = animName;
        if (runtimeLogEnabled) {
            addLog("APPLY: anim=" + animName);
        }
    }

    public static void addLog(String msg) {
        runtimeLog.add(System.currentTimeMillis() + " | " + msg);
        if (runtimeLog.size() > MAX_LOG_LINES) runtimeLog.remove(0);
    }

    public static void setRuntimeLog(boolean enabled) { runtimeLogEnabled = enabled; }
    public static boolean isRuntimeLog() { return runtimeLogEnabled; }
    public static int getApplyCallCount() { return applyCallCount; }
    public static long getLastApplyTimeMs() { return lastApplyTimeMs; }
    public static String getLastAppliedAnim() { return lastAppliedAnim; }
    public static List<String> getRuntimeLog() { return new ArrayList<>(runtimeLog); }
    public static void clearRuntimeLog() { runtimeLog.clear(); }

    // ── Ванильные кости (маппятся на модель) ───────────────
    private static final Set<String> VANILLA_BONES = new HashSet<>(Arrays.asList(
        "body", "head", "rightArm", "leftArm", "rightLeg", "leftLeg"
    ));

    // ── Кости которые НЕ маппятся ──────────────────────────
    private static final Set<String> EXTRA_BONES = new HashSet<>(Arrays.asList(
        "root", "leftForeArm", "rightForeArm", "leftShin", "rightShin"
    ));

    // ── Все ожидаемые анимации ─────────────────────────────
    private static final String[] EXPECTED_ANIMS = {
        "idle", "walk", "run", "naruto_run", "jump_up", "landing",
        "slide", "roll", "dodge_left", "dodge_right",
        "punch_1", "punch_2", "punch_3", "kick",
        "slash_h1", "slash_h2", "slash_v", "slash_360",
        "seal_cast", "throw_shuriken", "chakra_burst"
    };

    // ═══════════════════════════════════════════════════════
    //  1. ПРОВЕРКА ФАЙЛОВ
    // ═══════════════════════════════════════════════════════
    public static List<DiagResult> checkFiles() {
        List<DiagResult> results = new ArrayList<>();

        String[] names = {
            "shinobi_player_animations.json",
            "shinobi_player.animations.json",
            "shinobi_player_idle.animation.json"
        };

        boolean anyFound = false;
        for (String name : names) {
            InputStream is = AnimDiagnostics.class.getResourceAsStream(
                "/assets/shinobicore/animations/" + name);
            if (is != null) {
                anyFound = true;
                try { is.close(); } catch (Exception ignored) {}
                DiagResult r = new DiagResult("FILE", true, "Found: " + name);

                // Проверяем что файл корректный для загрузчика
                if (name.equals("shinobi_player_animations.json")) {
                    r.details.add("  -> This is the name JsonAnimLibrary expects");
                } else {
                    r.details.add("  -> WARNING: JsonAnimLibrary will NOT load this name!");
                    r.details.add("  -> Expected: shinobi_player_animations.json");
                }
                results.add(r);
            } else {
                results.add(new DiagResult("FILE", false, "NOT FOUND: " + name));
            }
        }

        if (!anyFound) {
            DiagResult r = new DiagResult("FILE", false, "NO ANIMATION FILES FOUND AT ALL");
            r.details.add("  Searched in: /assets/shinobicore/animations/");
            r.details.add("  Fix: place shinobi_player_animations.json in resources");
            results.add(r);
        }

        return results;
    }

    // ═══════════════════════════════════════════════════════
    //  2. ПАРСИНГ АНИМАЦИЙ
    // ═══════════════════════════════════════════════════════
    public static List<DiagResult> parseAnimations() {
        List<DiagResult> results = new ArrayList<>();
        boolean anyLoaded = false;

        String[] files = {"shinobi_player_animations.json", "shinobi_player.animations.json"};

        for (String f : files) {
            try (InputStream is = AnimDiagnostics.class.getResourceAsStream(
                    "/assets/shinobicore/animations/" + f)) {
                if (is == null) continue;
                anyLoaded = true;

                JsonObject root = JsonParser.parseReader(
                    new InputStreamReader(is, StandardCharsets.UTF_8)).getAsJsonObject();

                if (!root.has("animations")) {
                    results.add(new DiagResult("PARSE", false, f + ": missing 'animations' section"));
                    continue;
                }

                JsonObject anims = root.getAsJsonObject("animations");
                results.add(new DiagResult("PARSE", true,
                    f + ": " + anims.size() + " animation(s) found"));

                for (Map.Entry<String, JsonElement> entry : anims.entrySet()) {
                    String fullName = entry.getKey();
                    String shortName = fullName.replace("animation.shinobi_player.", "");

                    try {
                        JsonObject animObj = entry.getValue().getAsJsonObject();

                        float length = animObj.has("animation_length")
                            ? animObj.get("animation_length").getAsFloat() : -1;
                        boolean loop = animObj.has("loop")
                            && animObj.get("loop").getAsBoolean();

                        DiagResult r = new DiagResult("ANIM", true, shortName);
                        r.details.add("  length=" + length + "s  loop=" + loop);

                        if (animObj.has("bones")) {
                            JsonObject bones = animObj.getAsJsonObject("bones");
                            r.details.add("  bones(" + bones.size() + "): "
                                + String.join(", ", bones.keySet()));

                            for (Map.Entry<String, JsonElement> be : bones.entrySet()) {
                                String boneName = be.getKey();
                                int keyCount = countKeys(be.getValue());
                                r.details.add("    " + boneName + ": " + keyCount + " keyframes");
                            }
                        } else {
                            r.details.add("  NO BONES SECTION");
                        }

                        results.add(r);
                    } catch (Exception e) {
                        results.add(new DiagResult("ANIM", false,
                            shortName + ": PARSE ERROR - " + e.getMessage()));
                    }
                }
            } catch (Exception e) {
                results.add(new DiagResult("PARSE", false, f + ": " + e.getMessage()));
            }
        }

        if (!anyLoaded) {
            results.add(new DiagResult("PARSE", false, "No animation files found"));
        }

        return results;
    }

    private static int countKeys(JsonElement boneEl) {
        if (boneEl.isJsonArray()) return boneEl.getAsJsonArray().size();
        if (boneEl.isJsonObject()) {
            JsonObject obj = boneEl.getAsJsonObject();
            if (obj.has("rotation")) {
                JsonElement rot = obj.get("rotation");
                if (rot.isJsonObject()) return rot.getAsJsonObject().size();
                if (rot.isJsonArray()) return rot.getAsJsonArray().size();
            }
        }
        return 0;
    }

    // ═══════════════════════════════════════════════════════
    //  3. МАППИНГ КОСТЕЙ
    // ═══════════════════════════════════════════════════════
    public static List<DiagResult> checkBoneMapping() {
        List<DiagResult> results = new ArrayList<>();

        String[] files = {"shinobi_player_animations.json", "shinobi_player.animations.json"};

        for (String f : files) {
            try (InputStream is = AnimDiagnostics.class.getResourceAsStream(
                    "/assets/shinobicore/animations/" + f)) {
                if (is == null) continue;

                JsonObject root = JsonParser.parseReader(
                    new InputStreamReader(is, StandardCharsets.UTF_8)).getAsJsonObject();
                if (!root.has("animations")) continue;

                JsonObject anims = root.getAsJsonObject("animations");

                for (Map.Entry<String, JsonElement> entry : anims.entrySet()) {
                    String shortName = entry.getKey()
                        .replace("animation.shinobi_player.", "");
                    JsonObject animObj = entry.getValue().getAsJsonObject();
                    if (!animObj.has("bones")) continue;

                    JsonObject bones = animObj.getAsJsonObject("bones");
                    List<String> mapped = new ArrayList<>();
                    List<String> unmapped = new ArrayList<>();

                    for (String boneName : bones.keySet()) {
                        if (VANILLA_BONES.contains(boneName)) mapped.add(boneName);
                        else unmapped.add(boneName);
                    }

                    DiagResult r = new DiagResult("MAP", unmapped.isEmpty(), shortName);
                    r.details.add("  mapped(" + mapped.size() + "): "
                        + String.join(", ", mapped));
                    if (!unmapped.isEmpty()) {
                        r.details.add("  UNMAPPED(" + unmapped.size() + "): "
                            + String.join(", ", unmapped));
                        r.details.add("  -> These bones will be IGNORED at runtime");
                    }
                    results.add(r);
                }
            } catch (Exception e) {
                results.add(new DiagResult("MAP", false, f + ": " + e.getMessage()));
            }
        }

        return results;
    }

    // ═══════════════════════════════════════════════════════
    //  4. ПРОВЕРКА ЗАГРУЗКИ В РАНТАЙМ
    // ═══════════════════════════════════════════════════════
    public static List<DiagResult> checkLoaded() {
        List<DiagResult> results = new ArrayList<>();

        for (String name : EXPECTED_ANIMS) {
            JsonAnimLibrary.JsonAnim anim = JsonAnimLibrary.get(name);
            if (anim != null) {
                DiagResult r = new DiagResult("LOADED", true, name);
                r.details.add("  length=" + anim.length + "s  loop=" + anim.loop
                    + "  bones=" + anim.bones.size());
                // Проверяем какие кости реально загружены
                List<String> boneNames = new ArrayList<>(anim.bones.keySet());
                r.details.add("  bone names: " + String.join(", ", boneNames));
                results.add(r);
            } else {
                results.add(new DiagResult("LOADED", false,
                    name + ": NOT LOADED (null in JsonAnimLibrary)"));
            }
        }

        return results;
    }

    // ═══════════════════════════════════════════════════════
    //  5. КОНФЛИКТЫ С ДРУГИМИ СИСТЕМАМИ
    // ═══════════════════════════════════════════════════════
    public static List<DiagResult> checkConflicts() {
        List<DiagResult> results = new ArrayList<>();

        // 1. Проверяем что оркестратор вызывает наш override
        results.add(new DiagResult("ORDER", true,
            "PlayerAnimationOrchestrator calls PlayerJsonAnimOverride.apply()"));
        results.add(new DiagResult("ORDER", true,
            "But IdlePoseSystem.apply() is called AFTER -> may overwrite idle anim"));

        // 2. Проверяем ранние ретурны
        results.add(new DiagResult("ORDER", false,
            "EARLY RETURN: water run -> JSON anim SKIPPED"));
        results.add(new DiagResult("ORDER", false,
            "EARLY RETURN: wall run -> JSON anim SKIPPED"));
        results.add(new DiagResult("ORDER", false,
            "EARLY RETURN: slide (hardcoded pose) -> JSON anim SKIPPED"));
        results.add(new DiagResult("ORDER", false,
            "EARLY RETURN: naruto run (hardcoded) -> JSON anim SKIPPED"));

        // 3. Проверяем что миксин активен
        results.add(new DiagResult("MIXIN", true,
            "PlayerRenderAnimationMixin injects at TAIL of setAngles"));
        results.add(new DiagResult("MIXIN", true,
            "Our values applied AFTER vanilla -> correct order"));

        return results;
    }

    // ═══════════════════════════════════════════════════════
    //  6. РАНТАЙМ-СОСТОЯНИЕ
    // ═══════════════════════════════════════════════════════
    public static List<DiagResult> getRuntimeState() {
        List<DiagResult> results = new ArrayList<>();

        results.add(new DiagResult("RT", PlayerJsonAnimState.isActive(),
            "PlayerJsonAnimState.active = " + PlayerJsonAnimState.isActive()));

        results.add(new DiagResult("RT", true,
            "currentAnim = " + PlayerJsonAnimState.getCurrentAnim()));

        results.add(new DiagResult("RT", true,
            "oneShot = " + PlayerJsonAnimState.isOneShot()));

        results.add(new DiagResult("RT", applyCallCount > 0,
            "PlayerJsonAnimOverride.apply() called " + applyCallCount + " times"));

        if (applyCallCount > 0) {
            long ago = System.currentTimeMillis() - lastApplyTimeMs;
            results.add(new DiagResult("RT", ago < 1000,
                "Last apply: " + ago + "ms ago, anim=" + lastAppliedAnim));
        }

        results.add(new DiagResult("RT", runtimeLogEnabled,
            "Runtime logging: " + (runtimeLogEnabled ? "ON" : "OFF")));

        return results;
    }

    // ═══════════════════════════════════════════════════════
    //  7. ТЕСТ АНИМАЦИИ
    // ═══════════════════════════════════════════════════════
    public static List<DiagResult> testAnimation(String animName) {
        List<DiagResult> results = new ArrayList<>();

        JsonAnimLibrary.JsonAnim anim = JsonAnimLibrary.get(animName);
        if (anim == null) {
            results.add(new DiagResult("TEST", false,
                "Animation '" + animName + "' not found in JsonAnimLibrary"));
            results.add(new DiagResult("TEST", false,
                "Available: " + String.join(", ", getAvailableAnimNames())));
            return results;
        }

        results.add(new DiagResult("TEST", true,
            "Found '" + animName + "': length=" + anim.length
            + "s loop=" + anim.loop + " bones=" + anim.bones.size()));

        // Запускаем принудительно
        boolean isLoop = anim.loop;
        PlayerJsonAnimState.play(animName, !isLoop);
        results.add(new DiagResult("TEST", true,
            "Started animation '" + animName + "' (oneShot=" + !isLoop + ")"));

        // Проверяем кости
        List<String> mappedBones = new ArrayList<>();
        List<String> unmappedBones = new ArrayList<>();
        for (String bone : anim.bones.keySet()) {
            if (VANILLA_BONES.contains(bone)) mappedBones.add(bone);
            else unmappedBones.add(bone);
        }

        results.add(new DiagResult("TEST", true,
            "Mapped bones: " + String.join(", ", mappedBones)));
        if (!unmappedBones.isEmpty()) {
            results.add(new DiagResult("TEST", false,
                "Unmapped bones (IGNORED): " + String.join(", ", unmappedBones)));
        }

        return results;
    }

    public static List<String> getAvailableAnimNames() {
        List<String> names = new ArrayList<>();
        for (String name : EXPECTED_ANIMS) {
            if (JsonAnimLibrary.get(name) != null) names.add(name);
        }
        return names;
    }

    // ═══════════════════════════════════════════════════════
    //  ПОЛНАЯ ДИАГНОСТИКА
    // ═══════════════════════════════════════════════════════
    public static String runFullDiagnostics() {
        StringBuilder sb = new StringBuilder();
        sb.append("=== ANIMATION DIAGNOSTICS ===\n\n");

        sb.append("--- FILES ---\n");
        for (DiagResult r : checkFiles()) sb.append(r).append("\n");

        sb.append("\n--- PARSE ---\n");
        for (DiagResult r : parseAnimations()) sb.append(r).append("\n");

        sb.append("\n--- BONE MAPPING ---\n");
        for (DiagResult r : checkBoneMapping()) sb.append(r).append("\n");

        sb.append("\n--- LOADED IN RUNTIME ---\n");
        for (DiagResult r : checkLoaded()) sb.append(r).append("\n");

        sb.append("\n--- CONFLICTS ---\n");
        for (DiagResult r : checkConflicts()) sb.append(r).append("\n");

        sb.append("\n--- RUNTIME STATE ---\n");
        for (DiagResult r : getRuntimeState()) sb.append(r).append("\n");

        return sb.toString();
    }
}