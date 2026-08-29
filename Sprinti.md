Отлично! Все решения приняты, теперь у нас полная картина. Составляю **детальный план реализации V3** на основе твоих ответов.

---

## 📋 ИТОГОВАЯ АРХИТЕКТУРА V3

### Моды-зависимости (все совместимы с Fabric 1.20.1):

| Мод | Версия | Роль |
|---|---|---|
| **Iron's Spells 'n Spellbooks** | Fabric 1.20.1 | Каст-система (заменяем ману → чакра) |
| **Origins** | Fabric 1.20.1 | Клановая система (расы = кланы) |
| **Better Combat** | Fabric 1.20.1 | Боевая система (комбо, хитбоксы) |
| **PlayerAnimator** | Fabric 1.20.1 | Анимации игрока (печати, стойки) |
| **GeckoLib** | Fabric 1.20.1 | Анимации мобов/врагов |
| **Cardinal Components API** | 5.2.2 | Хранение данных игрока |
| **MixinExtras** | 0.4.1 | Безопасные миксины |

### Шейдеры (не интегрируем, рекомендуем в паке):
- **Complementary Reimagined** — пресет "Anime/Japanese"
- **Bliss Shader** — для слабых ПК
- **Solas Shader** — PBR для японских блоков

---

## 🗂️ ПЛАН РЕАЛИЗАЦИИ ПО СПРИНТАМ

---

### 🔷 Спринт 1: Фундамент — интеграция модов

**Цель:** Подключить все моды, чтобы они не конфликтовали.

#### 1.1. `build.gradle` — добавить зависимости:

```groovy
repositories {
    maven { url 'https://maven.shedaniel.me/' }          // Cloth Config
    maven { url 'https://dl.cloudsmith.io/public/geckolib3/geckolib/maven/' } // GeckoLib
    maven { url 'https://maven.ladysnake.org/releases' }  // CCA
    maven { url 'https://maven.kosmx.dev/' }               // PlayerAnimator
    maven { url 'https://maven.maximilian-schneider.dev/releases' } // Iron's Spells
    maven { url 'https://maven.cafeteria.dev/' }            // Origins
}

dependencies {
    // Iron's Spells (заменяем ману чакрой)
    modImplementation 'net.maximilian-schneider:irons-spells-fabric:1.20.1-...'
    
    // Origins (кланы)
    modImplementation 'com.github.apace100:origins-fabric:1.10.0'
    modImplementation 'io.github.edwinmindcraft:origins-forge:...' // если нужен
    
    // Better Combat + PlayerAnimator
    modImplementation fileTree(dir: 'libs', include: ['*.jar'])
    
    // GeckoLib
    modImplementation 'software.bernie.geckolib:geckolib-fabric-1.20.1:4.4.9'
    
    // CCA
    modImplementation 'dev.onyxstudios.cardinal-components-api:cardinal-components-base:5.2.2'
    modImplementation 'dev.onyxstudios.cardinal-components-api:cardinal-components-entity:5.2.2'
}
```

#### 1.2. `fabric.mod.json` — обновить entrypoints:

```json
{
  "entrypoints": {
    "cardinal-components": [
      "com.example.shinobicore.stat.component.NinjaComponentInitializer"
    ],
    "main": ["com.example.shinobicore.ShinobiCore"],
    "client": ["com.example.shinobicore.ShinobiCoreClient"]
  },
  "depends": {
    "bettercombat": "*",
    "irons_spells": "*"
  }
}
```

#### 1.3. Замена маны → чакра в Iron's:

Создать файл `data/shinobicore/irons_spells_compat.json`:
```json
{
  "replace_mana_with": "shinobicore:chakra",
  "chakra_component": "shinobicore:chakra",
  "hide_mana_bar": true,
  "show_chakra_bar": true
}
```

И миксин `IronSpellsManaMixin.java`:
```java
@Mixin(targets = "net.maximilian_schneider.irons_spells...ManaComponent")
public abstract class IronSpellsManaMixin {
    @Redirect(method = "getMana", at = @At(value = "FIELD", target = "...mana"))
    private float replaceManaWithChakra(...) {
        // Возвращаем чакру вместо маны
        return NinjaComponents.getChakra(player).getCurrentChakra();
    }
}
```

---

### 🔷 Спринт 2: Физика паркура (клиент-авторитарная)

**Ключевые решения из твоих ответов:**

| Вопрос | Решение | Реализация |
|---|---|---|
| Сползание со стены | Медленно | `vel.y = -0.02` при отсутствии ввода |
| Прыжок от стены | В направлении взгляда | `vel = lookDir * 0.6 + (0, 0.45, 0)` |
| Потеря чакры на воде | Резко падать | `setOnGround(false)`, не гасить `vel.y` |
| Слайд в чакра-режиме | Длиннее | `25 тиков` вместо `15` |
| Двойной прыжок | Сохраняет инерцию | НЕ обнулять `vel.x/vel.z` |

#### 2.1. `WallWalkPhysics.java` (новая версия):

```java
package com.example.shinobicore.client.parkour;

public final class WallWalkPhysics {
    private static final double SLIDE_SPEED = -0.02;   // медленное сползание
    private static final double CLIMB_SPEED = 0.08;
    private static final double STRAFE_SPEED = 0.08;

    public static boolean tick(ClientPlayerEntity player) {
        if (!ClientNinjaState.chakraMode) return false;
        if (player.isOnGround()) return false;

        Vec3d normal = WallDetector.getWallNormal(player);
        if (normal == null) return false;

        Vec3d vel = player.getVelocity();
        float inputForward = player.input.movementForward;
        float inputStrafe = player.input.movementSideways;

        // 1. Отмена скорости В стену
        double dot = vel.x * normal.x + vel.z * normal.z;
        if (dot < 0) {
            vel = vel.subtract(normal.multiply(dot));
        }

        // 2. Вертикальное движение:
        //    - Ввод вперёд → вверх
        //    - Ввод назад → вниз
        //    - Нет ввода → МЕДЛЕННОЕ сползание (-0.02)
        double verticalVel;
        if (Math.abs(inputForward) > 0.01f) {
            verticalVel = inputForward * CLIMB_SPEED;
        } else {
            verticalVel = SLIDE_SPEED; // медленное сползание
        }

        // 3. Горизонтальное движение вдоль стены
        Vec3d look = player.getRotationVector();
        Vec3d forward = look.subtract(normal.multiply(look.dotProduct(normal)));
        if (forward.lengthSquared() < 0.001) forward = new Vec3d(0, 1, 0);
        forward = forward.normalize();
        Vec3d right = forward.crossProduct(normal).normalize();

        Vec3d move = forward.multiply(inputForward * STRAFE_SPEED)
                          .add(right.multiply(inputStrafe * STRAFE_SPEED));

        // 4. НЕ отменяем ванильный тик — только корректируем скорость
        player.setVelocity(move.x, verticalVel, move.z);
        player.fallDistance = 0f;

        return true;
    }
}
```

#### 2.2. `WaterWalkPhysics.java` (новая версия):

```java
public final class WaterWalkPhysics {
    public static boolean tick(ClientPlayerEntity player) {
        if (!ClientNinjaState.chakraMode) return false;

        BlockPos belowPos = player.getBlockPos().down();
        FluidState fluid = player.getWorld().getFluidState(belowPos);
        boolean isWater = fluid.isOf(Fluids.WATER) || fluid.isOf(Fluids.FLOWING_WATER);

        if (!isWater) return false;

        boolean isOnSurface = player.getY() >= belowPos.getY() + 0.85
                           && player.getY() <= belowPos.getY() + 1.15;

        if (isOnSurface && !player.isSubmergedInWater()) {
            // Ходьба по воде: фиксируем Y
            Vec3d vel = player.getVelocity();
            if (vel.y < 0) {
                player.setVelocity(vel.x, 0.0, vel.z);
            }
            player.setOnGround(true); // для прыжков
            player.fallDistance = 0f;
            return true;
        }

        // Потеря чакры или глубокая вода → РЕЗКО падаем
        // (НЕ гасим vel.y — просто не фиксируем)
        return false;
    }
}
```

#### 2.3. `WallJumpLogic.java`:

```java
public static void handleWallJump(ClientPlayerEntity player) {
    Vec3d normal = WallDetector.getWallNormal(player);
    if (normal == null) return;

    // Прыжок В НАПРАВЛЕНИИ ВЗГЛЯДА (решение #2)
    Vec3d look = player.getRotationVector();
    Vec3d jumpDir = new Vec3d(look.x, 0, look.z).normalize();

    // Компонент от стены + вверх
    Vec3d jumpVel = jumpDir.multiply(0.5)
                           .add(normal.multiply(0.3))
                           .add(0, 0.45, 0);

    player.setVelocity(jumpVel);
    player.velocityModified = true;
    player.fallDistance = 0f;
}
```

#### 2.4. `DoubleJumpLogic.java`:

```java
public static void handleDoubleJump(ClientPlayerEntity player) {
    Vec3d vel = player.getVelocity();

    // СОХРАНЯЕМ ИНЕРЦИЮ (решение #5)
    // НЕ обнуляем vel.x и vel.z
    player.setVelocity(vel.x, 0.95, vel.z);
    player.velocityModified = true;
}
```

#### 2.5. `SlideLogic.java`:

```java
public static void handleSlide(ClientPlayerEntity player, boolean chakraMode) {
    // Длиннее в чакра-режиме (решение #4)
    int duration = chakraMode ? 25 : 15;

    player.setPose(EntityPose.SWIMMING);
    float boost = chakraMode ? 0.81f : 0.45f;

    Vec3d look = player.getRotationVector();
    float rad = player.getYaw() * 0.017453292F;
    player.setVelocity(
        -Math.sin(rad) * boost,
        0.0,
        Math.cos(rad) * boost
    );
    player.velocityModified = true;
}
```

#### 2.6. Миксин — НЕ отменяем `tickMovement`:

```java
// ❌ НЕ ДЕЛАЕМ ТАК (это была ошибка V2):
// @Inject(method = "tickMovement", at = @At("HEAD"), cancellable = true)
// ci.cancel();

// ✅ ДЕЛАЕМ ТАК (мягкая коррекция):
@Mixin(LivingEntity.class)
public abstract class ChakraMovementMixin {
    @Inject(method = "travel", at = @At("TAIL"))
    private void shinobicore_chakraTravel(Vec3d movementInput, CallbackInfo ci) {
        if ((Object)this instanceof ClientPlayerEntity player) {
            if (ClientNinjaState.chakraMode) {
                // Мягкая коррекция скорости после ванильного расчёта
                WallWalkPhysics.tick(player);
                WaterWalkPhysics.tick(player);
            }
        }
    }
}
```

---

### 🔷 Спринт 3: Боевая система (катаны, комбо, блок)

**Ключевые решения:**

| Вопрос | Решение | Реализация |
|---|---|---|
| Уникальные комбо катан | Через прокачку ветки катан | Разные `weapon_attributes` |
| Парирование | Отражает снаряды | `KatanaDeflectMixin` |
| Сейган | 360° защита | Без проверки направления |
| Удар ногой | Часть комбо + самостоятельный | Два режима |
| Блок | Фиксированное кол-во стамины | `10 стамины за блок` |

#### 3.1. Датасеты катан для Better Combat:

`data/shinobicore/weapon_attributes/katana_iron.json`:
```json
{
  "attributes": {
    "attack_range": 3.0,
    "two_handed": false,
    "category": "katana",
    "attack_speed": 1.6,
    "attacks": [
      { "hitbox": "HORIZONTAL_PLANE", "damage_multiplier": 1.0, "angle": 120,
        "animation": "bettercombat:one_handed_slash_horizontal_right" },
      { "hitbox": "HORIZONTAL_PLANE", "damage_multiplier": 1.0, "angle": 120,
        "animation": "bettercombat:one_handed_slash_horizontal_left" },
      { "hitbox": "FORWARD_BOX", "damage_multiplier": 1.4, "angle": 0,
        "animation": "bettercombat:one_handed_stab" }
    ]
  }
}
```

`data/shinobicore/weapon_attributes/katana_advanced.json` (для прокачанной ветки):
```json
{
  "attributes": {
    "attack_range": 3.2,
    "two_handed": false,
    "category": "katana_advanced",
    "attack_speed": 1.8,
    "attacks": [
      { "hitbox": "HORIZONTAL_PLANE", "damage_multiplier": 1.1, "angle": 150,
        "animation": "player-anim:katana_slash_1" },
      { "hitbox": "HORIZONTAL_PLANE", "damage_multiplier": 1.1, "angle": 150,
        "animation": "player-anim:katana_slash_2" },
      { "hitbox": "VERTICAL_PLANE", "damage_multiplier": 1.3, "angle": 90,
        "animation": "player-anim:katana_slash_3" },
      { "hitbox": "HORIZONTAL_PLANE", "damage_multiplier": 1.5, "angle": 180,
        "animation": "player-anim:katana_slash_4" },
      { "hitbox": "FORWARD_BOX", "damage_multiplier": 2.0, "angle": 0,
        "animation": "player-anim:katana_finisher" }
    ]
  }
}
```

#### 3.2. `KatanaDeflectMixin.java` (отражение снарядов):

```java
@Mixin(LivingEntity.class)
public abstract class KatanaDeflectMixin {
    @Inject(method = "damage", at = @At("HEAD"), cancellable = true)
    private void shinobicore_katanaDeflect(DamageSource source, float amount,
                                           CallbackInfoReturnable<Boolean> cir) {
        LivingEntity self = (LivingEntity)(Object)this;
        if (!(self instanceof ServerPlayerEntity player)) return;

        ICombatComponent combat = NinjaComponents.getCombat(player);
        if (combat == null || !combat.isDeflecting()) return;

        // Проверяем стойку
        Stance stance = Stance.fromId(combat.getStanceId());
        if (!stance.canDeflect()) return;

        // Сейган — 360° защита (решение #8)
        if (stance != Stance.SEIGAN) {
            // Для остальных стоек проверяем фронт
            if (source.getSource() != null) {
                Vec3d toSource = source.getSource().getPos().subtract(player.getPos());
                Vec3d look = player.getRotationVector();
                double dot = toSource.normalize().dotProduct(look);
                if (dot < -0.2) return; // снаряд сзади
            }
        }

        // Отражаем снаряд
        if (source.getSource() instanceof PersistentProjectileEntity projectile) {
            projectile.setVelocity(projectile.getVelocity().multiply(-1.3));
            projectile.setOwner(player);
            projectile.velocityModified = true;
            cir.setReturnValue(false); // урон не проходит
        }
    }
}
```

#### 3.3. Удар ногой — часть комбо + самостоятельный:

```java
// В ClientInputHandler:
if (KeyBindings.KICK.wasPressed()) {
    // Самостоятельный удар ногой
    ParkourActionPacket.send(ParkourActions.KICK, player.getYaw());
}

// В ServerHandler:
case ParkourActions.KICK -> handleKick(player, parkour);

// В Better Combat датасете — 5-й шаг комбо = удар ногой
{
  "attacks": [
    ...,
    { "hitbox": "FORWARD_BOX", "damage_multiplier": 1.8, "angle": 60,
      "animation": "player-anim:kick_finisher" }
  ]
}
```

#### 3.4. Блок — фиксированная стамина:

```java
public static void handleBlock(ServerPlayerEntity player, boolean blocking) {
    ICombatComponent combat = NinjaComponents.getCombat(player);
    IChakraComponent chakra = NinjaComponents.getChakra(player);
    if (combat == null || chakra == null) return;

    if (blocking) {
        // Фиксированное кол-во стамины (решение #10)
        float staminaCost = 10.0f;
        if (chakra.getCurrentStamina() >= staminaCost) {
            chakra.spendStamina(staminaCost);
            combat.setBlocking(true);
        }
    } else {
        combat.setBlocking(false);
    }
}
```

---

### 🔷 Спринт 4: Дзюцу (замена маны → чакра)

**Ключевые решения:**

| Вопрос | Решение | Реализация |
|---|---|---|
| Замена маны чакрой | Да | Миксин на `ManaComponent` |
| Прогресс-бар | Под прицелом | `HudRenderCallback` |
| Печати рук | Параметр в JSON | `"hand_signs": true/false` |

#### 4.1. JSON техники с параметром печатей:

```json
{
  "id": "shinobicore:fireball",
  "name": "Fire Release: Fireball",
  "behavior": "projectile",
  "hand_signs": true,
  "hand_signs_duration": 30,
  "params": { "speed": 1.5, "radius": 1.0 },
  "baseCost": 30.0,
  "baseDamage": 10.0
}
```

#### 4.2. Прогресс-бар под прицелом:

```java
public class CastProgressBarHud {
    public static void render(DrawContext ctx, float tickDelta) {
        // Рисуем ПОД прицелом (решение #16)
        int cx = width / 2;
        int cy = height / 2 + 20; // под прицелом

        float progress = HandSignsClientState.getProgress();
        int barWidth = 100;
        int barHeight = 6;

        ctx.fill(cx - barWidth/2, cy, cx + barWidth/2, cy + barHeight, 0xFF333333);
        ctx.fill(cx - barWidth/2, cy, cx - barWidth/2 + (int)(barWidth * progress),
                 cy + barHeight, 0xFFFF8800);
    }
}
```

---

### 🔷 Спринт 5: Визуал (камера, модель, частицы)

**Ключевые решения:**

| Вопрос | Решение | Реализация |
|---|---|---|
| Камера на стене | Зависит от нормали | `roll = atan2(normal.x, normal.z) * 20` |
| Модель | Целиком наклоняется | `body.roll += rollRad` |
| Камера | Плавно поворачивается | `lerp(currentRoll, targetRoll, 0.1f)` |
| Частицы воды | Сплеши | `ParticleTypes.SPLASH` |

#### 5.1. `CameraRollSystem.java`:

```java
public class CameraRollSystem {
    private static float currentRoll = 0f;

    public static void tick(ClientPlayerEntity player) {
        float targetRoll = 0f;

        if (WallRunClientState.isActive()) {
            Vec3d normal = WallRunClientState.getWallNormal();
            float yawRad = player.getYaw() * 0.017453292F;
            float cos = (float) Math.cos(yawRad);
            float sin = (float) Math.sin(yawRad);
            float relX = normal.x * cos + normal.z * sin;
            targetRoll = relX * 20.0f; // зависит от нормали
            targetRoll = Math.max(-30.0f, Math.min(30.0f, targetRoll));
        }

        // Плавный поворот (решение #13)
        currentRoll += (targetRoll - currentRoll) * 0.1f;
    }

    public static float getCurrentRoll() { return currentRoll; }
}
```

#### 5.2. Миксин модели — целиком наклоняется:

```java
@Mixin(PlayerEntityModel.class)
public abstract class WallRunModelMixin extends BipedEntityModel<LivingEntity> {
    @Inject(method = "setAngles", at = @At("TAIL"))
    private void applyWallRunPose(...) {
        if (!WallRunClientState.isActive()) return;

        float rollRad = CameraRollSystem.getCurrentRoll() * 0.017453292F;

        // ЦЕЛИКОМ наклоняем модель (решение #12)
        this.body.roll += rollRad;
        this.head.roll += rollRad;
        this.rightArm.roll += rollRad;
        this.leftArm.roll += rollRad;
        this.rightLeg.roll += rollRad;
        this.leftLeg.roll += rollRad;
    }
}
```

#### 5.3. Частицы воды — сплеши:

```java
// В WaterWalkPhysics:
if (player.age % 3 == 0) {
    // СПЛЕШИ (решение #14)
    world.addParticle(ParticleTypes.SPLASH,
        player.getX(), player.getY() - 0.2, player.getZ(),
        0.2, 0.0, 0.2);
}
```

---

### 🔷 Спринт 6: Сетевая синхронизация

**Ключевые решения:**

| Вопрос | Решение | Реализация |
|---|---|---|
| Рассинхронизация | Плавная интерполяция | `lerp(clientPos, serverPos, 0.1f)` |
| Пакет позы | При смене позы | НЕ каждый тик |
| Баффы чакра-режима | Плавно затухают | `lerp(currentMult, targetMult, 0.05f)` |

#### 6.1. `PredictionCorrectionSystem.java`:

```java
public class PredictionCorrectionSystem {
    public static void applyCorrection(ClientPlayerEntity player,
                                       Vec3d serverPos, Vec3d serverVel) {
        Vec3d clientPos = player.getPos();
        double dist = clientPos.distanceTo(serverPos);

        if (dist > 10.0) {
            // Сильный рассинхрон — телепорт
            player.setPosition(serverPos);
        } else if (dist > 0.05) {
            // Плавная интерполяция (решение #18)
            Vec3d lerped = clientPos.lerp(serverPos, 0.1f);
            player.setPosition(lerped);
        }
    }
}
```

#### 6.2. Пакет позы — только при смене:

```java
// В ParkourServerHandler:
NinjaPose newPose = determinePose(player);
if (newPose != parkour.getCurrentPose()) {
    parkour.setCurrentPose(newPose);
    // Пакет ТОЛЬКО при смене (решение #19)
    NinjaComponents.PARKOUR.sync(player, parkour);
}
```

#### 6.3. Баффы чакра-режима — плавно затухают:

```java
public class ChakraModeSystem {
    private static float currentSpeedMult = 1.0f;

    public static void tick(ServerPlayerEntity player, boolean chakraMode) {
        float targetMult = chakraMode ? 1.5f : 1.0f;

        // Плавное затухание (решение #20)
        currentSpeedMult += (targetMult - currentSpeedMult) * 0.05f;

        var speedAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
        if (speedAttr != null) {
            speedAttr.setBaseValue(0.1 * currentSpeedMult);
        }
    }
}
```

---

### 🔷 Спринт 7: Контент (конец)

#### 7.1. Клоны (последняя очередь):
- `CloneEntity` через GeckoLib
- Статический манекен, разлетается при уроне

#### 7.2. Новые техники (последняя очередь):
- Добавлять через JSON + Behavior

#### 7.3. Новые кланы (последняя очередь):
- Добавлять через Origins + JSON

---

## 📊 ИТОГОВАЯ ТАБЛИЦА РЕШЕНИЙ

| # | Вопрос | Ответ | Файл реализации |
|---|---|---|---|
| 1 | Сползание со стены | Медленно (-0.02) | `WallWalkPhysics.java` |
| 2 | Прыжок от стены | В направлении взгляда | `WallJumpLogic.java` |
| 3 | Потеря чакры на воде | Резко падать | `WaterWalkPhysics.java` |
| 4 | Слайд в чакра-режиме | Длиннее (25 тиков) | `SlideLogic.java` |
| 5 | Двойной прыжок | Сохраняет инерцию | `DoubleJumpLogic.java` |
| 6 | Уникальные комбо катан | Через прокачку ветки | `weapon_attributes/*.json` |
| 7 | Парирование | Отражает снаряды | `KatanaDeflectMixin.java` |
| 8 | Сейган | 360° защита | `KatanaDeflectMixin.java` |
| 9 | Удар ногой | Часть комбо + самостоятельный | `weapon_attributes` + `ParkourActions` |
| 10 | Блок | Фиксированная стамина | `BlockSystem.java` |
| 11 | Камера на стене | Зависит от нормали | `CameraRollSystem.java` |
| 12 | Модель на стене | Целиком наклоняется | `WallRunModelMixin.java` |
| 13 | Камера | Плавно поворачивается | `CameraRollSystem.java` |
| 14 | Частицы воды | Сплеши | `WaterWalkPhysics.java` |
| 15 | Замена маны | Чакра | `IronSpellsManaMixin.java` |
| 16 | Прогресс-бар | Под прицелом | `CastProgressBarHud.java` |
| 17 | Печати рук | Параметр в JSON | `jutsu/*.json` |
| 18 | Рассинхронизация | Плавная интерполяция | `PredictionCorrectionSystem.java` |
| 19 | Пакет позы | При смене позы | `ParkourServerHandler.java` |
| 20 | Баффы чакра-режима | Плавно затухают | `ChakraModeSystem.java` |

