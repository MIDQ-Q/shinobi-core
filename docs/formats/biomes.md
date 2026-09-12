# Формат: биомы (Biomes Pack, Спринт 18)

Статус: СОГЛАСОВАН, реализация в Спринте 18. Шаблон:
`data/shinobicore/_templates/biome_template.json`.

## Двухслойность
Биом = ванильный `worldgen/biome` JSON (генерация через Fabric Biome API)
+ блок `shinobicore` (атмосфера и привязки мода). Один шаблон описывает оба слоя:
при реализации скрипт-генератор раскладывает его в два файла.

## Слой vanilla (ключ "vanilla")
Стандартный формат 1.20.1: temperature, downfall, has_precipitation,
effects (цвета неба/тумана/воды, grass/foliage, mood_sound), spawners,
carvers, features. Никаких модовых полей — чтобы ванильная генерация не ломалась.

## Слой shinobicore (ключ "shinobicore")
| Поле | Тип | Описание |
|---|---|---|
| atmosphere.type | enum | peaceful / tense / oppressive / eerie — пресет клиентской атмосферы |
| atmosphere.fogDensity | float 0..1 | плотность тумана (клиентский рендер-хук) |
| atmosphere.particleAmbient | string | пресет фоновых частиц (falling_leaf / ash / petal / mist / spore) |
| atmosphere.particleColor | hex | цвет фоновых частиц |
| atmosphere.ambientSound | string | id эмбиента (Sound Pack — Спринт 32) |
| atmosphere.oppressive | bool | «гнетущее чувство» (Лес Смерти): десатурация + виньетка (клиент) |
| generation.weight | int | вес в Fabric Biome API |
| generation.allowedVanillaNeighbors | string[] | соседи для плавных переходов |
| resourceOverrides.ores | string[] | доп. руды из item_catalog (чакра-кристалл и т.д.) |
| structurePool | string | пул структур Спринта 19 для этого биома |

## Целевой состав (Спринт 18)
Япония: бамбуковый лес, рисовые террасы, горный перевал, цветущая долина.
Атмосферные: Лес Смерти (oppressive=true), пепельная пустошь, затопленные руины,
подземное озеро. Каждый биом: 1 шаблон → 2 файла при генерации.

## Правила валидации
- цвета — int или #hex (генератор приводит к int для ванили);
- structurePool ссылается только на описанные в structures.md структуры;
- spawners.type — только существующие EntityType.