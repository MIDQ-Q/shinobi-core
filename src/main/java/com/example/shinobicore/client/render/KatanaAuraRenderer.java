package com.example.shinobicore.client.render;

import com.example.shinobicore.item.KatanaItem;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.particle.ParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;

/**
 * Always-on particles around a held katana.
 * Config per weapon: assets/shinobicore/weapon_visuals/<item_id>.json
 */
public final class KatanaAuraRenderer {
    private static int tickCounter = 0;

    private KatanaAuraRenderer() {}

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(KatanaAuraRenderer::tick);
    }

    private static void tick(MinecraftClient client) {
        if (client.world == null) return;
        tickCounter++;
        for (AbstractClientPlayerEntity p : client.world.getPlayers()) {
            ItemStack main = p.getMainHandStack();
            if (!(main.getItem() instanceof KatanaItem)) continue;
            WeaponVisualRegistry.Visual v = WeaponVisualRegistry.get(main);
            if (v == null || !v.particlesEnabled) continue;
            if (tickCounter % v.intervalTicks != 0) continue;
            spawn(client, p, v);
        }
    }

    private static void spawn(MinecraftClient client, AbstractClientPlayerEntity p,
                              WeaponVisualRegistry.Visual v) {
        Vec3d look = p.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        Vec3d hand = p.getEyePos().add(look.multiply(0.6)).add(right.multiply(0.35)).add(0, -0.3, 0);
        ParticleEffect eff = resolve(v);
        for (int i = 0; i < v.rate; i++) {
            double ox = (Math.random() - 0.5) * v.spread;
            double oy = (Math.random() - 0.5) * v.spread;
            double oz = (Math.random() - 0.5) * v.spread;
            client.world.addParticle(eff, hand.x + ox, hand.y + oy, hand.z + oz, 0, 0.02, 0);
        }
    }

    private static ParticleEffect resolve(WeaponVisualRegistry.Visual v) {
        switch (v.particleType) {
            case "end_rod": return ParticleTypes.END_ROD;
            case "flame": return ParticleTypes.FLAME;
            case "soul_fire": return ParticleTypes.SOUL_FIRE_FLAME;
            case "crit": return ParticleTypes.CRIT;
            case "enchant": return ParticleTypes.ENCHANT;
            case "cloud": return ParticleTypes.CLOUD;
            case "splash": return ParticleTypes.SPLASH;
            case "spark": return ParticleTypes.ELECTRIC_SPARK;
            case "reverse_portal": return ParticleTypes.REVERSE_PORTAL;
            case "witch": return ParticleTypes.WITCH;
            default: return new DustParticleEffect(v.colorVec(), 0.8f);
        }
    }
}