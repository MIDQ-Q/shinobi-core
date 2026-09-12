package com.example.shinobicore.event;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.combat.KenjutsuStance;
import com.example.shinobicore.tree.TreePassives;
import com.example.shinobicore.network.ModPackets;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.mob.MobEntity;
import net.minecraft.network.PacketByteBuf;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import com.example.shinobicore.combat.MarkTracker;
import net.minecraft.entity.attribute.EntityAttributeModifier;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import java.util.UUID;
import com.example.shinobicore.event.tick.ChakraRegenService;
import com.example.shinobicore.event.tick.FatigueDecayService;
import com.example.shinobicore.event.tick.MeditationService;
import com.example.shinobicore.event.tick.ChakraModeDrainService;
import com.example.shinobicore.event.tick.SpeedModifierService;
import com.example.shinobicore.event.tick.CombatStatusService;

public class NinjaTickHandler {
    private static int tickCounter = 0;
    private static final UUID SPEED_UUID = UUID.fromString("9e1a5b6c-7d8f-4a2b-9c3d-1e2f3a4b5c6d");
    private static final UUID SPRINT_UUID = UUID.fromString("8f7a6b5c-4d3e-2f1a-0b9c-8d7e6f5a4b3c");

    public static void onServerTick(MinecraftServer server) {
        // P1-7 + C2: было removeModifier+addPersistentModifier КАЖДЫЙ тик
        // (~20 пакетов синхронизации атрибутов в секунду на игрока).
        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            SpeedModifierService.tickEveryTick(server, player);
        }
        tickCounter++;
        if (tickCounter < 20) return;
        tickCounter = 0;



        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            // C2: проверка canMeditate переехала в MeditationService.tick
            ChakraRegenService.tick(server, player);   // C2 (включая ветку расенгана)
            FatigueDecayService.tick(server, player);  // C2
            MeditationService.tick(server, player);    // C2
            ChakraModeDrainService.tick(server, player);  // C2
            // P1-1: щит стойки и истощение вынесены в CombatStatusService.
            // Раньше блок "если не истощён" ниже снимал ВСЕ SLOWNESS/WEAKNESS
            // в том же тике, делая медитацию и блок бесплатными.
            CombatStatusService.tick(server, player);
            SpeedModifierService.tickPerSecond(server, player);  // C2 + P1-7
                // === PHASE_FIX2_TICK: sensory glow + danger sense + rasengan dissipate ===
    TreePassives.Bonuses b2 = TreePassives.collectServer(data);
    int sensoryTick = (int)(player.getWorld().getTime() % 5);
        if (b2.sensory && data.isSensoryEnabled() && sensoryTick == 0) {
        int radius = b2.sensoryRadius > 0 ? b2.sensoryRadius : 20;
        for (LivingEntity mob : player.getWorld().getEntitiesByClass(LivingEntity.class,
                player.getBoundingBox().expand(radius), e -> !(e instanceof ServerPlayerEntity))) {
            mob.addStatusEffect(new StatusEffectInstance(StatusEffects.GLOWING, 40, 0, false, false));
        }
    }
    if (b2.dangerSense) {
        boolean danger = false;
        for (LivingEntity mob : player.getWorld().getEntitiesByClass(LivingEntity.class,
                player.getBoundingBox().expand(16), e -> e instanceof MobEntity)) {
            if (((MobEntity) mob).getTarget() == player) { danger = true; break; }
        }
        if (danger != data.getLastDangerState()) {
            data.setLastDangerState(danger);
            PacketByteBuf dbuf = new PacketByteBuf(Unpooled.buffer());
            dbuf.writeBoolean(danger);
            ServerPlayNetworking.send(player, ModPackets.DANGER_SYNC_ID, dbuf);
        }
    }
    if (data.isRasenganReady()) {
        data.setRasenganReadyTicks(data.getRasenganReadyTicks() + 20);
        if (data.getRasenganReadyTicks() >= 600) {
            data.setRasenganReady(false);
            data.setRasenganReadyTicks(0);
            player.sendMessage(Text.literal("\u00a77Rasengan dissipated..."), false);
            ShinobiCore.sendRasenganSync(player);
        }
    } else {
        data.setRasenganReadyTicks(0);
    }
    // === END PHASE_FIX2_TICK ===
            ShinobiCore.sendChakraSync(player);
            // P1-1: эффекты истощения обрабатывает CombatStatusService (по фронту).
            // Удалена ветка else с removeStatusEffect(WEAKNESS/SLOWNESS) — она снимала
            // чужие эффекты: замедление от медитации и от щита защитной стойки.

if (data.consumeStatsDirty()) {
                ShinobiCore.sendStatsSync(player);
            }
        }
    }

    /**
     * C2: больше не вызывается отсюда — логика переехала в MeditationService.
     * Метод сохранён как справочный; удалить после проверки, что
     * MeditationService.canMeditate совпадает с ним построчно.
     */
    @SuppressWarnings("unused")
    private static boolean canMeditate(ServerPlayerEntity player, NinjaPlayerData data) {
        if (data.isExhausted()) return false;
        if (!player.isOnGround()) return false;
        if (player.getHungerManager().getFoodLevel() < 6) return false;
        double dx = player.getX() - player.prevX;
        double dz = player.getZ() - player.prevZ;
        if (dx * dx + dz * dz > 0.01) return false;
        return true;
    }
}