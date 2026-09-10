package com.example.shinobicore.client.anim.json;

import com.example.shinobicore.item.KatanaItem;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;

/** Plays draw_katana / sheathe_katana when katana appears/leaves main hand. */
public class KatanaFsmTracker {
    private static boolean wasHolding = false;
    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(KatanaFsmTracker::tick);
    }
    private static void tick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) { wasHolding = false; return; }
        boolean holding = player.getMainHandStack().getItem() instanceof KatanaItem;
        if (holding && !wasHolding && !PlayerJsonAnimState.isPlayingOneShot()) {
            PlayerJsonAnimState.play("draw_katana", true);
        } else if (!holding && wasHolding && !PlayerJsonAnimState.isPlayingOneShot()) {
            PlayerJsonAnimState.play("sheathe_katana", true);
        }
        wasHolding = holding;
    }
}