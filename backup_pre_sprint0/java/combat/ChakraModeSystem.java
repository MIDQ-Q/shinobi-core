package com.example.shinobicore.combat;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.network.packet.ChakraModePacket;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.stat.component.IChakraComponent;
import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.entity.attribute.EntityAttributeModifier;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

import java.util.UUID;

/**
 * Chakra Mode v2: toggle (L), drain chakra per second,
 * +100% speed, +4 armor, JumpBoost I (hidden).
 * Auto-off at 0 chakra.
 */
public final class ChakraModeSystem {
    private static final UUID SPEED_UUID = UUID.fromString("7f3a1c2e-4b5d-4e6f-9a8b-1c2d3e4f5a6b");
    private static final UUID ARMOR_UUID = UUID.fromString("8e4b2d3f-5c6e-4f7a-8b9c-2d3e4f5a6b7c");

    private ChakraModeSystem() {}

    public static void init() {
        ServerPlayNetworking.registerGlobalReceiver(ChakraModePacket.ID,
            (server, player, handler, buf, sender) -> {
                server.execute(() -> toggle(player));
            });

        ServerTickEvents.END_SERVER_TICK.register(server -> {
            for (ServerPlayerEntity p : server.getPlayerManager().getPlayerList()) {
                IChakraComponent ch = NinjaComponents.getChakra(p);
                if (ch == null || !ch.isChakraMode()) continue;

                IStatsComponent stats = NinjaComponents.getStats(p);
                int control = (stats != null) ? stats.getStatLevel(StatType.CONTROL) : 0;
                float drainPerSec = 2.0f * (1.0f - Math.min(0.9f, control * 0.009f));
                ch.setCurrentChakra(ch.getCurrentChakra() - drainPerSec / 20.0f);

                if (ch.getCurrentChakra() <= 0.0f) {
                    setMode(p, ch, false);
                    p.sendMessage(Text.literal("Chakra depleted! Mode off."), true);
                    continue;
                }

                if (p.age % 20 == 0) {
                    ensureBuffs(p);
                }
            }
        });
        ShinobiCore.LOGGER.info("ChakraModeSystem initialized");
    }

    private static void toggle(ServerPlayerEntity player) {
        IChakraComponent ch = NinjaComponents.getChakra(player);
        if (ch == null) return;
        boolean now = !ch.isChakraMode();
        if (now && ch.getCurrentChakra() <= 1.0f) {
            player.sendMessage(Text.literal("Not enough chakra!"), true);
            return;
        }
        setMode(player, ch, now);
        player.sendMessage(Text.literal(now ? "Chakra Mode ON" : "Chakra Mode OFF"), true);
    }

    private static void setMode(ServerPlayerEntity player, IChakraComponent ch, boolean on) {
        ch.setChakraMode(on);
        var speedAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
        var armorAttr = player.getAttributeInstance(EntityAttributes.GENERIC_ARMOR);
        if (speedAttr != null) speedAttr.removeModifier(SPEED_UUID);
        if (armorAttr != null) armorAttr.removeModifier(ARMOR_UUID);
        if (on) {
            if (speedAttr != null) {
                speedAttr.addPersistentModifier(new EntityAttributeModifier(
                    SPEED_UUID, "shinobi_chakra_speed", 1.5, // Increased from 1.0 to 1.5 (+150% = x2.5 speed)
                    EntityAttributeModifier.Operation.MULTIPLY_TOTAL));
            }
            if (armorAttr != null) {
                armorAttr.addPersistentModifier(new EntityAttributeModifier(
                    ARMOR_UUID, "shinobi_chakra_armor", 4.0,
                    EntityAttributeModifier.Operation.ADDITION));
            }
            player.addStatusEffect(new StatusEffectInstance(
                StatusEffects.JUMP_BOOST, 40, 0, true, false, false));
        }
    }

    private static void ensureBuffs(ServerPlayerEntity player) {
        var speedAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
        var armorAttr = player.getAttributeInstance(EntityAttributes.GENERIC_ARMOR);
        if (speedAttr != null && speedAttr.getModifier(SPEED_UUID) == null) {
            speedAttr.addPersistentModifier(new EntityAttributeModifier(
                SPEED_UUID, "shinobi_chakra_speed", 1.5, // Increased from 1.0 to 1.5 (+150% = x2.5 speed)
                EntityAttributeModifier.Operation.MULTIPLY_TOTAL));
        }
        if (armorAttr != null && armorAttr.getModifier(ARMOR_UUID) == null) {
            armorAttr.addPersistentModifier(new EntityAttributeModifier(
                ARMOR_UUID, "shinobi_chakra_armor", 4.0,
                EntityAttributeModifier.Operation.ADDITION));
        }
        player.addStatusEffect(new StatusEffectInstance(
            StatusEffects.JUMP_BOOST, 40, 0, true, false, false));
    }
}