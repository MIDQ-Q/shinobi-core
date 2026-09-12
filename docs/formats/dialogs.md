# Формат: диалоги (NPC Pack / Quest Pack, Спринты 20 и 25)

Статус: СОГЛАСОВАН, реализация в Спринте 20. Шаблон:
`data/shinobicore/_templates/dialog_template.json`.

## Структура
Диалог — граф узлов. `start` — id первого узла. Узел:
| Поле | Тип | Описание |
|---|---|---|
| speaker | "npc"\|"player"\|"narrator" | кто говорит |
| text | {en_us,ru_ru} | текст (локализация обязательна) |
| choices | object[] | варианты ответа игрока |
| onEnter | object\|null | действие при открытии узла (см. эффекты) |

Вариант ответа (choice):
| Поле | Тип | Описание |
|---|---|---|
| text | {en_us,ru_ru} | текст варианта |
| goto | string\|null | следующий узел |
| condition | object\|null | условие видимости/доступности |
| action | object\|null | эффект при выборе |

## Условия (condition.type)
reputation_min {faction,value} / reputation_max / quest_active {quest} /
quest_done {quest} / flag {name,value} / has_item {item,count} / clan {clanId}

## Эффекты (action.type)
open_trades / start_quest {quest} / complete_quest {quest} / set_flag {name,value} /
give_item {item,count} / take_item {item,count} / teach_jutsu {jutsuId} /
add_reputation {faction,amount} / close

## Правила валидации
- все goto ссылаются на существующие узлы (циклы допустимы);
- каждый диалог достижим из start;
- text обязателен для обоих языков (иначе warn);
- start_quest.quest — существующий квест.

## Хранение
Каталог: `data/shinobicore/dialogs/<id>.json` (создаётся в Спринте 20;
шаблон лежит в _templates, чтобы Studio уже умела его править).