$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"

# === [1] ModItems.java: переписываем с правильным регистром ShinobiCore ===
$code = @'
package com.example.shinobicore.item;
import com.example.shinobicore.ShinobiCore;
import net.minecraft.item.Item;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;
public class ModItems {
    public static final Item KATANA = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "katana"), new KatanaItem());
    public static final Item SHURIKEN = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "shuriken"),
            new ThrowingWeaponItem(new Item.Settings().maxCount(16), 3f, 3.0f, 8));
    public static final Item KUNAI = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "kunai"),
            new ThrowingWeaponItem(new Item.Settings().maxCount(16), 5f, 2.2f, 12));
    public static void register() {
        ShinobiCore.LOGGER.info("Registered katana/shuriken/kunai items");
    }
}
'@
[System.IO.File]::WriteAllText("$src\item\ModItems.java", $code, $utf8)
Write-Host "[OK] ModItems.java: fixed ShinobiCore case" -ForegroundColor Green

# === [2] NinjaTickHandler: удаляем дубликаты seiganShield ===
$file = "$src\event\NinjaTickHandler.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
$cn = $c.Replace("`r`n", "`n")

# Считаем сколько раз встречается маркер
$marker = "boolean seiganShield = data.isKatanaDeflectHeld()"
$count = ([regex]::Matches($cn, [regex]::Escape($marker))).Count
Write-Host "Found seiganShield occurrences: $count"

if ($count -gt 1) {
    # Удаляем ВСЕ вхождения, затем добавим один раз в правильное место
    $badBlock = @'
            // === SEIGAN SHIELD SLOW ===
            boolean seiganShield = data.isKatanaDeflectHeld()
                    && com.example.shinobicore.combat.KenjutsuStance.fromId(data.getKatanaStanceId()) == com.example.shinobicore.combat.KenjutsuStance.SEIGAN;
            if (seiganShield) {
                player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 5, 2, false, false, false));
                if (tickCounter % 20 == 0) {
                    ShinobiCore.LOGGER.info("[SEIGAN] Shield slow applied to {}", player.getName().getString());
                }
            }

'@.Replace("`r`n", "`n")
    
    # Удаляем все вхождения badBlock
    while ($cn.Contains($badBlock)) {
        $cn = $cn.Replace($badBlock, "")
        Write-Host "  Removed one duplicate block"
    }
    
    # Также удаляем одиночные строки seiganShield если они остались
    $lines = $cn -split "`n"
    $newLines = New-Object System.Collections.ArrayList
    $skipNext = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($skipNext -gt 0) { $skipNext--; continue }
        if ($lines[$i] -match "boolean seiganShield = data\.isKatanaDeflectHeld") {
            # Пропускаем этот блок (7 строк)
            $skipNext = 7
            Write-Host "  Skipped orphan seiganShield block at line $i"
            continue
        }
        [void]$newLines.Add($lines[$i])
    }
    $cn = $newLines -join "`n"
    
    [System.IO.File]::WriteAllText($file, $cn, $utf8)
    Write-Host "[OK] NinjaTickHandler: removed duplicates" -ForegroundColor Green
} elseif ($count -eq 1) {
    Write-Host "[OK] NinjaTickHandler: seiganShield already correct (1 occurrence)" -ForegroundColor Gray
} else {
    Write-Host "[INFO] seiganShield not found - will add it" -ForegroundColor Yellow
}

# === [3] Убедимся что seiganShield блок есть в нужном месте ===
$c2 = [System.IO.File]::ReadAllText($file, $utf8).Replace("`r`n", "`n")
if (-not $c2.Contains("boolean seiganShield")) {
    $marker = @'
            double maxHp = NinjaFormula.maxHealth(data.getHpLevel());
'@
    $insert = @'
            // === SEIGAN SHIELD SLOW ===
            boolean seiganShield = data.isKatanaDeflectHeld()
                    && com.example.shinobicore.combat.KenjutsuStance.fromId(data.getKatanaStanceId()) == com.example.shinobicore.combat.KenjutsuStance.SEIGAN;
            if (seiganShield) {
                player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 5, 2, false, false, false));
                if (tickCounter % 20 == 0) {
                    ShinobiCore.LOGGER.info("[SEIGAN] Shield slow applied to {}", player.getName().getString());
                }
            }
            double maxHp = NinjaFormula.maxHealth(data.getHpLevel());
'@
    if ($c2.Contains($marker)) {
        $c2 = $c2.Replace($marker, $insert)
        [System.IO.File]::WriteAllText($file, $c2, $utf8)
        Write-Host "[OK] NinjaTickHandler: added seiganShield block" -ForegroundColor Green
    }
}

Write-Host "`nRun: .\gradlew.bat build" -ForegroundColor Cyan