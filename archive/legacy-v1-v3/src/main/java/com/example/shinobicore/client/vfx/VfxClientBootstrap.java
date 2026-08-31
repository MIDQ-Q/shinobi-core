package com.example.shinobicore.client.vfx;

import com.example.shinobicore.client.network.VfxSpawnPacketClient;
import com.example.shinobicore.network.VfxTypes;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandManager;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandRegistrationCallback;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.text.Text;

public class VfxClientBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        ClientVfxManager.register();
        VfxSpawnPacketClient.register();

        ClientCommandRegistrationCallback.EVENT.register((dispatcher, registryAccess) -> {
            dispatcher.register(ClientCommandManager.literal("vfxtest")
                    .executes(context -> {
                        ClientPlayerEntity player = context.getSource().getPlayer();
                        if (player != null) {
                            ClientVfxManager.enqueue(
                                    VfxTypes.FIREBALL,
                                    player.getX(),
                                    player.getY() + 1.0,
                                    player.getZ(),
                                    1.0f
                            );

                            player.sendMessage(Text.literal("ShinobiCore: local client VFX test spawned"), true);
                        }

                        return 1;
                    }));
        });
    }
}