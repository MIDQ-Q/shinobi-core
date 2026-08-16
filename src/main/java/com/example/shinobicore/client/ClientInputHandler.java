package com.example.shinobicore.client;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.entity.RasenshurikenEntity;
import com.example.shinobicore.entity.RasenganHandEntity;
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
    private static boolean prevRmbDown = false;
    private static boolean prevLmbDown = false;
    private static boolean prevCastAHeld = false;
    private static boolean prevCastBHeld = false;
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

        // === ИСПРАВЛЕННЫЙ БЛОК IAI DASH ===
        if (KeyBindings.IAI_DASH.wasPressed()) {
            String stance = ClientNinjaState.kenjutsuStance;
            
            // Используем уже существующую переменную hasKatana (без слова boolean)
            if (hasKatana && stance.equals("iai")) {
                // Вызываем существующий метод атаки. 
                // Внутри tryAttack уже есть проверка на стойку "iai" и вызов playIaiSlash.
                KenjutsuClientHandler.tryAttack(client.player); 
            }
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
        // S1-05: Track cast key release for chargeable jutsu
        boolean castAHeld = KeyBindings.CAST_A.isPressed();
        if (!castAHeld && prevCastAHeld && client.getNetworkHandler() != null) {
            PacketByteBuf releaseBuf = new PacketByteBuf(Unpooled.buffer());
            ClientPlayNetworking.send(ModPackets.RELEASE_CAST_ID, releaseBuf);
        }
        prevCastAHeld = castAHeld;
        boolean castBHeld = KeyBindings.CAST_B.isPressed();
        if (!castBHeld && prevCastBHeld && client.getNetworkHandler() != null) {
            PacketByteBuf releaseBuf2 = new PacketByteBuf(Unpooled.buffer());
            ClientPlayNetworking.send(ModPackets.RELEASE_CAST_ID, releaseBuf2);
        }
        prevCastBHeld = castBHeld;
        if (KeyBindings.CYCLE_A.wasPressed()) ClientNinjaState.cycleLoadout(0);
        if (KeyBindings.CYCLE_B.wasPressed()) ClientNinjaState.cycleLoadout(1);
        if (KeyBindings.PROGRESSION.wasPressed()) client.setScreen(new ProgressionScreen());
        
        // === RMB: throw rasenshuriken ===
        boolean rmbDown = client.options.useKey.isPressed();
        if (rmbDown && !prevRmbDown) {
            boolean hasRs = false;
            if (client.world != null && client.player != null) {
                int entitiesFound = 0;
                for (var e : client.world.getOtherEntities(client.player,
                        client.player.getBoundingBox().expand(3))) {
                    entitiesFound++;
                    if (e instanceof RasenshurikenEntity rs && !rs.isLaunched()) {
                        hasRs = true;
                        break;
                    }
                }
            }
            if (hasRs) {
                PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
                ClientPlayNetworking.send(ModPackets.THROW_RASENSHURIKEN_ID, buf);
            } else {
            }
        }
        // === S2-03: BLOCK STATE ===
        boolean handEmpty = client.player.getMainHandStack().isEmpty();
        hasKatana = client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem;
        boolean wantBlock = rmbDown && (handEmpty || hasKatana);
        if (wantBlock != ClientNinjaState.isBlockingClient) {
            ClientNinjaState.isBlockingClient = wantBlock;
            PacketByteBuf blockBuf = new PacketByteBuf(Unpooled.buffer());
            blockBuf.writeBoolean(wantBlock);
            ClientPlayNetworking.send(ModPackets.BLOCK_STATE_ID, blockBuf);
        }

        prevRmbDown = rmbDown;

        // === LMB: rasengan strike ===
        boolean lmbDown = client.options.attackKey.isPressed();
        if (lmbDown && !prevLmbDown) {
            boolean hasRg = false;
            if (client.world != null && client.player != null) {
                int entitiesFound = 0;
                for (var e : client.world.getOtherEntities(client.player,
                        client.player.getBoundingBox().expand(3))) {
                    entitiesFound++;
                    if (e instanceof RasenganHandEntity) {
                        hasRg = true;
                        break;
                    }
                }
            }
            if (hasRg) {
                PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
                ClientPlayNetworking.send(ModPackets.RASENGAN_STRIKE_ID, buf);
            } else {
            }
        }
        prevLmbDown = lmbDown;
        if (KeyBindings.CRAWL.wasPressed()) ShinobiCore.LOGGER.info("[INPUT] CRAWL (N) pressed");
        if (KeyBindings.KAWARIMI.wasPressed()) {
            net.minecraft.network.PacketByteBuf buf = new net.minecraft.network.PacketByteBuf(io.netty.buffer.Unpooled.buffer());
            net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking.send(com.example.shinobicore.network.S06NetworkLayer.KAWARIMI_ID, buf);
        }
        if (KeyBindings.DEBUG_OVERLAY.wasPressed()) {
            com.example.shinobicore.client.debug.DebugProfiler.toggle();
        }

        if (KeyBindings.TOGGLE_SCABBARD.wasPressed()) {
            net.minecraft.item.ItemStack mainHand = client.player.getMainHandStack();
            if (mainHand.getItem() instanceof com.example.shinobicore.item.KatanaItem) {
                net.minecraft.nbt.NbtCompound nbt = mainHand.getOrCreateNbt();
                boolean isSheathed = nbt.getBoolean("Sheathed");
                nbt.putBoolean("Sheathed", !isSheathed);
                client.player.sendMessage(net.minecraft.text.Text.literal(!isSheathed ? "\u00a7aРљР°С‚Р°РЅР° СѓР±СЂР°РЅР° РІ РЅРѕР¶РЅС‹ РЅР° СЃРїРёРЅРµ" : "\u00a7cРљР°С‚Р°РЅР° СЃРЅСЏС‚Р° СЃРѕ СЃРїРёРЅС‹"), true);
            }
        }
    }
    private static void sendMeditatePacket(MinecraftClient client, boolean start) {
        if (client.getNetworkHandler() != null) {
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeBoolean(start);
            ClientPlayNetworking.send(ModPackets.MEDITATE_ID, buf);
        }
    }
}
