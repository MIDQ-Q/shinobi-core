package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;

/**
 * Chakra Aura: particles around body in chakra mode.
 * Color depends on affinity (fire=red, water=blue, etc.)
 * Default: blue chakra glow.
 */
public class ChakraAuraRenderer {
    private static int tickCounter = 0;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ChakraAuraRenderer::tick);
    }

    private static void tick(MinecraftClient client) {
        if (client.world == null) return;
        tickCounter++;
        // Spawn particles every 2 ticks for performance
        if (tickCounter % 2 != 0) return;

        for (AbstractClientPlayerEntity p : client.world.getPlayers()) {
            boolean isLocal = (p == client.player);
            boolean hasChakra;
            String affinityId = null;

            if (isLocal) {
                hasChakra = ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0;
                affinityId = ClientNinjaState.affinityId;
            } else {
                // For other players, check their casting state as proxy
                hasChakra = CastingClientState.isCasting(p);
            }

            if (!hasChakra) continue;

            spawnAuraParticles(client, p, affinityId, isLocal);
        }
    }

    private static void spawnAuraParticles(MinecraftClient client, AbstractClientPlayerEntity p,
                                            String affinityId, boolean isLocal) {
        Vec3d pos = p.getPos();
        double bodyY = pos.y + 0.5;
        float bodyRadius = 0.4f;

        // Color from affinity
        Vector3f color = getColorForAffinity(affinityId);

        // === AURA: ring of particles around body ===
        int count = isLocal ? 6 : 3; // fewer for other players (performance)
        float rotation = tickCounter * 0.15f;

        for (int i = 0; i < count; i++) {
            float angle = rotation + (i / (float) count) * (float)(Math.PI * 2);
            double x = pos.x + Math.cos(angle) * bodyRadius;
            double z = pos.z + Math.sin(angle) * bodyRadius;
            // Rising particles along body height
            for (int h = 0; h < 3; h++) {
                double y = bodyY + h * 0.5 + (Math.random() - 0.5) * 0.2;
                DustParticleEffect effect = new DustParticleEffect(color, 0.8f);
                client.world.addParticle(effect, x, y, z,
                    0, 0.01, 0);
            }
        }

        // === FLAME-LIKE: rising wisps from shoulders ===
        if (isLocal && tickCounter % 4 == 0) {
            Vec3d look = p.getRotationVector();
            Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
            // Left shoulder
            Vec3d leftShoulder = pos.add(0, 1.3, 0).add(right.multiply(-0.3));
            // Right shoulder
            Vec3d rightShoulder = pos.add(0, 1.3, 0).add(right.multiply(0.3));

            client.world.addParticle(ParticleTypes.SOUL_FIRE_FLAME,
                leftShoulder.x, leftShoulder.y, leftShoulder.z,
                0, 0.03, 0);
            client.world.addParticle(ParticleTypes.SOUL_FIRE_FLAME,
                rightShoulder.x, rightShoulder.y, rightShoulder.z,
                0, 0.03, 0);
        }
    }

    private static Vector3f getColorForAffinity(String affinityId) {
        if (affinityId == null) return new Vector3f(0.3f, 0.5f, 1.0f); // default blue
        return switch (affinityId) {
            case "fire" -> new Vector3f(1.0f, 0.4f, 0.1f);
            case "water" -> new Vector3f(0.2f, 0.5f, 1.0f);
            case "wind" -> new Vector3f(0.5f, 1.0f, 0.7f);
            case "lightning" -> new Vector3f(1.0f, 1.0f, 0.3f);
            case "earth" -> new Vector3f(0.7f, 0.5f, 0.2f);
            default -> new Vector3f(0.3f, 0.5f, 1.0f);
        };
    }
}