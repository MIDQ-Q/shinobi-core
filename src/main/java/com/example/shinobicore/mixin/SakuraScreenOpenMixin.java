package com.example.shinobicore.mixin;

import com.example.shinobicore.client.sakura.SakuraHandler;
import com.example.shinobicore.client.sakura.SakuraHub;
import com.example.shinobicore.client.sakura.SakuraHubScreen;
import com.example.shinobicore.client.sakura.SakuraNetwork;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayNetworkHandler;
import net.minecraft.network.packet.s2c.play.OpenScreenS2CPacket;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(ClientPlayNetworkHandler.class)
public abstract class SakuraScreenOpenMixin {

    @Inject(method = "onOpenScreen", at = @At("HEAD"), cancellable = true)
    private void shinobicore$sakuraOpen(OpenScreenS2CPacket packet, CallbackInfo ci) {
        if (packet.getScreenHandlerType() != SakuraNetwork.TYPE) return;
        MinecraftClient client = MinecraftClient.getInstance();
        final int syncId = packet.getSyncId();
        client.execute(() -> {
            SakuraHandler handler = new SakuraHandler(syncId, client.player.getInventory());
            client.player.currentScreenHandler = handler;
            client.setScreen(new SakuraHubScreen(handler, client.player.getInventory(), SakuraHub.requestedTab));
        });
        ci.cancel();
    }
}