# Формат: предметы и материалы (Content Pack, Спринт 2)

Статус: СОГЛАСОВАН, реализация в Спринте 2. Каталог живёт в
`data/shinobicore/_templates/item_catalog.json` (позже — `docs/content/items_catalog.json`).

## Зачем один каталог, а не файл на предмет
Предметы в 1.20.1 регистрируются кодом (ModItems), поэтому JSON не может создать
предмет сам. Каталог — единый источник правды, из которого генерируются:
1. сниппет регистрации для `ModItems.java` (копипаст из Studio);
2. `assets/shinobicore/models/item/<id>.json`;
3. записи в `en_us.json` / `ru_ru.json`;
4. `data/shinobicore/recipes/<id>.json` (если есть `craft`);
5. строка креатив-таба.

## Поля записи
| Поле | Тип | Обяз. | Описание |
|---|---|---|---|
| id | string | да | `shinobicore:<имя>` — совпадает с item id |
| kind | enum | да | sword / material / throwable / consumable / scroll / tool |
| tier | enum | нет | wood / stone / iron / steel / chakra_steel / special |
| displayName | {en_us,ru_ru} | да | попадает в lang-файлы |
| texture | string | да | путь от `assets/shinobicore/textures/` без .png |
| model | string | нет | parent-модель; по умолчанию `item/generated` (материалы) или `item/handheld` (мечи) |
| stats.damage | float | для kind=sword | базовый урон (как у KatanaItem) |
| stats.attackSpeed | float | для kind=sword | отрицательное, как ваниль (-1.8 … -3.2) |
| stats.durability | int | да для sword/tool | 0 = нерушимый |
| stats.reach | float | нет | бонус дистанции атаки (нодачи +0.5) |
| stanceBonuses | {aggressive,defensive} | нет | множители урона в стойках (Combat Pack v1: две стойки) |
| craft | object | нет | recipeFile + ingredients (см. шаблон); генерирует рецепт |
| forgeUpgrades | string[] | нет | шаги кузницы: sharpening / tempering / chakra_coating (Спринт 3) |
| infusable | bool | нет | реализует IInfusableItem (пропитка чакрой) |
| creativeTab | string | нет | по умолчанию shinobicore.main |

## Правила валидации (для Studio и CI-скрипта)
- id уникален, префикс `shinobicore:`;
- kind=sword ⇒ stats.damage > 0 и durability > 0;
- craft.ingredients — только существующие item id (minecraft:* или из каталога);
- texture-файл обязан существовать к моменту сборки (проверка scan-скриптом).

## Связь с кодом
- `ModItems.register()` — регистрация (сниппет генерирует Studio);
- `KatanaItem` / `ThrowingWeaponItem` — поведение по kind;
- `WeaponVisualRegistry` (`assets/shinobicore/weapon_visuals/*.json`) — визуал в руке;
  для каждого меча добавляется запись с model/glint/particles (формат уже есть — katana.json);
- `IInfusableItem` — infusable=true.