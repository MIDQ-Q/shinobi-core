package com.example.shinobicore.event.tick;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.attribute.EntityAttributeModifier;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * P1-7: модификаторы атрибутов применяются ПО ФРОНТУ изменения состояния.
 *
 * БЫЛО: removeModifier + addPersistentModifier КАЖДЫЙ тик для каждого игрока.
 * addPersistentModifier помечает атрибут грязным, и ServerPlayerEntity рассылает
 * EntityAttributeModifierUpdateS2CPacket — то есть ~20 пакетов в секунду на игрока
 * плюс ощутимое дёрганье скорости (один из источников «коньков»).
 *
 * СТАЛО: состояние хранится в карте, модификатор меняется только при его изменении.
 */
public final class SpeedModifierService {

    private static final UUID SPEED_UUID  = UUID.fromString("9e1a5b6c-7d8f-4a2b-9c3d-1e2f3a4b5c6d");
    private static final UUID SPRINT_UUID = UUID.fromString("8f7a6b5c-4d3e-2f1a-0b9c-8d7e6f5a4b3c");

    private static final Map<UUID, Boolean> WAS_SPRINT_BOOSTED = new HashMap<>();
    private static final Map<UUID, Float>   LAST_SPEED_MULT    = new HashMap<>();

    private SpeedModifierService() {}

    public static void tickEveryTick(MinecraftServer server, ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        var speedAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
        if (speedAttr == null) return;

        UUID uid = player.getUuid();
        boolean want = data.isChakraMode() && data.getCurrentChakra() > 0 && player.isSprinting();
        Boolean was = WAS_SPRINT_BOOSTED.get(uid);

        if (was != null && was == want) return;      // P1-7: ничего не изменилось — не трогаем атрибут
        WAS_SPRINT_BOOSTED.put(uid, want);

        speedAttr.removeModifier(SPRINT_UUID);
        if (want) {
            speedAttr.addPersistentModifier(new EntityAttributeModifier(
                    SPRINT_UUID, "shinobicore_sprint", 0.5,
                    EntityAttributeModifier.Operation.MULTIPLY_BASE));
        }
    }

    public static void tickPerSecond(MinecraftServer server, ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        UUID uid = player.getUuid();

        double maxHp = NinjaFormula.maxHealth(data.getHpLevel());
        var hpAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MAX_HEALTH);
        if (hpAttr != null) {
            hpAttr.setBaseValue(maxHp);
            if (player.getHealth() > maxHp) player.setHealth((float) maxHp);
        }

        float speedMult = NinjaFormula.speedMultiplier(data.getSpeedLevel(), data.isChakraMode());
        Float last = LAST_SPEED_MULT.get(uid);
        if (last != null && Math.abs(last - speedMult) < 1.0E-4f) return;   // P1-7
        LAST_SPEED_MULT.put(uid, speedMult);

        var speedAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
        if (speedAttr == null) return;
        speedAttr.removeModifier(SPEED_UUID);
        if (speedMult != 1.0f) {
            speedAttr.addPersistentModifier(new EntityAttributeModifier(
                    SPEED_UUID, "shinobicore_speed", speedMult - 1.0,
                    EntityAttributeModifier.Operation.MULTIPLY_BASE));
        }
    }

    /** Очистка на DISCONNECT — иначе карты текут. */
    public static void removePlayer(UUID uid) {
        if (uid == null) return;
        WAS_SPRINT_BOOSTED.remove(uid);
        LAST_SPEED_MULT.remove(uid);
    }

    public static void clear() {
        WAS_SPRINT_BOOSTED.clear();
        LAST_SPEED_MULT.clear();
    }
}