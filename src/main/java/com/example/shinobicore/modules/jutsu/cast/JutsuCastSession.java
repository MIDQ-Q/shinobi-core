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