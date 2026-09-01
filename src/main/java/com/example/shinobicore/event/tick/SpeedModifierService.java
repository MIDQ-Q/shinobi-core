package com.example.shinobicore.event.tick;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.attribute.EntityAttributeModifier;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import java.util.UUID;

public final class SpeedModifierService {
    private static final UUID SPEED_UUID = UUID.fromString("9e1a5b6c-7d8f-4a2b-9c3d-1e2f3a4b5c6d");
    private static final UUID SPRINT_UUID = UUID.fromString("8f7a6b5c-4d3e-2f1a-0b9c-8d7e6f5a4b3c");
    private SpeedModifierService() {}

    public static void tickEveryTick(MinecraftServer server, ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        var speedAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
        if (speedAttr != null) {
            speedAttr.removeModifier(SPRINT_UUID);
            if (data.isChakraMode() && data.getCurrentChakra() > 0 && player.isSprinting()) {
                speedAttr.addPersistentModifier(new EntityAttributeModifier(
                    SPRINT_UUID, "shinobicore_sprint", 0.5,
                    EntityAttributeModifier.Operation.MULTIPLY_BASE));
            }
        }
    }

    public static void tickPerSecond(MinecraftServer server, ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        double maxHp = NinjaFormula.maxHealth(data.getHpLevel());
        var hpAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MAX_HEALTH);
        if (hpAttr != null) {
            hpAttr.setBaseValue(maxHp);
            if (player.getHealth() > maxHp) player.setHealth((float) maxHp);
        }
        float speedMult = NinjaFormula.speedMultiplier(data.getSpeedLevel(), data.isChakraMode());
        var speedAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
        if (speedAttr != null) {
            speedAttr.removeModifier(SPEED_UUID);
            if (speedMult != 1.0f) {
                speedAttr.addPersistentModifier(new EntityAttributeModifier(
                    SPEED_UUID, "shinobicore_speed", speedMult - 1.0,
                    EntityAttributeModifier.Operation.MULTIPLY_BASE));
            }
        }
    }
}