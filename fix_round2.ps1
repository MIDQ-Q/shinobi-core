$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"
$res = "E:\Games\mod\src\main\resources"

Write-Host "=== FIX ROUND 2 ===" -ForegroundColor Cyan

# === [1] SkillTreeScreen: боковые узлы дальше ===
$file = "$src\client\SkillTreeScreen.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
$c = $c.Replace("(int)(n.angleOffset() * 2)", "(int)(n.angleOffset() * 5)")
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[1] SkillTreeScreen: angleOffset x2 -> x5" -ForegroundColor Green

# === [2] NinjaFormula: ребаланс прыжков ===
$file = "$src\stat\NinjaFormula.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
$c = $c.Replace("return 3.0f + jumpLevel * 1.0f;", "return 2.0f + jumpLevel * 0.5f;")
$c = $c.Replace("return 1.5f + jumpLevel * 0.214f;", "return 1.5f + jumpLevel * 0.15f;")
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[2] NinjaFormula: jumps rebalanced (max 4.5x / 2.55x)" -ForegroundColor Green

# === [3] НОВЫЙ MIXIN: сохранение данных при смерти ===
$file = "$src\mixin\PlayerCopyMixin.java"
$code = @'
package com.example.shinobicore.mixin;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(ServerPlayerEntity.class)
public abstract class PlayerCopyMixin {
    @Inject(method = "copyFrom", at = @At("TAIL"))
    private void shinobicore_copyNinjaData(ServerPlayerEntity oldPlayer, boolean alive, CallbackInfo ci) {
        NinjaPlayerData oldData = ((NinjaDataHolder) oldPlayer).shinobicore_getData();
        NinjaPlayerData newData = ((NinjaDataHolder) (Object) this).shinobicore_getData();
        newData.readNbt(oldData.writeNbt());
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[3] PlayerCopyMixin.java created" -ForegroundColor Green

# === [4] mixins.json: регистрация ===
$file = "$res\shinobicore.mixins.json"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("PlayerCopyMixin")) {
    $c = $c.Replace('"CameraMixin"', '"CameraMixin",
    "PlayerCopyMixin"')
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[4] mixins.json: PlayerCopyMixin registered" -ForegroundColor Green
} else {
    Write-Host "[4] mixins.json: already registered" -ForegroundColor Gray
}

# === [5] NinjaPlayerData: фикс удвоения бонусов клана ===
$file = "$src\stat\NinjaPlayerData.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

# 5a. writeNbt: сохраняем применённые бонусы
$marker = 'nbt.putInt("ActiveSlotB", activeSlotB);'
$insert = @'
nbt.putInt("ActiveSlotB", activeSlotB);
        NbtCompound csb = new NbtCompound();
        for (Map.Entry<String, Integer> en : appliedClanStatBonuses.entrySet()) csb.putInt(en.getKey(), en.getValue());
        nbt.put("ClanStatBonuses", csb);
        NbtCompound cnb = new NbtCompound();
        for (Map.Entry<String, Integer> en : appliedClanNatureBonuses.entrySet()) cnb.putInt(en.getKey(), en.getValue());
        nbt.put("ClanNatureBonuses", cnb);
'@
$c = $c.Replace($marker, $insert)

# 5b. readNbt: НЕ применяем бонусы повторно, а восстанавливаем карту бонусов
$marker = @'
        if (!clanId.equals("none")) {
            applyClanBonuses(clanId);
        }
'@
$insert = @'
        appliedClanStatBonuses.clear();
        if (nbt.contains("ClanStatBonuses")) {
            NbtCompound csb = nbt.getCompound("ClanStatBonuses");
            for (String k : csb.getKeys()) appliedClanStatBonuses.put(k, csb.getInt(k));
        }
        appliedClanNatureBonuses.clear();
        if (nbt.contains("ClanNatureBonuses")) {
            NbtCompound cnb = nbt.getCompound("ClanNatureBonuses");
            for (String k : cnb.getKeys()) appliedClanNatureBonuses.put(k, cnb.getInt(k));
        }
'@
$c = $c.Replace($marker, $insert)
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[5] NinjaPlayerData: clan bonuses no longer double on reload/death" -ForegroundColor Green

# === [6] ModPackets: сервер сам списывает SP за аттюнмент ===
$file = "$src\network\ModPackets.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
$marker = @'
                if (success) {
                    data.setNatureUnlocked(element, true);
'@
$insert = @'
                if (success) {
                    int unlockedCount = 0;
                    for (ElementType e2 : ElementType.values()) {
                        if (data.isNatureUnlocked(e2)) unlockedCount++;
                    }
                    int cost = 10 + unlockedCount * 5;
                    if (data.getSkillPoints() < cost) {
                        player.sendMessage(Text.literal("§cNot enough SP! Need " + cost), false);
                        return;
                    }
                    data.addSkillPoints(-cost);
                    data.setNatureUnlocked(element, true);
'@
$c = $c.Replace($marker, $insert)

$marker = 'player.sendMessage(Text.literal("§aAttuned to " + elementId + "!"), false);'
$insert = 'player.sendMessage(Text.literal("§aAttuned to " + elementId + "! (-" + cost + " SP)"), false);'
$c = $c.Replace($marker, $insert)
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[6] ModPackets: attunement now server-side SP cost" -ForegroundColor Green

# === [7] ProgressionScreen: убрать клиентское списание SP ===
$file = "$src\client\ProgressionScreen.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
$c = $c.Replace("ClientNinjaState.skillPoints -= attuneCost;", "// SP deducted server-side on success")
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[7] ProgressionScreen: client-side SP deduction removed" -ForegroundColor Green

# === [8] AttunementScreen: звуки ===
$file = "$src\client\attunement\AttunementScreen.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

# 8a. импорты
$marker = 'import net.minecraft.text.Text;'
$insert = @'
import net.minecraft.text.Text;
import net.minecraft.client.MinecraftClient;
import net.minecraft.sound.SoundEvents;
'@
$c = $c.Replace($marker, $insert)

# 8b. звуки в mouseClicked
$marker = @'
        if (Math.abs(diff) <= zoneWidth / 2f) {
            phase = 1;
            sendResult(true);
        } else {
            attemptsLeft--;
            if (attemptsLeft <= 0) {
                phase = 2;
                sendResult(false);
            } else {
'@
$insert = @'
        if (Math.abs(diff) <= zoneWidth / 2f) {
            phase = 1;
            playResultSound(true);
            sendResult(true);
        } else {
            attemptsLeft--;
            if (attemptsLeft <= 0) {
                phase = 2;
                playResultSound(false);
                sendResult(false);
            } else {
                playMissSound();
'@
$c = $c.Replace($marker, $insert)

# 8c. методы звуков
$marker = '    private float angleDiff(float a, float b) {'
$insert = @'
    private void playResultSound(boolean success) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        if (success) {
            client.player.playSound(SoundEvents.ENTITY_EXPERIENCE_ORB_PICKUP, 1.0f, 1.2f);
            client.player.playSound(SoundEvents.BLOCK_BEACON_ACTIVATE, 0.8f, 1.0f);
        } else {
            client.player.playSound(SoundEvents.ENTITY_VILLAGER_NO, 1.0f, 0.8f);
        }
    }

    private void playMissSound() {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        client.player.playSound(SoundEvents.ENTITY_VILLAGER_NO, 0.4f, 1.5f);
    }

    private float angleDiff(float a, float b) {
'@
$c = $c.Replace($marker, $insert)
[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[8] AttunementScreen: sounds added" -ForegroundColor Green

Write-Host "`n=== ROUND 2 COMPLETE ===" -ForegroundColor Cyan
Write-Host "Run: .\gradlew.bat build; .\gradlew.bat runClient" -ForegroundColor Yellow