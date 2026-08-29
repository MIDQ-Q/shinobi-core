package com.example.shinobicore.combat;

import com.example.shinobicore.stat.component.IChakraComponent;
import com.example.shinobicore.stat.component.ICombatComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

/**
 * Stance lifecycle: switching, passive maintenance, Seigan chakra regen.
 * HLD: Section 4.2, 2.4
 */
public final class StanceManager {

    private StanceManager() {}

    public static void cycle(ServerPlayerEntity player) {
        ICombatComponent combat = NinjaComponents.getCombat(player);
        if (combat == null) {
            return;
        }
        Stance current = Stance.fromId(combat.getStanceId());
        Stance next = Stance.next(current);
        combat.setStanceId(next.getId());
        player.sendMessage(Text.literal("Stance: " + next.getId()), true);
    }

    public static void set(ServerPlayerEntity player, String id) {
        ICombatComponent combat = NinjaComponents.getCombat(player);
        if (combat == null) {
            return;
        }
        Stance s = Stance.fromId(id);
        combat.setStanceId(s.getId());
        player.sendMessage(Text.literal("Stance: " + s.getId()), true);
    }

    /**
     * Called once per second per player.
     * Maintains stance passives and regenerates chakra in Seigan.
     */
    public static void tickMaintain(ServerPlayerEntity player) {
        ICombatComponent combat = NinjaComponents.getCombat(player);
        IChakraComponent chakra = NinjaComponents.getChakra(player);
        if (combat == null || chakra == null) {
            return;
        }

        Stance s = Stance.fromId(combat.getStanceId());
        s.applyPassives(player);

        if (s == Stance.SEIGAN) {
            chakra.restoreChakra(2.0f);
        }

        // Combo decay: reset combo if no attack for 3 seconds (60 ticks approx)
        long now = player.getWorld().getTime();
        if (combat.getComboStep() > 0 && now - combat.getLastAttackMs() > 60L) {
            combat.resetCombo();
        }
    }
}