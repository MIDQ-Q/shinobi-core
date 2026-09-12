# Формат: квесты (Quest Pack, Спринт 25)

Статус: СОГЛАСОВАН, реализация в Спринте 25. Шаблон:
`data/shinobicore/_templates/quest_template.json`.

## Поля
| Поле | Тип | Описание |
|---|---|---|
| id | string | shinobicore:q_<имя> |
| type | enum | linear (цепочка сюжета) / random (повторяемое) / reputation (по репутации) |
| displayName | {en_us,ru_ru} | название в трекере |
| giver | object | kind: npc / faction_board / structure_marker / auto; ссылка на id |
| reputationRequired | object | {faction, min} — порог репутации (Спринт 23) |
| rankHint | D..S | сложность (влияет на награды и уровень врагов) |
| objectives | object[] | см. ниже; выполняются в любом порядке, если не указано order |
| rewards | object | xp, sp, items[], reputation{faction:amount}, unlockJutsu |
| next | string\|null | следующий квест цепочки |
| timeLimitTicks | int\|null | лимит времени |
| order | "any"\|"sequential" | порядок целей (по умолчанию any) |

## Типы целей (objectives[].type)
| type | параметры | Детектор |
|---|---|---|
| kill | target(entity id), count, radius | ServerLivingEntityEvents.AFTER_DEATH |
| collect | item, count, deliver | инвентарь / сдача у giver |
| reach | structure или pos, radius | позиция игрока (трекер структур) |
| talk | npc | диалоговая система |
| craft | recipe id, count | крафт-событие |
| cast | jutsuId, count | JutsuCaster.cast (уже логируется VerificationLogger) |
| escort | npc, destination | NPC жив + достиг точки |
| survive | ticks | таймер |

## Награды
- reputation — единственный «ранг» прогрессии (по решению: рангов ниндзя нет);
- unlockJutsu — добавляет jutsuId в learned напрямую (в обход дерева);
- sp — очки навыков дерева.

## Правила валидации
- objectives непустой; kill.target — существующий EntityType;
- collect.item — существующий item id;
- next — существующий quest id (без циклов!);
- reputationRequired.faction — существующая фракция.

## Связь с системами
Трекер квестов в HUD (Спринт 33) читает активные квесты из QuestComponent
(CCA, по образцу StealthComponent). Диалоги giver'а — формат dialogs.md.