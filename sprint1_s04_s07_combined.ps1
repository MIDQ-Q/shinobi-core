# ============================================================
#  SPRINT 1 / S1-04, S1-05, S1-06, S1-07 COMBINED
#  S1-04: Tier table + cooldowns
#  S1-05: Chargeable jutsu
#  S1-06: Tree audit (remove duplicates, fix forbidden)
#  S1-07: S-rank via teacher/scroll
#
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
#  Run: powershell -ExecutionPolicy Bypass -File .\sprint1_s04_s07_combined.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$res = "$root\src\main\resources\data\shinobicore"
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
    if (-not $cNorm.Contains($oldNorm)) { Write-Host "[FAIL] pattern: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; $script:err++; return }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  S1-04/05/06/07: TIERS + CHARGE + TREE AUDIT + S-RANK" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
#  S1-04: TIER TABLE
# ================================================================
Write-Host "=== S1-04: TIER TABLE ===" -ForegroundColor White

# 1. ModConfig: add TierConfig
Write-Host "[1/15] ModConfig.java (TierConfig)..." -ForegroundColor White
Patch-File "$java\config\ModConfig.java" `
    "public Stamina stamina = new Stamina();" `
    "public Stamina stamina = new Stamina();`n    public TierConfig tiers = new TierConfig();"

Patch-File "$java\config\ModConfig.java" `
    "public static class Stamina {`n        public float baseStamina = 100f;`n        public float baseRegen = 5.0f;`n        public float sprintCostPerSecond = 2.0f;`n    }" `
    "public static class Stamina {`n        public float baseStamina = 100f;`n        public float baseRegen = 5.0f;`n        public float sprintCostPerSecond = 2.0f;`n    }`n`n    public static class TierConfig {`n        public int t1CooldownTicks = 0;`n        public int t2CooldownTicks = 20;`n        public int t3CooldownTicks = 40;`n        public int t4CooldownTicks = 60;`n        public int t5CooldownTicks = 100;`n        public int getCooldownForTier(int tier) {`n            switch (tier) {`n                case 1: return t1CooldownTicks;`n                case 2: return t2CooldownTicks;`n                case 3: return t3CooldownTicks;`n                case 4: return t4CooldownTicks;`n                case 5: return t5CooldownTicks;`n                default: return t3CooldownTicks;`n            }`n        }`n    }"

# 2. JutsuRegistry: auto-detect tier from cost
Write-Host "[2/15] JutsuRegistry.java (auto tier)..." -ForegroundColor White
Patch-File "$java\jutsu\JutsuRegistry.java" `
    "int tier = json.has(""tier"") ? json.get(""tier"").getAsInt() : 1;" `
    "// S1-04: Auto-detect tier from cost if not specified`n        int tier;`n        if (json.has(""tier"")) {`n            tier = json.get(""tier"").getAsInt();`n        } else {`n            float autoCost = json.has(""chakra_cost"") ? json.get(""chakra_cost"").getAsFloat() :`n                             (json.has(""baseCost"") ? json.get(""baseCost"").getAsFloat() : 0f);`n            if (autoCost <= 15) tier = 1;`n            else if (autoCost <= 25) tier = 2;`n            else if (autoCost <= 40) tier = 3;`n            else if (autoCost <= 60) tier = 4;`n            else tier = 5;`n        }"

# 3. NinjaPlayerData: tier cooldown tracking
Write-Host "[3/15] NinjaPlayerData.java (tier cooldowns)..." -ForegroundColor White
Patch-File "$java\stat\NinjaPlayerData.java" `
    "private boolean lastDangerState = false;" `
    "private boolean lastDangerState = false;`n    private final Map<Integer, Long> tierCooldowns = new HashMap<>();`n    private final Set<String> teacherApprovedNodes = new HashSet<>();"

Patch-File "$java\stat\NinjaPlayerData.java" `
    "public int getJumpLevel() { return jumpLevel; }" `
    "public int getJumpLevel() { return jumpLevel; }`n    public long getLastCastTimeForTier(int tier) { return tierCooldowns.getOrDefault(tier, 0L); }`n    public void setLastCastTimeForTier(int tier, long time) { tierCooldowns.put(tier, time); }`n    public Set<String> getTeacherApprovedNodes() { return teacherApprovedNodes; }`n    public void approveTeacherNode(String nodeId) { teacherApprovedNodes.add(nodeId); statsDirty = true; }"

# NBT save/load for teacherApprovedNodes
Patch-File "$java\stat\NinjaPlayerData.java" `
    "NbtList nodes = new NbtList();`n        for (String nodeId : unlockedNodes) nodes.add(NbtString.of(nodeId));`n        nbt.put(""UnlockedNodes"", nodes);" `
    "NbtList nodes = new NbtList();`n        for (String nodeId : unlockedNodes) nodes.add(NbtString.of(nodeId));`n        nbt.put(""UnlockedNodes"", nodes);`n        NbtList teacherNodes = new NbtList();`n        for (String nodeId : teacherApprovedNodes) teacherNodes.add(NbtString.of(nodeId));`n        nbt.put(""TeacherApprovedNodes"", teacherNodes);"

Patch-File "$java\stat\NinjaPlayerData.java" `
    "if (nbt.contains(""UnlockedNodes"")) {`n            NbtList nodeList = nbt.getList(""UnlockedNodes"", 8);`n            for (int i = 0; i < nodeList.size(); i++) unlockedNodes.add(nodeList.getString(i));`n        }" `
    "if (nbt.contains(""UnlockedNodes"")) {`n            NbtList nodeList = nbt.getList(""UnlockedNodes"", 8);`n            for (int i = 0; i < nodeList.size(); i++) unlockedNodes.add(nodeList.getString(i));`n        }`n        if (nbt.contains(""TeacherApprovedNodes"")) {`n            NbtList teacherList = nbt.getList(""TeacherApprovedNodes"", 8);`n            for (int i = 0; i < teacherList.size(); i++) teacherApprovedNodes.add(teacherList.getString(i));`n        }"

# 4. JutsuCaster.beginCast: tier cooldown check
Write-Host "[4/15] JutsuCaster.java (tier cooldown)..." -ForegroundColor White
Patch-File "$java\jutsu\JutsuCaster.java" `
    "// === DOJUTSU CHECK ===`n        if (def.requiresDojutsu() != null) {`n            String activeDojutsu = data.getActiveDojutsu();" `
    "// S1-04: Tier cooldown check`n        int cooldownTicks = ModConfig.instance.tiers.getCooldownForTier(def.tier());`n        long nowMs = System.currentTimeMillis();`n        if (nowMs - data.getLastCastTimeForTier(def.tier()) < cooldownTicks * 50L) {`n            player.sendMessage(Text.literal(""\u00a7cJutsu on cooldown!""), false);`n            return false;`n        }`n        data.setLastCastTimeForTier(def.tier(), nowMs);`n        // === DOJUTSU CHECK ===`n        if (def.requiresDojutsu() != null) {`n            String activeDojutsu = data.getActiveDojutsu();"

# ================================================================
#  S1-05: CHARGEABLE JUTSU
# ================================================================
Write-Host ""
Write-Host "=== S1-05: CHARGEABLE JUTSU ===" -ForegroundColor White

# 5. CastingServerState.java: full rewrite with charge support
Write-Host "[5/15] CastingServerState.java (charge support)..." -ForegroundColor White
$castStateContent = @'
package com.example.shinobicore.combat;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.JutsuCaster;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuRegistry;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
* S1-05: Casting state with chargeable jutsu support.
* Flow: castTime -> chargePhase (if chargeable) -> executeCast
*/
public class CastingServerState {

    public static class ActiveCast {
        public final String jutsuId;
        public final long startTimeMs;
        public final int durationTicks;
        public final float chakraCost;
        // S1-05: Charge support
        public final boolean chargeable;
        public final float chargeMax;
        public boolean chargePhase = false;
        public long chargeStartTimeMs = 0;
        public int chargeMaxTicks = 0;

        public ActiveCast(String jutsuId, int durationTicks, float chakraCost,
                          boolean chargeable, float chargeMax) {
            this.jutsuId = jutsuId;
            this.startTimeMs = System.currentTimeMillis();
            this.durationTicks = durationTicks;
            this.chakraCost = chakraCost;
            this.chargeable = chargeable;
            this.chargeMax = chargeMax;
        }

        public boolean isCastComplete() {
            return System.currentTimeMillis() - startTimeMs >= (durationTicks * 50L);
        }

        public float getProgress() {
            long elapsed = System.currentTimeMillis() - startTimeMs;
            return Math.min(1f, (float) elapsed / (durationTicks * 50L));
        }

        public void startChargePhase() {
            this.chargePhase = true;
            this.chargeStartTimeMs = System.currentTimeMillis();
            this.chargeMaxTicks = (int)(chargeMax * 20);
        }

        public boolean isChargeComplete() {
            if (!chargePhase) return false;
            long elapsed = System.currentTimeMillis() - chargeStartTimeMs;
            return elapsed >= (chargeMaxTicks * 50L);
        }

        public float getChargeLevel() {
            if (!chargePhase || !chargeable) return 1.0f;
            long elapsed = System.currentTimeMillis() - chargeStartTimeMs;
            return Math.min(1f, (float) elapsed / (chargeMaxTicks * 50L));
        }
    }

    private static final Map<UUID, ActiveCast> ACTIVE = new ConcurrentHashMap<>();

    public static void startCast(ServerPlayerEntity player, String jutsuId,
            int durationTicks, float chakraCost, boolean chargeable, float chargeMax) {
        ACTIVE.put(player.getUuid(), new ActiveCast(jutsuId, durationTicks,
                chakraCost, chargeable, chargeMax));
    }

    public static boolean isCasting(ServerPlayerEntity player) {
        ActiveCast c = ACTIVE.get(player.getUuid());
        return c != null;
    }

    public static ActiveCast getActive(ServerPlayerEntity player) {
        return ACTIVE.get(player.getUuid());
    }

    public static void tickPlayer(ServerPlayerEntity player) {
        ActiveCast cast = ACTIVE.get(player.getUuid());
        if (cast == null) return;

        if (cast.isCastComplete()) {
            if (cast.chargeable && !cast.chargePhase) {
                // Transition to charge phase
                cast.startChargePhase();
                JutsuDefinition def = JutsuRegistry.get(cast.jutsuId);
                if (def != null) {
                    ShinobiCore.LOGGER.debug("[CAST] {} entered charge phase for {}",
                            player.getName().getString(), cast.jutsuId);
                }
            } else if (!cast.chargeable || cast.isChargeComplete()) {
                ACTIVE.remove(player.getUuid());
                JutsuCaster.executeCast(player, cast.jutsuId, cast.getChargeLevel());
            }
        }
    }

    /** S1-05: Called when player releases cast button */
    public static void releaseCast(ServerPlayerEntity player) {
        ActiveCast cast = ACTIVE.get(player.getUuid());
        if (cast == null) return;
        if (cast.chargePhase) {
            ACTIVE.remove(player.getUuid());
            float chargeLevel = cast.getChargeLevel();
            JutsuCaster.executeCast(player, cast.jutsuId, chargeLevel);
            ShinobiCore.LOGGER.debug("[CAST] {} released at charge {:.2f}",
                    player.getName().getString(), chargeLevel);
        }
    }

    public static void interruptCast(ServerPlayerEntity player) {
        ActiveCast cast = ACTIVE.remove(player.getUuid());
        if (cast == null) return;
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        float refund = cast.chakraCost * 0.5f;
        data.setCurrentChakra(Math.min(data.getCurrentChakra() + refund, NinjaFormula.maxChakra(data)));
        ShinobiCore.sendChakraSync(player);
        ShinobiCore.broadcastCastInterrupt(player);
        player.sendMessage(Text.literal("\u00a7cJutsu interrupted! (-" + (int)(cast.chakraCost * 0.5f) + " chakra lost)"), false);
    }

    public static void clearAll() { ACTIVE.clear(); }
}
'@
Write-File "$java\combat\CastingServerState.java" $castStateContent

# 6. JutsuCaster: update startCast call + executeCast with chargeLevel
Write-Host "[6/15] JutsuCaster.java (charge integration)..." -ForegroundColor White
Patch-File "$java\jutsu\JutsuCaster.java" `
    "com.example.shinobicore.combat.CastingServerState.startCast(player, jutsuId, castTimeTicks, cost);" `
    "com.example.shinobicore.combat.CastingServerState.startCast(player, jutsuId, castTimeTicks, cost, def.chargeable(), def.chargeMax());"

Patch-File "$java\jutsu\JutsuCaster.java" `
    "public static boolean executeCast(ServerPlayerEntity player, String jutsuId) {" `
    "public static boolean executeCast(ServerPlayerEntity player, String jutsuId) {`n        return executeCast(player, jutsuId, 1.0f);`n    }`n`n    public static boolean executeCast(ServerPlayerEntity player, String jutsuId, float chargeLevel) {"

Patch-File "$java\jutsu\JutsuCaster.java" `
    "float cost = NinjaFormula.calculateCost(def, data);`n        float damage = def.baseDamage() * NinjaFormula.damageMultiplier(data, def);" `
    "float cost = NinjaFormula.calculateCost(def, data);`n        // S1-05: Scale damage by charge level`n        float effectiveBaseDamage = def.baseDamage();`n        if (def.chargeable() && chargeLevel < 1.0f) {`n            effectiveBaseDamage = def.baseDamage() * (1.0f + (def.chargeMax() - 1.0f) * chargeLevel);`n        }`n        float damage = effectiveBaseDamage * NinjaFormula.damageMultiplier(data, def);"

# 7. ModPackets: RELEASE_CAST_ID
Write-Host "[7/15] ModPackets.java (RELEASE_CAST)..." -ForegroundColor White
Patch-File "$java
etwork\ModPackets.java" `
    "public static final Identifier IAI_DASH_ID = new Identifier(""shinobicore"", ""iai_dash"");" `
    "public static final Identifier IAI_DASH_ID = new Identifier(""shinobicore"", ""iai_dash"");`n    public static final Identifier RELEASE_CAST_ID = new Identifier(""shinobicore"", ""release_cast"");"

Patch-File "$java
etwork\ModPackets.java" `
    "data.setKatanaLastAttackMs(now);`n                ShinobiCore.sendChakraSync(player);`n            });`n        });`n    }" `
    "data.setKatanaLastAttackMs(now);`n                ShinobiCore.sendChakraSync(player);`n            });`n        });`n`n        // === S1-05: RELEASE CAST (charge release) ===`n        ServerPlayNetworking.registerGlobalReceiver(RELEASE_CAST_ID, (server, player, handler, buf, responseSender) -> {`n            server.execute(() -> {`n                com.example.shinobicore.combat.CastingServerState.releaseCast(player);`n            });`n        });`n    }"

# 8. ClientInputHandler: track cast key release
Write-Host "[8/15] ClientInputHandler.java (release tracking)..." -ForegroundColor White
Patch-File "$java\client\ClientInputHandler.java" `
    "private static boolean prevLmbDown = false;" `
    "private static boolean prevLmbDown = false;`n    private static boolean prevCastAHeld = false;`n    private static boolean prevCastBHeld = false;"

Patch-File "$java\client\ClientInputHandler.java" `
    "if (KeyBindings.CAST_A.wasPressed()) ClientNinjaState.castActiveJutsu(0);`n        if (KeyBindings.CAST_B.wasPressed()) ClientNinjaState.castActiveJutsu(1);" `
    "if (KeyBindings.CAST_A.wasPressed()) ClientNinjaState.castActiveJutsu(0);`n        if (KeyBindings.CAST_B.wasPressed()) ClientNinjaState.castActiveJutsu(1);`n        // S1-05: Track release for chargeable jutsu`n        boolean castAHeld = KeyBindings.CAST_A.isPressed();`n        if (!castAHeld && prevCastAHeld && client.getNetworkHandler() != null) {`n            PacketByteBuf releaseBuf = new PacketByteBuf(Unpooled.buffer());`n            ClientPlayNetworking.send(ModPackets.RELEASE_CAST_ID, releaseBuf);`n        }`n        prevCastAHeld = castAHeld;`n        boolean castBHeld = KeyBindings.CAST_B.isPressed();`n        if (!castBHeld && prevCastBHeld && client.getNetworkHandler() != null) {`n            PacketByteBuf releaseBuf = new PacketByteBuf(Unpooled.buffer());`n            ClientPlayNetworking.send(ModPackets.RELEASE_CAST_ID, releaseBuf);`n        }`n        prevCastBHeld = castBHeld;"

# ================================================================
#  S1-06: TREE AUDIT
# ================================================================
Write-Host ""
Write-Host "=== S1-06: TREE AUDIT ===" -ForegroundColor White

# 9. tree.json: remove duplicate gen_basic_fear
Write-Host "[9/15] tree.json (remove duplicate)..." -ForegroundColor White
$treePath = "$res\skill_tree\tree.json"
if (Test-Path $treePath) {
    $tc = [System.IO.File]::ReadAllText($treePath, $utf8)
    if ($tc.Contains('"gen_basic_fear"')) {
        # Remove the duplicate node block with surrounding comma
        $tc = [regex]::Replace($tc, '\{[^{}]*"id":\s*"gen_basic_fear"[^{}]*\},?\s*', '')
        # Fix potential double comma
        $tc = $tc.Replace(',,', ',')
        # Fix comma before ]
        $tc = [regex]::Replace($tc, ',\s*\]', ']')
        [System.IO.File]::WriteAllText($treePath, $tc, $utf8)
        Write-Host "[OK] Removed duplicate gen_basic_fear from tree.json" -ForegroundColor Green
        $ok++
    } else {
        Write-Host "[SKIP] gen_basic_fear already removed" -ForegroundColor Yellow
        $skip++
    }
} else {
    Write-Host "[MISS] tree.json not found" -ForegroundColor Red
    $err++
}

# 10. tree.json: add requires_teacher to forbidden nodes
Write-Host "[10/15] tree.json (requires_teacher)..." -ForegroundColor White
if (Test-Path $treePath) {
    $tc = [System.IO.File]::ReadAllText($treePath, $utf8)
    $changed = $false

    # Add requires_teacher to forb_8gates if not present
    $forbIdx = $tc.IndexOf('"forb_8gates"')
    if ($forbIdx -ge 0) {
        $nearby = $tc.Substring($forbIdx, [Math]::Min(300, $tc.Length - $forbIdx))
        if (-not $nearby.Contains('requires_teacher')) {
            $tc = [regex]::Replace($tc, '("id":\s*"forb_8gates",)', "`$1`n            `"requires_teacher`": true,")
            $changed = $true
        }
    }

    # Add requires_teacher to forb_gates_node if not present
    $gatesIdx = $tc.IndexOf('"forb_gates_node"')
    if ($gatesIdx -ge 0) {
        $nearby2 = $tc.Substring($gatesIdx, [Math]::Min(300, $tc.Length - $gatesIdx))
        if (-not $nearby2.Contains('requires_teacher')) {
            $tc = [regex]::Replace($tc, '("id":\s*"forb_gates_node",)', "`$1`n            `"requires_teacher`": true,")
            $changed = $true
        }
    }

    if ($changed) {
        [System.IO.File]::WriteAllText($treePath, $tc, $utf8)
        Write-Host "[OK] Added requires_teacher to forbidden nodes" -ForegroundColor Green
        $ok++
    } else {
        Write-Host "[SKIP] requires_teacher already present" -ForegroundColor Yellow
        $skip++
    }
}

# ================================================================
#  S1-07: S-RANK VIA TEACHER/SCROLL
# ================================================================
Write-Host ""
Write-Host "=== S1-07: S-RANK VIA TEACHER/SCROLL ===" -ForegroundColor White

# 11. ClientNinjaState: add teacherApproved
Write-Host "[11/15] ClientNinjaState.java..." -ForegroundColor White
Patch-File "$java\client\ClientNinjaState.java" `
    "public static final Set<String> unlockedNodes = new HashSet<>();" `
    "public static final Set<String> unlockedNodes = new HashSet<>();`n    public static final Set<String> teacherApproved = new HashSet<>();"

# 12. ShinobiCore.sendTreeSync: add teacherApproved
Write-Host "[12/15] ShinobiCore.java (sendTreeSync)..." -ForegroundColor White
Patch-File "$java\ShinobiCore.java" `
    "for (String nodeId : data.getUnlockedNodes()) buf.writeString(nodeId);`n        ServerPlayNetworking.send(player, ModPackets.TREE_SYNC_ID, buf);" `
    "for (String nodeId : data.getUnlockedNodes()) buf.writeString(nodeId);`n        // S1-07: Teacher approved nodes`n        buf.writeInt(data.getTeacherApprovedNodes().size());`n        for (String nodeId : data.getTeacherApprovedNodes()) buf.writeString(nodeId);`n        ServerPlayNetworking.send(player, ModPackets.TREE_SYNC_ID, buf);"

# 13. ShinobiCore.handleUnlockNode: check requiresTeacher + requiresScroll
Write-Host "[13/15] ShinobiCore.java (handleUnlockNode)..." -ForegroundColor White
Patch-File "$java\ShinobiCore.java" `
    "if (data.isNodeUnlocked(nodeId)) {`n            player.sendMessage(Text.literal(""В§cAlready unlocked!""), false);`n            return;`n        }" `
    "if (data.isNodeUnlocked(nodeId)) {`n            player.sendMessage(Text.literal(""В§cAlready unlocked!""), false);`n            return;`n        }`n        // S1-07: Check teacher requirement`n        if (node.requiresTeacher() && !data.getTeacherApprovedNodes().contains(nodeId)) {`n            player.sendMessage(Text.literal(""\u00a7cThis technique requires a teacher!""), false);`n            return;`n        }`n        // S1-07: Check scroll requirement`n        if (node.requiresScroll() != null && !node.requiresScroll().isEmpty()) {`n            boolean hasScroll = false;`n            for (int i = 0; i < player.getInventory().size(); i++) {`n                net.minecraft.item.ItemStack stack = player.getInventory().getStack(i);`n                if (stack.getItem() instanceof com.example.shinobicore.item.ScrollItem) {`n                    String scrollId = com.example.shinobicore.item.ScrollItem.getJutsuId(stack);`n                    if (node.requiresScroll().equals(scrollId)) { hasScroll = true; break; }`n                }`n            }`n            if (!hasScroll) {`n                player.sendMessage(Text.literal(""\u00a7cRequires scroll: "" + node.requiresScroll()), false);`n                return;`n            }`n        }"

# 14. SkillTreeScreen: canUnlock + tooltip
Write-Host "[14/15] SkillTreeScreen.java (teacher check)..." -ForegroundColor White
Patch-File "$java\client\SkillTreeScreen.java" `
    "if (ClientNinjaState.skillPoints < node.spCost()) return false;" `
    "if (ClientNinjaState.skillPoints < node.spCost()) return false;`n        if (node.requiresTeacher() && !ClientNinjaState.teacherApproved.contains(node.id())) return false;"

Patch-File "$java\client\SkillTreeScreen.java" `
    "else lines.add(""[Locked]"");" `
    "else {`n            lines.add(""[Locked]"");`n            if (node.requiresTeacher() && !ClientNinjaState.teacherApproved.contains(node.id())) {`n                lines.add(""  Requires a teacher"");`n            }`n            if (node.requiresScroll() != null && !node.requiresScroll().isEmpty()) {`n                lines.add(""  Requires scroll: "" + node.requiresScroll());`n            }`n        }"

# 15. NinjaCommand: /ninja teach + ShinobiCoreClient TREE_SYNC
Write-Host "[15/15] NinjaCommand + ShinobiCoreClient..." -ForegroundColor White
Patch-File "$java\command\NinjaCommand.java" `
    ".then(clanBranch())" `
    ".then(teachBranch())`n                .then(clanBranch())"

Patch-File "$java\command\NinjaCommand.java" `
    "private static ArgumentBuilder<ServerCommandSource, ?> clanBranch() {" `
    "private static ArgumentBuilder<ServerCommandSource, ?> teachBranch() {`n        return CommandManager.literal(""teach"")`n            .then(CommandManager.argument(""node"", StringArgumentType.word())`n                .suggests(NinjaCommand::suggestTreeNodes)`n                .executes(ctx -> teach(ctx.getSource(), StringArgumentType.getString(ctx, ""node""))));`n    }`n`n    private static int teach(ServerCommandSource source, String nodeId) {`n        ServerPlayerEntity p = source.getPlayer();`n        NinjaPlayerData d = data(p);`n        SkillTreeNode node = SkillTreeRegistry.get(nodeId);`n        if (node == null) {`n            source.sendFeedback(() -> Text.literal(""\u00a7cUnknown node: "" + nodeId), false);`n            return 0;`n        }`n        d.approveTeacherNode(nodeId);`n        ShinobiCore.sendTreeSync(p);`n        source.sendFeedback(() -> Text.literal(""\u00a7aTeacher approved for: "" + nodeId), false);`n        return 1;`n    }`n`n    private static CompletableFuture<Suggestions> suggestTreeNodes(CommandContext<ServerCommandSource> ctx, SuggestionsBuilder b) {`n        for (SkillTreeNode node : SkillTreeRegistry.getAll()) b.suggest(node.id());`n        return b.buildFuture();`n    }`n`n    private static ArgumentBuilder<ServerCommandSource, ?> clanBranch() {"

# Add imports to NinjaCommand if missing
Patch-File "$java\command\NinjaCommand.java" `
    "import com.example.shinobicore.stat.StatType;" `
    "import com.example.shinobicore.stat.StatType;`nimport com.example.shinobicore.tree.SkillTreeNode;`nimport com.example.shinobicore.tree.SkillTreeRegistry;"

# ShinobiCoreClient: update TREE_SYNC receiver
Patch-File "$java\client\ShinobiCoreClient.java" `
    "ClientPlayNetworking.registerGlobalReceiver(ModPackets.TREE_SYNC_ID, (client, handler, buf, responseSender) -> {`n            int count = buf.readInt();`n            Set<String> nodes = new HashSet<>();`n            for (int i = 0; i < count; i++) nodes.add(buf.readString());`n            client.execute(() -> {`n                ClientNinjaState.unlockedNodes.clear();`n                ClientNinjaState.unlockedNodes.addAll(nodes);`n            });`n        });" `
    "ClientPlayNetworking.registerGlobalReceiver(ModPackets.TREE_SYNC_ID, (client, handler, buf, responseSender) -> {`n            int count = buf.readInt();`n            Set<String> nodes = new HashSet<>();`n            for (int i = 0; i < count; i++) nodes.add(buf.readString());`n            // S1-07: Read teacher approved nodes`n            int teacherCount = buf.readInt();`n            Set<String> teacherNodes = new HashSet<>();`n            for (int i = 0; i < teacherCount; i++) teacherNodes.add(buf.readString());`n            client.execute(() -> {`n                ClientNinjaState.unlockedNodes.clear();`n                ClientNinjaState.unlockedNodes.addAll(nodes);`n                ClientNinjaState.teacherApproved.clear();`n                ClientNinjaState.teacherApproved.addAll(teacherNodes);`n            });`n        });"

# ================================================================
# SUMMARY
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  S1-04/05/06/07 COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  S1-04 Tier Table:" -ForegroundColor White
Write-Host "    + ModConfig.TierConfig (cooldowns per tier)" -ForegroundColor White
Write-Host "    + Auto tier detection from cost in JutsuRegistry" -ForegroundColor White
Write-Host "    + Tier cooldown enforcement in JutsuCaster.beginCast" -ForegroundColor White
Write-Host ""
Write-Host "  S1-05 Chargeable Jutsu:" -ForegroundColor White
Write-Host "    + CastingServerState rewritten with charge phase" -ForegroundColor White
Write-Host "    + JutsuCaster.executeCast scales damage by charge" -ForegroundColor White
Write-Host "    + RELEASE_CAST packet (client releases button)" -ForegroundColor White
Write-Host "    + ClientInputHandler tracks key release" -ForegroundColor White
Write-Host ""
Write-Host "  S1-06 Tree Audit:" -ForegroundColor White
Write-Host "    - Removed duplicate gen_basic_fear node" -ForegroundColor White
Write-Host "    + Added requires_teacher to forb_8gates, forb_gates_node" -ForegroundColor White
Write-Host ""
Write-Host "  S1-07 S-Rank:" -ForegroundColor White
Write-Host "    + NinjaPlayerData.teacherApprovedNodes + NBT" -ForegroundColor White
Write-Host "    + handleUnlockNode checks teacher + scroll" -ForegroundColor White
Write-Host "    + SkillTreeScreen shows lock reason" -ForegroundColor White
Write-Host "    + /ninja teach <nodeId> command" -ForegroundColor White
Write-Host "    + TREE_SYNC extended with teacherApproved" -ForegroundColor White
Write-Host ""
if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected!" -ForegroundColor Red
    exit 1
}
Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
Write-Host "  Then: sprint1_s08_passive_drift.ps1" -ForegroundColor Yellow
exit 0