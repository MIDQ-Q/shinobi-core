# fix_phase5.ps1
# Phase 5: Hand Signs (casting delay) + Jutsu Interrupt
$ErrorActionPreference = "Stop"
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-File($path, $content) {
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host "[OK] $path"
}

# ============================================================
# 1. NEW: CastingServerState.java - server-side cast tracker
# ============================================================
$css = "$root\combat\CastingServerState.java"
if (Test-Path $css) { Write-Host "[SKIP] CastingServerState exists" } else {
Write-File $css @"
package com.example.shinobicore.combat;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.JutsuCaster;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
public class CastingServerState {
    public static class ActiveCast {
        public final String jutsuId;
        public final long startTimeMs;
        public final int durationTicks;
        public final float chakraCost;
        public ActiveCast(String jutsuId, int durationTicks, float chakraCost) {
            this.jutsuId = jutsuId;
            this.startTimeMs = System.currentTimeMillis();
            this.durationTicks = durationTicks;
            this.chakraCost = chakraCost;
        }
        public boolean isComplete() {
            return System.currentTimeMillis() - startTimeMs >= (durationTicks * 50L);
        }
        public float getProgress() {
            long elapsed = System.currentTimeMillis() - startTimeMs;
            return Math.min(1f, (float) elapsed / (durationTicks * 50L));
        }
    }
    private static final Map<UUID, ActiveCast> ACTIVE = new ConcurrentHashMap<>();
    public static void startCast(ServerPlayerEntity player, String jutsuId, int durationTicks, float chakraCost) {
        ACTIVE.put(player.getUuid(), new ActiveCast(jutsuId, durationTicks, chakraCost));
    }
    public static boolean isCasting(ServerPlayerEntity player) {
        ActiveCast c = ACTIVE.get(player.getUuid());
        return c != null && !c.isComplete();
    }
    public static ActiveCast getActive(ServerPlayerEntity player) {
        return ACTIVE.get(player.getUuid());
    }
    public static void tickPlayer(ServerPlayerEntity player) {
        ActiveCast cast = ACTIVE.get(player.getUuid());
        if (cast == null) return;
        if (cast.isComplete()) {
            ACTIVE.remove(player.getUuid());
            JutsuCaster.executeCast(player, cast.jutsuId);
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
"@
}

# ============================================================
# 2. NEW: InterruptCastMixin.java
# ============================================================
$icm = "$root\mixin\InterruptCastMixin.java"
if (Test-Path $icm) { Write-Host "[SKIP] InterruptCastMixin exists" } else {
Write-File $icm @"
package com.example.shinobicore.mixin;
import com.example.shinobicore.combat.CastingServerState;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;
@Mixin(LivingEntity.class)
public abstract class InterruptCastMixin {
    @Inject(method = "damage", at = @At("HEAD"))
    private void shinobicore_checkInterrupt(DamageSource source, float amount, CallbackInfoReturnable<Boolean> cir) {
        LivingEntity self = (LivingEntity) (Object) this;
        if (self instanceof ServerPlayerEntity player && amount > 0) {
            if (CastingServerState.isCasting(player)) {
                CastingServerState.interruptCast(player);
            }
        }
    }
}
"@
}

# ============================================================
# 3. NEW: HandSignsClientState.java
# ============================================================
$hss = "$root\client\HandSignsClientState.java"
if (Test-Path $hss) { Write-Host "[SKIP] HandSignsClientState exists" } else {
Write-File $hss @"
package com.example.shinobicore.client;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
public class HandSignsClientState {
    public static class ActiveSigns {
        public final String jutsuId;
        public final long startTimeMs;
        public final int durationTicks;
        public ActiveSigns(String jutsuId, int durationTicks) {
            this.jutsuId = jutsuId;
            this.startTimeMs = System.currentTimeMillis();
            this.durationTicks = durationTicks;
        }
        public float getProgress() {
            long elapsed = System.currentTimeMillis() - startTimeMs;
            return Math.min(1f, (float) elapsed / (durationTicks * 50L));
        }
        public boolean isExpired() {
            return System.currentTimeMillis() - startTimeMs > (durationTicks * 50L) + 500;
        }
    }
    private static final Map<Integer, ActiveSigns> CASTING = new ConcurrentHashMap<>();
    public static void startCasting(int entityId, String jutsuId, int durationTicks) {
        CASTING.put(entityId, new ActiveSigns(jutsuId, durationTicks));
    }
    public static void interruptCasting(int entityId) {
        CASTING.remove(entityId);
    }
    public static ActiveSigns get(int entityId) {
        ActiveSigns a = CASTING.get(entityId);
        if (a != null && a.isExpired()) { CASTING.remove(entityId); return null; }
        return a;
    }
    public static boolean isCasting(int entityId) { return get(entityId) != null; }
    public static void clear() { CASTING.clear(); }
}
"@
}

# ============================================================
# 4. NEW: HandSignsHudRenderer.java
# ============================================================
$hsh = "$root\client\HandSignsHudRenderer.java"
if (Test-Path $hsh) { Write-Host "[SKIP] HandSignsHudRenderer exists" } else {
Write-File $hsh @"
package com.example.shinobicore.client;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;
import net.minecraft.util.math.ColorHelper;
public class HandSignsHudRenderer {
    public static void render(DrawContext ctx, float tickDelta) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        HandSignsClientState.ActiveSigns signs = HandSignsClientState.get(client.player.getId());
        if (signs == null) return;
        float progress = signs.getProgress();
        String name = ClientNinjaState.name(signs.jutsuId);
        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();
        int barW = 120, barH = 6;
        int barX = (sw - barW) / 2;
        int barY = sh / 2 + 40;
        int alpha = (int)(180 + 75 * Math.sin(System.currentTimeMillis() / 100.0));
        ctx.fill(barX - 1, barY - 1, barX + barW + 1, barY + barH + 1, 0xCC000000);
        ctx.fill(barX, barY, barX + barW, barY + barH, 0xFF222222);
        int fillW = (int)(barW * progress);
        int fillColor = ColorHelper.Argb.getArgb(alpha, 255, 170, 0);
        ctx.fill(barX, barY, barX + fillW, barY + barH, fillColor);
        ctx.fill(barX, barY, barX + fillW, barY + 1, ColorHelper.Argb.getArgb(alpha / 2, 255, 255, 255));
        String label = "Weaving signs: " + name + " (" + (int)(progress * 100) + "%)";
        int tw = client.textRenderer.getWidth(label);
        ctx.drawTextWithShadow(client.textRenderer, Text.literal(label),
            (sw - tw) / 2, barY - 12, 0xFFFFAA00);
    }
}
"@
}

# ============================================================
# 5. MODIFY: JutsuCaster.java - add beginCast + executeCast
# ============================================================
$jc = "$root\jutsu\JutsuCaster.java"
$jcc = [System.IO.File]::ReadAllText($jc, $utf8)

$sentinel = "// === PHASE5 BEGINCAST ==="
if ($jcc.Contains($sentinel)) { Write-Host "[SKIP] JutsuCaster already has beginCast" } else {
    # Add calculateCastTime and beginCast and executeCast methods before the last closing brace
    $newMethods = @"

    // === PHASE5 BEGINCAST ===
    public static int calculateCastTime(com.example.shinobicore.jutsu.JutsuDefinition def, NinjaPlayerData data) {
        float baseTime = 1.5f;
        float complexity = Math.max(0.5f, def.baseCost() / 30f);
        int control = data.getStatLevel(StatType.CONTROL);
        float controlFactor = 1f - (control / 100f * 0.5f);
        float castTimeSeconds = baseTime * complexity * controlFactor;
        int ticks = (int)(castTimeSeconds * 20f);
        return Math.max(10, Math.min(100, ticks));
    }

    public static boolean beginCast(ServerPlayerEntity player, String jutsuId) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        TreePassives.Bonuses pbs = TreePassives.collectServer(data);
        if (!data.getLearnedJutsus().contains(jutsuId)) {
            player.sendMessage(Text.literal("\u00a7cYou haven't learned this jutsu!"), false);
            return false;
        }
        com.example.shinobicore.jutsu.JutsuDefinition def = com.example.shinobicore.jutsu.JutsuRegistry.get(jutsuId);
        if (def == null) {
            player.sendMessage(Text.literal("\u00a7cJutsu not found!"), false);
            return false;
        }
        if (!NinjaFormula.checkRequirements(def, data)) {
            player.sendMessage(Text.literal("\u00a7cYour stats are too low for this jutsu!"), false);
            return false;
        }
        float cost = NinjaFormula.calculateCost(def, data);
        if (data.getCurrentChakra() < cost) {
            player.sendMessage(Text.literal("\u00a7cNot enough chakra!"), false);
            return false;
        }
        if (com.example.shinobicore.combat.CastingServerState.isCasting(player)) {
            com.example.shinobicore.combat.CastingServerState.interruptCast(player);
        }
        data.setCurrentChakra(data.getCurrentChakra() - cost);
        float strain = def.strain() * (1f - pbs.fatigueReduction);
        com.example.shinobicore.clan.ClanDefinition clan = com.example.shinobicore.clan.ClanRegistry.get(data.getClanId());
        if (clan != null) strain *= clan.fatigueMultiplier();
        data.setFatigue(data.getFatigue() + strain);
        NinjaFormula.grantUsage(data, jutsuId, 1);
        if (def.hasNature() && data.isNatureUnlocked(def.nature())) {
            float xpMult = (data.getAffinity() == def.nature())
                ? com.example.shinobicore.config.ModConfig.instance.combat.affinityXpMultiplier : 1f;
            int natureXp = Math.max(1, Math.round(cost * 0.2f * xpMult));
            NinjaFormula.grantNatureXp(data, def.nature(), natureXp);
        }
        int ninjutsuXp = Math.max(1, Math.round(cost * 0.1f));
        NinjaFormula.grantStatXp(data, StatType.NINJUTSU, ninjutsuXp);
        int castTimeTicks = calculateCastTime(def, data);
        ShinobiCore.sendChakraSync(player);
        com.example.shinobicore.combat.CastingServerState.startCast(player, jutsuId, castTimeTicks, cost);
        ShinobiCore.broadcastCastStart(player, jutsuId, castTimeTicks);
        JutsuLogger.logBehavior("hand_signs", String.format(
            "START: player=%s, jutsu=%s, castTime=%dticks, cost=%.1f",
            player.getName().getString(), jutsuId, castTimeTicks, cost));
        return true;
    }

    public static boolean executeCast(ServerPlayerEntity player, String jutsuId) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        TreePassives.Bonuses pbs = TreePassives.collectServer(data);
        com.example.shinobicore.jutsu.JutsuDefinition def = com.example.shinobicore.jutsu.JutsuRegistry.get(jutsuId);
        if (def == null) return false;
        float cost = NinjaFormula.calculateCost(def, data);
        float damage = def.baseDamage() * NinjaFormula.damageMultiplier(data, def);
        if (def.hasNature()) {
            String nid = def.nature().getId();
            float elemBonus = 0f;
            if (nid.equals("fire")) {
                elemBonus += pbs.kekkeiFire;
                if (pbs.fireWindSynergy > 0 && data.isNatureUnlocked(com.example.shinobicore.stat.ElementType.WIND))
                    elemBonus += pbs.fireWindSynergy;
            } else if (nid.equals("earth")) { elemBonus += pbs.kekkeiEarth; }
            else if (nid.equals("lightning")) { elemBonus += pbs.kekkeiLightning; }
            if (elemBonus > 0) damage *= (1f + elemBonus);
        }
        JutsuLogger.logCast(player, def, data, damage, cost);
        ShinobiCore.broadcastCastFx(player, def.hasNature() ? def.nature().getId() : "none");
        com.example.shinobicore.jutsu.JutsuBehavior behavior = com.example.shinobicore.jutsu.BehaviorRegistry.getFor(def);
        behavior.cast(player, def, data, def.params(), damage);
        return true;
    }
"@
    $lastBrace = $jcc.LastIndexOf("}")
    $jcc = $jcc.Substring(0, $lastBrace) + $newMethods + "`n}"
    Write-File $jc $jcc
    Write-Host "[FIX] JutsuCaster: added beginCast + executeCast"
}

# ============================================================
# 6. MODIFY: ModPackets.java - add CAST_START/INTERRUPT ids + change cast→beginCast
# ============================================================
$mp = "$root\network\ModPackets.java"
$mpc = [System.IO.File]::ReadAllText($mp, $utf8)

$sentinel2 = "CAST_START_ID"
if ($mpc.Contains($sentinel2)) { Write-Host "[SKIP] ModPackets already has CAST_START_ID" } else {
    # Add identifiers after SENSORY_TOGGLE_ID
    $mpc = $mpc.Replace(
        'public static final Identifier SENSORY_TOGGLE_ID = new Identifier("shinobicore", "sensory_toggle");',
        "public static final Identifier SENSORY_TOGGLE_ID = new Identifier(`"shinobicore`", `"sensory_toggle`");`n    public static final Identifier CAST_START_ID = new Identifier(`"shinobicore`", `"cast_start`");`n    public static final Identifier CAST_INTERRUPT_ID = new Identifier(`"shinobicore`", `"cast_interrupt`");"
    )
    Write-File $mp $mpc
    Write-Host "[FIX] ModPackets: added CAST_START_ID, CAST_INTERRUPT_ID"
}

# Change JutsuCaster.cast to JutsuCaster.beginCast in CAST_SLOT handler
$mpc2 = [System.IO.File]::ReadAllText($mp, $utf8)
$sentinel3 = "// === PHASE5_USE_BEGINCAST ==="
if ($mpc2.Contains($sentinel3)) { Write-Host "[SKIP] CAST_SLOT already uses beginCast" } else {
    $mpc2 = $mpc2.Replace(
        'boolean success = JutsuCaster.cast(player, id);',
        "boolean success = JutsuCaster.beginCast(player, id); // === PHASE5_USE_BEGINCAST ==="
    )
    Write-File $mp $mpc2
    Write-Host "[FIX] ModPackets: CAST_SLOT now uses beginCast()"
}

# ============================================================
# 7. MODIFY: ShinobiCore.java - add broadcastCastStart/Interrupt + tick
# ============================================================
$sc = "$root\ShinobiCore.java"
$scc = [System.IO.File]::ReadAllText($sc, $utf8)

$sentinel4 = "broadcastCastStart"
if ($scc.Contains($sentinel4)) { Write-Host "[SKIP] ShinobiCore already has broadcastCastStart" } else {
    $newMethods = @"

    // === PHASE5 CAST BROADCAST ===
    public static void broadcastCastStart(ServerPlayerEntity player, String jutsuId, int durationTicks) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(player.getId());
        buf.writeString(jutsuId);
        buf.writeInt(durationTicks);
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(player)) {
            ServerPlayNetworking.send(p, ModPackets.CAST_START_ID, buf);
        }
        ServerPlayNetworking.send(player, ModPackets.CAST_START_ID, buf);
    }

    public static void broadcastCastInterrupt(ServerPlayerEntity player) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(player.getId());
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(player)) {
            ServerPlayNetworking.send(p, ModPackets.CAST_INTERRUPT_ID, buf);
        }
        ServerPlayNetworking.send(player, ModPackets.CAST_INTERRUPT_ID, buf);
    }
"@
    $lastBrace = $scc.LastIndexOf("}")
    $scc = $scc.Substring(0, $lastBrace) + $newMethods + "`n}"
    Write-File $sc $scc
    Write-Host "[FIX] ShinobiCore: added broadcastCastStart/Interrupt"
}

# Add tick handler in onInitialize
$scc2 = [System.IO.File]::ReadAllText($sc, $utf8)
$sentinel5 = "// === PHASE5_CAST_TICK ==="
if ($scc2.Contains($sentinel5)) { Write-Host "[SKIP] Cast tick already registered" } else {
    $scc2 = $scc2.Replace(
        "ServerTickEvents.END_SERVER_TICK.register(NinjaTickHandler::onServerTick);",
        "ServerTickEvents.END_SERVER_TICK.register(NinjaTickHandler::onServerTick);`n        // === PHASE5_CAST_TICK ===`n        ServerTickEvents.END_SERVER_TICK.register(server -> {`n            for (ServerPlayerEntity p : server.getPlayerManager().getPlayerList()) {`n                com.example.shinobicore.combat.CastingServerState.tickPlayer(p);`n            }`n        });"
    )
    Write-File $sc $scc2
    Write-Host "[FIX] ShinobiCore: registered cast tick handler"
}

# ============================================================
# 8. MODIFY: ShinobiCoreClient.java - register receivers + HUD
# ============================================================
$scClient = "$root\client\ShinobiCoreClient.java"
$scClientC = [System.IO.File]::ReadAllText($scClient, $utf8)

$sentinel6 = "HandSignsClientState"
if ($scClientC.Contains($sentinel6)) { Write-Host "[SKIP] ShinobiCoreClient already has hand signs" } else {
    # Add imports
    $scClientC = $scClientC.Replace(
        "import com.example.shinobicore.client.CinematicCamera;",
        "import com.example.shinobicore.client.CinematicCamera;`nimport com.example.shinobicore.client.HandSignsClientState;`nimport com.example.shinobicore.client.HandSignsHudRenderer;"
    )
    
    # Add receivers before HudRenderCallback
    $receivers = @"
        // === PHASE5 HAND SIGNS ===
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.CAST_START_ID, (client, handler, buf, responseSender) -> {
            int entityId = buf.readInt();
            String jutsuId = buf.readString();
            int durationTicks = buf.readInt();
            client.execute(() -> HandSignsClientState.startCasting(entityId, jutsuId, durationTicks));
        });
        ClientPlayNetworking.registerGlobalReceiver(ModPackets.CAST_INTERRUPT_ID, (client, handler, buf, responseSender) -> {
            int entityId = buf.readInt();
            client.execute(() -> HandSignsClientState.interruptCasting(entityId));
        });
"@
    $scClientC = $scClientC.Replace(
        "HudRenderCallback.EVENT.register(ChakraHudRenderer::render);",
        "$receivers`n        HudRenderCallback.EVENT.register(ChakraHudRenderer::render);`n        HudRenderCallback.EVENT.register(HandSignsHudRenderer::render);"
    )
    
    # Add disconnect cleanup
    $scClientC = $scClientC.Replace(
        "HitStopManager.clear();",
        "HitStopManager.clear();`n            HandSignsClientState.clear();"
    )
    
    Write-File $scClient $scClientC
    Write-Host "[FIX] ShinobiCoreClient: registered hand signs receivers + HUD"
}

# ============================================================
# 9. MODIFY: shinobicore.mixins.json - add InterruptCastMixin
# ============================================================
$mixinsPath = "E:\Games\mod\src\main\resources\shinobicore.mixins.json"
$mixinsContent = [System.IO.File]::ReadAllText($mixinsPath, $utf8)

$sentinel7 = "InterruptCastMixin"
if ($mixinsContent.Contains($sentinel7)) { Write-Host "[SKIP] InterruptCastMixin already in mixins.json" } else {
    $mixinsContent = $mixinsContent.Replace(
        '"PlayerParryMixin"',
        "`"PlayerParryMixin`",`n        `"InterruptCastMixin`""
    )
    Write-File $mixinsPath $mixinsContent
    Write-Host "[FIX] shinobicore.mixins.json: added InterruptCastMixin"
}

Write-Host ""
Write-Host "=== PHASE 5 APPLIED ==="
Write-Host "Run: .\gradlew.bat build"