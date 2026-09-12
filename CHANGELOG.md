# Changelog

Все значимые изменения проекта. Формат основан на
[Keep a Changelog](https://keepachangelog.com/ru/1.1.0/),
версионирование — [SemVer](https://semver.org/lang/ru/).

---

## [1.1.5] - 2026-09-11

Внутренняя версия: hotfix CCA + статический аудит.
Применено скриптом `ShinobiCore_Hotfix_CCA_Master.ps1`.

### Fixed

- **Критический крах мира («Invalid player data»)**: в fabric.mod.json добавлен
  блок `"custom": { "cardinal-components": [ "shinobicore:stealth",
  "shinobicore:reputation" ] }`. Без него Cardinal Components API 5.2.2 не
  создаёт классы компонентных ключей и падает на первом же создании сущности
  (`shinobicore:stealth was not registered through mod metadata or plugin`),
  из-за чего не загружались чанки и игрок не размещался в мире.
  Сохранения миров не повреждены.
- Статический аудит: проверка entrypoints/custom-компонентов, наличия всех
  миксинов, парсинга jutsu/lang, отсутствия вернувшихся мин прошлых итераций.

---
## [1.1.4] - 2026-09-11

Внутренняя версия: Movement & Combat Feel Pack.
Применено скриптом `ShinobiCore_MovementCombat_Master.ps1`.

### Added

- **MovementFeel** (клиент) — единый движок «ощущения движения»:
  бег по воде с кривой разгона (ease-out), покачиванием камеры, шагами
  (брызги + звук каждые ~1.1 блока) и всплеском при касании; подъём по стене:
  W — быстрый забег как в аниме (0.16 бл/тик, в 3 раза быстрее прежнего),
  Shift+W — тихий подъём для стелса, Shift — спуск; шаги с пылью и звуком;
  grace-тики на воде после потери чакры (плавное погружение вместо мгновенного).
- Обратная связь: кольцо чакры при двойном прыжке, шлейф рывка, пыль подката,
  кольцо при выпуске заряженного прыжка, пыль у кромки при подъёме,
  просадка камеры и пылевое кольцо при приземлении (+ глухой звук).
- **CameraFxMixin** — камера наконец живая: тряска от ударов (CinematicCamera
  больше не «мёртвый код»), наклон к стене при wall-run, покачивание на воде,
  просадка при приземлении, камера «за правым плечом» в третьем лице.
  Всё отключается в конфиге (секция cameraFx).
- **Анимации**: бег по воде — короткий частый шаг, низкий наклон, руки назад;
  бег по стене — цикл от ПРОЙДЕННОГО ПУТИ (ноги больше не застывают в воздухе),
  наклон корпуса к стене с правильной стороны; новый цикл карабканья по стене.
- **Combat Pack v1**:
  - ДВЕ стойки катаны: aggressive и defensive (seigan переименован, iai убран;
    старые сохранения мигрируются автоматически: seigan -> defensive, iai -> aggressive);
  - БЛОК: удержание отражения в защитной стойке режет ближний урон на 60%
    (combat.blockReduction) и добавляет усталость за удар;
  - ПАРИРОВАНИЕ: удар в первые 400 мс нажатия отражения — урон отменён,
    атакующий отброшен и замедлен, стоп-кадр, искры, «звон»;
  - СОК ПОПАДАНИЙ: приёмник HIT_STOP теперь добавляет тряску камеры
    (пропорционально силе стоп-кадра) и искры/капли в точке контакта;
  - БОЕВОЙ РАЖ: серия убийств (1/2/3/5 за 3 с) даёт уровни 1-4 —
    серверный бонус урона +10/20/35/50% и клиентское визуальное замедление
    0.85/0.7/0.55/0.4x, красный оверлей с виньеткой, сердцебиение,
    полоса таймера. Тикрейт сервера не меняется — мультиплеер не страдает.
    Пакет FRENZY_SYNC, античит (лимит частоты убийств, сброс при смерти);
  - МЯГКОЕ НАВЕДЕНИЕ (soft lock-on): цель в конусе 60°/8 блоков с рейкастом
    видимости, «магнит» камеры (не жёсткая привязка, ≤2°/тик), индикатор-кольцо
    над целью (белеет -> оранжевеет при атаке -> краснеет в раже), приоритет
    у атакующих и недавно битых, отключение в паркуре. Клавиша J (lock_on),
    параметры в конфиге (combat.lockOn*).
- Конфиг: секции movement, cameraFx + 18 полей combat.
- Ключи локализации lock_on (en/ru).

### Changed

- WallRunAction: потолок скорости (movement.wallRunMaxSpeed, раньше разгон был
  бесконечным), удержание прыжка поднимает вдоль стены, затухание в последние
  25% дистанции, пыль и звуки шагов от MovementFeel.
- PlayerJsonAnimState переведён на AnimClock — анимации замедляются в раже.
- KatanaDeflectMixin: INFO-логи заменены на DEBUG (спам в логах при каждом
  попадании снаряда), удалена могибака в комментариях.

### Fixed

- Поза wall-run больше не зависит от limbAngle (в воздухе он обнуляется —
  ноги застывали, бег выглядел как ползание).
- Наклон корпуса при wall-run теперь в сторону стены, а не константой.
- Мгновенный setSprinting на воде дополнен кривой разгона — эффект «коньков»
  устранён покачиванием, шагами и брызгами.

---
## [1.1.3] - 2026-09-11

Внутренняя версия: ToolsPack 2 — стили визуала, примитивы Fx v3, Studio v3.
Применено скриптом `ShinobiCore_ToolsPack2_Master.ps1`.

### Added

- **Fx v3 — 25 стилей визуала** через visual-блок JSON (без правки кода):
  trailStyle (ribbon/helix/smoke/sparks/lightning), impactStyle
  (nova/shockwave/implosion), castStyle (runes/pillars/spiral),
  zoneStyle (dome/rune_circle/vortex/wall), beamStyle (lightning/spiral/pulse).
  Неизвестный или пустой стиль = default (поведение 1.1.2 без изменений).
- **7 новых эмиттеров-примитивов** Fx.java: lightPillar, vortex, helixColumn,
  shockwaveRing, chainArc, groundRunes, domeShell — строительные блоки для
  боссов, алтарей, святилищ и данжей (Спринты 21, 24).
- **/shinobicore fx v2**: новые примитивы (helix/vortex/shockwave/runes/pillar/
  dome/chain), параметр стиля (`fx fire beam spiral`), наборы `all`/`all2`.
- **Studio v3** (tools/studio/ext.js):
  - ручной пейнт воксельных моделей: сетка 32³ (кисть/ластик/пипетка, слой Y,
    симметрия X/Z, undo/redo Ctrl+Z/Y, вокселизация примитивов);
  - 12 генераторов примитивов (сфера, звезда, диск, клинок, кольцо, конус,
    цилиндр, спираль, пирамида, ромб, крестовина, коробка) + композиция
    (заменить/добавить со сдвигом и поворотом/круговой массив ×N);
  - импорт Blockbench .bbmodel (кубики, 1/16 -> блоки);
  - FX Lab: дропдауны всех стилей с симуляцией каждой хореографии,
    «📋 команда каста», «🎲 случайный визуал»;
  - мастер «🧙 техника за 30 секунд»: 16 архетипов (взрывной снаряд, залп,
    пронзающее копьё, луч, цепная молния, зона DoT, тюрьма, аура, рывок,
    мина, орбитальный щит, лечащая ладонь, удар, призыв, стена, ручная сфера),
    живое превью, баланс-подсказки по рангу, создание узла дерева в один клик.
- `docs/formats/fx_styles.md` — каталог стилей и примитивов.

### Changed

- `VisualDefinition` + `JutsuParser`: 5 новых опциональных ключей visual;
  прежний 6-аргументный конструктор сохранён (совместимость со всеми вызовами).
- `ProjectileSystem` передаёт скорость полёта в трейл (нужно для ribbon/helix).

---
## [1.1.2] - 2026-09-10

Внутренняя версия: инструментарий и визуал (ToolsPack).
Применено скриптом `ShinobiCore_ToolsPack_Master.ps1`.

### Added

- **Fx v2** — движок визуала техник: `FxPalette.java` (палитры стихий + разбор
  visual-блока JSON: color/particle/trail/scale/glow), переработанный `Fx.java`
  (круг каста, сбор чакры, слоистое ядро луча, границы зон, трейлы с ядром и
  ореолом, вспышки попаданий, призраки рывка, искры фитиля). Старые подписи
  сохранены — все существующие вызовы работают и стали ярче.
- **/shinobicore fx** — предпросмотр всех эффектов в игре без каста
  (`FxPreviewCommand.java`, 20-секундные серверные задачи).
- **Воксельные модели** (12 шт.) в `assets/shinobicore/voxels/` — включая
  `rasengan_blue` и `rasenshuriken`, на которые техники ссылались, но файлов
  не было (handheld-визуал не рисовался). Плюс `shuriken_voxel`/`kunai_voxel`
  — задел под Shuriken Pack.
- **visual-блок во всех 79 техниках**: частицы, яркий цвет стихии, glow,
  воксельная модель для projectile/handheld.
- **Studio v2** (`tools/studio/ext.js`): FX Lab (живая симуляция визуала),
  Воксели (3D-превью + генераторы моделей), Генераторы (пакетная генерация
  техник, кривые прокачки, достройка дерева, массовый визуал),
  Форматы (документы и шаблоны будущих паков).
- **Форматы будущих паков**: `docs/formats/{items,biomes,structures,npcs,quests,dialogs}.md`
  и шаблоны `data/shinobicore/_templates/*.json` — соглашение до реализации
  спринтов 2, 18–21, 25.
- `docs/TOOLS.md` — инструкция по инструментарию.

### Fixed

- `serve.ps1`/установщик Studio: белый список записи расширен
  (voxels, weapon_visuals, _templates), `/api/state` отдаёт списки моделей,
  шаблонов и документов.

### Changed

- BeamSystem, ZoneSystem, ProjectileSystem, DashSystem, FormExecutor,
  ActivationSystem, HandheldSystem, HitProperties, DelayedExplosionSystem,
  OrbitingSystem — переведены на эффекты Fx v2 с учётом visual-блока техники.

---
## [1.1.1] - 2026-09-10

Внутренняя версия: ремонт фундамента перед контентными паками.
Применено скриптом `ShinobiCore_Sprint1_MasterFix.ps1`.

### Fixed

- **P0-1** `shinobicore.mixins.json`: `compatibilityLevel` JAVA_21 -> JAVA_17.
  Мод падал у любого игрока на Java 17 (`fabric.mod.json` объявляет `java: >=17`).
- **P0-2** `fabric.mod.json`: добавлен entrypoint `cardinal-components-entity`
  -> `ShinobiCCA`. Компоненты `StealthComponent` и `ReputationComponent`
  никогда не прикреплялись к игроку; любой вызов `StealthComponent.KEY.get()`
  бросал исключение. Разблокированы Спринты 15 (стелс) и 23 (фракции).
- **P0-4** `player-animator` перенесён из `depends` в `suggests`:
  зависимость не подключена в `build.gradle` и не используется в коде.
- **P1-2** 22 строки с битым цветовым кодом (§ -> §) в 6 файлах:
  `JutsuCaster`, `ShinobiCore`, `ClientInputHandler`, `KatanaDeflectMixin`,
  `KenjutsuClientHandler`, `PlayerParryMixin`. Игрок видел в чате буквально
  "§cNot enough chakra!".
- **P1-4** Стоимость заряженного прыжка снова считает сервер.
  Клиент присылал готовое значение усталости и мог прислать <= 0,
  получая бесконечные заряженные прыжки. Теперь клиент шлёт долю заряда (0..1),
  сервер клампит её и умножает на `parkour.chargedJumpFatiguePerCharge`.
- **P1-6** В lang-файлы добавлены 14 ключей клавиш + 2 категории + 2 предмета;
  в меню управления больше не отображаются сырые идентификаторы.
- **H1** `HitStopManager`: TTL кэша 500 мс молча обрезал любую заморозку
  длиннее 500 мс. Поднят до `MAX_FREEZE_MS + 250` (2250 мс).
- **H2** `VisionCone.canSee`: `Math.acos` без клампа давал NaN на пограничных
  углах, из-за чего метод молча возвращал false. Добавлены кламп и проверка
  нулевых векторов.
- **H3** `ActivationSystem.ACTIVE`: записи PASSIVE / ON_DEATH
  (`duration = Integer.MAX_VALUE`) никогда не удалялись при выходе игрока.
  Добавлен `removePlayer(UUID)` и вызов на `DISCONNECT`.
- **H4** `PacketValidator.validJutsuId` возвращал `true` для null/пустой строки.
- **1.13a** Каст незарегистрированной техники был молчаливым. Теперь —
  сообщение в actionbar и WARN в лог.
- **1.13c** Покупка узла древа, техника которого не реализована, больше
  не списывает SP (79 из 82 техник в `tree.json` отсутствовали в реестре).

### Changed

- **ADR-002** Создан `combat/ComboMachine` — единый источник таблиц комбо.
  `TaijutsuCombo` и `KenjutsuFormulas` стали делегатами; дубликаты таблиц
  `STEP_DAMAGE`/`STEP_KNOCKBACK`/`STEP_MULT`/`STEP_KB` удалены.
- **D4** Создан `combat/KenjutsuBalance` — общие кулдауны катаны для клиента
  и сервера. Устранено расхождение 350 мс (клиент) против порога 341 мс (сервер).
- **CFG** `MeleeHitDetection.RANGE` / `CONE_ANGLE_DEG` из `static final`
  стали методами, читающими `ModConfig.taijutsu.range` / `.coneAngle`
  (поля были объявлены, но не читались — «фантомный конфиг»).
- **E2** Добавлен `PacketRateLimiter` на `PARKOUR_ACTION` (100 мс),
  `DODGE` (400 мс), `POSE_SYNC` (100 мс). В switch действия паркура
  добавлен `default` с логом отказа вместо молчаливого нуля.
- **A3** `build.gradle`: `options.encoding = 'UTF-8'` и
  `processResources.filteringCharset = 'UTF-8'`. Без этого javac на русской
  Windows читал исходники в windows-1251 — корневая причина P1-2.
- `fabric.mod.json`: добавлены ключи `stance.shinobicore.*` и
  `jutsu.shinobicore.missing` в локализацию.

### Removed

- **D-3 / ADR-012** Авто-парирование удалено полностью: `PlayerParryMixin`,
  поле `TreePassives.autoParryChance`, `case "tai_counter"`, узел `tai_counter`
  из `tree.json`. Узел был листовым (от него никто не зависел).
  Игрокам, уже купившим узел, возвращаются 6 SP при загрузке мира.
  Причина: пассивная случайная отмена урона обесценивала активное парирование.
- **C4** `config/ShinobiCoreConfig` — 0 ссылок, писал в тот же файл,
  что `ConfigManager`, с другой схемой.
- **C1** `client/physics/{PhysicsState,WaterWalkHandler,WallStickHandler}` —
  мёртвые копии `ChakraPhysicsClient` (второй источник правды для
  `standingOnWater` / `stickingToWall`).
- **F3** `assets/.../animations/shinobi_player_pack_anim_ver3.json` —
  байт-в-байт копия `shinobi_player_animations.json` (4 469 строк),
  не загружалась `JsonAnimLibrary`.
- **F4** Орфаны удалённой интеграции с Trinkets/Artifacts:
  `data/shinobicore/trinkets/**`, `models/item/shinobi_charm.json`,
  9 ключей локализации.
- **F1** Дубли: второй вызов `KatanaFsmTracker.register()`,
  второй вызов `ShinobiEventBus.setEnabled(true)`.
- **F2** Пустые обработчики: `PHASE5_CAST_TICK` (цикл по всем игрокам каждый тик
  с пустым телом) и пустой `for (world : server.getWorlds())`.
- **F5** `fix.ps1` — скрипт, вычищавший дубликаты объявлений регулярными
  выражениями; 7 строк-заглушек `[CLEANUP]` из `build.gradle` и
  `gradle.properties`.

### Added

- `CHANGELOG.md` (этот файл), `docs/DECISIONS.md` (ADR-001..ADR-013).
- `tools/scan_encoding.ps1` — поиск битой кодировки (запуск в CI обязателен).
- `tools/check_tree.ps1` — верификатор древа навыков и реестра дзюцу.
- `build.ps1` — локальная сборка с проверками.
- `combat/ComboMachine.java`, `combat/KenjutsuBalance.java`.

### Known issues (перенесено в следующие спринты)

- **P0-3** Сервер не отправляет `COMBO_SYNC` -> бой голыми руками ломается
  после первого удара. Скелет `ComboMachine` готов; правки в
  `CombatPacketHandlers` требуются вручную (структурная перестановка проверок).
- **P1-1** Ветка «не истощён» в `NinjaTickHandler` снимает ВСЕ эффекты
  SLOWNESS/WEAKNESS, убивая замедление от медитации и защитной стойки.
  Требуется `CombatStatusService` с управлением по фронту.
- **P1-3** `ChakraPhysicsClient.stickingToWall` не сбрасывается в двух ветках.
- **P1-5** Катана инкрементирует шаг комбо на клиенте -> рассинхрон при отказе.
- **P1-7** Модификатор скорости спринта пересоздаётся каждый тик.

---

[1.1.1]: https://example.invalid/shinobicore/releases/tag/v1.1.1