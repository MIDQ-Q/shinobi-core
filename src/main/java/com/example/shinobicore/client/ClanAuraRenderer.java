package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;

public class ClanAuraRenderer {
    private static int tickCounter = 0;

    private static final float[][] CLAN_COLORS = {
        {1.0f, 0.2f, 0.1f},
        {0.3f, 0.5f, 1.0f},
        {1.0f, 0.5f, 0.1f},
        {0.2f, 0.8f, 0.3f},
        {0.15f, 0.1f, 0.3f},
        {0.4f, 0.6f, 0.2f},
        {0.6f, 0.45f, 0.3f},
        {0.9f, 0.8f, 0.2f},
        {0.85f, 0.85f, 1.0f}
    };

    private static final String[] CLAN_IDS = {
        "uchiha", "hyuga", "uzumaki", "senju", "nara",
        "aburame", "inuzuka", "akimichi", "hatake"
    };

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ClanAuraRenderer::tick);
    }

    private static void tick(MinecraftClient client) {
        if (client.player == null || client.world == null) return;
        tickCounter++;
        if (tickCounter % 3 != 0) return;

        String clanId = ClientNinjaState.getClanId();
        if (clanId == null || clanId.isEmpty() || "none".equals(clanId)) return;
        if (!ClientNinjaState.isChakraMode()) return;

        int clanIndex = -1;
        for (int i = 0; i < CLAN_IDS.length; i++) {
            if (CLAN_IDS[i].equals(clanId)) { clanIndex = i; break; }
        }
        if (clanIndex < 0) return;

        float[] color = CLAN_COLORS[clanIndex];
        ClientPlayerEntity player = client.player;
        Vec3d pos = player.getPos();

        int count = 3 + client.world.getRandom().nextInt(3);
        for (int i = 0; i < count; i++) {
            double angle = tickCounter * 0.12 + (i / (double) count) * Math.PI * 2;
            double radius = 0.4 + client.world.getRandom().nextDouble() * 0.4;
            double x = pos.x + Math.cos(angle) * radius;
            double y = pos.y + 0.3 + client.world.getRandom().nextDouble() * 1.2;
            double z = pos.z + Math.sin(angle) * radius;

            DustParticleEffect effect = new DustParticleEffect(
                new Vector3f(color[0], color[1], color[2]), 0.7f);
            client.world.addParticle(effect, x, y, z, 0, 0.02, 0);
        }
    }
}