# fix_phase1_3.ps1
# Phase 1: Critical bug fixes
# Phase 2: Performance improvements
# Phase 3: Minimal architecture cleanup
# All ASCII markers, UTF-8 no BOM

$ErrorActionPreference = "Stop"
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Write-File($path, $content) {
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host "[OK] $path"
}

# ============================================================
# PART 1 FIX 1: ModPackets.java - remove DUPLICATE ATTUNEMENT_ID
# The second registration (without SP deduction) overwrites the first.
# We remove the second block.
# ============================================================
$mpPath = "$root\network\ModPackets.java"
$mp = [System.IO.File]::ReadAllText($mpPath, $utf8)

# Sentinel: the second attunement block starts with this comment
$sentinel1 = "// === ATTUNEMENT SECOND REGISTRATION FIX ==="
if ($mp.Contains($sentinel1)) {
    Write-Host "[SKIP] ModPackets already fixed"
} else {
    # Find the second ATTUNEMENT_ID registration
    # It starts after PARKOUR_ACTION_ID handler, near the end
    # Pattern: the block that does NOT have "addSkillPoints(-cost)"
    $searchStr = @"
        // === ATTUNEMENT FIX MARKER ===
        ServerPlayNetworking.registerGlobalReceiver(ATTUNEMENT_ID, (server, player, handler, buf, responseSender) -> {
            String elementId = buf.readString();
            boolean success = buf.readBoolean();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                ElementType element = null;
                for (ElementType e : ElementType.values()) {
                    if (e.getId().equals(elementId)) { element = e; break; }
                }
                if (element == null) return;
                if (success) {
                    data.setNatureUnlocked(element, true);
                    if (data.getNatureLevel(element) < 1) {
                        data.setNatureLevel(element, 1);
                    }
                    ShinobiCore.sendStatsSync(player);
                    player.sendMessage(Text.literal("\u00a7aAttuned to " + elementId + "!"), false);
                } else {
                    player.sendMessage(Text.literal("\u00a7cAttunement failed."), false);
                }
            });
        });
"@
    # Replace the second block with nothing
    if ($mp.Contains("ServerPlayNetworking.registerGlobalReceiver(ATTUNEMENT_ID,")) {
        # Count occurrences
        $firstIdx = $mp.IndexOf("ServerPlayNetworking.registerGlobalReceiver(ATTUNEMENT_ID,")
        $secondIdx = $mp.IndexOf("ServerPlayNetworking.registerGlobalReceiver(ATTUNEMENT_ID,", $firstIdx + 10)
        if ($secondIdx -gt 0) {
            # Find the end of the second block (next "ServerPlayNetworking.registerGlobalReceiver" or end of method)
            $blockStart = $secondIdx
            # Go back to find the comment line before it
            $commentStart = $mp.LastIndexOf("// ===", $blockStart)
            if ($commentStart -gt 0 -and ($blockStart - $commentStart) -lt 200) {
                $blockStart = $commentStart
            }
            # Find end: next registerGlobalReceiver or closing of register()
            $nextRegister = $mp.IndexOf("ServerPlayNetworking.registerGlobalReceiver(", $secondIdx + 50)
            $blockEnd = if ($nextRegister -gt 0) { $nextRegister } else { $mp.IndexOf("}", $secondIdx + 500) + 1 }
            
            $mp = $mp.Substring(0, $blockStart) + $mp.Substring($blockEnd)
            Write-Host "[FIX] Removed duplicate ATTUNEMENT_ID registration"
        }
    }
    Write-File $mpPath $mp
}

# ============================================================
# PART 1 FIX 2: ShinobiCore.java - remove duplicate affinity block
# ============================================================
$scPath = "$root\ShinobiCore.java"
$sc = [System.IO.File]::ReadAllText($scPath, $utf8)

$sentinel2 = "// === AFFINITY DEDUP FIX ==="
if ($sc.Contains($sentinel2)) {
    Write-Host "[SKIP] ShinobiCore already fixed"
} else {
    # Find the SECOND occurrence of "if (randomClan.affinity() != null)"
    $firstAff = $sc.IndexOf("if (randomClan.affinity() != null)")
    if ($firstAff -ge 0) {
        $secondAff = $sc.IndexOf("if (randomClan.affinity() != null)", $firstAff + 10)
        if ($secondAff -ge 0) {
            # Find the end of the second block (closing brace + newline)
            $braceCount = 0
            $pos = $sc.IndexOf("{", $secondAff)
            $blockEnd = $pos
            for ($i = $pos; $i -lt $sc.Length; $i++) {
                if ($sc[$i] -eq '{') { $braceCount++ }
                if ($sc[$i] -eq '}') { $braceCount--; if ($braceCount -eq 0) { $blockEnd = $i + 1; break } }
            }
            # Also remove the comment line before it if present
            $lineStart = $sc.LastIndexOf("`n", $secondAff) + 1
            $commentCheck = $sc.Substring($lineStart, $secondAff - $lineStart).Trim()
            if ($commentCheck.StartsWith("//")) { $secondAff = $lineStart }
            
            $sc = $sc.Substring(0, $secondAff) + $sc.Substring($blockEnd)
            $sc = $sc.Replace("data.setAffinity(randomClan.affinity());", 
                "data.setAffinity(randomClan.affinity());`n                $sentinel2")
            Write-Host "[FIX] Removed duplicate affinity unlock block"
        }
    }
    Write-File $scPath $sc
}

# ============================================================
# PART 2 FIX 1: MarkTracker - add cleanup method
# ============================================================
$mtPath = "$root\combat\MarkTracker.java"
$mt = [System.IO.File]::ReadAllText($mtPath, $utf8)

$sentinel3 = "cleanupExpired"
if ($mt.Contains($sentinel3)) {
    Write-Host "[SKIP] MarkTracker already has cleanup"
} else {
    $newMt = @"
package com.example.shinobicore.combat;

import net.minecraft.entity.LivingEntity;
import java.util.Iterator;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public class MarkTracker {
    private static final Map<UUID, Long> MARKS = new ConcurrentHashMap<>();

    public static void mark(LivingEntity e, long ms) {
        MARKS.put(e.getUuid(), System.currentTimeMillis() + ms);
    }

    public static boolean isMarked(LivingEntity e) {
        Long t = MARKS.get(e.getUuid());
        if (t == null) return false;
        if (t <= System.currentTimeMillis()) {
            MARKS.remove(e.getUuid());
            return false;
        }
        return true;
    }

    public static float boost(LivingEntity e, float dmg) {
        return isMarked(e) ? dmg * 1.2f : dmg;
    }

    // cleanupExpired: call every 200 ticks from server tick handler
    public static void cleanupExpired() {
        long now = System.currentTimeMillis();
        MARKS.entrySet().removeIf(entry -> entry.getValue() <= now);
    }
}
"@
    Write-File $mtPath $newMt
    Write-Host "[FIX] MarkTracker: added cleanupExpired()"
}

# ============================================================
# PART 2 FIX 2: Call MarkTracker.cleanupExpired() from NinjaTickHandler
# ============================================================
$ntPath = "$root\event\NinjaTickHandler.java"
$nt = [System.IO.File]::ReadAllText($ntPath, $utf8)

$sentinel4 = "MarkTracker.cleanupExpired()"
if ($nt.Contains($sentinel4)) {
    Write-Host "[SKIP] NinjaTickHandler already calls MarkTracker cleanup"
} else {
    # Insert after "tickCounter = 0;" line
    $anchor = "tickCounter = 0;"
    if ($nt.Contains($anchor)) {
        $nt = $nt.Replace($anchor, "$anchor`n        com.example.shinobicore.combat.MarkTracker.cleanupExpired();")
        Write-File $ntPath $nt
        Write-Host "[FIX] NinjaTickHandler: added MarkTracker.cleanupExpired() call"
    } else {
        Write-Host "[WARN] Could not find anchor in NinjaTickHandler"
    }
}

# ============================================================
# PART 2 FIX 3: IdlePoseSystem - add cleanup + disconnect handling
# ============================================================
$ipPath = "$root\client\IdlePoseSystem.java"
$ip = [System.IO.File]::ReadAllText($ipPath, $utf8)

$sentinel5 = "public static void cleanup(UUID id)"
if ($ip.Contains($sentinel5)) {
    Write-Host "[SKIP] IdlePoseSystem already has cleanup"
} else {
    # Add cleanup method before the last closing brace
    $lastBrace = $ip.LastIndexOf("}")
    $cleanupMethod = @"

    public static void cleanup(UUID id) {
        STATES.remove(id);
    }

    public static void cleanupAll() {
        STATES.clear();
    }
"@
    $ip = $ip.Substring(0, $lastBrace) + $cleanupMethod + "`n}" 
    Write-File $ipPath $ip
    Write-Host "[FIX] IdlePoseSystem: added cleanup methods"
}

# ============================================================
# PART 2 FIX 4: TaijutsuAnimations - add cleanup
# ============================================================
$taPath = "$root\client\combat\TaijutsuAnimations.java"
$ta = [System.IO.File]::ReadAllText($taPath, $utf8)

$sentinel6 = "public static void cleanup(UUID id)"
if ($ta.Contains($sentinel6)) {
    Write-Host "[SKIP] TaijutsuAnimations already has cleanup"
} else {
    $lastBrace = $ta.LastIndexOf("}")
    $cleanupMethod = @"

    public static void cleanup(UUID id) {
        activeAnimations.remove(id);
        activeKicks.remove(id);
    }
"@
    $ta = $ta.Substring(0, $lastBrace) + $cleanupMethod + "`n}"
    Write-File $taPath $ta
    Write-Host "[FIX] TaijutsuAnimations: added cleanup"
}

# ============================================================
# PART 2 FIX 5: KenjutsuAnimations - add cleanup
# ============================================================
$kaPath = "$root\client\combat\KenjutsuAnimations.java"
$ka = [System.IO.File]::ReadAllText($kaPath, $utf8)

$sentinel7 = "public static void cleanup(UUID id)"
if ($ka.Contains($sentinel7)) {
    Write-Host "[SKIP] KenjutsuAnimations already has cleanup"
} else {
    $lastBrace = $ka.LastIndexOf("}")
    $cleanupMethod = @"

    public static void cleanup(UUID id) {
        SLASHES.remove(id);
        DEFLECTS.remove(id);
    }
"@
    $ka = $ka.Substring(0, $lastBrace) + $cleanupMethod + "`n}"
    Write-File $kaPath $ka
    Write-Host "[FIX] KenjutsuAnimations: added cleanup"
}

# ============================================================
# PART 2 FIX 6: JutsuLogger - use BufferedWriter instead of new FileWriter per write
# ============================================================
$jlPath = "$root\jutsu\JutsuLogger.java"
$jl = [System.IO.File]::ReadAllText($jlPath, $utf8)

$sentinel8 = "private static java.io.BufferedWriter bufferedWriter"
if ($jl.Contains($sentinel8)) {
    Write-Host "[SKIP] JutsuLogger already uses BufferedWriter"
} else {
    # Replace the write method to use a shared BufferedWriter
    $oldWrite = @"
    private static void write(String message) {
        String timestamp = LocalDateTime.now().format(FMT);
        String line = timestamp + " " + message;
        // V konsol (debug uroven chtoby ne zasoryat)
        CONSOLE.debug(line);
        // V fail
        try (PrintWriter pw = new PrintWriter(new FileWriter(logPath.toFile(), true))) {
            pw.println(line);
        } catch (IOException ignored) {
            // Tikho ignoriruem oshibki zapisi
        }
    }
"@
    $newWrite = @"
    private static java.io.BufferedWriter bufferedWriter;

    private static void write(String message) {
        String timestamp = LocalDateTime.now().format(FMT);
        String line = timestamp + " " + message;
        CONSOLE.debug(line);
        try {
            if (bufferedWriter == null) {
                bufferedWriter = new java.io.BufferedWriter(
                    new java.io.FileWriter(logPath.toFile(), true));
            }
            bufferedWriter.write(line);
            bufferedWriter.newLine();
            bufferedWriter.flush();
        } catch (IOException ignored) {
        }
    }
"@
    # Try to replace - if exact match fails, do regex-style replacement
    if ($jl.Contains("try (PrintWriter pw = new PrintWriter(new FileWriter(logPath.toFile(), true)))")) {
        $jl = $jl.Replace(
            "try (PrintWriter pw = new PrintWriter(new FileWriter(logPath.toFile(), true))) {`n            pw.println(line);`n        } catch (IOException ignored) {`n            // Tikho ignoriruem oshibki zapisi`n        }",
            "try {`n            if (bufferedWriter == null) {`n                bufferedWriter = new java.io.BufferedWriter(`n                    new java.io.FileWriter(logPath.toFile(), true));`n            }`n            bufferedWriter.write(line);`n            bufferedWriter.newLine();`n            bufferedWriter.flush();`n        } catch (IOException ignored) {`n        }"
        )
        # Add field declaration
        $jl = $jl.Replace("private static boolean enabled = true;",
            "private static boolean enabled = true;`n    private static java.io.BufferedWriter bufferedWriter;")
        Write-File $jlPath $jl
        Write-Host "[FIX] JutsuLogger: switched to BufferedWriter"
    } else {
        Write-Host "[WARN] JutsuLogger pattern not found, skipping"
    }
}

# ============================================================
# PART 2 FIX 7: ChakraHudRenderer - avoid ArrayList allocation per frame
# ============================================================
$hrPath = "$root\client\ChakraHudRenderer.java"
$hr = [System.IO.File]::ReadAllText($hrPath, $utf8)

$sentinel9 = "private static final List<BarSpec> barsCache"
if ($hr.Contains($sentinel9)) {
    Write-Host "[SKIP] ChakraHudRenderer already optimized"
} else {
    # Replace "List<BarSpec> bars = new ArrayList<>();" with reused list
    $hr = $hr.Replace(
        "List<BarSpec> bars = new ArrayList<>();",
        "barsCache.clear();`n        List<BarSpec> bars = barsCache;"
    )
    # Add the static field
    $hr = $hr.Replace(
        "private record BarSpec(",
        "private static final List<BarSpec> barsCache = new ArrayList<>(8);`n    private record BarSpec("
    )
    Write-File $hrPath $hr
    Write-Host "[FIX] ChakraHudRenderer: reuse bars list"
}

# ============================================================
# PART 2 FIX 8: Add disconnect cleanup in ShinobiCoreClient
# ============================================================
$sccPath = "$root\client\ShinobiCoreClient.java"
$scc = [System.IO.File]::ReadAllText($sccPath, $utf8)

$sentinel10 = "ClientPlayConnectionEvents"
if ($scc.Contains($sentinel10)) {
    Write-Host "[SKIP] ShinobiCoreClient already has disconnect handler"
} else {
    # Add import and disconnect handler
    $scc = $scc.Replace(
        "import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;",
        "import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;`nimport net.fabricmc.fabric.api.client.networking.v1.ClientPlayConnectionEvents;"
    )
    # Add disconnect cleanup before HudRenderCallback registration
    $scc = $scc.Replace(
        "HudRenderCallback.EVENT.register(ChakraHudRenderer::render);",
        @"
ClientPlayConnectionEvents.DISCONNECT.register((handler, client) -> {
            IdlePoseSystem.cleanupAll();
            com.example.shinobicore.client.combat.TaijutsuAnimations.cleanup(client.player.getUuid());
            com.example.shinobicore.client.combat.KenjutsuAnimations.cleanup(client.player.getUuid());
            CastingClientState.clear();
        });
        HudRenderCallback.EVENT.register(ChakraHudRenderer::render);
"@
    )
    Write-File $sccPath $scc
    Write-Host "[FIX] ShinobiCoreClient: added disconnect cleanup"
}

# ============================================================
# PART 2 FIX 9: CastingClientState - add clear() method
# ============================================================
$csPath = "$root\client\CastingClientState.java"
$cs = [System.IO.File]::ReadAllText($csPath, $utf8)

$sentinel11 = "public static void clear()"
if ($cs.Contains($sentinel11)) {
    Write-Host "[SKIP] CastingClientState already has clear()"
} else {
    $lastBrace = $cs.LastIndexOf("}")
    $clearMethod = @"

    public static void clear() {
        CASTS.clear();
    }
"@
    $cs = $cs.Substring(0, $lastBrace) + $clearMethod + "`n}"
    Write-File $csPath $cs
    Write-Host "[FIX] CastingClientState: added clear()"
}

Write-Host ""
Write-Host "=== ALL FIXES APPLIED ==="
Write-Host "Run: .\gradlew.bat build"