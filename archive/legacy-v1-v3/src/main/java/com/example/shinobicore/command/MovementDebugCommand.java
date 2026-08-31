// SHINOBICORE:SPRINT12:FILE
package com.example.shinobicore.command;

import com.example.shinobicore.chakra.client.ChakraClientController;
import com.example.shinobicore.movement.client.ClientMovementState;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandManager;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandRegistrationCallback;
import net.fabricmc.fabric.api.client.command.v2.FabricClientCommandSource;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

/**
 * SPRINT 12 client-side debug command.
 * Usage: /shinobicore movement state
 */
public final class MovementDebugCommand {
    private MovementDebugCommand() {}

    public static void register() {
        ClientCommandRegistrationCallback.EVENT.register((dispatcher, registryAccess) -> {
            dispatcher.register(ClientCommandManager.literal("shinobicore")
                .then(ClientCommandManager.literal("movement")
                    .then(ClientCommandManager.literal("state")
                        .executes(ctx -> {
                            FabricClientCommandSource src = ctx.getSource();
                            src.sendFeedback(Text.literal("=== Client Movement State ===").formatted(Formatting.GOLD));
                            src.sendFeedback(Text.literal("Phase: " + ClientMovementState.getPhase().name()).formatted(Formatting.AQUA));
                            src.sendFeedback(Text.literal("Invulnerable: " + ClientMovementState.isInvulnerable()).formatted(Formatting.WHITE));
                            src.sendFeedback(Text.literal("On Wall: " + ClientMovementState.isOnWall()).formatted(Formatting.WHITE));
                            src.sendFeedback(Text.literal("On Water: " + ClientMovementState.isOnWater()).formatted(Formatting.WHITE));
                            src.sendFeedback(Text.literal("Air Jumps: " + ClientMovementState.getAirJumpsUsed() + " / " + ClientMovementState.getMaxAirJumps()).formatted(Formatting.WHITE));
                            src.sendFeedback(Text.literal("Chakra: " + String.format("%.0f / %.0f", ChakraClientController.getCurrentChakra(), ChakraClientController.getMaxChakra())).formatted(Formatting.GREEN));
                            src.sendFeedback(Text.literal("Mode: " + ChakraClientController.isChakraModeActive()).formatted(Formatting.YELLOW));
                            return 1;
                        }))));
        });
    }
}