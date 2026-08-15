# SHINOBI CORE — Контекст проекта v2.0

## Паспорт
Naruto-мод для Minecraft 1.20.1, Fabric, одиночка + сервер.
Стек: Fabric Loader 0.16.9, Fabric API 0.92.3+1.20.1, Loom 1.9.2, Yarn mappings, Java 21.
Пакет: com.example.shinobicore. Точка входа: ShinobiCore (сервер), ShinobiCoreClient (клиент).
Запуск: .\gradlew.bat runClient
Конфиг: run/config/shinobicore/main.json

## Управление
M (удерж.) — медитация; R — каст слота A; T — каст слота B;
G — цикл слотов A; H — цикл слотов B;
K — меню прокачки; L — чакра-режим; V — удар ногой;
Z — додж влево; C — додж вправо; N — ползание;
B — переключение стиля тай-дзюцу (Standard/Strong Fist)

## Команды /ninja
info; set chakra|fatigue|stat|nature|clan|affinity;
give xp stat|nature|reserve; give sp;
jutsu list|info; learn <id>; cast <id>;
slot a|b <1-5> <id>; clan choose|list; reloadconfig

## Сеть (пакеты)
server→client: chakra_sync, loadout_sync, stats_sync, body_sync, catalog_sync, rasengan_sync
client→server: meditate, select_slot, cast_slot, spend_sp, chakra_mode, set_slot,
taijutsu_attack, taijutsu_kick, taijutsu_style, parkour_action, dodge, pose_sync, rasengan_strike

## ЧТО ГОТОВО

### Фаза 0: Очистка ✅
- Удалены мёртвые файлы (ChakraWaterWalkMixin, ExampleMixin, enchantment/)
- BOM-фиксы, compatibilityLevel JAVA_21, fabric.mod.json java >=21

### Фаза 1: Клановая система ✅
- Миграция ClanType enum → строковые ID (getClanId())
- costMultiplier подключён к NinjaFormula.calculateCost()
- fatigueMultiplier подключён к JutsuCaster.cast()
- statBonuses/natureBonuses применяются при выборе клана (applyClanBonuses/removeClanBonuses)
- 6 кланов JSON: uchiha, hyuga, uzumaki, nara, hatake, sarutobi

### Фаза 2: Behaviors ✅
- DashBehavior: урон по пути, отброс, waveWidth, trail-частицы, splash при приземлении
- MeleeBehavior: конус вместо box, fullCircle (360°), ignite, statusEffect, knockback
- AoeBehavior: частицы, knockback, stun, statusEffect (slowness/weakness/poison)
- ProjectileBehavior: speed, radius, particle, lifetime, gravity, pierce, bounce, count, spread
- WallBehavior: временная стена, диагональная постановка, только на земле, WallRemovalTask
- UtilityBehavior: heal, chakra_heal, regen, speed, strength, resistance, clear

### Фаза 3: Боевая система ✅
- Анти-чит комбо: серверная валидация comboStep + таймингов
- Переключатель стилей (B): Standard ↔ Strong Fist
- TaijutsuStyle: STANDARD, STRONG_FIST
- Звуки: заглушки через TaijutsuSounds (ванильные звуки)
- Анимации: улучшенные (ease-in-out, overshoot)

### Камера ✅
- Over-the-shoulder (за правым плечом)
- Плавное следование (lerp)
- Минимальная тряска
- FOV-эффекты отключены (не укачивает)

### Расенган ✅
- RasenganBehavior: зарядка в руке (baseChargeTicks=120, minChargeTicks=40)
- Время зарядки зависит от control: control=0 → 6 сек, control=100 → 2 сек
- Расенган готов → ЛКМ → рывок вперёд + урон + отброс
- Визуал: SOUL_FIRE_FLAME + END_ROD + CRIT (синий+белый)
- Пакеты: rasengan_sync (сервер→клиент), rasengan_strike (клиент→сервер)

### Контент: 20+ техник ✅
- Огонь: Flame Bullet, Phoenix Sage, Great Fireball, Dragon Flame
- Вода: Water Bullet, Great Waterfall, Raging Waves
- Ветер: Gale Palm, Passing Gale, Great Breakthrough
- Молния: Shock, False Darkness
- Земля: Earth Wall, Mud Wave
- Тай-дзюцу: Leaf Whirlwind
- Медицинские: Mystical Palm, Poison Extraction, Rope Escape
- Расенган (кастомный behavior)

### Визуал техник ✅
- NinjaProjectileRenderer: 6 квадов для объёма (3 вертикальных + горизонт + 2 диагональных)
- Текстура лавы (lava_still.png) для огненных шаров
- Текстура воды (water_still.png) для водяных
- White.png + tint для остальных стихий
- 2-3 слоя: ядро + свечение + внешний (для больших)
- trackRangeChunks=32

### JutsuLogger ✅
- Отдельный лог: config/shinobicore/jutsu_debug.log
- logCast, logBehavior, logProjectile, logCollision, logError, logInfo

### Паркур (из предыдущих сессий) ✅
- 9 действий: slide, wall run, edge grab, charged jump, roll, dodge, crawl, wall jump, double jump
- Синхронизация позы через пакет pose_sync + LowPoseTracker

### HUD ✅
- Кастомный в стиле Naruto
- Полоски: чакра, усталость, кислород, броня
- Лоауты A/B, комбо-счётчик, стиль тай-дзюцу, кулдаун удара ногой
- Расенган-индикатор (зарядка/готовность)

### Меню прокачки (K) ✅
- Стиль свитка: пергамент + деревянные валики
- Вкладки: Stats / Natures / Body / Jutsu

## НЕ СДЕЛАНО (приоритеты пользователя)
1. Аттюнмент (миниигра из меню K) — ПРИОРИТЕТ
2. Древо прокачки техник за SP — ПРИОРИТЕТ
3. Гендзюцу (фреймворк, резист, снятие, визуал)
4. Тай-дзюцу прокаченное (блокирование, парирование, Gentle Fist)
5. Сюрикен-дзюцу (метание, предметы)
6. Кен-дзюцу (катаны, анимации, стили)
7. Визуал: анимация каста (печати), свечение рук при касте
8. Стена в чакра-режиме v2 (полноценная: ноги на стене, мир переворачивается)
9. Баланс прыжков (сейчас перебор при макс прокачке)
10. Перевод техник (lang)
11. Звуки (пока ванильные, потом кастомные)
12. Клоны (Kage Bunshin) — ПОТОМ
13. Объём новых техник и кланов — ПОТОМ
14. Додзюцу (Sharingan, Byakugan) — ПОТОМ

## ГЛАВНЫЕ ТЕХ-РЕШЕНИЯ (не наступать на грабли!)
- Движение игрока в одиночке считается НА КЛИЕНТЕ. Физику движения делать в ClientTickEvents.
- Имена методов для Mixin брать из Yarn 1.20.1.
- Не вызывать внутри @Inject метода тот же метод (рекурсия).
- Кастомным сущностям обязательно регистрировать EntityRendererRegistry на клиенте.
- JSON-файлы создавать в UTF-8 без BOM.
- Gson-конфиг: load() затем save() — новые поля сами появляются.
- PowerShell Set-Content -Encoding UTF8 пишет BOM! Использовать [System.IO.File]::WriteAllBytes или скрипт удаления BOM.
- ProjectileEntity.tick() НЕ перемещает сущность в 1.20.1 — нужно ручное setPosition в tick().
- ProjectileUtil.getEntityHitResult имеет другую сигнатуру в 1.20.1 — использовать ручной рейкаст через Box.raycast().
- ModelPart не имеет поля swing в 1.20.1 — использовать pitch/yaw/roll.
- Direction.fromHorizontalDegrees не существует в 1.20.1 — использовать Direction.fromRotation().
- ParticleTypes.FALLING_DUST может требовать BlockState — использовать POOF для earth.
- ClientPlayNetworking.send читает buf сразу — нельзя читать buf внутри server.execute().

## Изменения формул
- jumpHorizontalMultiplier: chakraMode = 2.0 + jumpLevel * 0.5 (макс 5.5x)
- jumpVerticalMultiplier: chakraMode = 1.5 + jumpLevel * 0.15 (макс 2.55x)
- Rasengan chargeTicks = max(minChargeTicks, baseChargeTicks - control * 0.8)
- Mastery = 25% usage + 75% characterScore

## CHANGELOG
- 2026-08-07: Шаги 1-6 (конфиг, формулы, кланы, меню, техники, чакра-режим)
- 2026-08-08: Шаг 7 (лоауты, паркур, behaviors)
- 2026-08-10: Шаги A-F (полный паркур + HUD + меню-свиток)
- 2026-08-11: Фаза 0 (очистка), Фаза 1 (кланы), Фаза 2 (behaviors)
- 2026-08-12: Фаза 3 (анти-чит, стили, анимации), Камера, Расенган
- 2026-08-13: Волна 1 (UtilityBehavior), Волна 2 (Melee/AOE/Dash)
- 2026-08-14: Визуал техник (текстура лавы, 6 квадов), JutsuLogger, 20+ техник

## Р¤Р°Р·Р°: Р‘РѕРµРІР°СЏ СЃРёСЃС‚РµРјР° РєР°С‚Р°РЅС‹ v2 (Р”РѕР±Р°РІР»РµРЅРѕ СЃРєСЂРёРїС‚Р°РјРё phase_combat_1-4)
### РљРѕРјР±Рѕ:
- 6 С€Р°РіРѕРІ РєРѕРјР±Рѕ (РІРјРµСЃС‚Рѕ 4), С€Р°Рі 5 = С„РёРЅРёС€РµСЂ 360В°
- РЈРґР°СЂ РІ РїСЂС‹Р¶РєРµ (LMB РІ РІРѕР·РґСѓС…Рµ): x2.5 СѓСЂРѕРЅ, slam down
- РЈРґР°СЂ СЃ Р±РµРіР° (LMB РїСЂРё СЃРїСЂРёРЅС‚Рµ): x1.6 СѓСЂРѕРЅ, push forward
- Iai Dash (R РІ СЃС‚РѕР№РєРµ Iai): СЂС‹РІРѕРє + x3.0 СѓСЂРѕРЅ

### РЎС‚РѕР№РєРё:
- AGGRESSIVE: x1.15 СѓСЂРѕРЅ, x1.25 СЃРєРѕСЂРѕСЃС‚СЊ, x1.4 СѓСЃС‚Р°Р»РѕСЃС‚СЊ
- SEIGAN: x0.85 СѓСЂРѕРЅ, РїР°СЂРёСЂРѕРІР°РЅРёРµ, +0.5 С‡Р°РєСЂС‹ Р·Р° РїР°СЂРёСЂРѕРІР°РЅРёРµ, РїР°СЃСЃРёРІРЅС‹Р№ СЂРµРіРµРЅ С‡Р°РєСЂС‹
- IAI: x1.0 СѓСЂРѕРЅ, x0.85 СЃРєРѕСЂРѕСЃС‚СЊ, x1.5 С‡Р°РєСЂР°-СѓСЂРѕРЅ, Iai Dash

### Р§Р°РєСЂР°-РёРЅС‚РµРіСЂР°С†РёСЏ:
- Р§Р°РєСЂР°-СЂРµР¶РёРј СѓСЃРёР»РёРІР°РµС‚ СѓРґР°СЂС‹ (РјРЅРѕР¶РёС‚РµР»СЊ Р·Р°РІРёСЃРёС‚ РѕС‚ СЃС‚РѕР№РєРё)
- Chakra Combo: РїРѕСЃР»РµРґРѕРІР°С‚РµР»СЊРЅС‹Рµ СѓРґР°СЂС‹ РІ С‡Р°РєСЂР°-СЂРµР¶РёРјРµ РґР°СЋС‚ +5% Р·Р° СѓРґР°СЂ (РјР°РєСЃ +50%)
- РЎРїРµС†СѓРґР°СЂС‹ СЃС‚РѕСЏС‚ С‡Р°РєСЂСѓ (jump=3, sprint=1.5, iai dash=5)
- РџР°СЂРёСЂРѕРІР°РЅРёРµ РІ Seigan РіРµРЅРµСЂРёСЂСѓРµС‚ С‡Р°РєСЂСѓ

### РљР»Р°РІРёС€Рё:
- R (РІ СЃС‚РѕР№РєРµ Iai): Iai Dash
- X: РџР°СЂРёСЂРѕРІР°РЅРёРµ
- F: РЎРјРµРЅР° СЃС‚РѕР№РєРё
## Р¤Р°Р·Р°: VOXEL MODELS MASTER (apply_voxel_master.ps1)
- РљР°С‚Р°РЅС‹: РІР°РЅРёР»СЊРЅС‹Рµ JSON-РјРѕРґРµР»Рё СЃ elements (10 РєСѓР±РѕРІ: РєР»РёРЅРѕРє/С…Р°/С†СѓР±Р°/РѕР±РјРѕС‚РєР°), РїР°Р»РёС‚СЂС‹ С‚РµРєСЃС‚СѓСЂ РЅР° С‚РёСЂ, overrides custom_model_data РґР»СЏ РЅРѕР¶РµРЅ.
- РќРѕР¶РЅС‹ РЅР° СЃРїРёРЅРµ: РїР°Р»РёС‚СЂР° РїРѕРґ С‚РёСЂ РєР°С‚Р°РЅС‹ (iron/diamond/netherite), СЃР°Р№СЏ + РѕР±РјРѕС‚РєРё + Р°РєС†РµРЅС‚С‹ РєР°Рє РІ СЂРµС„РµСЂРµРЅСЃРµ.
- Р‘СЂРѕРЅСЏ: ArmorRenderer (Fabric API) вЂ” РІРѕРєСЃРµР»СЊРЅС‹Р№ Р¶РёР»РµС‚ СЃ РєР°СЂРјР°РЅР°РјРё, РїРѕРІСЏР·РєР°-РїСЂРѕС‚РµРєС‚РѕСЂ СЃРѕ СЃС‚Р°Р»СЊРЅРѕР№ РїР»Р°СЃС‚РёРЅРѕР№, РїРѕРґСЃСѓРјРѕРє, Р±РёРЅС‚С‹, СЃР°РЅРґР°Р»РёРё.
- UX: РєР»Р°РІРёС€Р° O СЃРєСЂС‹РІР°РµС‚ РєР»РёРЅРѕРє (empty-РјРѕРґРµР»СЊ) + Р·РІСѓРєРё РґРѕСЃС‚Р°РІР°РЅРёСЏ/РЅРѕР¶РµРЅ; creative-РІРєР»Р°РґРєР°; РїРѕР»РЅС‹Рµ lang en/ru; РїРёРєСЃРµР»СЊ-Р°СЂС‚ РёРєРѕРЅРєРё СЃСЋСЂРёРєРµРЅР°/РєСѓРЅР°СЏ/Р±СЂРѕРЅРё.