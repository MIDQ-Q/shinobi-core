

Создай файл `PROJECT_HANDOFF.md` в корне проекта и вставь туда следующее:

```markdown
# 🍥 ShinobiCore — Документ передачи проекта

## 📌 Основная информация

- **Проект:** Minecraft Fabric мод "ShinobiCore" (тематика Naruto)
- **Версия Minecraft:** 1.20.1
- **Загрузчик:** Fabric Loader 0.16.9 + Fabric API 0.92.3
- **Java:** 21
- **Расположение:** E:\Games\mod
- **Пакет:** com.example.shinobicore

---

## 🏗️ Архитектура проекта

### Структура пакетов:

```
com.example.shinobicore/
├── ShinobiCore.java              ← Главный класс мода (серверная инициализация)
├── client/                        ← Клиентская часть
│   ├── ShinobiCoreClient.java    ← Клиентский entrypoint
│   ├── KeyBindings.java          ← Все клавиши мода
│   ├── ClientInputHandler.java   ← Обработка нажатий клавиш
│   ├── ClientNinjaState.java     ← Клиентское состояние игрока
│   ├── ChakraHudRenderer.java    ← HUD (полоски чакры, усталости)
│   ├── ChakraPhysicsClient.java  ← Физика хождения по воде
│   ├── ProgressionScreen.java    ← Меню прокачки (K)
│   ├── combat/                   ← Боевая система
│   │   ├── TaijutsuClientHandler.java   ← Комбо-удары руками
│   │   ├── TaijutsuKickHandler.java     ← Удар ногой (V)
│   │   ├── TaijutsuAnimations.java      ← Анимации ударов
│   │   └── TaijutsuParticleEffects.java ← Частицы при ударах
│   └── parkour/                  ← Паркур-система
│       ├── ParkourManager.java          ← Менеджер паркур-действий
│       ├── actions/                     ← Каждое действие паркура
│       │   ├── ParkourAction.java       ← Интерфейс
│       │   ├── ParkourContext.java      ← Контекст (кулдауны)
│       │   ├── DodgeAction.java         ← Додж (Z/C)
│       │   ├── SlideAction.java         ← Подкат
│       │   ├── WallRunAction.java       ← Бег по стене
│       │   ├── EdgeGrabAction.java      ← Захват края
│       │   ├── RollAction.java          ← Кувырок
│       │   ├── CrawlAction.java         ← Ползание
│       │   └── ChargedJumpAction.java   ← Заряженный прыжок
│       └── util/                        ← Утилиты
│           ├── PoseHelper.java          ← Позы игрока
│           └── ParkourSounds.java       ← Звуки
├── combat/                        ← Серверная боевая логика
│   ├── TaijutsuStyle.java        ← Стили боя (Standard, Strong Fist)
│   ├── TaijutsuCombo.java        ← Параметры комбо
│   ├── TaijutsuFormulas.java     ← Формулы урона
│   └── MeleeHitDetection.java    ← Конус-детекция урона
├── config/                        ← Конфигурация
│   └── ModConfig.java            ← Настройки мода
├── data/                          ← Данные
├── event/                         ← События
│   └── NinjaTickHandler.java     ← Серверный тик (регенерация, скорость)
├── jutsu/                         ← Техники
│   ├── JutsuCaster.java          ← Каст техник
│   └── ...                        ← Поведения техник
├── mixin/                         ← Mixin'ы
│   ├── PlayerAttackMixin.java    ← Перехват атаки (тай-дзюцу)
│   ├── PlayerRenderAnimationMixin.java ← Анимации модели
│   └── ...                        ← Другие миксины
├── network/                       ← Сеть
│   └── ModPackets.java           ← Все пакеты клиент↔сервер
├── pose/                          ← Позы
│   └── LowPoseTracker.java       ← Отслеживание низких поз
├── stat/                          ← Статистика
│   ├── NinjaPlayerData.java      ← Данные игрока (сервер)
│   ├── NinjaFormula.java         ← Формулы (урон, скорость, регенерация)
│   ├── StatType.java             ← Типы статов
│   └── ElementType.java          ← Типы стихий
└── command/                       ← Команды
    └── NinjaCommand.java         ← /ninja команда
```

---

## ⌨️ Раскладка клавиш (текущая)

| Клавиша | Действие | Статус |
|---------|----------|--------|
| **L** | Чакра-режим (вкл/выкл) | ✅ Работает |
| **M** | Медитация (зажать — регенерация чакры) | ✅ Работает |
| **R** | Каст техники (слот A) | ✅ Работает |
| **T** | Каст техники (слот B) | ✅ Работает |
| **G** | Переключение слота A | ✅ Работает |
| **H** | Переключение слота B | ✅ Работает |
| **V** | Удар ногой (тай-дзюцу) | ✅ Работает |
| **Z** | Додж влево (в чакра-режиме) | ✅ Работает |
| **C** | Додж вправо (в чакра-режиме) | ✅ Работает |
| **K** | Меню прокачки | ✅ Работает |
| **N** | Ползание | ✅ Работает |
| **Shift (3 сек)** | Альтернативная медитация | ⚠️ Удалена (была на M) |

---

## 🔑 Ключевые паттерны и подходы

### 1. Обработка клавиш
- `KeyBindings.java` — регистрация всех клавиш через `KeyBindingHelper.registerKeyBinding()`
- `ClientInputHandler.java` — обработка нажатий в `ClientTickEvents.END_CLIENT_TICK`
- **ВАЖНО:** `wasPressed()` можно вызывать ТОЛЬКО ОДИН РАЗ за тик для одной клавиши. Если нужно проверить клавишу в нескольких местах — используй `isPressed()` + отслеживание перехода.

### 2. Паркур-система
- `ParkourManager.java` — центральный менеджер, вызывает `canActivate()` → `activate()` → `tick()` → `deactivate()` для каждого действия
- Каждое действие реализует интерфейс `ParkourAction`
- Кулдауны через `ParkourContext`
- **ВАЖНО:** Для dodge используем `isPressed()` + `prevLeftDown/prevRightDown` (static) для определения НОВОГО нажатия. НЕ используем `wasPressed()` в dodge!

### 3. Боевая система (тай-дзюцу)
- `PlayerAttackMixin` — перехват ванильной атаки при пустой руке
- `TaijutsuClientHandler` — комбо-логика (4 удара: правая, левая, правая, левая)
- `TaijutsuKickHandler` — удар ногой (V), кулдаун 500ms
- `PlayerRenderAnimationMixin` — анимация модели через `BipedEntityModel.setAngles()`
- Урон считается на СЕРВЕРЕ через `MeleeHitDetection.findTargetsInCone()`

### 4. Сеть (клиент → сервер)
- Все пакеты в `ModPackets.java`
- Идентификаторы: `Identifier("shinobicore", "имя")`
- Каст техник: пакет `cast_slot` (writeInt(set) + writeInt(slot))
- Чакра-режим: пакет `chakra_mode` (writeBoolean)
- Медитация: пакет `meditate` (writeBoolean)
- Удар ногой: пакет `taijutsu_kick` (writeString(styleId))
- Комбо-удар: пакет `taijutsu_attack` (writeInt(step) + writeString(styleId))

### 5. Чакра-режим (L)
- Клиент: `ClientNinjaState.chakraMode` переключается
- Отправляется пакет `CHAKRA_MODE_ID` на сервер
- Сервер: `NinjaPlayerData.setChakraMode(enable)` + `sendBodySync()`
- В `NinjaTickHandler`: drain чакры, множитель скорости x2, спринт-бонус

### 6. Медитация (M)
- При нажатии M → пакет `MEDITATE_ID` (true)
- При отпускании M → пакет `MEDITATE_ID` (false)
- Сервер: `data.setMeditating(true/false)`
- В `NinjaTickHandler`: регенерация × `meditationRegenMultiplier()`
- Требования: на земле, не двигается, голод > 6

---

## 🐛 Известные проблемы и их решения

### Проблема: `wasPressed()` конфликт
**Симптом:** Клавиша работает только в одном месте, в другом — нет.
**Причина:** `wasPressed()` сбрасывает флаг после первого вызова.
**Решение:** Используй `isPressed()` + `prevDown` (static) для определения нового нажатия.

### Проблема: Mixin не находит метод
**Симптом:** `Critical injection failure: could not find any targets matching 'interact'`
**Причина:** Метод не существует в целевом классе для 1.20.1.
**Решение:** Проверяй маппинги Yarn для 1.20.1. Метод `interact` НЕ существует в `ClientPlayerEntity`. Используй `PlayerEntity.attack()` или обработчики Fabric API.

### Проблема: Кулдаун не работает
**Симптом:** Действие активируется много раз подряд.
**Причина:** `ctx.setCooldown()` в `ParkourContext` может не работать надёжно.
**Решение:** Используй `System.currentTimeMillis()` + static переменную для кулдауна.

### Проблема: Кодировка в PowerShell
**Симптом:** Кракозябры в логах (`╨╖╨░╨│╤А╤Г╨╢╨░╨╡╤В╤Б╤П`).
**Причина:** UTF-8 не выставлена в консоли.
**Решение:** `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8` или игнорировать.

---

## 📂 Ключевые файлы ресурсов

```
src/main/resources/
├── fabric.mod.json                    ← Метаданные мода
├── shinobicore.mixins.json            ← Конфигурация миксинов
├── assets/shinobicore/
│   ├── lang/en_us.json               ← Английские переводы
│   ├── lang/ru_ru.json               ← Русские переводы
│   └── data/jutsu/                   ← JSON-файлы техник
│       ├── fire_release_great_fireball.json
│       ├── water_release_water_bullet.json
│       ├── wind_release_gale_palm.json
│       ├── lightning_release_shock.json
│       └── earth_release_earth_wall.json
```

---

## 🔄 Команды сборки

```powershell
cd E:\Games\mod
.\gradlew.bat build          # Сборка
.\gradlew.bat runClient      # Запуск клиента (тестирование)
.\gradlew.bat clean build    # Чистая сборка
```

---

## 📝 Что было сделано в текущей сессии

### Волна 1: Базовый бой (тай-дзюцу)
- ✅ Комбо-удары руками (LMB, пустая рука)
- ✅ Конус-урон на сервере
- ✅ Стат TAIJUTSU добавлен
- ✅ Урон масштабируется от уровня

### Волна 2: Анимации + удар ногой
- ✅ Анимации ударов через `BipedEntityModel.setAngles()`
- ✅ Удар ногой (V) с кулдауном 500ms
- ✅ Частицы при ударах
- ✅ Лоу-кик анимация (наклон корпуса)

### Волна 3: Клавиши и системы
- ✅ Каст техник (R/T) через пакет `cast_slot`
- ✅ Переключение слотов (G/H)
- ✅ Чакра-режим (L) с пакетом на сервер
- ✅ Медитация (M) через пакет `meditate`
- ✅ Додж (Z/C) с i-frames
- ✅ Меню прокачки (K)
- ❌ Target Lock — убран (слишком много проблем)

---

## ⚠️ ВАЖНО для следующей нейросети

1. **Пользователь работает на Windows**, PowerShell, путь `E:\Games\mod`
2. **НЕ используй `wasPressed()`** в нескольких местах для одной клавиши — используй `isPressed()` + `prevDown`
3. **Проверяй маппинги Yarn** перед созданием миксинов — не все методы существуют в 1.20.1
4. **Кулдауны** лучше делать через `System.currentTimeMillis()` + static, а не через `ParkourContext`
5. **Пользователь предпочитает** полные файлы целиком, а не фрагменты для вставки
6. **Логи** — используй `ShinobiCore.LOGGER.info()` для отладки
7. **Сборка:** `.\gradlew.bat build` → `.\gradlew.bat runClient`
8. **Язык общения:** русский
9. **Пользователь часто** просит команды для терминала чтобы не ошибиться в путях
10. **При ошибках компиляции** пользователь присылает полный лог — анализируй его целиком

---

## 🎯 Следующие шаги (не сделаны)

1. **Блокирование/парирование** в тай-дзюцу (отложено)
2. **Strong Fist стиль** — переключатель стилей (Standard ↔ Strong Fist)
3. **8 Врат** — интеграция с Strong Fist
4. **Gentle Fist (Хьюга)** — когда добавим клан Хьюга
5. **Звуки** для ударов тай-дзюцу (сейчас используются ванильные)
6. **Улучшение анимаций** — более плавные переходы
7. **Баланс** — настройка урона, кулдаунов, стоимости чакры

---

## 📊 Текущий статус систем

| Система | Статус | Примечание |
|---------|--------|------------|
| Тай-дзюцу комбо | ✅ | 4 удара, урон по конусу |
| Удар ногой | ✅ | V, кулдаун 500ms |
| Анимации ударов | ✅ | Через BipedEntityModel |
| Каст техник | ✅ | R/T, 5 техник |
| Чакра-режим | ✅ | L, drain + скорость x2 |
| Медитация | ✅ | M, регенерация чакры |
| Додж | ✅ | Z/C, i-frames, кулдаун 1s |
| Паркур | ✅ | Подкат, бег по стене, кувырок и т.д. |
| Прокачка | ✅ | K, меню со статами |
| Хождение по воде | ✅ | В чакра-режиме |
| Target Lock | ❌ | Убран, можно добавить сторонний мод |
```

---

## Шаг 3: Отправь другой нейросети

1. **Файл `FULL_CODE_DUMP.txt`** — весь код мода
2. **Файл `PROJECT_HANDOFF.md`** — документ выше
3. **Первое сообщение:**

```
Я продолжаю работу над Minecraft Fabric модом "ShinobiCore" (Naruto тематика, 
MC 1.20.1, Fabric API). Прикрепляю документ с описанием проекта и полный код.

Прочитай PROJECT_HANDOFF.md и FULL_CODE_DUMP.txt, пойми архитектуру.

Моя текущая задача: [опиши что нужно сделать]

Работаю на Windows, путь E:\Games\mod, PowerShell. 
Предпочитаю полные файлы целиком, а не фрагменты.
```

Удачи с проектом! 🍥