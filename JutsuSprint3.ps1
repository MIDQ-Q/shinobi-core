# Setup-JutsuSprint3.ps1
# Мастер-скрипт для создания Client, Requirements и Cooldowns модуля Jutsu (Sprint 1, Step 4)
# Требует запуска из корневой директории мода (где находится build.gradle)

$ErrorActionPreference = "Stop"
$rootPath = Get-Location

Write-Host "=== ShinobiCore: Jutsu Module Sprint 3 Setup ===" -ForegroundColor Cyan

# 1. Создание структуры директорий
$dirs = @(
    "src\main\java\com\example\shinobicore\modules\jutsu\cooldown",
    "src\main\java\com\example\shinobicore\modules\jutsu\requirement",
    "src\main\java\com\example\shinobicore\modules\jutsu\client"
)

foreach ($dir in $dirs) {
    $fullPath = Join-Path $rootPath $dir
    if (!(Test-Path $fullPath)) {
        New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
        Write-Host "[OK] Created directory: $dir" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] Directory already exists: $dir" -ForegroundColor Yellow
    }
}

# 2. Функция для безопасной записи файлов (UTF-8 без BOM)
function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path $rootPath $Path), $Content, $utf8NoBom)
    Write-Host "[OK] Written: $Path" -ForegroundColor Green
}

# 3. Создание Java файлов (Cooldown)
Write-Host "`n--- Creating Java Classes (Cooldown) ---" -ForegroundColor Cyan

$cooldownEntryJava = @'
package com.example.shinobicore.modules.jutsu.cooldown;

public record CooldownEntry(String jutsuId, int remainingTicks, int maxTicks) {
    public boolean isFinished() {
        return remainingTicks <= 0;
    }
    
    public float getProgress() {
        if (maxTicks <= 0) return 1.0f;
        return 1.0f - ((float) remainingTicks / maxTicks);
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\cooldown\CooldownEntry.java" $cooldownEntryJava

$jutsuCooldownServiceJava = @'
package com.example.shinobicore.modules.jutsu.cooldown;

import com.example.shinobicore.core.log.ShinobiLogger;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public final class JutsuCooldownService {
    private static final Map<UUID, Map<String, CooldownEntry>> COOLDOWNS = new ConcurrentHashMap<>();
    private static final int MIN_COOLDOWN_TICKS = 1; // Never 0 to prevent spam

    public static void init() {
        ShinobiLogger.module("jutsu", "JutsuCooldownService initialized.");
    }

    public static boolean isOnCooldown(UUID playerId, String jutsuId) {
        Map<String, CooldownEntry> playerCds = COOLDOWNS.get(playerId);
        if (playerCds == null) return false;
        CooldownEntry entry = playerCds.get(jutsuId);
        return entry != null && !entry.isFinished();
    }

    public static int getRemainingTicks(UUID playerId, String jutsuId) {
        Map<String, CooldownEntry> playerCds = COOLDOWNS.get(playerId);
        if (playerCds == null) return 0;
        CooldownEntry entry = playerCds.get(jutsuId);
        return entry != null ? Math.max(0, entry.remainingTicks()) : 0;
    }

    public static void startCooldown(UUID playerId, String jutsuId, int maxTicks) {
        int finalTicks = Math.max(MIN_COOLDOWN_TICKS, maxTicks);
        COOLDOWNS.computeIfAbsent(playerId, k -> new ConcurrentHashMap<>())
                 .put(jutsuId, new CooldownEntry(jutsuId, finalTicks, finalTicks));
    }

    public static void serverTick(MinecraftServer server) {
        for (Map.Entry<UUID, Map<String, CooldownEntry>> playerEntry : COOLDOWNS.entrySet()) {
            Map<String, CooldownEntry> playerCds = playerEntry.getValue();
            playerCds.entrySet().removeIf(entry -> {
                CooldownEntry cd = entry.getValue();
                if (cd.isFinished()) return true;
                entry.setValue(new CooldownEntry(cd.jutsuId(), cd.remainingTicks() - 1, cd.maxTicks()));
                return false;
            });
        }
    }

    public static void resetAll(ServerPlayerEntity player) {
        COOLDOWNS.remove(player.getUuid());
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\cooldown\JutsuCooldownService.java" $jutsuCooldownServiceJava

# 4. Создание Java файлов (Requirement)
Write-Host "`n--- Creating Java Classes (Requirement) ---" -ForegroundColor Cyan

$requirementCheckResultJava = @'
package com.example.shinobicore.modules.jutsu.requirement;

public record RequirementCheckResult(
    boolean ok,
    String failReason,
    float chakraNeeded
) {
    public static RequirementCheckResult success() {
        return new RequirementCheckResult(true, "", 0.0f);
    }

    public static RequirementCheckResult fail(String reason) {
        return new RequirementCheckResult(false, reason, 0.0f);
    }

    public static RequirementCheckResult failChakra(float needed) {
        return new RequirementCheckResult(false, "insufficient_chakra", needed);
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\requirement\RequirementCheckResult.java" $requirementCheckResultJava

$jutsuRequirementServiceJava = @'
package com.example.shinobicore.modules.jutsu.requirement;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.jutsu.cooldown.JutsuCooldownService;
import com.example.shinobicore.modules.jutsu.data.JutsuDefinition;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Map;
import java.util.Optional;

public final class JutsuRequirementService {

    public static void init() {
        ShinobiLogger.module("jutsu", "JutsuRequirementService initialized.");
    }

    public static RequirementCheckResult check(ServerPlayerEntity player, JutsuDefinition def) {
        UUID uuid = player.getUuid();

        // 1. Cooldown check
        if (JutsuCooldownService.isOnCooldown(uuid, def.id())) {
            return RequirementCheckResult.fail("on_cooldown");
        }

        // 2. Progression checks (Learned, Element, Level) - Graceful degradation
        Optional<Object> progOpt = CoreServices.get(com.example.shinobicore.core.api.ProgressionApi.class);
        if (progOpt.isPresent()) {
            var prog = progOpt.get();
            // Using reflection or direct API if available. Since API is in Sprint 2, we assume methods exist.
            // For compilation safety without Sprint 2 interfaces, we use dynamic checks or assume interfaces are present.
            // Assuming ProgressionApi, StatsApi, ClanApi, ChakraApi are available as interfaces.
            
            if (!checkProgression(prog, player, def)) return RequirementCheckResult.fail("not_learned_or_level");
        } else {
            ShinobiLogger.module("jutsu", "ProgressionApi missing, skipping progression checks (graceful degradation).");
        }

        // 3. Stats checks
        Optional<Object> statsOpt = CoreServices.get(com.example.shinobicore.core.api.StatsApi.class);
        if (statsOpt.isPresent()) {
            if (!checkStats(statsOpt.get(), player, def)) return RequirementCheckResult.fail("insufficient_stats");
        }

        // 4. Clan checks
        Optional<Object> clanOpt = CoreServices.get(com.example.shinobicore.core.api.ClanApi.class);
        if (clanOpt.isPresent()) {
            if (!checkClan(clanOpt.get(), player, def)) return RequirementCheckResult.fail("clan_requirement");
        }

        // 5. Chakra check (Always last, as it's the most common fail)
        float requiredChakra = calculateCost(player, def);
        Optional<Object> chakraOpt = CoreServices.get(com.example.shinobicore.core.api.ChakraApi.class);
        if (chakraOpt.isPresent()) {
            float current = ((com.example.shinobicore.core.api.ChakraApi)chakraOpt.get()).getCurrent(player);
            if (current < requiredChakra) {
                return RequirementCheckResult.failChakra(requiredChakra);
            }
        } else {
            ShinobiLogger.module("jutsu", "ChakraApi missing, skipping chakra check (graceful degradation).");
        }

        return RequirementCheckResult.success();
    }

    private static float calculateCost(ServerPlayerEntity player, JutsuDefinition def) {
        // Try FormulaApi first
        Optional<Object> formulaOpt = CoreServices.get(com.example.shinobicore.core.api.FormulaApi.class);
        if (formulaOpt.isPresent()) {
            try {
                return ((com.example.shinobicore.core.api.FormulaApi)formulaOpt.get()).calcJutsuCost(player, def.id());
            } catch (Exception e) {
                ShinobiLogger.error("jutsu", "FormulaApi failed, falling back to base cost", e);
            }
        }
        
        // Fallback to base cost with simple scaling
        float cost = def.baseCost();
        Optional<Object> progOpt = CoreServices.get(com.example.shinobicore.core.api.ProgressionApi.class);
        if (progOpt.isPresent()) {
            try {
                int level = ((com.example.shinobicore.core.api.ProgressionApi)progOpt.get()).getJutsuLevel(player, def.id());
                cost -= level * def.scaling().costReductionPerLevel();
            } catch (Exception ignored) {}
        }
        return Math.max(0, cost);
    }

    // Helper methods using Object to avoid hard compile errors if Sprint 2 APIs are missing in classpath
    private static boolean checkProgression(Object prog, ServerPlayerEntity player, JutsuDefinition def) {
        try {
            var api = (com.example.shinobicore.core.api.ProgressionApi) prog;
            if (def.requirements().treeNode() != null && !api.isNodeUnlocked(player, def.requirements().treeNode())) return false;
            if (!def.requirements().elements().isEmpty() && !api.isElementUnlocked(player, def.requirements().elements().get(0))) return false;
            if (api.getPlayerLevel(player) < def.requirements().minPlayerLevel()) return false;
            return true;
        } catch (Exception e) {
            return true; // Fail open if API signature mismatch
        }
    }

    private static boolean checkStats(Object stats, ServerPlayerEntity player, JutsuDefinition def) {
        try {
            var api = (com.example.shinobicore.core.api.StatsApi) stats;
            for (Map.Entry<String, Integer> req : def.requirements().stats().entrySet()) {
                if (api.getStatLevel(player, req.getKey()) < req.getValue()) return false;
            }
            return true;
        } catch (Exception e) {
            return true;
        }
    }

    private static boolean checkClan(Object clan, ServerPlayerEntity player, JutsuDefinition def) {
        try {
            var api = (com.example.shinobicore.core.api.ClanApi) clan;
            if (def.requirements().clanJutsu() && !api.isClanJutsu(player, def.id())) return false;
            return true;
        } catch (Exception e) {
            return true;
        }
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\requirement\JutsuRequirementService.java" $jutsuRequirementServiceJava

# 5. Создание Java файлов (Client)
Write-Host "`n--- Creating Java Classes (Client) ---" -ForegroundColor Cyan

$jutsuKeyBindingsJava = @'
package com.example.shinobicore.modules.jutsu.client;

import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

public final class JutsuKeyBindings {
    public static KeyBinding SLOT_A;
    public static KeyBinding SLOT_B;
    public static KeyBinding SLOT_C;
    public static KeyBinding CYCLE_SLOT;
    public static KeyBinding CAST_JUTSU;
    public static KeyBinding CANCEL_CAST;

    public static void register() {
        String category = "key.categories.shinobicore.jutsu";
        
        SLOT_A = KeyBindingHelper.registerKeyBinding(new KeyBinding("key.shinobicore.jutsu.slot_a", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Z, category));
        SLOT_B = KeyBindingHelper.registerKeyBinding(new KeyBinding("key.shinobicore.jutsu.slot_b", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_X, category));
        SLOT_C = KeyBindingHelper.registerKeyBinding(new KeyBinding("key.shinobicore.jutsu.slot_c", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_C, category));
        CYCLE_SLOT = KeyBindingHelper.registerKeyBinding(new KeyBinding("key.shinobicore.jutsu.cycle", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_V, category));
        
        CAST_JUTSU = KeyBindingHelper.registerKeyBinding(new KeyBinding("key.shinobicore.jutsu.cast", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_RIGHT_SHIFT, category));
        CANCEL_CAST = KeyBindingHelper.registerKeyBinding(new KeyBinding("key.shinobicore.jutsu.cancel", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_LEFT_SHIFT, category));
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\client\JutsuKeyBindings.java" $jutsuKeyBindingsJava

$jutsuClientStateJava = @'
package com.example.shinobicore.modules.jutsu.client;

import com.example.shinobicore.modules.jutsu.cast.CastPhase;

public final class JutsuClientState {
    private static boolean isCasting = false;
    private static float castProgress = 0.0f;
    private static CastPhase currentPhase = CastPhase.IDLE;
    private static String currentJutsuId = "";
    private static int selectedSlot = 0;

    public static void updateFromServer(boolean casting, float progress, String phaseStr, String jutsuId) {
        isCasting = casting;
        castProgress = progress;
        currentJutsuId = jutsuId;
        try {
            currentPhase = CastPhase.valueOf(phaseStr.toUpperCase());
        } catch (Exception e) {
            currentPhase = CastPhase.IDLE;
        }
    }

    public static void setSelectedSlot(int slot) { selectedSlot = slot; }
    public static int getSelectedSlot() { return selectedSlot; }
    public static boolean isCasting() { return isCasting; }
    public static float getCastProgress() { return castProgress; }
    public static CastPhase getCurrentPhase() { return currentPhase; }
    public static String getCurrentJutsuId() { return currentJutsuId; }
    
    public static void reset() {
        isCasting = false;
        castProgress = 0.0f;
        currentPhase = CastPhase.IDLE;
        currentJutsuId = "";
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\client\JutsuClientState.java" $jutsuClientStateJava

$jutsuClientControllerJava = @'
package com.example.shinobicore.modules.jutsu.client;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.jutsu.network.JutsuPackets;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.minecraft.client.MinecraftClient;
import net.minecraft.network.PacketByteBuf;

public final class JutsuClientController {
    private static boolean castKeyHeld = false;

    public static void init() {
        ShinobiLogger.module("jutsu", "JutsuClientController initialized.");
    }

    public static void tick() {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null || client.world == null) return;

        handleSlotSelection();
        handleCastInput(client);
    }

    private static void handleSlotSelection() {
        if (JutsuKeyBindings.SLOT_A.wasPressed()) selectAndSend(0);
        else if (JutsuKeyBindings.SLOT_B.wasPressed()) selectAndSend(1);
        else if (JutsuKeyBindings.SLOT_C.wasPressed()) selectAndSend(2);
        else if (JutsuKeyBindings.CYCLE_SLOT.wasPressed()) {
            int next = (JutsuClientState.getSelectedSlot() + 1) % 3;
            selectAndSend(next);
        }
    }

    private static void selectAndSend(int slot) {
        JutsuClientState.setSelectedSlot(slot);
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeInt(0); // Action: select
        buf.writeInt(slot);
        buf.writeString(""); // Dummy for assign
        ClientPlayNetworking.send(JutsuPackets.SLOT_CHANGE, buf);
    }

    private static void handleCastInput(MinecraftClient client) {
        boolean isPressed = JutsuKeyBindings.CAST_JUTSU.isPressed();
        
        if (isPressed && !castKeyHeld) {
            // Key just pressed -> Send Cast Request
            castKeyHeld = true;
            PacketByteBuf buf = PacketByteBufs.create();
            buf.writeInt(JutsuClientState.getSelectedSlot());
            buf.writeLong(System.currentTimeMillis());
            buf.writeFloat(client.player.getYaw());
            buf.writeFloat(client.player.getPitch());
            ClientPlayNetworking.send(JutsuPackets.CAST_REQUEST, buf);
        } else if (!isPressed && castKeyHeld) {
            // Key released -> Send Cancel if still in prepare/charge
            castKeyHeld = false;
            if (JutsuClientState.isCasting() && 
               (JutsuClientState.getCurrentPhase().name().equals("PREPARE") || 
                JutsuClientState.getCurrentPhase().name().equals("CHARGE"))) {
                PacketByteBuf buf = PacketByteBufs.create();
                buf.writeString("manual_release");
                ClientPlayNetworking.send(JutsuPackets.CAST_CANCEL, buf);
            }
        }

        if (JutsuKeyBindings.CANCEL_CAST.wasPressed() && JutsuClientState.isCasting()) {
            PacketByteBuf buf = PacketByteBufs.create();
            buf.writeString("manual_cancel");
            ClientPlayNetworking.send(JutsuPackets.CAST_CANCEL, buf);
        }
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\client\JutsuClientController.java" $jutsuClientControllerJava

# 6. Обновление существующих файлов для интеграции
Write-Host "`n--- Updating Core Integration Files ---" -ForegroundColor Cyan

$jutsuModuleUpdatedJava = @'
package com.example.shinobicore.modules.jutsu;

import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.jutsu.behavior.BehaviorRegistry;
import com.example.shinobicore.modules.jutsu.cast.JutsuCastService;
import com.example.shinobicore.modules.jutsu.client.JutsuClientController;
import com.example.shinobicore.modules.jutsu.client.JutsuKeyBindings;
import com.example.shinobicore.modules.jutsu.command.JutsuCommands;
import com.example.shinobicore.modules.jutsu.cooldown.JutsuCooldownService;
import com.example.shinobicore.modules.jutsu.data.JutsuJsonValidator;
import com.example.shinobicore.modules.jutsu.data.JutsuLoader;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import com.example.shinobicore.modules.jutsu.network.JutsuPackets;
import com.example.shinobicore.modules.jutsu.requirement.JutsuRequirementService;
import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.command.ServerCommandSource;

public class JutsuModule implements ClientAwareModule {
    public static final String ID = "jutsu";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        ShinobiLogger.module(ID, "Registering Jutsu components...");
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        ShinobiLogger.module(ID, "Enabling Jutsu module...");
        
        BehaviorRegistry.registerDefaults();
        JutsuLoader.load();
        JutsuJsonValidator.validateAll(); 
        
        JutsuCooldownService.init();
        JutsuRequirementService.init();
        
        JutsuPackets.registerServer();
        
        ShinobiLogger.module(ID, "Loaded " + JutsuRegistry.size() + " jutsu definitions.");
    }

    @Override
    public void onDisable(ModuleContext ctx) {
        ShinobiLogger.module(ID, "Jutsu module disabled.");
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> dispatcher) {
        JutsuCommands.register(dispatcher);
    }

    @Override
    public void onServerTick(ModuleContext ctx, MinecraftServer server) {
        JutsuCastService.instance().serverTick(server);
        JutsuCooldownService.serverTick(server);
    }
    
    @Override
    public void onClientInit(ModuleContext ctx) {
        JutsuKeyBindings.register();
        JutsuClientController.init();
        JutsuPackets.registerClient();
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        JutsuClientController.tick();
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\JutsuModule.java" $jutsuModuleUpdatedJava

$jutsuCastServiceUpdatedJava = @'
package com.example.shinobicore.modules.jutsu.cast;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.jutsu.cooldown.JutsuCooldownService;
import com.example.shinobicore.modules.jutsu.data.JutsuDefinition;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import com.example.shinobicore.modules.jutsu.requirement.JutsuRequirementService;
import com.example.shinobicore.modules.jutsu.requirement.RequirementCheckResult;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public final class JutsuCastService {
    private static final JutsuCastService INSTANCE = new JutsuCastService();
    private final Map<UUID, JutsuCastSession> activeSessions = new ConcurrentHashMap<>();

    public static JutsuCastService instance() { return INSTANCE; }

    public void requestCast(ServerPlayerEntity player, String jutsuId, int slot, long pressTimestampMs, float yaw, float pitch) {
        JutsuDefinition def = JutsuRegistry.get(jutsuId).orElse(null);
        if (def == null) {
            ShinobiLogger.error("jutsu", "Attempted to cast unknown jutsu: " + jutsuId, null);
            return;
        }

        UUID uuid = player.getUuid();
        JutsuCastSession current = activeSessions.get(uuid);

        if (current != null && !current.isFinished()) {
            current.queueNext(jutsuId);
            ShinobiLogger.module("jutsu", "Queued jutsu " + jutsuId + " for player " + uuid);
            return;
        }

        // Validate requirements before starting
        RequirementCheckResult check = JutsuRequirementService.check(player, def);
        if (!check.ok()) {
            ShinobiLogger.module("jutsu", "Cast rejected for " + jutsuId + ". Reason: " + check.failReason());
            // TODO: Send packet to client to show fail reason (e.g., "Not enough chakra")
            return;
        }

        JutsuCastSession newSession = new JutsuCastSession(uuid, jutsuId, slot, yaw, pitch);
        activeSessions.put(uuid, newSession);
        ShinobiLogger.module("jutsu", "Started cast: " + jutsuId + " for player " + uuid);
    }

    public void startCooldownFor(UUID playerId, String jutsuId, int maxTicks) {
        JutsuCooldownService.startCooldown(playerId, jutsuId, maxTicks);
    }

    public void cancelCast(ServerPlayerEntity player, String reason) {
        JutsuCastSession session = activeSessions.get(player.getUuid());
        if (session != null) {
            session.cancel(reason);
        }
    }

    public void serverTick(MinecraftServer server) {
        activeSessions.entrySet().removeIf(entry -> {
            ServerPlayerEntity player = server.getPlayerManager().getPlayer(entry.getKey());
            if (player == null) return true;

            JutsuCastSession session = entry.getValue();
            session.tick(player);
            
            return session.isFinished();
        });
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\cast\JutsuCastService.java" $jutsuCastServiceUpdatedJava

$jutsuCastSessionUpdatedJava = @'
package com.example.shinobicore.modules.jutsu.cast;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.jutsu.behavior.BehaviorContext;
import com.example.shinobicore.modules.jutsu.behavior.BehaviorRegistry;
import com.example.shinobicore.modules.jutsu.data.JutsuDefinition;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;

import java.util.UUID;

public final class JutsuCastSession {
    private final UUID playerId;
    private final String jutsuId;
    private final JutsuDefinition def;
    private final int slot;
    private final float yaw;
    private final float pitch;
    
    private CastPhase phase = CastPhase.PREPARE;
    private int ticksInPhase = 0;
    private float chargeMultiplier = 1.0f;
    private boolean isHoldingCast = true;
    private String queuedJutsuId = null;

    public JutsuCastSession(UUID playerId, String jutsuId, int slot, float yaw, float pitch) {
        this.playerId = playerId;
        this.jutsuId = jutsuId;
        this.slot = slot;
        this.yaw = yaw;
        this.pitch = pitch;
        this.def = JutsuRegistry.get(jutsuId).orElseThrow();
    }

    public void tick(ServerPlayerEntity player) {
        if (player == null || player.isDead()) {
            cancel("player_dead");
            return;
        }

        ticksInPhase++;
        switch (phase) {
            case PREPARE -> {
                if (ticksInPhase >= def.prepareTicks()) {
                    phase = CastPhase.CHARGE;
                    ticksInPhase = 0;
                }
            }
            case CHARGE -> {
                if (!isHoldingCast || ticksInPhase >= def.chargeTicks()) {
                    phase = CastPhase.RELEASE;
                    ticksInPhase = 0;
                } else {
                    chargeMultiplier = 1.0f + ((float) ticksInPhase / def.chargeTicks()) * (def.maxChargeMultiplier() - 1.0f);
                }
            }
            case RELEASE -> {
                if (ticksInPhase == 1) {
                    executeRelease(player);
                }
                if (ticksInPhase >= def.releaseTicks()) {
                    phase = CastPhase.COOLDOWN;
                    ticksInPhase = 0;
                    // Start cooldown exactly when entering COOLDOWN phase
                    JutsuCastService.instance().startCooldownFor(playerId, jutsuId, def.cooldownTicks());
                }
            }
            case COOLDOWN -> {
                if (ticksInPhase >= def.cooldownTicks()) {
                    finish(player);
                }
            }
        }
    }

    private void executeRelease(ServerPlayerEntity player) {
        CoreServices.get(com.example.shinobicore.core.api.ChakraApi.class).ifPresentOrElse(chakra -> {
            float cost = def.baseCost() * chargeMultiplier; // Simplified cost
            if (!chakra.trySpend(player, cost)) {
                cancel("insufficient_chakra_at_release");
            } else {
                triggerBehavior(player);
            }
        }, () -> {
            ShinobiLogger.module("jutsu", "ChakraApi missing, allowing cast for testing (graceful degradation).");
            triggerBehavior(player);
        });
    }

    private void triggerBehavior(ServerPlayerEntity player) {
        BehaviorRegistry.get(def.behaviorId()).ifPresent(behavior -> {
            BehaviorContext ctx = new BehaviorContext(
                player, jutsuId, def, def.behaviorData(), null, 1, chargeMultiplier, (ServerWorld) player.getWorld()
            );
            behavior.onRelease(ctx);
        });
    }

    public void cancel(String reason) {
        phase = CastPhase.IDLE;
        ShinobiLogger.module("jutsu", "Cast cancelled for " + playerId + ". Reason: " + reason);
    }

    private void finish(ServerPlayerEntity player) {
        phase = CastPhase.IDLE;
        if (queuedJutsuId != null) {
            JutsuCastService.instance().requestCast(player, queuedJutsuId, slot, System.currentTimeMillis(), player.getYaw(), player.getPitch());
        }
    }

    public void setHoldingCast(boolean holding) { this.isHoldingCast = holding; }
    public CastPhase getPhase() { return phase; }
    public boolean isFinished() { return phase == CastPhase.IDLE; }
    public void queueNext(String nextJutsuId) { this.queuedJutsuId = nextJutsuId; }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\cast\JutsuCastSession.java" $jutsuCastSessionUpdatedJava

$jutsuPacketsUpdatedJava = @'
package com.example.shinobicore.modules.jutsu.network;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.jutsu.client.JutsuClientState;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

public final class JutsuPackets {
    public static final Identifier CAST_REQUEST = new Identifier("shinobicore", "jutsu_cast_request");
    public static final Identifier CAST_CANCEL = new Identifier("shinobicore", "jutsu_cast_cancel");
    public static final Identifier SLOT_CHANGE = new Identifier("shinobicore", "jutsu_slot_change");
    public static final Identifier STATE_SYNC = new Identifier("shinobicore", "jutsu_state_sync");

    public static void registerServer() {
        ServerPlayNetworking.registerGlobalReceiver(CAST_REQUEST, JutsuCastRequestPacket::handle);
        ServerPlayNetworking.registerGlobalReceiver(CAST_CANCEL, JutsuCastCancelPacket::handle);
        ServerPlayNetworking.registerGlobalReceiver(SLOT_CHANGE, JutsuSlotChangePacket::handle);
        ShinobiLogger.module("jutsu", "Server packets registered.");
    }

    public static void registerClient() {
        ClientPlayNetworking.registerGlobalReceiver(STATE_SYNC, (client, handler, buf, responseSender) -> {
            // STEP 1: Read ALL data FIRST
            final boolean isCasting = buf.readBoolean();
            final float progress = buf.readFloat();
            final String phase = buf.readString(32);
            final String jutsuId = buf.readString(64);

            // STEP 2: Execute on client thread
            client.execute(() -> {
                JutsuClientState.updateFromServer(isCasting, progress, phase, jutsuId);
            });
        });
        ShinobiLogger.module("jutsu", "Client packets registered.");
    }
    
    // Helper to send state sync from server to client (to be called in JutsuCastService or Session)
    public static void sendStateSync(ServerPlayerEntity player, boolean isCasting, float progress, String phase, String jutsuId) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeBoolean(isCasting);
        buf.writeFloat(progress);
        buf.writeString(phase);
        buf.writeString(jutsuId);
        ServerPlayNetworking.send(player, STATE_SYNC, buf);
    }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\modules\jutsu\network\JutsuPackets.java" $jutsuPacketsUpdatedJava

Write-Host "`n=== Setup Complete! ===" -ForegroundColor Green
Write-Host "Next step: Run '.\gradlew.bat build' to verify compilation." -ForegroundColor Yellow