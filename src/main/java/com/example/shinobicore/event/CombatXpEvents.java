package com.example.shinobicore.event;

import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import com.example.shinobicore.stat.component.StatType;
import net.fabricmc.fabric.api.event.player.AttackEntityCallback;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.item.SwordItem;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.ActionResult;
import net.minecraft.util.Hand;
import net.minecraft.util.hit.EntityHitResult;
import net.minecraft.world.World;

/**
 * SPRINT A: Handles XP rewards for combat.
 * Uses Fabric API AttackEntityCallback to avoid dangerous Mixins.
 */
public final class CombatXpEvents {
    private CombatXpEvents() {}

    public static void register() {
        AttackEntityCallback.EVENT.register((PlayerEntity player, World world, Hand hand, Entity entity, EntityHitResult hitResult) -> {
            if (world.isClient) return ActionResult.PASS;
            if (!(player instanceof ServerPlayerEntity serverPlayer)) return ActionResult.PASS;
            if (!(entity instanceof LivingEntity target)) return ActionResult.PASS;
            
            IStatsComponent stats = NinjaComponents.getStats(serverPlayer);
            if (stats == null) return ActionResult.PASS;

            // Determine attack type based on weapon
            ItemStack weapon = serverPlayer.getMainHandStack();
            StatType attackStat = StatType.TAIJUTSU; // Default: Unarmed
            
            // Simple check for swords (Kenjutsu). 
            if (weapon.getItem() instanceof SwordItem) {
                attackStat = StatType.KENJUTSU;
            } else if (weapon.getItem().toString().contains("shuriken") || weapon.getItem().toString().contains("kunai")) {
                attackStat = StatType.SHURIKEN;
            }

            // Base XP per hit (can be scaled by damage later)
            int xpReward = 2; 
            
            // Add XP and check for level up
            boolean leveledUp = stats.addXp(attackStat, xpReward);
            
            if (leveledUp) {
                sendLevelUpPacket(serverPlayer, attackStat, stats.getStatLevel(attackStat));
            }

            return ActionResult.PASS;
        });
    }

    public static void sendLevelUpPacket(ServerPlayerEntity player, StatType type, int newLevel) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeString(type.getId());
        buf.writeVarInt(newLevel);
        ServerPlayNetworking.send(player, ModPackets.LEVEL_UP_EVENT, buf);
    }
}