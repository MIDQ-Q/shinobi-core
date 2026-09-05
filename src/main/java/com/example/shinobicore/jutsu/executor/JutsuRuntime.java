package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.entity.event.v1.ServerLivingEntityEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.fabricmc.fabric.api.event.player.AttackEntityCallback;

public class JutsuRuntime {

    public static void register() {
        ServerTickEvents.END_SERVER_TICK.register(server -> {
            ProjectileSystem.tick(server);
            HandheldSystem.tick(server);
            DashSystem.tick(server);
            ZoneSystem.tick(server);
            BeamSystem.tick(server);
            ConstructSystem.tick(server);
            TempBlockSystem.tick(server);
            DelayedExplosionSystem.tick(server);
            StatusSystem.tick(server);
            CooldownSystem.tick();
            ActivationSystem.tick(server);
            StickSystem.tick(server);
            OrbitingSystem.tick(server);
            com.example.shinobicore.ai.AiSystem.tick(server);
        });

        AttackEntityCallback.EVENT.register((player, world, hand, entity, hitResult) -> {
            if (player instanceof net.minecraft.server.network.ServerPlayerEntity sp) {
                if (entity instanceof net.minecraft.entity.LivingEntity living) {
                    HandheldSystem.onPlayerHit(sp, living);
                }
            }
            return net.minecraft.util.ActionResult.PASS;
        });

        ServerLivingEntityEvents.ALLOW_DAMAGE.register((entity, source, amount) -> {
            if (entity instanceof net.minecraft.server.network.ServerPlayerEntity sp) {
                if (source.getAttacker() instanceof net.minecraft.entity.LivingEntity att) {
                    com.example.shinobicore.ai.AiSystem.noteOwnerAttacker(sp.getUuid(), att.getUuid());
                }
                if (!ActivationSystem.onDamageTaken(sp, amount)) return false;
                return true;
            }
            if (com.example.shinobicore.ai.AiSystem.hasBrain(entity.getUuid())) {
                com.example.shinobicore.ai.AiBrain br = com.example.shinobicore.ai.AiSystem.get(entity.getUuid());
                if (br != null && "enemy".equals(br.behavior)) {
                    return com.example.shinobicore.ai.EnemyCombat.onDamaged(br, source, amount);
                }
            }
            if (source.getAttacker() instanceof net.minecraft.server.network.ServerPlayerEntity attacker) {
                HandheldSystem.onPlayerHit(attacker, entity);
            }
            return true;
        });

        ShinobiCore.LOGGER.info("[JutsuRuntime] v2 executors registered (C4-3)");
    }
}