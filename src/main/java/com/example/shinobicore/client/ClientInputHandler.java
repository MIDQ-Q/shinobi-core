package com.example.shinobicore.client;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.combat.TaijutsuKickHandler;
import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import com.example.shinobicore.client.combat.KenjutsuClientHandler;
import com.example.shinobicore.combat.TaijutsuStyle;
import com.example.shinobicore.combat.TaijutsuFormulas;
import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;
public class ClientInputHandler {
    private static boolean prevMeditatePressed = false;
    private static boolean prevDeflectDown = false;
    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ClientInputHandler::onClientTick);
    }
    private static void onClientTick(MinecraftClient client) {
        if (client.player == null) return;
        if (KeyBindings.CHAKRA_MODE.wasPressed()) {
            ClientNinjaState.chakraMode = !ClientNinjaState.chakraMode;
            if (ClientNinjaState.chakraMode) com.example.shinobicore.client.combat.ChakraBurstAnimations.playBurst(client.player); // PHASE_A_BURST_HOOK
            if (client.getNetworkHandler() != null) {
                PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
                buf.writeBoolean(ClientNinjaState.chakraMode);
                ClientPlayNetworking.send(ModPackets.CHAKRA_MODE_ID, buf);
            }
        }
        boolean meditatePressed = KeyBindings.MEDITATE.isPressed();
        if (meditatePressed && !prevMeditatePressed) sendMeditatePacket(client, true);
        else if (!meditatePressed && prevMeditatePressed) sendMeditatePacket(client, false);
        prevMeditatePressed = meditatePressed;
        boolean hasKatana = client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem;
        if (KeyBindings.KICK.wasPressed()) {
            boolean handEmpty = client.player.getMainHandStack().isEmpty();
            if (handEmpty || hasKatana) TaijutsuKickHandler.tryKick(client.player);
        }
        if (KeyBindings.SWITCH_STANCE.wasPressed() && hasKatana) {
            KenjutsuClientHandler.cycleStance(client.player);
        }
        boolean deflectDown = KeyBindings.KATANA_DEFLECT.isPressed();
        if (deflectDown != prevDeflectDown) {
            prevDeflectDown = deflectDown;
            if (hasKatana) KenjutsuClientHandler.setDeflectHeld(client.player, deflectDown);
        }
        if (KeyBindings.SWITCH_STYLE.wasPressed()) {
            if (hasKatana) {
                KenjutsuClientHandler.cycleStance(client.player);
            } else {
                TaijutsuStyle currentStyle = TaijutsuClientHandler.getCurrentStyle();
                TaijutsuStyle newStyle;
                if (currentStyle == TaijutsuStyle.STANDARD) {
                    int taijutsuLevel = ClientNinjaState.statLevels.getOrDefault("taijutsu", 0);
                    if (!TaijutsuFormulas.canUseStrongFist(taijutsuLevel)) {
                        client.player.sendMessage(Text.literal("В§cYou need Taijutsu level " +
                                TaijutsuFormulas.strongFistUnlockLevel() + " to use Strong Fist!"), false);
                        return;
                    }
                    newStyle = TaijutsuStyle.STRONG_FIST;
                } else {
                    newStyle = TaijutsuStyle.STANDARD;
                }
                TaijutsuClientHandler.setStyle(newStyle);
                client.player.sendMessage(Text.literal("В§aStyle: " + newStyle.getId()), false);
                if (client.getNetworkHandler() != null) {
                    PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
                    buf.writeString(newStyle.getId());
                    ClientPlayNetworking.send(ModPackets.TAIJUTSU_STYLE_ID, buf);
                }
            }
        }
        if (KeyBindings.TOGGLE_SENSORY.wasPressed()) {
            boolean newState = !ClientNinjaState.sensoryEnabled;
            ClientNinjaState.sensoryEnabled = newState;
            if (client.getNetworkHandler() != null) {
                PacketByteBuf senBuf = new PacketByteBuf(Unpooled.buffer());
                senBuf.writeBoolean(newState);
                ClientPlayNetworking.send(ModPackets.SENSORY_TOGGLE_ID, senBuf);
            }
            client.player.sendMessage(Text.literal(newState ? "В§aSensory: ON" : "В§7Sensory: OFF"), false);
        }
        if (KeyBindings.CAST_A.wasPressed()) ClientNinjaState.castActiveJutsu(0);
        if (KeyBindings.CAST_B.wasPressed()) ClientNinjaState.castActiveJutsu(1);
        if (KeyBindings.CYCLE_A.wasPressed()) ClientNinjaState.cycleLoadout(0);
        if (KeyBindings.CYCLE_B.wasPressed()) ClientNinjaState.cycleLoadout(1);
        if (KeyBindings.PROGRESSION.wasPressed()) client.setScreen(new ProgressionScreen());
        if (KeyBindings.CRAWL.wasPressed()) ShinobiCore.LOGGER.info("[INPUT] CRAWL (N) pressed");
    }
    private static void sendMeditatePacket(MinecraftClient client, boolean start) {
        if (client.getNetworkHandler() != null) {
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeBoolean(start);
            ClientPlayNetworking.send(ModPackets.MEDITATE_ID, buf);
        }
    }
}