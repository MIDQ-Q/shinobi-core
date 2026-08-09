# SHINOBI CORE — контекст проекта

## Паспорт
- Naruto-мод для Minecraft 1.20.1, Fabric, одиночка + сервер.
- Стек: Fabric Loader 0.16.9, Fabric API 0.92.3+1.20.1, Loom 1.9.2, Yarn mappings, Java 21.
- Пакет: com.example.shinobicore. Точка входа: ShinobiCore (сервер/общая), ShinobiCoreClient (клиент).
- Запуск: `.\gradlew.bat runClient`. Конфиг: `run/config/shinobicore/main.json` (в проде `.minecraft/config/...`).
- Контент через JSON: `src/main/resources/data/shinobicore/jutsu/*.json` и `.../clans/*.json`.

## Управление
- M (удерж.) — медитация; R — каст активного слота; G — цикл слотов; 1-5 — слоты (не назначены);
- K — меню прокачки; L — toggle чакра-режима; V — колесо дзюцу (задел, не используется).

## Команды (/ninja ...)
info; set chakra|fatigue|stat|nature|clan|affinity; give xp stat|nature|reserve; give sp;
jutsu list|info; learn <id>; cast <id>; slot <1-5> <id>; clan choose|list; reloadconfig.

## Сеть (пакеты)
server→client: chakra_sync, loadout_sync, stats_sync, body_sync.
client→server: meditate, select_slot, cast_slot, spend_sp, chakra_mode.

## Mixins (зарегистрированы в shinobicore.mixins.json)
- ServerPlayerEntityMixin — хранение NinjaPlayerData в NBT игрока.
- FallDamageMixin — в чакра-режиме: ≤40 блоков без урона, далее +1 HP за каждые 5 блоков.
- ChakraWaterTouchMixin — isTouchingWater()=false в чакра-режиме (наземная физика на воде).
- Мёртвые файлы (НЕ в json, можно удалить): ChakraWaterWalkMixin.java, ExampleMixin.java.

## Архитектура (ключевые классы)
- stat/: NinjaPlayerData (все поля игрока + NBT + анти-абуз бюджет), NinjaFormula (ВСЕ формулы, читает ModConfig), StatType (7 статов), ElementType (5 стихий), ClanType.
- config/ModConfig — свой JSON-конфиг (Gson, авто-допись новых полей при load+save). ВЕСЬ баланс в конфиге.
- jutsu/: JutsuDefinition (record), JutsuRegistry (JSON), BehaviorRegistry (type→JutsuBehavior), JutsuCaster, behaviors: projectile/aoe/dash/melee/wall(заглушка)/utility(заглушка).
- entity/: NinjaProjectileEntity + ModEntities + NinjaProjectileRenderer (рендерер обязателен, иначе NPE-краш!).
- clan/: ClanDefinition, ClanRegistry (JSON).
- event/NinjaTickHandler — сервер: реген/усталость/медитация/трата чакры/HP/атрибуты скорости/прыжок-буст/синхронизация (раз в сек).
- client/ChakraPhysicsClient — КЛИЕНТСКАЯ физика чакра-режима (каждый тик): вода (snap к поверхности, onGround=true, принудительные jump()/setSprinting()), стены (horizontalCollision → vy +0.15/0/-0.15: W/Space вверх, Shift вниз, ничего — висит).
- client/: ProgressionScreen (меню K, вкладки Stats/Natures/Body), ChakraHudRenderer (HUD), ClientNinjaState (клиент-копия данных), KeyBindings, ClientInputHandler, ShinobiCoreClient.
- enchantment/ — файлы зачарования воды (НЕ используются, можно удалить).

## ГЛАВНЫЕ ТЕХ-РЕШЕНИЯ (не наступать на грабли!)
1. Движение игрока в одиночке считается НА КЛИЕНТЕ. Любую физику движения делать в ClientTickEvents (client), на сервере только баланс/урон/синхронизация. Серверные setVelocity для локального игрока перезатираются клиентом.
2. Имена методов для Mixin брать из Yarn 1.20.1; при сомнениях указывать явный дескриптор, например `canWalkOnFluid(Lnet/minecraft/fluid/FluidState;)Z`. canWalkOnFluid поднимает игрока на ПОЛНУЮ высоту блока («полёт +1») — не использовать для воды.
3. Не вызывать внутри @Inject метода тот же метод (рекурсия).
4. Кастомным сущностям обязательно регистрировать EntityRendererRegistry на клиенте.
5. JSON-файлы создавать в UTF-8 без BOM; проверять `dir` после создания.
6. Gson-конфиг: load() затем save() — новые поля сами появляются в файле.

## ЧТО ГОТОВО (шаги 1–6)
1. Конфиг main.json (все числа баланса), релоад командой.
2. Формулы v2: mastery = 25% usage + 75% characterScore (веса категорий в конфиге); урон = base*(0.6+0.8*mastery); XP за каст (стихия+ниндзюцу) с анти-абузом (maxXpPerMinute=500, maxUsagePerMinute=10); SP +1 за level-up.
3. Кланы: 6 JSON, авто-выдача при первом входе (флаг clanChosen, хранится в NBT), /ninja clan choose/list, бонусы через ClanRegistry (reserveBonus, costMultiplier и т.д. — часть ещё не подключена к формулам!).
4. Меню K: вкладки Stats/Natures(замки для неоткрытых)/Body; Body = HP(20→160), Speed, Jump (по 7 уровней, только за SP, цена 2).
5. Типы техник + свой снаряд (частицы, AOE, урон от mastery); 5 тестовых дзюцу. wall/utility — заглушки.
6. Чакра-режим (L): трата 2/с → 0.2/с при control 100; реген x0.2 в режиме (в медитации — обычный); ходьба по воде (бег+прыжки работают); стены v1 (паук); спринт +50% и спринт-прыжок; прыжок в режиме: длина x3→x10, высота x1.5→x3; снижение урона от падения.

## НЕ ДОДЕЛАНО / ОТЛОЖЕНО (см. ROADMAP)
- wall/utility behaviors полноценные; dash без урона.
- Кла́новые costMultiplier/fatigueMultiplier ещё не в формулах.
- Гендзюцу, эффекты, клоны, аттюнмент-миниигра, додзюцу, стены v2.

## Как добавить технику (архитектура для будущих шагов)

### 90% техник = только JSON (без кода)
Создать `src/main/resources/data/shinobicore/jutsu/my_jutsu.json`:
```json
{
  "id": "shinobicore:my_jutsu",
  "name": "My Jutsu",
  "category": "elemental_ninjutsu",
  "nature": "fire",
  "type": "projectile",
  "params": { "speed": 1.5, "radius": 2.0, "particle": "flame" },
  "baseCost": 25,
  "baseDamage": 7,
  "strain": 5,
  "requiredUsesForFullProficiency": 40,
  "requirements": { "control": 10, "nature_fire": 15, "ninjutsu": 8 }
}


## CHANGELOG
- 2026-08-07: шаги 1–6 завершены, чакра-режим работает (вода/стены/бег/прыжки).
- 2026-08-08: Шаг 7 (фундамент) завершён: два лоаута (A: R/G, B: T/H), назначение слотов из меню K (вкладка Jutsu), паркур (double jump/wall jump/vault, без траты чакры, малая усталость), сервер без физики движения, event-синхронизация статов, reflection-behaviors (behaviorClass в JSON), каталог техник на клиенте.
