package com.example.shinobicore.client.vfx;

import com.example.shinobicore.network.VfxTypes;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayConnectionEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.world.ClientWorld;
import net.minecraft.particle.ParticleEffect;
import net.minecraft.particle.ParticleTypes;

import java.util.ArrayDeque;
import java.util.Queue;
import java.util.Random;

public final class ClientVfxManager {
    private static final Queue<VfxEvent> QUEUE = new ArrayDeque<>();
    private static final Random RANDOM = new Random();

    private static final int MAX_QUEUE = 256;
    private static final int MAX_PROCESSED_PER_TICK = 32;
    private static final int MAX_SPAWNS_PER_TICK = 4;
    private static final double MAX_DISTANCE_SQ = 64.0 * 64.0;

    private static boolean registered = false;

    private ClientVfxManager() {
    }

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;
        ClientTickEvents.END_CLIENT_TICK.register(ClientVfxManager::tick);
        ClientPlayConnectionEvents.DISCONNECT.register((handler, client) -> clear());
    }

    public static void enqueue(int type, double x, double y, double z, float scale) {
        if (QUEUE.size() >= MAX_QUEUE) {
            QUEUE.poll();
        }

        QUEUE.add(new VfxEvent(type, x, y, z, scale));
    }

    public static void clear() {
        QUEUE.clear();
    }

    private static void tick(MinecraftClient client) {
        if (client == null || client.world == null || client.player == null) {
            clear();
            return;
        }

        int processed = 0;
        int spawned = 0;

        while (processed < MAX_PROCESSED_PER_TICK && !QUEUE.isEmpty()) {
            VfxEvent event = QUEUE.poll();
            if (event == null) {
                break;
            }

            processed++;

            if (client.player.squaredDistanceTo(event.x(), event.y(), event.z()) > MAX_DISTANCE_SQ) {
                continue;
            }

            if (spawned >= MAX_SPAWNS_PER_TICK) {
                continue;
            }

            spawn(client.world, event);
            spawned++;
        }
    }

    private static void spawn(ClientWorld world, VfxEvent event) {
        float scale = clampScale(event.scale());

        int count = (int) (8.0f + 10.0f * scale);
        if (count < 4) {
            count = 4;
        }
        if (count > 24) {
            count = 24;
        }

        switch (event.type()) {
            case VfxTypes.FIREBALL ->
                    burst(world, event.x(), event.y(), event.z(), scale, ParticleTypes.FLAME, ParticleTypes.SMOKE, count, 0.03);

            case VfxTypes.WATER ->
                    burst(world, event.x(), event.y(), event.z(), scale, ParticleTypes.SPLASH, ParticleTypes.BUBBLE, count, 0.02);

            case VfxTypes.WIND ->
                    burst(world, event.x(), event.y(), event.z(), scale, ParticleTypes.CLOUD, ParticleTypes.CRIT, count, 0.05);

            case VfxTypes.LIGHTNING ->
                    burst(world, event.x(), event.y(), event.z(), scale, ParticleTypes.ELECTRIC_SPARK, ParticleTypes.CRIT, count, 0.06);

            case VfxTypes.EARTH ->
                    burst(world, event.x(), event.y(), event.z(), scale, ParticleTypes.SMOKE, ParticleTypes.CRIT, count, 0.02);

            case VfxTypes.RASENGAN ->
                    burst(world, event.x(), event.y(), event.z(), scale, ParticleTypes.END_ROD, ParticleTypes.CRIT, count, 0.04);

            case VfxTypes.HIT_IMPACT ->
                    burst(world, event.x(), event.y(), event.z(), scale, ParticleTypes.CRIT, ParticleTypes.SMOKE, count, 0.05);

            case VfxTypes.DOJUTSU_ACTIVATE ->
                    burst(world, event.x(), event.y(), event.z(), scale, ParticleTypes.END_ROD, ParticleTypes.HAPPY_VILLAGER, count, 0.02);

            default ->
                    burst(world, event.x(), event.y(), event.z(), scale, ParticleTypes.SMOKE, ParticleTypes.SMOKE, Math.max(2, count / 2), 0.01);
        }
    }

    private static float clampScale(float scale) {
        if (Float.isNaN(scale) || Float.isInfinite(scale)) {
            return 1.0f;
        }

        if (scale < 0.25f) {
            return 0.25f;
        }

        if (scale > 4.0f) {
            return 4.0f;
        }

        return scale;
    }

    private static void burst(ClientWorld world, double x, double y, double z, float scale,
                              ParticleEffect main, ParticleEffect secondary, int count, double speed) {
        for (int i = 0; i < count; i++) {
            ParticleEffect effect = ((i & 1) == 0) ? main : secondary;

            double dx = (RANDOM.nextDouble() - 0.5) * 0.7 * scale;
            double dy = (RANDOM.nextDouble() - 0.5) * 0.5 * scale;
            double dz = (RANDOM.nextDouble() - 0.5) * 0.7 * scale;

            double vx = (RANDOM.nextDouble() - 0.5) * speed;
            double vy = (RANDOM.nextDouble() - 0.5) * speed;
            double vz = (RANDOM.nextDouble() - 0.5) * speed;

            world.addParticle(effect, x + dx, y + dy, z + dz, vx, vy, vz);
        }
    }

    private record VfxEvent(int type, double x, double y, double z, float scale) {
    }
}