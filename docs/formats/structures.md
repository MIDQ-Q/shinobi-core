# Формат: структуры (Structure Pack v1/v2, Спринты 19 и 21)

Статус: СОГЛАСОВАН, реализация в Спринте 19. Шаблон:
`data/shinobicore/_templates/structure_template.json`.

## Слои
1. **placement** — ванильный `worldgen/structure_set` (random_spread: spacing,
   separation, salt, biomes-тег). Генерируется без изменений.
2. **pieces** — ссылки на NBT/джейго-кусочки (`template`), rotation, position,
   processors (выветривание, замена блоков под биом).
3. **markers** — интерактивные точки (Спринт 21). Маркер = блок-метка
   `shinobicore:marker_*` в структуре; при загрузке чанка сканер читает
   block entity и регистрирует сущность/логику. Так интерактивность не
   зашивается в NBT, а описывается данными.

## Виды маркеров (kind)
| kind | data | Что делает |
|---|---|---|
| altar | blessing, amount, radius, duration | алтарь: бафф игроку в радиусе |
| trap | trap (spike/arrow/flame_jet/pit), damage, resetTicks | ловушка (Спринт 21) |
| puzzle_seal | sealSequence[], reward | загадка печатей: повторить последовательность |
| loot | table, tier | сундук с лут-таблицей |
| training_dummy | tier, hp | манекен (туториал, Спринт 16; тренировка, Спринт 19) |
| boss_arena | bossId, fogGate | арена босса (Спринт 24): туманные врата, музыка |
| bonfire | — | костёр Dark Souls: точка отдыха/телепорта (Спринт 21) |
| shortcut | targetPiece, oneWay | короткий путь (открывается с одной стороны) |
| npc_spawn | npcId, count | спавн NPC (Спринт 20) |
| jutsu_shrine | jutsuId | святилище: разблокировка техники |

## darkSouls-блок
shortcutDoors/bonfire/fogGates — флаг-переключатели стиля структуры
(арены боссов и петли коротких путей — по решению дорожной карты).

## Правила валидации
- placement.salt уникален на структуру;
- separation < spacing;
- markers[].kind — только из таблицы выше;
- boss_arena.bossId ссылается на описанного босса (Спринт 24);
- loot.table — существующая лут-таблица.

## Генерация
Studio (раздел «Форматы») правит шаблон; при реализации Спринта 19 скрипт
раскладывает шаблон в: worldgen/structure/*.json, worldgen/structure_set/*.json,
реестр маркеров и список NBT-кусочков, которые нужно построить вручную.