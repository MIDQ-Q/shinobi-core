# 📚 SHINOBI EDITOR v2.0 — ФИНАЛЬНАЯ ДОКУМЕНТАЦИЯ

**Версия:** 2.0.0  
**Дата:** 2026-09-05  
**Статус:** ✅ Утверждено (все решения зафиксированы)

---

## 📖 ОГЛАВЛЕНИЕ

1. [Философия и ключевые решения](#1-философия-и-ключевые-решения)
2. [Архитектура 4 слоёв](#2-архитектура-4-слоёв)
3. [Слой 1: ФОРМА (8 примитивов)](#3-слой-1-форма)
4. [Слой 2: ЭФФЕКТ (5 типов)](#4-слой-2-эффект)
5. [Слой 3: СВОЙСТВА (теги с параметрами)](#5-слой-3-свойства)
6. [Слой 4: СТИХИЯ (8 элементов)](#6-слой-4-стихия)
7. [Активация](#7-активация)
8. [Ресурсы и стоимость](#8-ресурсы-и-стоимость)
9. [Требования](#9-требования)
10. [Прокачка (1–15 уровней)](#10-прокачка)
11. [Формат JSON (финальный)](#11-формат-json)
12. [Валидация](#12-валидация)
13. [Редактор: интерфейс](#13-редактор-интерфейс)
14. [Предпросмотр](#14-предпросмотр)
15. [Интеграция с Blockbench](#15-интеграция-с-blockbench)
16. [Экспорт и интеграция с модом](#16-экспорт-и-интеграция)
17. [Примеры каноничных техник](#17-примеры)
18. [Справочник: полный список примитивов](#18-справочник)

---

## 1. ФИЛОСОФИЯ И КЛЮЧЕВЫЕ РЕШЕНИЯ

### 1.1 Принятые решения

| # | Вопрос | Решение |
|---|--------|---------|
| 1 | Формат данных | **Плоский объект** — все поля на одном уровне |
| 2 | Редактор | **Гибрид** — вкладки сверху + предпросмотр справа |
| 3 | Предпросмотр | **Средний** — воксельная сцена 16×16, манекен, частицы |
| 4 | Свойства | **Массив объектов с параметрами** |
| 5 | Совместимость | **Теги на каждом свойстве + мягкая валидация** |
| 6 | Экспорт | **Один файл на технику** |
| 7 | Прокачка | **Таблица уровней** |
| 8 | Blockbench | **Импорт/экспорт файлов** |
| 9 | Старые техники | **Полностью удаляются**, мод принимает только из редактора |
| 10 | Валидация | **Обязательные поля + совместимость** |

### 1.2 Принципы

- **Минимум примитивов**: ~25 примитивов вместо 300+ поведений
- **Композиция**: техника = Форма + Эффекты + Свойства + Стихия
- **Один файл = одна техника**
- **Мягкая валидация**: предупреждения, не блокировка
- **Только из редактора**: мод не принимает рукописные JSON

---

## 2. АРХИТЕКТУРА 4 СЛОЁВ

```
ТЕХНИКА = ФОРМА + ЭФФЕКТЫ + СВОЙСТВА + СТИХИЯ + МЕТА
```

| Слой | Обязательный? | Количество | Описание |
|------|:---:|:---:|----------|
| **ФОРМА** | ✅ | Ровно 1 | Как техника доставляется |
| **ЭФФЕКТЫ** | ✅ | 1–3 | Что делает при срабатывании |
| **СВОЙСТВА** | ❌ | 0–12 | Модификаторы поведения |
| **СТИХИЯ** | ❌ | 0–1 | Элементальная природа |

---

## 3. СЛОЙ 1: ФОРМА

### 3.1 Полный список (8 примитивов)

| ID | Название | Описание | Параметры |
|----|----------|----------|-----------|
| `point` | Точка | Эффект на себе или на цели вблизи | `range`, `targetMode` |
| `projectile` | Снаряд | Летящий объект | `speed`, `gravity`, `lifetime`, `size` |
| `beam` | Луч | Непрерывный поток | `width`, `maxRange`, `tickRate` |
| `zone` | Зона | Область с эффектом | `radius`, `duration`, `tickRate`, `shape` |
| `dash` | Рывок | Кастер летит к цели | `distance`, `speed`, `damageOnPath` |
| `summon` | Призыв | Появление сущности | `entityType`, `count`, `lifetime`, `behavior` |
| `construct` | Конструкт | Создание объекта из блоков | `width`, `height`, `duration`, `shape` |
| `handheld` | Ручной конструкт | Объект в руке кастера | `chargeTime`, `holdDuration`, `activation` |

### 3.2 Детали параметров

#### `point`
```json
{
  "type": "point",
  "params": {
    "range": 3.0,
    "targetMode": "self"  // self | touch | look_entity | raycast_point
  }
}
```

#### `projectile`
```json
{
  "type": "projectile",
  "params": {
    "speed": 1.4,
    "gravity": 0.02,
    "lifetime": 80,
    "size": 0.5,
    "count": 1,
    "spread": 0
  }
}
```

#### `beam`
```json
{
  "type": "beam",
  "params": {
    "width": 1.0,
    "maxRange": 16.0,
    "tickRate": 5
  }
}
```

#### `zone`
```json
{
  "type": "zone",
  "params": {
    "radius": 5.0,
    "duration": 100,
    "tickRate": 10,
    "shape": "sphere"  // sphere | cylinder | box
  }
}
```

#### `dash`
```json
{
  "type": "dash",
  "params": {
    "distance": 8.0,
    "speed": 3.0,
    "damageOnPath": true
  }
}
```

#### `summon`
```json
{
  "type": "summon",
  "params": {
    "entityType": "minecraft:wolf",
    "count": 2,
    "lifetime": 1200,
    "behavior": "fight_for_caster",
    "spawnPosition": "around_caster"
  }
}
```
**Поведения призыва:**
- `fight_for_caster` — атакует врагов кастера
- `protect_caster` — защищает, не атакует
- `passive` — просто существует
- `kamikaze` — атакует всё и взрывается
- `follow` — следует за кастером

#### `construct`
```json
{
  "type": "construct",
  "params": {
    "width": 5,
    "height": 3,
    "depth": 1,
    "duration": 200,
    "blockType": "earth",
    "shape": "wall"  // wall | dome | cage | pillar | platform
  }
}
```

#### `handheld`
```json
{
  "type": "handheld",
  "params": {
    "chargeTime": 40,
    "holdDuration": 400,
    "activation": "on_hit",  // on_hit | on_release | on_timeout
    "size": 1.0,
    "voxelModel": "rasengan_blue",
    "throwable": false
  }
}
```
**Особенности `handheld`:**
- Объект «висит» на руке кастера
- Исчезает при: ударе, истечении `holdDuration`, ручном сбросе
- При таймауте — просто растворяется без эффекта
- `throwable: true` позволяет бросить как снаряд

---

## 4. СЛОЙ 2: ЭФФЕКТ

### 4.1 Полный список (5 типов)

| Тип | Описание |
|-----|----------|
| `damage` | Нанесение урона |
| `control` | Ограничение действий цели |
| `buff` | Усиление цели |
| `debuff` | Ослабление цели |
| `world` | Изменение блоков/объектов |

### 4.2 Подтипы `damage`

| Подтип | Описание | Параметры |
|--------|----------|-----------|
| `instant` | Мгновенный урон | `amount` |
| `dot` | Урон со временем | `amount`, `duration`, `tickRate` |
| `percent` | % от макс. HP | `percent` |
| `true` | Истинный урон (игнор брони) | `amount` |
| `cellular` | Клеточный урон (Расенсюрикен) | `amount`, `duration` |

### 4.3 Подтипы `control`

| Подтип | Описание | Параметры |
|--------|----------|-----------|
| `stun` | Полное оглушение | `duration` |
| `root` | Обездвиживание | `duration`, `breakDamage` |
| `silence` | Запрет каста | `duration` |
| `blind` | Ослепление | `duration` |
| `fear` | Паника | `duration`, `fleeSpeed` |
| `confusion` | Дезориентация | `duration` |
| `sleep` | Сон | `duration`, `wakeOnDamage` |
| `paralysis` | Паралич | `duration` |
| `pull` | Притягивание | `force`, `point` |
| `push` | Отталкивание | `force` |
| `launch` | Подбрасывание | `force` |

### 4.4 Подтипы `buff`

| Подтип | Описание | Параметры |
|--------|----------|-----------|
| `heal` | Лечение | `amount` |
| `regen` | Регенерация | `rate`, `duration` |
| `chakra_regen` | Регенерация чакры | `rate`, `duration` |
| `shield` | Поглощение урона | `amount`, `duration` |
| `speed` | Ускорение | `bonus`, `duration` |
| `strength` | Увеличение урона | `bonus`, `duration` |
| `resistance` | Снижение урона | `percent`, `duration` |
| `haste` | Ускорение каста | `bonus`, `duration` |
| `invisibility` | Невидимость | `duration`, `breakOnAttack` |
| `purify` | Снятие дебаффов | `count` |

### 4.5 Подтипы `debuff`

| Подтип | Описание | Параметры |
|--------|----------|-----------|
| `burn` | Горение | `dps`, `duration`, `spread` |
| `poison` | Отравление | `dps`, `duration`, `type` |
| `slow` | Замедление | `percent`, `duration` |
| `weakness` | Снижение урона | `percent`, `duration` |
| `vulnerability` | Увеличение получаемого урона | `percent`, `duration` |
| `bleed` | Кровотечение | `dps`, `duration`, `stackable` |
| `curse` | Проклятие | `type`, `duration`, `spread` |
| `exhaustion` | Усиление усталости | `amount` |
| `chakra_drain` | Поглощение чакры | `rate`, `duration` |

### 4.6 Подтипы `world`

| Подтип | Описание | Параметры |
|--------|----------|-----------|
| `place_block` | Поставить временный блок | `blockType`, `duration` |
| `remove_block` | Удалить блок | `area` |
| `transform_block` | Трансформировать блок | `from`, `to` |
| `ignite` | Поджечь блоки | `area` |
| `freeze` | Заморозить воду | `area` |
| `create_entity` | Создать сущность | `entityType` |

### 4.7 Пример мульти-эффекта

```json
"effects": [
  { "type": "damage", "subtype": "instant", "params": { "amount": 15 } },
  { "type": "control", "subtype": "stun", "params": { "duration": 40 } },
  { "type": "debuff", "subtype": "burn", "params": { "dps": 2, "duration": 100 } }
]
```

---

## 5. СЛОЙ 3: СВОЙСТВА

### 5.1 Формат: массив объектов с параметрами

Каждое свойство — объект с `id` и `params`:
```json
"properties": [
  { "id": "homing", "params": { "turnRate": 0.3 } },
  { "id": "piercing", "params": { "count": 3 } },
  { "id": "explode_on_hit", "params": { "radius": 3.0, "damage": 8.0 } }
]
```

### 5.2 Полный список свойств

#### Траектория (для `projectile`)

| ID | Название | Параметры | Совместимые формы |
|----|----------|-----------|:---:|
| `trajectory_straight` | Прямая | — | `projectile` |
| `trajectory_arc` | Дуга | `arcHeight` | `projectile` |
| `trajectory_spiral` | Спираль | `spiralRate` | `projectile` |
| `trajectory_wave` | Волна | `amplitude`, `frequency` | `projectile` |
| `homing` | Самонаведение | `turnRate` | `projectile` |
| `boomerang` | Возврат | — | `projectile` |

#### Поведение в полёте (для `projectile`)

| ID | Название | Параметры | Совместимые формы |
|----|----------|-----------|:---:|
| `piercing` | Пробивание | `count`, `damageFalloff` | `projectile`, `beam` |
| `bouncing` | Рикошет | `count`, `speedLoss` | `projectile` |
| `splitting` | Разделение | `count`, `angle` | `projectile` |
| `chaining` | Цепь | `count`, `range`, `falloff` | `projectile` |
| `orbiting` | Орбита | `radius`, `speed`, `count` | `projectile` |
| `volley` | Залп | `count`, `spreadAngle` | `projectile` |
| `gravity_affected` | Гравитация | `strength` | `projectile` |
| `no_gravity` | Без гравитации | — | `projectile` |

#### Поведение при попадании

| ID | Название | Параметры | Совместимые формы |
|----|----------|-----------|:---:|
| `explode_on_hit` | Взрыв | `radius`, `damage`, `knockback` | `projectile`, `dash`, `handheld` |
| `stick_on_hit` | Прилипание | `duration` | `projectile` |
| `delayed_explosion` | Отложенный взрыв | `delay`, `radius`, `damage` | `projectile`, `zone` |
| `chain_explosion` | Цепной взрыв | `count`, `delay`, `radius` | `projectile`, `zone` |
| `implosion` | Имплозия | `radius`, `pullForce` | `projectile`, `zone` |

#### Специальные

| ID | Название | Параметры | Совместимые формы |
|----|----------|-----------|:---:|
| `multi_target` | Несколько целей | `count` | все |
| `self_target` | Только на себе | — | `point`, `zone` |
| `ally_target` | Можно на союзниках | — | `point`, `zone` |
| `silent` | Без звука | — | все |
| `invisible_projectile` | Невидимый снаряд | — | `projectile` |
| `unblockable` | Нельзя заблокировать | — | все |
| `unreflectable` | Нельзя отразить | — | все |
| `lifesteal` | Вампиризм | `percent` | все с уроном |
| `chakra_drain_on_hit` | Кража чакры | `amount` | все с уроном |
| `execute_bonus` | Бонус казни | `threshold`, `bonus` | все с уроном |
| `chargeable` | Можно заряжать | `minCharge`, `maxCharge` | `projectile`, `handheld` |
| `interruptible` | Можно прервать | — | все |
| `throwable` | Можно бросить | — | `handheld` |
| `multi_use` | Многоразовый | — | `handheld` |

#### Длительность

| ID | Название | Параметры | Совместимые формы |
|----|----------|-----------|:---:|
| `channeled` | Канал | `chakraPerTick`, `maxDuration` | `beam`, `zone` |
| `aura` | Аура вокруг кастера | `radius`, `chakraPerTick` | `zone` |
| `toggle` | Вкл/выкл | — | `zone`, `buff` |
| `permanent` | Постоянно | — | `construct`, `world` |

### 5.3 Теги совместимости

Каждое свойство содержит поле `compatibleForms`:
```json
{
  "id": "homing",
  "name": "Самонаведение",
  "params": { "turnRate": { "type": "float", "default": 0.3, "min": 0.1, "max": 1.0 } },
  "compatibleForms": ["projectile"]
}
```

### 5.4 Мягкая валидация

При добавлении несовместимого свойства:
- ⚠️ Показывается **жёлтое предупреждение**
- ❌ **Не блокируется** добавление
- Пользователь может игнорировать предупреждение

---

## 6. СЛОЙ 4: СТИХИЯ

### 6.1 Полный список (8 элементов)

| ID | Название | Авто-визуал | Авто-звук | Дефолтный эффект |
|----|----------|-------------|-----------|------------------|
| `fire` | Огонь | Оранжевые частицы | `entity.blaze.shoot` | Поджог |
| `water` | Вода | Синие частицы | `entity.generic.splash` | Замедление |
| `wind` | Ветер | Зелёные вихри | `entity.player.attack.sweep` | Отбрасывание |
| `earth` | Земля | Коричневая пыль | `block.stone.hit` | Оглушение |
| `lightning` | Молния | Жёлтые искры | `entity.lightning_bolt.thunder` | Шок |
| `yin` | Инь | Фиолетовые частицы | `entity.illusioner.cast_spell` | Иллюзия |
| `yang` | Ян | Белое свечение | `entity.player.levelup` | Усиление |
| `none` | Нет | Настраивается вручную | Настраивается | — |

### 6.2 Стихия опциональна

```json
"element": "fire"   // или "none"
```

### 6.3 Кеккей Генкай (запланировано на будущее)

В текущей версии **не реализовано**. Зарезервировано поле:
```json
"kekkeiGenkai": null  // будущее: ["water", "wind"] → "ice"
```

---

## 7. АКТИВАЦИЯ

Активация — **параметр техники**, не отдельный слой.

| Тип | Описание | Параметры |
|-----|----------|-----------|
| `instant` | Мгновенная | — |
| `handseals` | Печати рук | `sealCount`, `sealSpeed` |
| `charge` | Зарядка | `minCharge`, `maxCharge` |
| `hold` | Удержание | `chakraPerTick` |
| `combo` | Серия действий | `steps`, `windowMs` |
| `counter` | Контратака | `windowMs`, `damageThreshold` |
| `on_death` | При смерти | — |
| `passive` | Пассивная | — |
| `conditional` | По условию | `condition` |

```json
"activation": {
  "type": "handseals",
  "params": { "sealCount": 3, "sealSpeed": 1.0 }
}
```

---

## 8. РЕСУРСЫ И СТОИМОСТЬ

```json
"cost": {
  "chakra": 30,
  "fatigue": 6
}
```

Доступные ресурсы:
- `chakra` — чакра
- `fatigue` — усталость
- `hunger` — голод
- `health` — здоровье
- `item` — предмет (указать `itemId`)
- `eye` — додзюцу-ресурс

---

## 9. ТРЕБОВАНИЯ

Все поля опциональны. Если поле не указано — требование не предъявляется.

```json
"requirements": {
  "uses": 50,
  "sp": 5,
  "stats": {
    "control": 30,
    "ninjutsu": 25
  },
  "elements": {
    "fire": 20
  },
  "dojutsu": "sharingan_3"
}
```

---

## 10. ПРОКАЧКА (1–15 УРОВНЕЙ)

### 10.1 Формат: таблица уровней

```json
"leveling": {
  "maxLevel": 15,
  "levels": {
    "1": { "damage": 8, "cost": 35, "range": 24 },
    "3": { "damage": 10, "cost": 32, "unlock": ["burn"] },
    "5": { "damage": 12, "cost": 28, "requirements": { "uses": 30, "sp": 3 } },
    "7": { "damage": 14, "cost": 25, "unlock": ["knockback_up"] },
    "10": { "damage": 16, "cost": 22, "requirements": { "stats": { "ninjutsu": 30 } } },
    "12": { "damage": 18, "cost": 20, "unlock": ["piercing"] },
    "15": { "damage": 20, "cost": 18, "requirements": { "uses": 200, "sp": 12 } }
  }
}
```

### 10.2 Правила

- Уровни указываются **только для изменяемых**
- Между указанными уровнями — **линейная интерполяция**
- `unlock` — новые свойства на уровне
- `requirements` — требования для достижения уровня

### 10.3 Вкладки требований уровня

| Поле | Описание |
|------|----------|
| `uses` | Количество использований |
| `sp` | Стоимость в очках навыков |
| `stats` | Требуемые уровни статов |
| `elements` | Требуемые уровни стихий |

Если поле не указано — требование не предъявляется.

---

## 11. ФОРМАТ JSON (ФИНАЛЬНЫЙ)

### 11.1 Полная структура

```json
{
  "id": "shinobicore:fire_release_great_fireball",
  "name": "Fire Release: Great Fireball Jutsu",
  "description": "Мощный огненный шар",
  "category": "elemental_ninjutsu",
  "rank": "C",

  "form": {
    "type": "projectile",
    "params": {
      "speed": 1.4,
      "gravity": 0.02,
      "lifetime": 80,
      "size": 0.5
    }
  },

  "effects": [
    { "type": "damage", "subtype": "instant", "params": { "amount": 8 } },
    { "type": "debuff", "subtype": "burn", "params": { "dps": 1, "duration": 40 } }
  ],

  "properties": [
    { "id": "explode_on_hit", "params": { "radius": 3.0, "damage": 8.0, "knockback": 0.5 } },
    { "id": "trajectory_straight", "params": {} }
  ],

  "element": "fire",

  "activation": {
    "type": "handseals",
    "params": { "sealCount": 3, "sealSpeed": 1.0 }
  },

  "cost": {
    "chakra": 30,
    "fatigue": 6
  },

  "requirements": {
    "stats": { "control": 15, "ninjutsu": 15 },
    "elements": { "fire": 1 }
  },

  "leveling": {
    "maxLevel": 15,
    "levels": {
      "1": { "damage": 8, "cost": 35, "range": 24 },
      "5": { "damage": 12, "cost": 28, "requirements": { "uses": 30, "sp": 3 } },
      "10": { "damage": 16, "cost": 22, "requirements": { "stats": { "ninjutsu": 30 } } },
      "15": { "damage": 20, "cost": 18 }
    }
  },

  "visual": {
    "particle": "flame",
    "trail": true,
    "impactParticle": "lava",
    "color": "#FF6600",
    "voxelModel": null
  },

  "sound": {
    "cast": "entity.blaze.shoot",
    "hit": "entity.generic.explode"
  },

  "tags": ["fire", "projectile", "offensive", "aoe"]
}
```

### 11.2 Обязательные поля

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | string | Уникальный ID |
| `name` | string | Название |
| `form` | object | Форма (ровно 1) |
| `effects` | array | Эффекты (1–3) |

### 11.3 Необязательные поля

| Поле | Тип | Описание |
|------|-----|----------|
| `description` | string | Описание |
| `category` | string | Категория |
| `rank` | string | Ранг (D, C, B, A, S) |
| `properties` | array | Свойства (0–12) |
| `element` | string | Стихия или `"none"` |
| `activation` | object | Активация |
| `cost` | object | Стоимость |
| `requirements` | object | Требования |
| `leveling` | object | Прокачка |
| `visual` | object | Визуал |
| `sound` | object | Звук |
| `tags` | array | Теги |

---

## 12. ВАЛИДАЦИЯ

### 12.1 Уровень 1: Обязательные поля (ошибки)

- ❌ Отсутствует `id` или `name`
- ❌ Отсутствует `form` или `form.type` не из списка
- ❌ Отсутствует `effects` или массив пуст
- ❌ `effects` содержит более 3 элементов
- ❌ `form.type` = `handheld` но `activation.type` = `handseals` (нельзя одновременно)

### 12.2 Уровень 2: Совместимость (предупреждения)

- ⚠️ Свойство несовместимо с формой
- ⚠️ Более 3 стихийных свойств
- ⚠️ `element: none` но свойства стихийные
- ⚠️ `cost.chakra` = 0 и нет `cost.health`
- ⚠️ `effects` содержит два одинаковых `subtype`

### 12.3 Пример вывода валидации

```
✅ Обязательные поля: ОК
⚠️ Свойство "orbiting" несовместимо с формой "dash"
⚠️ Стихия не указана, но есть свойство "explode_on_hit"
✅ Совместимость: 2 предупреждения
```

---

## 13. РЕДАКТОР: ИНТЕРФЕЙС

### 13.1 Макет (гибрид: вкладки + предпросмотр)

```
┌─────────────────────────────────────────────────────────────┐
│ [Форма] [Эффект] [Свойства] [Стихия] [Активация] [Прокачка]│
├──────────────────────────────────────┬──────────────────────┤
│                                      │                      │
│   Содержимое выбранной вкладки       │   ПРЕДПРОСМОТР      │
│                                      │   (3D сцена)        │
│   ┌──────────────────────────────┐   │                      │
│   │ Список примитивов            │   │   Воксельная        │
│   │ с поиском                    │   │   сцена 16×16       │
│   └──────────────────────────────┘   │   с манекеном       │
│                                      │   и частицами       │
│   ┌──────────────────────────────┐   │                      │
│   │ Параметры выбранного         │   │                      │
│   │ (слайдеры, инпуты)           │   │                      │
│   └──────────────────────────────┘   │                      │
│                                      │                      │
│   ┌──────────────────────────────┐   │                      │
│   │ Добавлено в технику          │   │                      │
│   │ (список с удалением)         │   │                      │
│   └──────────────────────────────┘   │                      │
│                                      │                      │
├──────────────────────────────────────┴──────────────────────┤
│ [Валидация: ⚠️ 2 предупреждения]  [Экспорт] [Сохранить]    │
└─────────────────────────────────────────────────────────────┘
```

### 13.2 Вкладки

| Вкладка | Содержимое |
|---------|-----------|
| **Форма** | Выбор 1 из 8 форм, настройка параметров |
| **Эффект** | Добавление 1–3 эффектов, настройка подтипов |
| **Свойства** | Добавление тегов из списка, настройка параметров |
| **Стихия** | Выбор стихии или `none`, авто-визуал |
| **Активация** | Выбор типа активации, параметры |
| **Прокачка** | Таблица уровней, требования, разблокировки |

### 13.3 Панель предпросмотра

- Воксельная сцена 16×16 блоков
- Персонаж-манекен
- Визуализация формы (траектория снаряда, зона, рывок)
- Частицы по стихии
- Обновление в реальном времени при изменении параметров

---

## 14. ПРЕДПРОСМОТР

### 14.1 Уровень детализации: средний

- ✅ Воксельная сцена 16×16 блоков
- ✅ Персонаж-манекен
- ✅ Визуализация формы и эффектов частицами
- ✅ Траектория снаряда
- ✅ Зона действия
- ❌ Анимация каста (не требуется)
- ❌ Сложная физика
- ❌ Полноценный рендер моделей

### 14.2 Что показывается

| Элемент | Как показывается |
|---------|-----------------|
| Снаряд | Точка с траекторией + частицы |
| Зона | Полупрозрачная сфера/цилиндр |
| Рывок | Стрелка направления |
| Луч | Линия с частицами |
| Ручной конструкт | Сфера на руке манекена |
| Призыв | Иконка сущности |
| Конструкт | Воксельная стена/купол |

---

## 15. ИНТЕГРАЦИЯ С BLOCKBENCH

### 15.1 Решение: импорт/экспорт файлов

- **Импорт**: загрузка `.bbmodel` → конвертация в воксельный формат
- **Экспорт**: сохранение воксельной модели как `.bbmodel`
- **Хранение**: `assets/shinobicore/voxels/*.json`

### 15.2 Поля в технике

```json
"visual": {
  "voxelModel": "rasengan_blue",
  "particle": "flame",
  "trail": true,
  "color": "#FF6600"
}
```

Если `voxelModel` указан — используется 3D-модель из вокселей.
Если `null` — используются стандартные частицы.

---

## 16. ЭКСПОРТ И ИНТЕГРАЦИЯ

### 16.1 Один файл на технику

```
data/shinobicore/jutsu/
├── fire_release_great_fireball.json
├── rasengan.json
├── chidori.json
├── amaterasu.json
└── kamui.json
```

### 16.2 Два режима экспорта

#### Режим A: Скачивание
- Кнопка «Экспорт» → скачивается `.json` файл
- Пользователь вручную кладёт в папку мода

#### Режим B: Интеграция с модом
- Пользователь указывает путь к папке мода
- Редактор автоматически записывает файл
- Опционально: копирует воксельные модели

### 16.3 Старые техники удаляются

- Мод **не принимает** рукописные JSON
- Все техники создаются **только через редактор**
- Старые файлы из `data/shinobicore/jutsu/` удаляются

### 16.4 Загрузка модом

```java
// JutsuRegistry.reload()
// Читает только файлы, созданные редактором
// Проверяет наличие поля "editor_version"
// Если поле отсутствует — файл игнорируется с предупреждением
```

---

## 17. ПРИМЕРЫ КАНОНИЧНЫХ ТЕХНИК

### 17.1 Огненный шар (Катон: Гокакью)

```json
{
  "id": "shinobicore:katon_gokakyu",
  "name": "Fire Release: Great Fireball",
  "category": "elemental_ninjutsu",
  "rank": "C",
  "form": {
    "type": "projectile",
    "params": { "speed": 1.4, "gravity": 0.02, "lifetime": 80, "size": 0.5 }
  },
  "effects": [
    { "type": "damage", "subtype": "instant", "params": { "amount": 8 } },
    { "type": "debuff", "subtype": "burn", "params": { "dps": 1, "duration": 40 } }
  ],
  "properties": [
    { "id": "explode_on_hit", "params": { "radius": 3.0, "damage": 8.0, "knockback": 0.5 } }
  ],
  "element": "fire",
  "activation": { "type": "handseals", "params": { "sealCount": 3 } },
  "cost": { "chakra": 30, "fatigue": 6 },
  "requirements": { "stats": { "control": 15, "ninjutsu": 15 }, "elements": { "fire": 1 } },
  "leveling": {
    "maxLevel": 15,
    "levels": {
      "1": { "damage": 8, "cost": 35 },
      "5": { "damage": 12, "cost": 28 },
      "10": { "damage": 16, "cost": 22 },
      "15": { "damage": 20, "cost": 18 }
    }
  },
  "tags": ["fire", "projectile", "offensive"]
}
```

### 17.2 Расенган

```json
{
  "id": "shinobicore:rasengan",
  "name": "Rasengan",
  "category": "shape_ninjutsu",
  "rank": "A",
  "form": {
    "type": "handheld",
    "params": {
      "chargeTime": 40,
      "holdDuration": 400,
      "activation": "on_hit",
      "size": 1.0,
      "voxelModel": "rasengan_blue",
      "throwable": false
    }
  },
  "effects": [
    { "type": "damage", "subtype": "instant", "params": { "amount": 16 } },
    { "type": "control", "subtype": "launch", "params": { "force": 1.5 } }
  ],
  "properties": [
    { "id": "explode_on_hit", "params": { "radius": 2.0, "damage": 16.0, "knockback": 2.0 } },
    { "id": "multi_use", "params": {} }
  ],
  "element": "none",
  "activation": { "type": "charge", "params": { "minCharge": 20, "maxCharge": 60 } },
  "cost": { "chakra": 50, "fatigue": 12 },
  "requirements": { "stats": { "control": 30, "ninjutsu": 25 } },
  "leveling": {
    "maxLevel": 15,
    "levels": {
      "1": { "damage": 16, "cost": 50 },
      "10": { "damage": 32, "cost": 40 },
      "15": { "damage": 40, "cost": 35 }
    }
  },
  "visual": { "voxelModel": "rasengan_blue", "particle": "soul_fire_flame" },
  "tags": ["shape", "melee", "offensive"]
}
```

### 17.3 Чидори

```json
{
  "id": "shinobicore:chidori",
  "name": "Chidori",
  "category": "elemental_ninjutsu",
  "rank": "A",
  "form": {
    "type": "dash",
    "params": { "distance": 8.0, "speed": 3.0, "damageOnPath": true }
  },
  "effects": [
    { "type": "damage", "subtype": "instant", "params": { "amount": 20 } },
    { "type": "control", "subtype": "stun", "params": { "duration": 10 } }
  ],
  "properties": [
    { "id": "piercing", "params": { "count": 3 } }
  ],
  "element": "lightning",
  "activation": { "type": "charge", "params": { "minCharge": 30, "maxCharge": 45 } },
  "cost": { "chakra": 60, "fatigue": 15 },
  "requirements": {
    "stats": { "control": 35, "ninjutsu": 30 },
    "elements": { "lightning": 1 },
    "dojutsu": "sharingan_1"
  },
  "leveling": {
    "maxLevel": 15,
    "levels": {
      "1": { "damage": 20, "cost": 60 },
      "15": { "damage": 45, "cost": 45 }
    }
  },
  "tags": ["lightning", "dash", "offensive"]
}
```

### 17.4 Амацерасу

```json
{
  "id": "shinobicore:amaterasu",
  "name": "Amaterasu",
  "category": "elemental_ninjutsu",
  "rank": "S",
  "form": {
    "type": "projectile",
    "params": { "speed": 2.0, "gravity": 0, "lifetime": 200, "size": 0.3 }
  },
  "effects": [
    { "type": "damage", "subtype": "instant", "params": { "amount": 5 } },
    { "type": "debuff", "subtype": "burn", "params": { "dps": 3, "duration": 200, "spread": true } },
    { "type": "debuff", "subtype": "curse", "params": { "type": "burn", "duration": 200 } }
  ],
  "properties": [
    { "id": "stick_on_hit", "params": { "duration": 200 } },
    { "id": "unblockable", "params": {} },
    { "id": "unreflectable", "params": {} }
  ],
  "element": "fire",
  "activation": { "type": "instant", "params": {} },
  "cost": { "chakra": 80, "eye": 1 },
  "requirements": {
    "stats": { "control": 50, "ninjutsu": 45 },
    "elements": { "fire": 3 },
    "dojutsu": "mangekyo_sharingan"
  },
  "tags": ["fire", "projectile", "offensive", "kinjutsu"]
}
```

### 17.5 Теневые путы (Нара)

```json
{
  "id": "shinobicore:shadow_bind",
  "name": "Shadow Possession Jutsu",
  "category": "shape_ninjutsu",
  "rank": "B",
  "form": {
    "type": "zone",
    "params": { "radius": 3.0, "duration": 120, "tickRate": 10, "shape": "cylinder" }
  },
  "effects": [
    { "type": "control", "subtype": "root", "params": { "duration": 120, "breakDamage": 10 } }
  ],
  "properties": [],
  "element": "yin",
  "activation": { "type": "handseals", "params": { "sealCount": 1 } },
  "cost": { "chakra": 40, "fatigue": 8 },
  "requirements": { "stats": { "control": 30, "ninjutsu": 25 } },
  "tags": ["yin", "zone", "control"]
}
```

### 17.6 Гендзюцу: Паралич

```json
{
  "id": "shinobicore:genjutsu_paralysis",
  "name": "Genjutsu: Paralysis",
  "category": "genjutsu",
  "rank": "B",
  "form": {
    "type": "point",
    "params": { "range": 12.0, "targetMode": "look_entity" }
  },
  "effects": [
    { "type": "control", "subtype": "paralysis", "params": { "duration": 40 } },
    { "type": "debuff", "subtype": "slow", "params": { "percent": 50, "duration": 60 } }
  ],
  "properties": [],
  "element": "yin",
  "activation": { "type": "instant", "params": {} },
  "cost": { "chakra": 35, "fatigue": 10 },
  "requirements": { "stats": { "genjutsu": 20, "control": 15 } },
  "tags": ["yin", "genjutsu", "control"]
}
```

### 17.7 Расенсюрикен

```json
{
  "id": "shinobicore:rasenshuriken",
  "name": "Wind Release: Rasenshuriken",
  "category": "shape_ninjutsu",
  "rank": "S",
  "form": {
    "type": "handheld",
    "params": {
      "chargeTime": 80,
      "holdDuration": 600,
      "activation": "on_release",
      "size": 2.0,
      "voxelModel": "rasenshuriken",
      "throwable": true
    }
  },
  "effects": [
    { "type": "damage", "subtype": "instant", "params": { "amount": 45 } },
    { "type": "damage", "subtype": "cellular", "params": { "amount": 10, "duration": 100 } },
    { "type": "control", "subtype": "push", "params": { "force": 3.0 } }
  ],
  "properties": [
    { "id": "explode_on_hit", "params": { "radius": 8.0, "damage": 45.0, "knockback": 3.0 } },
    { "id": "trajectory_straight", "params": {} }
  ],
  "element": "wind",
  "activation": { "type": "charge", "params": { "minCharge": 60, "maxCharge": 120 } },
  "cost": { "chakra": 100, "fatigue": 20 },
  "requirements": {
    "stats": { "control": 40, "ninjutsu": 40 },
    "elements": { "wind": 40 }
  },
  "leveling": {
    "maxLevel": 15,
    "levels": {
      "1": { "damage": 45, "cost": 100 },
      "15": { "damage": 90, "cost": 80 }
    }
  },
  "visual": { "voxelModel": "rasenshuriken", "particle": "cloud" },
  "tags": ["wind", "shape", "offensive", "aoe"]
}
```

### 17.8 Призыв: Волки

```json
{
  "id": "shinobicore:summon_wolves",
  "name": "Summoning: Wolf Pack",
  "category": "summoning",
  "rank": "B",
  "form": {
    "type": "summon",
    "params": {
      "entityType": "minecraft:wolf",
      "count": 2,
      "lifetime": 1200,
      "behavior": "fight_for_caster",
      "spawnPosition": "around_caster"
    }
  },
  "effects": [],
  "properties": [],
  "element": "none",
  "activation": { "type": "handseals", "params": { "sealCount": 3 } },
  "cost": { "chakra": 45, "fatigue": 10 },
  "requirements": { "stats": { "control": 20, "ninjutsu": 20 } },
  "tags": ["summon", "support"]
}
```

### 17.9 Камуи

```json
{
  "id": "shinobicore:kamui",
  "name": "Kamui",
  "category": "space_time_ninjutsu",
  "rank": "S",
  "form": {
    "type": "point",
    "params": { "range": 32.0, "targetMode": "raycast_point" }
  },
  "effects": [
    { "type": "world", "subtype": "create_entity", "params": { "entityType": "shinobicore:kamui_portal" } }
  ],
  "properties": [
    { "id": "unblockable", "params": {} },
    { "id": "unreflectable", "params": {} }
  ],
  "element": "none",
  "activation": { "type": "instant", "params": {} },
  "cost": { "chakra": 100, "eye": 1 },
  "requirements": {
    "stats": { "control": 60, "space_time": 40 },
    "dojutsu": "mangekyo_sharingan"
  },
  "tags": ["space_time", "utility", "kinjutsu"]
}
```

### 17.10 Водяная стена

```json
{
  "id": "shinobicore:water_wall",
  "name": "Water Release: Water Wall",
  "category": "elemental_ninjutsu",
  "rank": "B",
  "form": {
    "type": "construct",
    "params": {
      "width": 5,
      "height": 3,
      "depth": 1,
      "duration": 200,
      "blockType": "water",
      "shape": "wall"
    }
  },
  "effects": [
    { "type": "debuff", "subtype": "slow", "params": { "percent": 30, "duration": 200 } }
  ],
  "properties": [
    { "id": "permanent", "params": {} }
  ],
  "element": "water",
  "activation": { "type": "handseals", "params": { "sealCount": 2 } },
  "cost": { "chakra": 35, "fatigue": 8 },
  "requirements": { "stats": { "control": 20, "ninjutsu": 15 }, "elements": { "water": 1 } },
  "tags": ["water", "construct", "defensive"]
}
```

---

## 18. СПРАВОЧНИК: ПОЛНЫЙ СПИСОК ПРИМИТИВОВ

### Формы (8)
`point` | `projectile` | `beam` | `zone` | `dash` | `summon` | `construct` | `handheld`

### Эффекты (5 типов, 41 подтип)
- `damage`: `instant`, `dot`, `percent`, `true`, `cellular`
- `control`: `stun`, `root`, `silence`, `blind`, `fear`, `confusion`, `sleep`, `paralysis`, `pull`, `push`, `launch`
- `buff`: `heal`, `regen`, `chakra_regen`, `shield`, `speed`, `strength`, `resistance`, `haste`, `invisibility`, `purify`
- `debuff`: `burn`, `poison`, `slow`, `weakness`, `vulnerability`, `bleed`, `curse`, `exhaustion`, `chakra_drain`
- `world`: `place_block`, `remove_block`, `transform_block`, `ignite`, `freeze`, `create_entity`

### Свойства (32)
Траектория: `trajectory_straight`, `trajectory_arc`, `trajectory_spiral`, `trajectory_wave`, `homing`, `boomerang`

Полёт: `piercing`, `bouncing`, `splitting`, `chaining`, `orbiting`, `volley`, `gravity_affected`, `no_gravity`

Попадание: `explode_on_hit`, `stick_on_hit`, `delayed_explosion`, `chain_explosion`, `implosion`

Специальные: `multi_target`, `self_target`, `ally_target`, `silent`, `invisible_projectile`, `unblockable`, `unreflectable`, `lifesteal`, `chakra_drain_on_hit`, `execute_bonus`, `chargeable`, `interruptible`, `throwable`, `multi_use`

Длительность: `channeled`, `aura`, `toggle`, `permanent`

### Стихии (8)
`fire` | `water` | `wind` | `earth` | `lightning` | `yin` | `yang` | `none`

### Активации (9)
`instant` | `handseals` | `charge` | `hold` | `combo` | `counter` | `on_death` | `passive` | `conditional`

### Ресурсы (6)
`chakra` | `fatigue` | `hunger` | `health` | `item` | `eye`

---

**Документация утверждена. Все 10 решений зафиксированы.** 🍥