package com.example.shinobicore.client;

import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;
import org.lwjgl.glfw.GLFW;

public class JutsuKeybindClient {

    public static final Identifier ID = new Identifier("shinobicore", "jutsu_cast_v2");
    private static boolean prevA = false;
    private static boolean prevB = false;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            if (client.player == null) return;
            boolean a = isDown(KeyBindings.CAST_A, client);
            boolean b = isDown(KeyBindings.CAST_B, client);
            if (a && !prevA) sendCast(0);
            if (b && !prevB) sendCast(1);
            prevA = a;
            prevB = b;
        });
    }

    private static boolean isDown(KeyBinding kb, MinecraftClient client) {
        if (kb == null) return false;
        InputUtil.Key key = KeyBindingHelper.getBoundKeyOf(kb);
        if (key == null) return false;
        long handle = client.getWindow().getHandle();
        if (key.getCategory() == InputUtil.Type.MOUSE) {
            return GLFW.glfwGetMouseButton(handle, key.getCode()) == GLFW.GLFW_PRESS;
        }
        return InputUtil.isKeyPressed(handle, key.getCode());
    }

    public static void sendCast(int set) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(set);
        ClientPlayNetworking.send(ID, buf);
    }
}