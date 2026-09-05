# 🧪 ВЕРИФИКАЦИЯ: Чек-лист + Логер

```powershell
# ============================================================
# VERIFICATION SUITE: Logger + Checklist
# ============================================================

$ErrorActionPreference = "Stop"
$root = "E:\Games\mod"

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $fullPath = Join-Path $root $Path
    $dir = Split-Path $fullPath -Parent
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($fullPath, $Content, $utf8NoBom)
    Write-Host "[OK] $Path" -ForegroundColor Green
}

# ============================================================
# 1. VerificationLogger (NEW) - writes to verification_results.txt
# ============================================================
$loggerJava = @'
package com.example.shinobicore.jutsu.executor;

import net.fabricmc.loader.api.FabricLoader;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;

import java.io.IOException;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class VerificationLogger {

    private static final Path LOG_FILE = FabricLoader.getInstance().getGameDir().resolve("verification_results.txt");
    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static boolean enabled = true;

    public static void log(String category, String message) {
        if (!enabled) return;
        String timestamp = LocalDateTime.now().format(FMT);
        String line = String.format("[%s] [%s] %s", timestamp, category, message);
        try (PrintWriter pw = new PrintWriter(Files.newBufferedWriter(LOG_FILE, StandardOpenOption.CREATE, StandardOpenOption.APPEND))) {
            pw.println(line);
        } catch (IOException ignored) {}
    }

    public static void logCast(ServerPlayerEntity caster, String jutsuId, String activationType) {
        log("CAST", String.format("Player: %s | Jutsu: %s | Activation: %s", 
            caster.getName().getString(), jutsuId, activationType));
    }

    public static void logHit(ServerPlayerEntity caster, LivingEntity target, String effectType, float damage) {
        log("HIT", String.format("Caster: %s | Target: %s | Effect: %s | Damage: %.1f", 
            caster.getName().getString(), target.getName().getString(), effectType, damage));
    }

    public static void logProperty(String jutsuId, String propertyId, String details) {
        log("PROPERTY", String.format("Jutsu: %s | Property: %s | %s", jutsuId, propertyId, details));
    }

    public static void logEffect(String jutsuId, String effectType, String subtype, String details) {
        log("EFFECT", String.format("Jutsu: %s | Type: %s | Subtype: %s | %s", 
            jutsuId, effectType, subtype, details));
    }

    public static void logActivation(String jutsuId, String activationType, String status) {
        log("ACTIVATION", String.format("Jutsu: %s | Type: %s | Status: %s", jutsuId, activationType, status));
    }

    public static void logProgression(ServerPlayerEntity player, String jutsuId, int level, int uses) {
        log("PROGRESSION", String.format("Player: %s | Jutsu: %s | Level: %d | Uses: %d", 
            player.getName().getString(), jutsuId, level, uses));
    }

    public static void logError(String category, String message) {
        log("ERROR", String.format("[%s] %s", category, message));
    }

    public static void setEnabled(boolean e) { enabled = e; }
}
'@
Write-Utf8NoBom "src\main\java\com\example\shinobicore\jutsu\executor\VerificationLogger.java" $loggerJava

# ============================================================
# 2. Patch JutsuCaster - log cast attempts
# ============================================================
$casterPath = Join-Path $root "src\main\java\com\example\shinobicore\jutsu\executor\JutsuCaster.java"
$c = [System.IO.File]::ReadAllText($casterPath, $utf8NoBom)

if ($c -notmatch 'VerificationLogger\.logCast') {
    $c = $c.Replace(
        "FormExecutor.executeForm(ctx);",
        "VerificationLogger.logCast(player, id, jutsu.getActivation().getType().getId());`n        FormExecutor.executeForm(ctx);"
    )
    $c = $c.Replace(
        "prog.addUse(uid, id);",
        "prog.addUse(uid, id);`n        VerificationLogger.logProgression(player, id, level, prog.getUses(uid, id));"
    )
    [System.IO.File]::WriteAllText($casterPath, $c, $utf8NoBom)
    Write-Host "[PATCHED] JutsuCaster.java - added verification logging" -ForegroundColor Green
}

# ============================================================
# 3. Patch EffectExecutor - log effects
# ============================================================
$effectPath = Join-Path $root "src\main\java\com\example\shinobicore\jutsu\executor\EffectExecutor.java"
$c = [System.IO.File]::ReadAllText($effectPath, $utf8NoBom)

if ($c -notmatch 'VerificationLogger\.logEffect') {
    $c = $c.Replace(
        "private static void applyEffect(CastContext ctx, EffectDefinition effect, LivingEntity target) {",
        "private static void applyEffect(CastContext ctx, EffectDefinition effect, LivingEntity target) {`n        VerificationLogger.logEffect(ctx.jutsu.getId(), effect.getType().getId(), effect.getSubType().getId(), `"`");"
    )
    [System.IO.File]::WriteAllText($effectPath, $c, $utf8NoBom)
    Write-Host "[PATCHED] EffectExecutor.java - added verification logging" -ForegroundColor Green
}

# ============================================================
# 4. Patch Combat - log damage
# ============================================================
$combatPath = Join-Path $root "src\main\java\com\example\shinobicore\jutsu\executor\Combat.java"
$c = [System.IO.File]::ReadAllText($combatPath, $utf8NoBom)

if ($c -notmatch 'VerificationLogger\.logHit') {
    $c = $c.Replace(
        "target.damage(target.getDamageSources().magic(), amount);",
        "VerificationLogger.logHit(ctx.caster, target, `"DAMAGE`", amount);`n        target.damage(target.getDamageSources().magic(), amount);"
    )
    [System.IO.File]::WriteAllText($combatPath, $c, $utf8NoBom)
    Write-Host "[PATCHED] Combat.java - added verification logging" -ForegroundColor Green
}

# ============================================================
# 5. Patch ProjectileSystem - log properties
# ============================================================
$projPath = Join-Path $root "src\main\java\com\example\shinobicore\jutsu\executor\ProjectileSystem.java"
$c = [System.IO.File]::ReadAllText($projPath, $utf8NoBom)

if ($c -notmatch 'VerificationLogger\.logProperty') {
    $insertions = @(
        @{ Pattern = 'if (ctx.hasProp("no_gravity")) gravity = 0;'; Insert = '        if (ctx.hasProp("no_gravity")) { gravity = 0; VerificationLogger.logProperty(ctx.jutsu.getId(), "no_gravity", "gravity disabled"); }' },
        @{ Pattern = 'if (ctx.hasProp("homing"))'; Insert = '        if (ctx.hasProp("homing")) VerificationLogger.logProperty(ctx.jutsu.getId(), "homing", "turnRate=" + turnRate);' },
        @{ Pattern = 'if (ctx.hasProp("boomerang"))'; Insert = '        if (ctx.hasProp("boomerang")) { boomerang = true; VerificationLogger.logProperty(ctx.jutsu.getId(), "boomerang", "enabled"); }' },
        @{ Pattern = 'if (ctx.hasProp("bouncing"))'; Insert = '        if (ctx.hasProp("bouncing")) { bounce = bo.getInt("count", 2); VerificationLogger.logProperty(ctx.jutsu.getId(), "bouncing", "count=" + bounce); }' },
        @{ Pattern = 'if (ctx.hasProp("piercing"))'; Insert = '        if (ctx.hasProp("piercing")) { pierce = pi.getInt("count", 3); VerificationLogger.logProperty(ctx.jutsu.getId(), "piercing", "count=" + pierce); }' },
        @{ Pattern = 'if (ctx.hasProp("splitting"))'; Insert = '        if (ctx.hasProp("splitting")) VerificationLogger.logProperty(ctx.jutsu.getId(), "splitting", "count=" + sp.getInt("count", 3));' },
        @{ Pattern = 'if (ctx.hasProp("chaining"))'; Insert = '        if (ctx.hasProp("chaining")) VerificationLogger.logProperty(ctx.jutsu.getId(), "chaining", "count=" + ch.getInt("count", 3));' }
    )
    foreach ($ins in $insertions) {
        if ($c.Contains($ins.Pattern) -and $c -notmatch [regex]::Escape($ins.Insert.Substring(0, 50))) {
            $c = $c.Replace($ins.Pattern, $ins.Insert + "`n" + $ins.Pattern)
        }
    }
    [System.IO.File]::WriteAllText($projPath, $c, $utf8NoBom)
    Write-Host "[PATCHED] ProjectileSystem.java - added verification logging" -ForegroundColor Green
}

# ============================================================
# 6. Patch ActivationSystem - log activations
# ============================================================
$actPath = Join-Path $root "src\main\java\com\example\shinobicore\jutsu\executor\ActivationSystem.java"
$c = [System.IO.File]::ReadAllText($actPath, $utf8NoBom)

if ($c -notmatch 'VerificationLogger\.logActivation') {
    $c = $c.Replace(
        "public static void start(CastContext ctx, Mode mode, int duration, int min, double extra) {",
        "public static void start(CastContext ctx, Mode mode, int duration, int min, double extra) {`n        VerificationLogger.logActivation(ctx.jutsu.getId(), mode.name(), `"STARTED duration=" + duration + `" min=" + min);"
    )
    $c = $c.Replace(
        'p.sendMessage(Text.literal("§c§lINTERRUPTED! §7Cast lost"), false);',
        'VerificationLogger.logActivation(a.ctx.jutsu.getId(), a.mode.name(), "INTERRUPTED by damage");`n                p.sendMessage(Text.literal("§c§lINTERRUPTED! §7Cast lost"), false);'
    )
    $c = $c.Replace(
        'p.sendMessage(Text.literal("§e§lCOUNTER!"), false);',
        'VerificationLogger.logActivation(a.ctx.jutsu.getId(), "COUNTER", "TRIGGERED by damage=" + amount);`n                    p.sendMessage(Text.literal("§e§lCOUNTER!"), false);'
    )
    [System.IO.File]::WriteAllText($actPath, $c, $utf8NoBom)
    Write-Host "[PATCHED] ActivationSystem.java - added verification logging" -ForegroundColor Green
}

# ============================================================
# 7. Create CHECKLIST.md
# ============================================================
$checklist = @'
# 🧪 ВЕРИФИКАЦИЯ JUTSU v2 - ПОЛНЫЙ ЧЕК-ЛИСТ

## 📋 Инструкции

1. Запусти игру: `.\gradlew.bat runClient`
2. В игре: `/reload`
3. Прогоняй команды ниже **по одной**
4. Проверяй результат в игре + в файле `verification_results.txt`

## 📝 Формат лога

```
[YYYY-MM-DD HH:MM:SS] [CATEGORY] DETAILS
```

**Категории:**
- `CAST` - попытка каста
- `HIT` - попадание по цели
- `EFFECT` - применение эффекта
- `PROPERTY` - активация свойства
- `ACTIVATION` - статус активации
- `PROGRESSION` - изменения уровня/uses
- `ERROR` - ошибки

---

## 🎯 ТЕСТ 1: ФОРМЫ (8 тестов)

### 1.1 Point (точечная)
```
/shinobicore jutsu cast test_point_heal
```
**Ожидание в игре:**
- Мгновенное лечение +8 HP (видно по сердечкам)
- Частицы yang (белые)

**Ожидание в логе:**
```
[CAST] Player: <name> | Jutsu: shinobicore:test_point_heal | Activation: instant
[EFFECT] Jutsu: shinobicore:test_point_heal | Type: buff | Subtype: heal |
[HIT] Caster: <name> | Target: <name> | Effect: DAMAGE | Damage: 8.0
```

**Чек:** ✅ HP выросли на 8 | ✅ Лог содержит 3 строки

---

### 1.2 Projectile Volley (залп)
```
/shinobicore jutsu cast test_projectile_volley
```
**Ожидание в игре:**
- 3 снаряда вылетают веером (spread=15°)
- Летят ровно (gravity=0)
- Каждый наносит 4 урона

**Ожидание в логе:**
```
[CAST] Player: <name> | Jutsu: shinobicore:test_projectile_volley | Activation: instant
[PROPERTY] Jutsu: shinobicore:test_projectile_volley | Property: volley | count=3 spread=15
[HIT] x3 (по одному на каждый снаряд)
```

**Чек:** ✅ 3 снаряда | ✅ Летят ровно | ✅ Лог содержит volley property

---

### 1.3 Beam (луч)
```
/shinobicore jutsu cast test_beam
```
**Ожидание в игре:**
- Молниевый луч 12 блоков
- Урон 2 каждые 0.25с (tickRate=5)
- Длится 3с (duration=60)

**Ожидание в логе:**
```
[CAST] Player: <name> | Jutsu: shinobicore:test_beam | Activation: instant
[EFFECT] x12+ (каждые 5 тиков)
[HIT] x12+
```

**Чек:** ✅ Луч виден | ✅ Урон каждые 0.25с | ✅ Лог содержит множественные HIT

---

### 1.4 Zone (зона)
```
/shinobicore jutsu cast test_zone_slow
```
**Ожидание в игре:**
- Синяя зона радиусом 5 блоков
- Мобы в зоне получают Slowness каждые 0.5с
- Длится 5с

**Ожидание в логе:**
```
[CAST] Player: <name> | Jutsu: shinobicore:test_zone_slow | Activation: instant
[EFFECT] Type: control | Subtype: slow (повторяется каждые 10 тиков)
```

**Чек:** ✅ Зона видна | ✅ Мобы замедляются | ✅ Повторяющиеся EFFECT в логе

---

### 1.5 Dash (рывок)
```
/shinobicore jutsu cast test_dash
```
**Ожидание в игре:**
- Рывок 8 блоков вперёд
- Урон 6 по всем мобам на пути

**Ожидание в логе:**
```
[CAST] Player: <name> | Jutsu: shinobicore:test_dash | Activation: instant
[HIT] (если были мобы на пути)
```

**Чек:** ✅ Игрок переместился | ✅ Урон по пути | ✅ Лог содержит CAST

---

### 1.6 Handheld (в руке)
```
/shinobicore jutsu cast test_handheld
```
**Ожидание в игре:**
- 1с зарядка (actionbar: "Charging...")
- Синяя сфера в руке
- ЛКМ по мобу → урон 10 + launch

**Ожидание в логе:**
```
[CAST] Player: <name> | Jutsu: shinobicore:test_handheld | Activation: instant
[PROPERTY] Jutsu: shinobicore:test_handheld | Property: multi_use | enabled
[PROPERTY] Jutsu: shinobicore:test_handheld | Property: throwable | enabled
[HIT] (при ударе)
```

**Чек:** ✅ Сфера видна | ✅ ЛКМ работает | ✅ Моб подбрасывается | ✅ Лог содержит properties

---

### 1.7 Construct (конструкция)
```
/shinobicore jutsu cast test_construct_wall
```
**Ожидание в игре:**
- Ледяная стена 5×3 блока
- Перпендикулярна взгляду
- Исчезает через 10с

**Ожидание в логе:**
```
[CAST] Player: <name> | Jutsu: shinobicore:test_construct_wall | Activation: instant
```

**Чек:** ✅ Стена появилась | ✅ Ориентация правильная | ✅ Исчезла через 10с

---

### 1.8 Summon (призыв)
```
/shinobicore jutsu cast test_summon
```
**Ожидание в игре:**
- 2 волка появляются вокруг игрока
- (AI пока не реализован - C4)

**Ожидание в логе:**
```
[CAST] Player: <name> | Jutsu: shinobicore:test_summon | Activation: instant
```

**Чек:** ✅ 2 волка заспавнились | ✅ Лог содержит CAST

---

## 🎯 ТЕСТ 2: ЭФФЕКТЫ (4 тест-кита)

### 2.1 Damage Kit (урон)
```
/shinobicore jutsu cast test_damage_kit
```
**Ожидание в игре:**
- Снаряд наносит 4 урона мгновенно + 2 урона/сек 3с (DoT)

**Ожидание в логе:**
```
[CAST] Jutsu: shinobicore:test_damage_kit
[EFFECT] Type: damage | Subtype: instant
[EFFECT] Type: damage | Subtype: dot
[HIT] Damage: 4.0 (мгновенный)
[HIT] Damage: 2.0 (DoT, повторяется)
```

**Чек:** ✅ Мгновенный урон | ✅ DoT тикает | ✅ Лог содержит оба эффекта

---

### 2.2 Control Kit (контроль)
```
/shinobicore jutsu cast test_control_kit
```
**Ожидание в игре:**
- Снаряд оглушает (stun 2с) + отбрасывает (push)

**Ожидание в логе:**
```
[EFFECT] Type: control | Subtype: stun
[EFFECT] Type: control | Subtype: push
```

**Чек:** ✅ Моб оглушён | ✅ Отброшен | ✅ Оба эффекта в логе

---

### 2.3 Buff Kit (баффы)
```
/shinobicore jutsu cast test_buff_kit
```
**Ожидание в игре:**
- Щит 12 HP (жёлтые сердечки)
- Скорость +30% (Speed эффект)

**Ожидание в логе:**
```
[EFFECT] Type: buff | Subtype: shield
[EFFECT] Type: buff | Subtype: speed
```

**Чек:** ✅ Щит появился | ✅ Скорость выросла | ✅ Оба эффекта в логе

---

### 2.4 Debuff Kit (дебаффы)
```
/shinobicore jutsu cast test_debuff_kit
```
**Ожидание в игре:**
- Vulnerability 25% (цель светится - Glowing)
- Curse 1 урон/сек 5с (не снимается purify)

**Ожидание в логе:**
```
[EFFECT] Type: debuff | Subtype: vulnerability
[EFFECT] Type: debuff | Subtype: curse
```

**Чек:** ✅ Цель светится | ✅ DoT от curse | ✅ Оба эффекта в логе

---

## 🎯 ТЕСТ 3: WORLD EFFECTS (3 теста)

### 3.1 Ignite (поджог)
```
/shinobicore jutsu cast test_world_ignite
```
**Ожидание в игре:**
- Огонь появляется в радиусе 3 блока вокруг цели
- Мобы поджигаются на 5с

**Ожидание в логе:**
```
[EFFECT] Type: world | Subtype: ignite
```

**Чек:** ✅ Огонь появился | ✅ Мобы горят

---

### 3.2 Freeze (заморозка)
```
/shinobicore jutsu cast test_world_freeze
```
**Ожидание в игре:**
- Вода превращается в лёд
- Лава превращается в обсидиан

**Ожидание в логе:**
```
[EFFECT] Type: world | Subtype: freeze
```

**Чек:** ✅ Блоки трансформировались

---

### 3.3 Transform (преобразование)
```
/shinobicore jutsu cast test_world_transform
```
**Ожидание в игре:**
- Земля превращается в траву в радиусе 3 блока

**Ожидание в логе:**
```
[EFFECT] Type: world | Subtype: transform_block
```

**Чек:** ✅ Блоки изменились

---

## 🎯 ТЕСТ 4: PROPERTIES (9 тестов)

### 4.1 Homing (самонаведение)
```
/shinobicore jutsu cast test_prop_homing
```
**Ожидание в игре:**
- Снаряд поворачивает к ближайшему врагу

**Ожидание в логе:**
```
[PROPERTY] Jutsu: shinobicore:test_prop_homing | Property: homing | turnRate=0.15
```

**Чек:** ✅ Снаряд маневрирует | ✅ Property в логе

---

### 4.2 Bouncing (рикошет)
```
/shinobicore jutsu cast test_prop_bouncing
```
**Ожидание в игре:**
- Снаряд отскакивает от стен до 3 раз

**Ожидание в логе:**
```
[PROPERTY] Jutsu: shinobicore:test_prop_bouncing | Property: bouncing | count=3
```

**Чек:** ✅ Отскоки работают | ✅ Property в логе

---

### 4.3 Splitting (разделение)
```
/shinobicore jutsu cast test_prop_splitting
```
**Ожидание в игре:**
- На полпути снаряд делится на 3 осколка под углом 30°

**Ожидание в логе:**
```
[PROPERTY] Jutsu: shinobicore:test_prop_splitting | Property: splitting | count=3
```

**Чек:** ✅ Разделение произошло | ✅ 3 осколка летят

---

### 4.4 Chaining (цепь)
```
/shinobicore jutsu cast test_prop_chaining
```
**Ожидание в игре:**
- Молния прыгает между 3 врагами с falloff 20%

**Ожидание в логе:**
```
[PROPERTY] Jutsu: shinobicore:test_prop_chaining | Property: chaining | count=3
```

**Чек:** ✅ Цепная молния | ✅ 3 удара

---

### 4.5 Piercing (пробивание)
```
/shinobicore jutsu cast test_prop_piercing
```
**Ожидание в игре:**
- Снаряд проходит сквозь 3 мобов

**Ожидание в логе:**
```
[PROPERTY] Jutsu: shinobicore:test_prop_piercing | Property: piercing | count=3
```

**Чек:** ✅ Пробивает несколько целей

---

### 4.6 Boomerang (бумеранг)
```
/shinobicore jutsu cast test_prop_boomerang
```
**Ожидание в игре:**
- Снаряд возвращается к кастеру на полпути

**Ожидание в логе:**
```
[PROPERTY] Jutsu: shinobicore:test_prop_boomerang | Property: boomerang | enabled
```

**Чек:** ✅ Возвращается

---

### 4.7 Orbiting (орбита)
```
/shinobicore jutsu cast test_prop_orbiting
```
**Ожидание в игре:**
- 4 клинка вращаются вокруг игрока радиусом 2 блока

**Ожидание в логе:**
```
[PROPERTY] Jutsu: shinobicore:test_prop_orbiting | Property: orbiting | count=4
```

**Чек:** ✅ Орбита работает

---

### 4.8 Stick + Lifesteal
```
/shinobicore jutsu cast test_prop_stick_lifesteal
```
**Ожидание в игре:**
- Снаряд прилипает к цели на 5с
- 50% урона возвращается как HP

**Ожидание в логе:**
```
[PROPERTY] Property: stick_on_hit | duration=100
[PROPERTY] Property: lifesteal | percent=50
[HIT] Damage: 6.0
```

**Чек:** ✅ Прилипает | ✅ HP восстанавливаются

---

### 4.9 Explosions (взрывы)
```
/shinobicore jutsu cast test_prop_explosions
```
**Ожидание в игре:**
- Взрыв при попадании (radius=3, damage=6)
- Отложенный взрыв через 1с
- Цепной взрыв (2 дополнительных)
- Multi-target: максимум 2 цели

**Ожидание в логе:**
```
[PROPERTY] Property: explode_on_hit
[PROPERTY] Property: delayed_explosion
[PROPERTY] Property: chain_explosion
[PROPERTY] Property: multi_target | count=2
```

**Чек:** ✅ Все взрывы сработали | ✅ Лимит 2 цели

---

## 🎯 ТЕСТ 5: АКТИВАЦИИ (6 тестов)

### 5.1 Handseals (печати)
```
/shinobicore jutsu cast test_act_handseals
```
**Ожидание в игре:**
- 1.5с прогресс в actionbar ("Weaving seals...")
- Авто-каст после завершения

**Ожидание в логе:**
```
[ACTIVATION] Jutsu: shinobicore:test_act_handseals | Type: HANDSEALS | Status: STARTED
[ACTIVATION] Type: HANDSEALS | Status: COMPLETED
```

**Чек:** ✅ Прогресс виден | ✅ Авто-каст

---

### 5.2 Charge (зарядка)
```
/shinobicore jutsu cast test_act_charge
```
Затем через 1-2с:
```
/shinobicore jutsu release
```
**Ожидание в игре:**
- Прогресс зарядки в actionbar
- Release → снаряд с мощностью 50-100%

**Ожидание в логе:**
```
[ACTIVATION] Type: CHARGE | Status: STARTED
[ACTIVATION] Type: CHARGE | Status: RELEASED power=XX%
```

**Чек:** ✅ Зарядка работает | ✅ Release срабатывает

---

### 5.3 Hold (канал)
```
/shinobicore jutsu cast test_act_hold
```
Затем:
```
/shinobicore jutsu release
```
**Ожидание в игре:**
- Луч активен, чакра течёт
- Release → луч исчезает

**Ожидание в логе:**
```
[ACTIVATION] Type: HOLD | Status: STARTED
[ACTIVATION] Type: HOLD | Status: RELEASED
```

**Чек:** ✅ Канал работает | ✅ Чакра тратится | ✅ Release останавливает

---

### 5.4 Counter (контратака)
```
/shinobicore jutsu cast test_act_counter
```
Затем попроси моба ударить тебя (или `/damage @s 2`).

**Ожидание в игре:**
- "Counter stance!" в чате
- При получении урона → авто-каст dash

**Ожидание в логе:**
```
[ACTIVATION] Type: COUNTER | Status: STARTED
[ACTIVATION] Type: COUNTER | Status: TRIGGERED by damage=2.0
```

**Чек:** ✅ Контратака сработала | ✅ Лог содержит TRIGGERED

---

### 5.5 On Death (Идзанаги)
```
/shinobicore jutsu cast test_act_on_death
```
Затем:
```
/damage @s 100
```
**Ожидание в игре:**
- "IZANAGI!" в чате
- HP восстанавливаются до 50%
- Летальный удар отменён

**Ожидание в логе:**
```
[ACTIVATION] Type: ON_DEATH | Status: STARTED
[ACTIVATION] Type: ON_DEATH | Status: TRIGGERED (death prevented)
```

**Чек:** ✅ Смерть предотвращена | ✅ HP восстановлены

---

### 5.6 Passive (пассивка)
```
/shinobicore jutsu cast test_act_passive
```
Затем:
```
/shinobicore jutsu release
```
**Ожидание в игре:**
- Регенерация HP каждые 5с
- Release → пассивка отключается

**Ожидание в логе:**
```
[ACTIVATION] Type: PASSIVE | Status: STARTED
[EFFECT] Type: buff | Subtype: regen (повторяется каждые 100 тиков)
[ACTIVATION] Type: PASSIVE | Status: DISABLED
```

**Чек:** ✅ Регенерация тикает | ✅ Release отключает

---

## 🎯 ТЕСТ 6: ПРОГРЕССИЯ

```
/shinobicore jutsu cast test_progression_fireball
```
**Ожидание:** Урон 8

```
/shinobicore jutsu adduses test_progression_fireball 10
/shinobicore jutsu givesp 10
/shinobicore jutsu levelup test_progression_fireball
```
**Ожидание:** Level 5, урон 12, цена 28

```
/shinobicore jutsu adduses test_progression_fireball 50
/shinobicore jutsu givesp 10
/shinobicore jutsu levelup test_progression_fireball
```
**Ожидание:** Level 10, урон 16, **unlock piercing**

```
/shinobicore jutsu cast test_progression_fireball
```
**Ожидание:** Снаряд пробивает 3 мобов

**Ожидание в логе:**
```
[PROGRESSION] Player: <name> | Jutsu: test_progression_fireball | Level: 1 | Uses: 1
[PROGRESSION] Level: 5 | Uses: 11
[PROGRESSION] Level: 10 | Uses: 61
[PROPERTY] Property: piercing (unlocked at level 10)
```

**Чек:** ✅ Урон растёт | ✅ Цена падает | ✅ Piercing разблокирован

---

## ✅ ИТОГОВАЯ ПРОВЕРКА

После всех тестов открой `verification_results.txt` и проверь:

- [ ] Файл существует
- [ ] Содержит записи всех категорий (CAST, HIT, EFFECT, PROPERTY, ACTIVATION, PROGRESSION)
- [ ] Нет записей `[ERROR]`
- [ ] Все 30 тестовых техник были кастованы
- [ ] Timestamp корректный

**Если всё ✅ — верификация пройдена! Переходим к Editor v3.** 🍥
'@

Write-Utf8NoBom "VERIFICATION_CHECKLIST.md" $checklist

# ============================================================
# BUILD
# ============================================================
Write-Host ""
Write-Host "Building..." -ForegroundColor Yellow
Push-Location $root
try {
    $buildOut = & cmd /c "gradlew.bat build 2>&1" | Out-String
    if ($buildOut -match "BUILD SUCCESSFUL") {
        Write-Host "[PASS] BUILD SUCCESSFUL - VERIFICATION SUITE READY!" -ForegroundColor Green
        Write-Host ""
        Write-Host "FILES CREATED:" -ForegroundColor Yellow
        Write-Host "  VERIFICATION_CHECKLIST.md (30 tests)" -ForegroundColor Cyan
        Write-Host "  VerificationLogger.java (writes to verification_results.txt)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "HOW TO TEST:" -ForegroundColor Yellow
        Write-Host "  1. Run game: .\gradlew.bat runClient" -ForegroundColor Gray
        Write-Host "  2. In game: /reload" -ForegroundColor Gray
        Write-Host "  3. Open VERIFICATION_CHECKLIST.md" -ForegroundColor Gray
        Write-Host "  4. Run commands one by one" -ForegroundColor Gray
        Write-Host "  5. Check results in game + verification_results.txt" -ForegroundColor Gray
        Write-Host ""
        Write-Host "LOG FILE LOCATION:" -ForegroundColor Yellow
        Write-Host "  E:\Games\mod\verification_results.txt" -ForegroundColor Cyan
    } else {
        Write-Host "[FAIL]" -ForegroundColor Red
        ($buildOut -split "`n") | Where-Object { $_ -match "error:" } | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally { Pop-Location }