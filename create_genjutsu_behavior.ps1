# create_genjutsu_behavior.ps1
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$outputPath = "E:\Games\mod\src\main\java\com\example\shinobicore\jutsu\GenjutsuBehavior.java"

# Проверка: файл уже существует?
if (Test-Path $outputPath) {
    Write-Host "[SKIP] GenjutsuBehavior.java already exists"
    exit 0
}

$code = @'
package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.hit.EntityHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Vec3d;

public class GenjutsuBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (!(player.getWorld() instanceof ServerWorld serverWorld)) return;
        
        float range = params.has("range") ? params.get("range").getAsFloat() : 12.0f;
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 100;
        int amplifier = params.has("amplifier") ? params.get("amplifier").getAsInt() : 0;
        String effectType = params.has("effect") ? params.get("effect").getAsString() : "fear";
        
        Vec3d eyePos = player.getEyePos();
        Vec3d lookVec = player.getRotationVector();
        Vec3d endPos = eyePos.add(lookVec.multiply(range));
        
        EntityHitResult hitResult = serverWorld.raycastEntity(
            player, eyePos, endPos,
            entity -> entity instanceof LivingEntity && entity != player && entity.isAlive()
        );
        
        if (hitResult == null || hitResult.getType() != HitResult.Type.ENTITY) {
            player.sendMessage(Text.literal("\u00a7cNo target in range!"), false);
            return;
        }
        
        Entity target = hitResult.getEntity();
        if (!(target instanceof LivingEntity livingTarget)) return;
        
        float resistChance = calculateResistChance(livingTarget, data);
        float roll = serverWorld.getRandom().nextFloat();
        
        if (roll < resistChance) {
            player.sendMessage(Text.literal("\u00a7e" + livingTarget.getName().getString() + " resisted!"), false);
            spawnResistParticles(serverWorld, livingTarget);
            return;
        }
        
        applyGenjutsuEffect(livingTarget, effectType, duration, amplifier);
        spawnGenjutsuParticles(serverWorld, livingTarget);
        player.sendMessage(Text.literal("\u00a7aGenjutsu applied!"), false);
    }
    
    private float calculateResistChance(LivingEntity target, NinjaPlayerData casterData) {
        float baseResist = 0.10f;
        
        if (target instanceof PlayerEntity playerTarget) {
            try {
                NinjaPlayerData targetData = ((NinjaDataHolder) playerTarget).shinobicore_getData();
                int targetGenjutsuLevel = targetData.getStatLevel(StatType.GENJUTSU);
                baseResist += targetGenjutsuLevel * 0.01f;
            } catch (Exception e) {
                // ignore
            }
        }
        
        int casterGenjutsu = casterData.getStatLevel(StatType.GENJUTSU);
        float levelDiffBonus = Math.max(0, (casterGenjutsu - 20) * 0.005f);
        float finalResist = Math.max(0.05f, baseResist - levelDiffBonus);
        return Math.min(0.90f, finalResist);
    }
    
    private void applyGenjutsuEffect(LivingEntity target, String effectType, int duration, int amplifier) {
        switch (effectType) {
            case "fear" -> {
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, duration, amplifier + 1, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.MINING_FATIGUE, duration, amplifier, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.NAUSEA, duration, 0, false, false));
            }
            case "blindness" -> {
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.BLINDNESS, duration, 0, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, duration, amplifier, false, false));
            }
            case "nightmare" -> {
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.BLINDNESS, duration, 0, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, duration, amplifier + 1, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.WEAKNESS, duration, amplifier, false, false));
                target.addStatusEffect(new StatusEffectInstance(StatusEffects.NAUSEA, duration, 0, false, false));
            }
        }
    }
    
    private void spawnGenjutsuParticles(ServerWorld world, LivingEntity target) {
        Vec3d pos = target.getPos().add(0, target.getHeight() / 2.0, 0);
        for (int i = 0; i < 30; i++) {
            double angle = (i / 30.0) * Math.PI * 2;
            double r = 0.8 + Math.random() * 0.4;
            world.spawnParticles(ParticleTypes.PORTAL,
                pos.x + Math.cos(angle) * r, pos.y + (Math.random() - 0.5) * target.getHeight(), pos.z + Math.sin(angle) * r,
                1, (Math.random() - 0.5) * 0.1, Math.random() * 0.2, (Math.random() - 0.5) * 0.1, 0.05);
        }
    }
    
    private void spawnResistParticles(ServerWorld world, LivingEntity target) {
        Vec3d pos = target.getPos().add(0, target.getHeight() / 2.0, 0);
        for (int i = 0; i < 20; i++) {
            double angle = (i / 20.0) * Math.PI * 2;
            world.spawnParticles(ParticleTypes.CLOUD,
                pos.x + Math.cos(angle) * 0.6, pos.y, pos.z + Math.sin(angle) * 0.6,
                1, Math.cos(angle) * 0.2, 0.3, Math.sin(angle) * 0.2, 0.1);
        }
    }
}
'@

[System.IO.File]::WriteAllText($outputPath, $code, $utf8)
Write-Host "[FIX] GenjutsuBehavior.java created"