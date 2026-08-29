package com.example.shinobicore.client;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;
public class CastingClientVisual {
    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(CastingClientVisual::tick);
    }
    private static void tick(MinecraftClient client) {
        if (client.world == null) return;
        for (AbstractClientPlayerEntity p : client.world.getPlayers()) {
            CastingClientState.Cast c = CastingClientState.get(p);
            if (c == null) continue;
            int color = CastingClientState.color(c.nature);
            float r = ((color >> 16) & 0xFF) / 255f;
            float g = ((color >> 8) & 0xFF) / 255f;
            float b = (color & 0xFF) / 255f;
            DustParticleEffect effect = new DustParticleEffect(new Vector3f(r, g, b), 1.0f);
            Vec3d hand = handPos(p);
            for (int i = 0; i < 3; i++) {
                client.world.addParticle(effect,
                    hand.x + (Math.random() - 0.5) * 0.3,
                    hand.y + (Math.random() - 0.5) * 0.3,
                    hand.z + (Math.random() - 0.5) * 0.3,
                    0, 0.03, 0);
            }
        }
    }
    private static Vec3d handPos(AbstractClientPlayerEntity p) {
        Vec3d look = p.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        return p.getEyePos().add(look.multiply(0.6)).add(right.multiply(0.3)).add(0, -0.35, 0);
    }
}