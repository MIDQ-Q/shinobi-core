# Формат: NPC (NPC Pack, Спринт 20)

Статус: СОГЛАСОВАН, реализация в Спринте 20. Шаблон:
`data/shinobicore/_templates/npc_template.json`.

## Поля
| Поле | Тип | Описание |
|---|---|---|
| id | string | shinobicore:<имя> |
| kind | enum | merchant / teacher / questgiver / villager / bandit / nukenin / guard |
| displayName | {en_us,ru_ru} | имя в диалоге и над головой |
| faction | string | id из FactionRegistry (leaf, bandits, ...) — влияет на репутацию (Спринт 23) |
| model / textures | string / string[] | модель игрокоподобная (ShinobiPlayerModel), скины на выбор при спавне |
| ai.tier | string | ссылка на data/shinobicore/ai_tiers/*.json (genin/chunin/jonin/anbu) |
| ai.behavior | enum | passive / enemy / fight_for_caster / patrol / flee — уже поддерживается AiBrain |
| schedule | object[] | расписание: from/to (тики дня), action (at_structure/patrol/idle_home/sleep), poi |
| dialog | string | id диалога (формат dialogs.md) |
| trades | object[] | buy/sell/reputationDiscount/maxUses — торговля (Спринт 20) |
| teaches | string[] | jutsuId, которым учит teacher (цена SP/деньги) |
| reputationGates | object | minReputation — не подпустит/не заговорит при низкой репутации |
| spawn | object | structures[] / biomes[] / weight — где спавнится (структуры Спринта 19) |

## Расписания
Днём — at_structure (рынок, храм), ночью — idle_home или patrol (для guard).
Реализация: SimpleAi-цели по времени суток; точка poi берётся из маркеров
структуры (npc_spawn marker).

## Враждебные NPC
bandit/nukenin используют ai.tier + behavior=enemy; лут — из loot-таблиц;
убийство меняет репутацию фракции (FactionManager, Спринт 23).

## Правила валидации
- faction — существующий id в data/shinobicore/factions/;
- ai.tier — существующий файл ai_tiers;
- teaches[] — только зарегистрированные jutsuId;
- dialog — существующий id в каталоге диалогов.