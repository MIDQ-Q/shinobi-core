package com.example.shinobicore.client.sakura;

import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.resource.featuretoggle.FeatureFlags;
import net.minecraft.screen.ScreenHandlerType;
import net.minecraft.screen.SimpleNamedScreenHandlerFactory;
import net.minecraft.text.Text;
import net.minecraft.util.Identifier;

public class SakuraNetwork {
    public static final Identifier OPEN_ID = new Identifier("shinobicore", "sakura_open");

    public static final ScreenHandlerType<SakuraHandler> TYPE = Registry.register(
            Registries.SCREEN_HANDLER,
            new Identifier("shinobicore", "sakura"),
            new ScreenHandlerType<>(SakuraHandler::new, FeatureFlags.VANILLA_FEATURES));

    public static void register() {
        ServerPlayNetworking.registerGlobalReceiver(OPEN_ID, (server, player, handler, buf, rs) ->
                server.execute(() -> player.openHandledScreen(new SimpleNamedScreenHandlerFactory(
                        (syncId, inv, p) -> new SakuraHandler(syncId, inv),
                        Text.literal("Shinobi")))));
    }

    // Client screen binding is done by SakuraScreenOpenMixin (no HandledScreens needed)
    public static void registerClient() { }
}