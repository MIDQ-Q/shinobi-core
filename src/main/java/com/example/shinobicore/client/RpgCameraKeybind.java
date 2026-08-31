package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;

public class RpgCameraKeybind {
    public static final KeyBinding FLIP = new KeyBinding(
        "key.shinobicore.camera_flip", 63, "key.category.shinobicore"); // F5

    public static void register() {
        KeyBindingHelper.registerKeyBinding(FLIP);
        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            while (FLIP.wasPressed()) RpgCamera.flipShoulder();
        });
    }
}