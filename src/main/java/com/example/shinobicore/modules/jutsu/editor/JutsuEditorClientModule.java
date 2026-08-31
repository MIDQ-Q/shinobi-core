package com.example.shinobicore.modules.jutsu.editor;

import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandManager;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandRegistrationCallback;
import net.minecraft.client.MinecraftClient;

public final class JutsuEditorClientModule implements ClientAwareModule {
    public static final String ID = "jutsu_editor";

    @Override public String id() { return ID; }

    @Override
    public void onClientInit(ModuleContext ctx) {
        ClientCommandRegistrationCallback.EVENT.register((dispatcher, registryAccess) -> {
            dispatcher.register(ClientCommandManager.literal("jutsu_editor")
                .executes(c -> {
                    MinecraftClient mc = MinecraftClient.getInstance();
                    if (mc.player != null) {
                        mc.setScreen(new JutsuEditorScreen());
                    }
                    return 1;
                })
            );
        });
        ShinobiLogger.module(ID, "Jutsu Editor registered. Type /jutsu_editor");
    }
}