# =========================================================================
# MASTER SCRIPT: ShinobiCore Combat Module - Steps A, B, and C
# Ensures UTF-8 without BOM (TZ Rule 6.4)
# =========================================================================

$baseDir = "src/main/java/com/example/shinobicore/modules/combat"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

Write-Host "Creating directory structure..." -ForegroundColor Cyan
$dirs = @(
    "$baseDir/common", "$baseDir/compat", "$baseDir/component",
    "$baseDir/service", "$baseDir/input", "$baseDir/client",
    "$baseDir/network", "$baseDir/view", "$baseDir/config",
    "$baseDir/data", "$baseDir/render", "$baseDir/audio"
)
foreach ($dir in $dirs) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

# Helper function to write files safely
function Write-File {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  Created: $Path" -ForegroundColor Gray
}

# =====================================================================
# 1. COMMON & COMPAT (Step B)
# =====================================================================
Write-Host "Writing Common & Compat files..." -ForegroundColor Cyan

Write-File "$baseDir/common/Stance.java" @"
package com.example.shinobicore.modules.combat.common;

public enum Stance {
    AGGRESSIVE,
    DEFENSIVE,
    NONE;

    public static Stance fromOrdinal(int ordinal) {
        if (ordinal < 0 || ordinal >= values().length) return NONE;
        return values()[ordinal];
    }
}
"@

Write-File "$baseDir/common/WeaponClass.java" @"
package com.example.shinobicore.modules.combat.common;

public enum WeaponClass {
    KATANA, KUNAI, SHURIKEN, UNARMED, UNKNOWN;

    public static WeaponClass fromString(String name) {
        for (WeaponClass wc : values()) {
            if (wc.name().equalsIgnoreCase(name)) return wc;
        }
        return UNKNOWN;
    }
}
"@

Write-File "$baseDir/compat/CombatCompatibilityChecker.java" @"
package com.example.shinobicore.modules.combat.compat;

import net.fabricmc.loader.api.FabricLoader;

public final class CombatCompatibilityChecker {
    private CombatCompatibilityChecker() {}
    public static boolean isBetterCombatOk() {
        return FabricLoader.getInstance().isModLoaded("bettercombat");
    }
}
"@

Write-File "$baseDir/compat/BetterCombatAdapter.java" @"
package com.example.shinobicore.modules.combat.compat;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.combat.common.WeaponClass;
import net.fabricmc.loader.api.FabricLoader;
import net.minecraft.item.ItemStack;

public final class BetterCombatAdapter {
    private static boolean enabled = false;
    private static String status = "not initialized";

    private BetterCombatAdapter() {}

    public static void init() {
        if (FabricLoader.getInstance().isModLoaded("bettercombat")) {
            enabled = true;
            status = "loaded";
            ShinobiLogger.module("combat", "Better Combat detected, delegating melee.");
        } else {
            enabled = false;
            status = "not installed";
            ShinobiLogger.error("combat", "Better Combat NOT installed. Adapter disabled.", null);
        }
    }

    public static boolean isEnabled() { return enabled; }
    public static String getStatus() { return status; }

    public static WeaponClass resolveWeaponClass(ItemStack stack) {
        if (!enabled || stack.isEmpty()) return WeaponClass.UNARMED;
        String itemId = stack.getItem().getTranslationKey();
        if (itemId.contains("katana")) return WeaponClass.KATANA;
        if (itemId.contains("kunai")) return WeaponClass.KUNAI;
        if (itemId.contains("shuriken")) return WeaponClass.SHURIKEN;
        return WeaponClass.UNARMED;
    }
}
"@

# =====================================================================
# 2. COMPONENT (CCA) (Step A)
# =====================================================================
Write-Host "Writing Component files..." -ForegroundColor Cyan

Write-File "$baseDir/component/CombatComponent.java" @"
package com.example.shinobicore.modules.combat.component;

import com.example.shinobicore.modules.combat.common.Stance;
import dev.onyxstudios.cca.api.v3.component.Component;

public interface CombatComponent extends Component {
    Stance getStance();
    void setStance(Stance stance);
    boolean isBlocking();
    void setBlocking(boolean blocking);
    boolean isParrying();
    void setParrying(boolean parrying);
    int getComboStep();
    void setComboStep(int step);
    void resetCombo();
    boolean isSheathed();
    void setSheathed(boolean sheathed);
    long getParryFailRecoveryUntil();
    void setParryFailRecoveryUntil(long timestampMs);
    long getComboExpireAtMs();
    void setComboExpireAtMs(long timestampMs);
}
"@

Write-File "$baseDir/component/CombatComponentKey.java" @"
package com.example.shinobicore.modules.combat.component;

import dev.onyxstudios.cca.api.v3.component.ComponentKey;
import dev.onyxstudios.cca.api.v3.component.ComponentRegistry;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentFactoryRegistry;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentInitializer;
import dev.onyxstudios.cca.api.v3.entity.RespawnCopyStrategy;
import net.minecraft.util.Identifier;

public final class CombatComponentKey implements EntityComponentInitializer {
    public static final Identifier ID = new Identifier("shinobicore", "combat");
    public static final ComponentKey<CombatComponent> KEY = 
            ComponentRegistry.getOrCreate(ID, CombatComponent.class);

    @Override
    public void registerEntityComponentFactories(EntityComponentFactoryRegistry registry) {
        registry.registerForPlayers(KEY, player -> new CombatComponentImpl(), RespawnCopyStrategy.ALWAYS_COPY);
    }

    public static void register() {
        // Static initialization triggers registry
    }
}
"@

Write-File "$baseDir/component/CombatComponentImpl.java" @"
package com.example.shinobicore.modules.combat.component;

import com.example.shinobicore.modules.combat.common.Stance;
import net.minecraft.nbt.NbtCompound;

public class CombatComponentImpl implements CombatComponent {
    private Stance stance = Stance.NONE;
    private boolean blocking = false;
    private boolean parrying = false;
    private int comboStep = 0;
    private boolean sheathed = false;
    private long parryFailRecoveryUntil = 0;
    private long comboExpireAtMs = 0;

    @Override public Stance getStance() { return stance; }
    @Override public void setStance(Stance stance) { this.stance = stance; }
    @Override public boolean isBlocking() { return blocking; }
    @Override public void setBlocking(boolean blocking) { this.blocking = blocking; }
    @Override public boolean isParrying() { return parrying; }
    @Override public void setParrying(boolean parrying) { this.parrying = parrying; }
    @Override public int getComboStep() { return comboStep; }
    @Override public void setComboStep(int step) { this.comboStep = step; }
    @Override public void resetCombo() { this.comboStep = 0; this.comboExpireAtMs = 0; }
    @Override public boolean isSheathed() { return sheathed; }
    @Override public void setSheathed(boolean sheathed) { this.sheathed = sheathed; }
    @Override public long getParryFailRecoveryUntil() { return parryFailRecoveryUntil; }
    @Override public void setParryFailRecoveryUntil(long timestampMs) { this.parryFailRecoveryUntil = timestampMs; }
    @Override public long getComboExpireAtMs() { return comboExpireAtMs; }
    @Override public void setComboExpireAtMs(long timestampMs) { this.comboExpireAtMs = timestampMs; }

    @Override
    public void readFromNbt(NbtCompound tag) {
        this.stance = Stance.fromOrdinal(tag.getInt("Stance"));
        this.blocking = tag.getBoolean("Blocking");
        this.parrying = tag.getBoolean("Parrying");
        this.comboStep = tag.getInt("ComboStep");
        this.sheathed = tag.getBoolean("Sheathed");
        this.parryFailRecoveryUntil = tag.getLong("ParryFailRecovery");
        this.comboExpireAtMs = tag.getLong("ComboExpire");
    }

    @Override
    public void writeFromNbt(NbtCompound tag) {
        tag.putInt("Stance", stance.ordinal());
        tag.putBoolean("Blocking", blocking);
        tag.putBoolean("Parrying", parrying);
        tag.putInt("ComboStep", comboStep);
        tag.putBoolean("Sheathed", sheathed);
        tag.putLong("ParryFailRecovery", parryFailRecoveryUntil);
        tag.putLong("ComboExpire", comboExpireAtMs);
    }
}
"@

# =====================================================================
# 3. SERVICES (Stubs for compilation) (Step A/B)
# =====================================================================
Write-Host "Writing Service stubs..." -ForegroundColor Cyan

$services = @("StanceService", "BlockService", "ParryService", "ComboTracker", "SheathService", "ProjectileDeflectService")
foreach ($svc in $services) {
    Write-File "$baseDir/service/${svc}.java" @"
package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.api.ModuleContext;
import net.minecraft.server.MinecraftServer;

public final class $svc {
    public static void init(ModuleContext ctx) { }
    public static void serverTick(MinecraftServer server) { }
}
"@
}

# =====================================================================
# 4. CLIENT & INPUT (Step C)
# =====================================================================
Write-Host "Writing Client & Input files..." -ForegroundColor Cyan

Write-File "$baseDir/client/CombatClientState.java" @"
package com.example.shinobicore.modules.combat.client;

import com.example.shinobicore.modules.combat.common.Stance;

public final class CombatClientState {
    private static Stance currentStance = Stance.NONE;
    private static boolean isSheathed = false;
    private static boolean inCombatContext = false;

    public static Stance getCurrentStance() { return currentStance; }
    public static void setCurrentStance(Stance stance) { currentStance = stance; }
    
    public static boolean isSheathed() { return isSheathed; }
    public static void setSheathed(boolean sheathed) { isSheathed = sheathed; }
    
    public static boolean isInCombatContext() { return inCombatContext; }
    public static void setInCombatContext(boolean inContext) { inCombatContext = inContext; }
}
"@

Write-File "$baseDir/input/CombatKeyBindings.java" @"
package com.example.shinobicore.modules.combat.input;

import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

public final class CombatKeyBindings {
    public static KeyBinding stanceToggle;
    public static KeyBinding kick;
    public static KeyBinding sheathToggle;
    public static KeyBinding quickSlot;

    public static void register() {
        stanceToggle = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.combat.stance", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_V, "category.shinobicore.combat"));
        
        kick = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.combat.kick", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_F, "category.shinobicore.combat"));
            
        sheathToggle = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.combat.sheath", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_H, "category.shinobicore.combat"));
            
        quickSlot = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.combat.quickslot", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_R, "category.shinobicore.combat"));
    }
}
"@

Write-File "$baseDir/input/CombatInputDispatcher.java" @"
package com.example.shinobicore.modules.combat.input;

import com.example.shinobicore.modules.combat.client.CombatClientState;
import com.example.shinobicore.modules.combat.common.Stance;
import com.example.shinobicore.modules.combat.network.CombatPackets;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.util.ActionResult;
import net.minecraft.util.Hand;

public final class CombatInputDispatcher {

    public static ActionResult onUseItem(ClientPlayerEntity player, Hand hand) {
        if (hand != Hand.MAIN_HAND) return ActionResult.PASS;
        if (!CombatClientState.isInCombatContext()) {
            return ActionResult.PASS; // Let vanilla handle eating, bows, etc.
        }

        ItemStack mainHand = player.getMainHandStack();
        String itemId = mainHand.getItem().getTranslationKey();

        // Priority 1: Throw (if holding throwable)
        if (itemId.contains("shuriken") || itemId.contains("kunai")) {
            CombatPackets.sendThrow(player.getYaw(), player.getPitch());
            return ActionResult.SUCCESS;
        }

        // Priority 2: Parry (Defensive stance)
        if (CombatClientState.getCurrentStance() == Stance.DEFENSIVE) {
            CombatPackets.sendParryAttempt(System.currentTimeMillis());
            return ActionResult.SUCCESS;
        }

        // Priority 3: Block (Aggressive stance + melee)
        if (CombatClientState.getCurrentStance() == Stance.AGGRESSIVE && !itemId.contains("shuriken") && !itemId.contains("kunai")) {
            CombatPackets.sendBlockStart();
            return ActionResult.SUCCESS;
        }

        // Priority 4: Sheath toggle (if katana and sheathed, quick draw)
        if (CombatClientState.isSheathed() && itemId.contains("katana")) {
            CombatPackets.sendSheathToggle();
            return ActionResult.SUCCESS;
        }

        return ActionResult.PASS;
    }
}
"@

Write-File "$baseDir/input/CombatInputHandler.java" @"
package com.example.shinobicore.modules.combat.input;

import com.example.shinobicore.modules.combat.client.CombatClientState;
import com.example.shinobicore.modules.combat.common.Stance;
import com.example.shinobicore.modules.combat.network.CombatPackets;
import net.minecraft.client.MinecraftClient;

public final class CombatInputHandler {

    public static void tick() {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null || client.world == null) return;

        // Stance Toggle
        while (CombatKeyBindings.stanceToggle.wasPressed()) {
            Stance next = (CombatClientState.getCurrentStance() == Stance.AGGRESSIVE) ? Stance.DEFENSIVE : Stance.AGGRESSIVE;
            CombatClientState.setCurrentStance(next);
            CombatPackets.sendStanceChange(next.ordinal());
        }

        // Sheath Toggle
        while (CombatKeyBindings.sheathToggle.wasPressed()) {
            CombatClientState.setSheathed(!CombatClientState.isSheathed());
            CombatPackets.sendSheathToggle();
        }

        // Kick
        while (CombatKeyBindings.kick.wasPressed()) {
            CombatPackets.sendKick();
        }

        // Quick Slot
        while (CombatKeyBindings.quickSlot.wasPressed()) {
            CombatPackets.sendQuickSlotCycle();
        }
    }
}
"@

# =====================================================================
# 5. NETWORK (Unified Packets)
# =====================================================================
Write-Host "Writing Network files..." -ForegroundColor Cyan

Write-File "$baseDir/network/CombatPackets.java" @"
package com.example.shinobicore.modules.combat.network;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.combat.common.Stance;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

public final class CombatPackets {
    private static final Identifier STANCE_CHANGE = new Identifier("shinobicore", "combat_stance_change");
    private static final Identifier BLOCK_START = new Identifier("shinobicore", "combat_block_start");
    private static final Identifier PARRY_ATTEMPT = new Identifier("shinobicore", "combat_parry_attempt");
    private static final Identifier THROW = new Identifier("shinobicore", "combat_throw");
    private static final Identifier SHEATH_TOGGLE = new Identifier("shinobicore", "combat_sheath_toggle");
    private static final Identifier KICK = new Identifier("shinobicore", "combat_kick");
    private static final Identifier QUICK_SLOT = new Identifier("shinobicore", "combat_quick_slot");
    private static final Identifier STATE_SYNC = new Identifier("shinobicore", "combat_state_sync");

    public static void registerServer() {
        ServerPlayNetworking.registerGlobalReceiver(STANCE_CHANGE, (server, player, handler, buf, sender) -> {
            final int stanceOrdinal = buf.readInt();
            server.execute(() -> {
                ShinobiLogger.module("combat", "Server received stance change: " + stanceOrdinal + " from " + player.getName().getString());
                // TODO: Validate and call StanceService
            });
        });
        
        ServerPlayNetworking.registerGlobalReceiver(PARRY_ATTEMPT, (server, player, handler, buf, sender) -> {
            final long pressTimeMs = buf.readLong();
            server.execute(() -> {
                ShinobiLogger.module("combat", "Server received parry attempt at " + pressTimeMs);
                // TODO: Validate and call ParryService
            });
        });

        // Register other receivers similarly...
        ShinobiLogger.module("combat", "Server combat packets registered");
    }

    public static void registerClient() {
        ClientPlayNetworking.registerGlobalReceiver(STATE_SYNC, (client, handler, buf, sender) -> {
            final int stanceOrdinal = buf.readInt();
            final boolean isSheathed = buf.readBoolean();
            client.execute(() -> {
                com.example.shinobicore.modules.combat.client.CombatClientState.setCurrentStance(Stance.fromOrdinal(stanceOrdinal));
                com.example.shinobicore.modules.combat.client.CombatClientState.setSheathed(isSheathed);
            });
        });
        ShinobiLogger.module("combat", "Client combat packets registered");
    }

    // --- Client Send Methods ---
    public static void sendStanceChange(int stanceOrdinal) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeInt(stanceOrdinal);
        ClientPlayNetworking.send(STANCE_CHANGE, buf);
    }

    public static void sendParryAttempt(long pressTimeMs) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeLong(pressTimeMs);
        ClientPlayNetworking.send(PARRY_ATTEMPT, buf);
    }

    public static void sendBlockStart() {
        ClientPlayNetworking.send(BLOCK_START, PacketByteBufs.create());
    }

    public static void sendThrow(float yaw, float pitch) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeFloat(yaw);
        buf.writeFloat(pitch);
        ClientPlayNetworking.send(THROW, buf);
    }

    public static void sendSheathToggle() {
        ClientPlayNetworking.send(SHEATH_TOGGLE, PacketByteBufs.create());
    }

    public static void sendKick() {
        ClientPlayNetworking.send(KICK, PacketByteBufs.create());
    }

    public static void sendQuickSlotCycle() {
        ClientPlayNetworking.send(QUICK_SLOT, PacketByteBufs.create());
    }
}
"@

# =====================================================================
# 6. VIEW & MODULE ENTRY
# =====================================================================
Write-Host "Writing View and Module Entry files..." -ForegroundColor Cyan

Write-File "$baseDir/view/CombatVisualView.java" @"
package com.example.shinobicore.modules.combat.view;

public interface CombatVisualView {
    String getCurrentStance();
    boolean isBlocking();
    boolean isParrying();
    int getComboStep();
    boolean isSheathed();
    boolean isThrowing();
    float getBlockProgress();
    float getParryWindowProgress();
    String getWeaponClass();
}
"@

Write-File "$baseDir/view/CombatVisualViewImpl.java" @"
package com.example.shinobicore.modules.combat.view;

import com.example.shinobicore.modules.combat.common.Stance;
import com.example.shinobicore.modules.combat.component.CombatComponent;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import net.minecraft.entity.player.PlayerEntity;
import java.util.Optional;

public class CombatVisualViewImpl implements CombatVisualView {
    private final PlayerEntity player;

    public CombatVisualViewImpl(PlayerEntity player) {
        this.player = player;
    }

    @Override
    public String getCurrentStance() {
        return getComp().map(c -> c.getStance().name().toLowerCase()).orElse("none");
    }

    @Override
    public boolean isBlocking() {
        return getComp().map(CombatComponent::isBlocking).orElse(false);
    }

    @Override
    public boolean isParrying() {
        return getComp().map(CombatComponent::isParrying).orElse(false);
    }

    @Override
    public int getComboStep() {
        return getComp().map(CombatComponent::getComboStep).orElse(0);
    }

    @Override
    public boolean isSheathed() {
        return getComp().map(CombatComponent::isSheathed).orElse(false);
    }

    @Override
    public boolean isThrowing() {
        return false; // TODO: Implement
    }

    @Override
    public float getBlockProgress() {
        return 0.0f; // TODO: Implement
    }

    @Override
    public float getParryWindowProgress() {
        return 0.0f; // TODO: Implement
    }

    @Override
    public String getWeaponClass() {
        return "katana"; // TODO: Resolve from BetterCombatAdapter
    }

    private Optional<CombatComponent> getComp() {
        return Optional.ofNullable(CombatComponentKey.KEY.getNullable(player));
    }
}
"@

Write-File "$baseDir/CombatModule.java" @"
package com.example.shinobicore.modules.combat;

import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.event.*;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.module.ModuleManager;
import com.example.shinobicore.modules.combat.compat.BetterCombatAdapter;
import com.example.shinobicore.modules.combat.compat.CombatCompatibilityChecker;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import com.example.shinobicore.modules.combat.input.CombatInputHandler;
import com.example.shinobicore.modules.combat.input.CombatKeyBindings;
import com.example.shinobicore.modules.combat.network.CombatPackets;
import com.example.shinobicore.modules.combat.service.*;
import com.example.shinobicore.modules.combat.view.CombatVisualView;
import com.example.shinobicore.modules.combat.view.CombatVisualViewImpl;
import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.command.ServerCommandSource;

public class CombatModule implements ClientAwareModule {
    public static final String ID = "combat";

    @Override public String id() { return ID; }

    @Override
    public void onRegister(ModuleContext ctx) {
        CombatComponentKey.register();
        ShinobiLogger.module(ID, "Combat component key registered");
    }

    @Override
    public void onEnable(ModuleContext ctx) {
        if (!CombatCompatibilityChecker.isBetterCombatOk()) {
            ShinobiLogger.error(ID, "Better Combat is REQUIRED but not detected. Disabling module.", null);
            ctx.events().publish(new ModuleDisabledEvent(ID, "Missing required mod: bettercombat"));
            ModuleManager.disable(ID, "Missing Better Combat");
            return;
        }

        BetterCombatAdapter.init();
        
        StanceService.init(ctx);
        BlockService.init(ctx);
        ParryService.init(ctx);
        SheathService.init(ctx);
        ProjectileDeflectService.init(ctx);
        ComboTracker.init(ctx);

        CombatPackets.registerServer();
        ShinobiLogger.module(ID, "Combat module enabled successfully");
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        ctx.events().subscribe(PlayerDiedEvent.class, e -> {
            var comp = CombatComponentKey.KEY.getNullable(e.player());
            if (comp != null) {
                comp.setStance(com.example.shinobicore.modules.combat.common.Stance.NONE);
                comp.setBlocking(false);
                comp.setParrying(false);
                comp.resetCombo();
                comp.setSheathed(false);
            }
        });
        ctx.events().subscribe(PlayerRespawnedEvent.class, e -> {
            // Reset to default
        });
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        ctx.views().register(CombatVisualView.class, player ->
            java.util.Optional.of(new CombatVisualViewImpl(player)));
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> dispatcher) {
        // TODO: Register combat commands
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        CombatKeyBindings.register();
        CombatPackets.registerClient();
        ShinobiLogger.module(ID, "Combat client initialized");
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        CombatInputHandler.tick();
    }

    @Override
    public void onServerTick(ModuleContext ctx, MinecraftServer server) {
        BlockService.serverTick(server);
        ParryService.serverTick(server);
        ProjectileDeflectService.serverTick(server);
        ComboTracker.serverTick(server);
    }
}
"@

Write-Host "=========================================================" -ForegroundColor Green
Write-Host " SUCCESS: Steps A, B, and C completed!" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "Files created in: src/main/java/com/example/shinobicore/modules/combat/" -ForegroundColor Yellow
Write-Host "Next step: Run '.\gradlew.bat build' to verify compilation." -ForegroundColor Cyan