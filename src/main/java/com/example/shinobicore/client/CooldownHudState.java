package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.util.Identifier;

import java.util.HashMap;
import java.util.Map;

public class CooldownHudState {
    public static final Identifier ID = new Identifier("shinobicore", "cooldown_sync");
    private static final Map<String, int[]> MAP = new HashMap<>(); // id -> [remaining, total]

    public static void register() {
        ClientPlayNetworking.registerGlobalReceiver(ID, (client, handler, buf, sender) -> {
            final String id = buf.readString();
            final int remaining = buf.readInt();
            // Server may or may not append "total"; read defensively.
            final int max = buf.readableBytes() >= 4 ? buf.readInt() : remaining;
            client.execute(() -> {
                if (remaining <= 0) MAP.remove(id);
                else MAP.put(id, new int[]{remaining, Math.max(1, max)});
            });
        });
        ClientTickEvents.END_CLIENT_TICK.register(client -> tick());
    }

    private static void tick() {
        if (MAP.isEmpty()) return;
        MAP.values().forEach(a -> a[0]--);
        MAP.values().removeIf(a -> a[0] <= 0);
    }

    public static int getRemaining(String id) {
        int[] a = MAP.get(id);
        return a == null ? 0 : Math.max(0, a[0]);
    }

    public static float getProgress(String id) {
        int[] a = MAP.get(id);
        if (a == null || a[1] <= 0) return 0f;
        return Math.max(0f, Math.min(1f, (float) a[0] / (float) a[1]));
    }
}