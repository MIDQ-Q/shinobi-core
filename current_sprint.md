# ДЕТАЛЬНЫЙ ПЛАН ТРЕКА Г: ИНТЕРФЕЙС + ПРОКАЧКА

Изучил дамп от 14:25 и зафиксировал архитектуру. Ниже — полный план всех 5 спринтов с файлами, методами, логикой и алгоритмами. После этого останется только писать синтаксис.

---

## 📊 ТЕКУЩЕЕ СОСТОЯНИЕ (из дампа)

### Уже есть:
- ✅ `StatType.java` с 14 статами (TAIJUTSU, KENJUTSU, SHURIKEN, GENJUTSU, NINJUTSU, CHAKRA_CONTROL, PERCEPTION, TAIJUTSU_DEFENSE, KENJUTSU_DEFENSE, SHURIKEN_DEFENSE, GENJUTSU_DEFENSE, SPEED, JUMP, STAMINA)
- ✅ `IStatsComponent` + `StatsComponentImpl` (базовые методы getStatLevel, addXp)
- ✅ `ShinobiConstants` (MAX_STAT_LEVEL = 100, XP_BASE = 100, XP_PER_LEVEL = 25, SP_PER_LEVEL_UP = 1)
- ✅ Базовые команды `/shinobicore stats`
- ✅ NBT-сохранение через CCA

### Отсутствует:
- ❌ 5 новых статов (PHYSICAL, SPIRITUAL, FOCUS, WILLPOWER, INSIGHT)
- ❌ Хуки XP за бой и техники
- ❌ `ProgressionScreen` (экран K)
- ❌ `SkillTreeScreen` (древо с зумом)
- ❌ Мини-игры (аттюнмент, контроль, меткость, спарринг)
- ❌ Визуальные эффекты повышения уровня

---

## 🎯 СТРАТЕГИЯ

### Формула XP (экспоненциальная, но мягкая):
```java
// xpForLevel = base * (1 + level * factor + level^2 * squared)
// При level=1: 100 * (1 + 0.1 + 0.05) = 115 XP
// При level=10: 100 * (1 + 1.0 + 5.0) = 700 XP
// При level=50: 100 * (1 + 5.0 + 125.0) = 13,100 XP
// При level=100: 100 * (1 + 10.0 + 500.0) = 51,100 XP
```

**Константы:**
- `XP_BASE = 100`
- `XP_FACTOR = 0.1` (линейный рост)
- `XP_SQUARED = 0.05` (квадратичный рост)

### 5 новых статов:
| Стат | Категория | Влияние |
|------|-----------|---------|
| `PHYSICAL` | Физический | +HP, +урон ближнего боя, +скорость |
| `SPIRITUAL` | Духовный | +макс чакра, +реген чакры |
| `FOCUS` | Духовный | -стоимость техник, +скорость каста |
| `WILLPOWER` | Духовный | +резист гендзюцу, -усталость |
| `INSIGHT` | Вспомогательный | +множитель XP, +крит шанс |

### Архитектура сохранения:
- Статы хранятся в `IStatsComponent` (уже есть)
- Добавляем поля для 5 новых статов
- NBT-сохранение уже работает через CCA
- Миграция старых данных: старые статы остаются, новые добавляются с дефолтными значениями

### Готовность дерева:
- Текущий `tree.json` содержит узлы для старых статов
- Добавляем новые ветки для PHYSICAL, SPIRITUAL, FOCUS, WILLPOWER, INSIGHT
- Старые узлы не ломаем

---

## 📋 СПРИНТ A: ФУНДАМЕНТ ПРОКАЧКИ (2-3 дня)

**Цель:** Расширить систему статов, добавить источники XP, протестировать сохранение.

### Шаг A1: Расширение `StatType`

**Файл:** `stat/StatType.java`

**Изменения:**
```java
// Добавляем 5 новых статов
PHYSICAL("physical", StatCategory.COMBAT, "PHYSICAL"),
SPIRITUAL("spiritual", StatCategory.CHAKRA, "SPIRITUAL"),
FOCUS("focus", StatCategory.CHAKRA, "FOCUS"),
WILLPOWER("willpower", StatCategory.CHAKRA, "WILLPOWER"),
INSIGHT("insight", StatCategory.UTILITY, "INSIGHT");
```

**Категории:**
- `COMBAT`: TAIJUTSU, KENJUTSU, SHURIKEN, GENJUTSU, NINJUTSU, PHYSICAL
- `CHAKRA`: CHAKRA_CONTROL, SPIRITUAL, FOCUS, WILLPOWER
- `UTILITY`: PERCEPTION, INSIGHT
- `DEFENSE`: все DEFENSE статы

### Шаг A2: Расширение `IStatsComponent`

**Файл:** `stat/component/IStatsComponent.java`

**Новые методы:**
```java
// Геттеры для новых статов
int getStatLevel(StatType type);
int getStatXp(StatType type);
float getProgressToNextLevel(StatType type);

// XP формула
int getXpForNextLevel(StatType type);

// Добавление XP
void addXp(StatType type, int amount);

// Проверка повышения уровня
boolean tryLevelUp(StatType type);

// Получение бонусов от статов
float getPhysicalDamageBonus();
float getSpiritualChakraBonus();
float getFocusCostReduction();
float getWillpowerFatigueReduction();
float getInsightXpMultiplier();
```

### Шаг A3: Реализация в `StatsComponentImpl`

**Файл:** `stat/component/impl/StatsComponentImpl.java`

**Новые поля:**
```java
private final Map<StatType, Integer> statLevels = new EnumMap<>(StatType.class);
private final Map<StatType, Integer> statXp = new EnumMap<>(StatType.class);
```

**Логика `addXp()`:**
```java
public void addXp(StatType type, int amount) {
    // Применяем множитель INSIGHT
    float insightMult = getInsightXpMultiplier();
    amount = (int)(amount * insightMult);
    
    int currentXp = statXp.getOrDefault(type, 0);
    currentXp += amount;
    statXp.put(type, currentXp);
    
    // Проверяем повышение уровня
    while (tryLevelUp(type)) {
        // Цикл, если XP хватило на несколько уровней
    }
    
    markDirty();
}

public boolean tryLevelUp(StatType type) {
    int currentLevel = statLevels.getOrDefault(type, 1);
    int currentXp = statXp.getOrDefault(type, 0);
    int requiredXp = getXpForNextLevel(type);
    
    if (currentXp >= requiredXp) {
        currentXp -= requiredXp;
        currentLevel++;
        statLevels.put(type, currentLevel);
        statXp.put(type, currentXp);
        
        // Выдаем SP
        int spGain = ShinobiConstants.SP_PER_LEVEL_UP;
        addSp(spGain);
        
        // Отправляем событие повышения уровня клиенту
        sendLevelUpEvent(type, currentLevel);
        
        return true;
    }
    return false;
}

public int getXpForNextLevel(StatType type) {
    int level = statLevels.getOrDefault(type, 1);
    int base = ShinobiConstants.XP_BASE;
    float factor = ShinobiConstants.XP_FACTOR;
    float squared = ShinobiConstants.XP_SQUARED;
    
    return (int)(base * (1.0f + level * factor + level * level * squared));
}
```

**NBT-сохранение:**
```java
@Override
public void readFromNbt(NbtCompound nbt) {
    // Читаем старые статы (для совместимости)
    // ...
    
    // Читаем новые статы
    if (nbt.contains("StatLevels")) {
        NbtCompound levelsNbt = nbt.getCompound("StatLevels");
        for (StatType type : StatType.values()) {
            if (levelsNbt.contains(type.getId())) {
                statLevels.put(type, levelsNbt.getInt(type.getId()));
            }
        }
    }
    
    if (nbt.contains("StatXp")) {
        NbtCompound xpNbt = nbt.getCompound("StatXp");
        for (StatType type : StatType.values()) {
            if (xpNbt.contains(type.getId())) {
                statXp.put(type, xpNbt.getInt(type.getId()));
            }
        }
    }
}

@Override
public void writeToNbt(NbtCompound nbt) {
    // ...
    
    NbtCompound levelsNbt = new NbtCompound();
    for (Map.Entry<StatType, Integer> entry : statLevels.entrySet()) {
        levelsNbt.putInt(entry.getKey().getId(), entry.getValue());
    }
    nbt.put("StatLevels", levelsNbt);
    
    NbtCompound xpNbt = new NbtCompound();
    for (Map.Entry<StatType, Integer> entry : statXp.entrySet()) {
        xpNbt.putInt(entry.getKey().getId(), entry.getValue());
    }
    nbt.put("StatXp", xpNbt);
}
```

### Шаг A4: Хуки XP в `JutsuCaster`

**Файл:** `jutsu/JutsuCaster.java`

**Изменения в `cast()`:**
```java
// После успешного каста (строка ~150)
if (success) {
    // ...
    
    // Выдаем XP за использование техники
    IStatsComponent stats = NinjaComponents.getStats(caster);
    if (stats != null) {
        StatType primaryStat = getPrimaryStatForJutsu(jutsu);
        int xpReward = (int)(jutsu.getBaseXpReward() * jutsu.getLevel());
        stats.addXp(primaryStat, xpReward);
        
        // Также даем XP в CHAKRA_CONTROL
        stats.addXp(StatType.CHAKRA_CONTROL, (int)(xpReward * 0.5f));
    }
}
```

**Метод `getPrimaryStatForJutsu()`:**
```java
private StatType getPrimaryStatForJutsu(JutsuDefinition jutsu) {
    // Определяем основной стат по тегам техники
    if (jutsu.hasTag("taijutsu")) return StatType.TAIJUTSU;
    if (jutsu.hasTag("kenjutsu")) return StatType.KENJUTSU;
    if (jutsu.hasTag("shuriken")) return StatType.SHURIKEN;
    if (jutsu.hasTag("genjutsu")) return StatType.GENJUTSU;
    if (jutsu.hasTag("ninjutsu")) return StatType.NINJUTSU;
    return StatType.NINJUTSU; // По умолчанию
}
```

### Шаг A5: Хуки XP в `LivingEntity.damage()`

**Файл:** Миксин `LivingEntityDamageMixin.java`

**Логика:**
```java
@Mixin(LivingEntity.class)
public class LivingEntityDamageMixin {
    @Inject(method = "damage", at = @At("HEAD"))
    private void shinobicore_onDamage(DamageSource source, float amount, CallbackInfoReturnable<Boolean> cir) {
        LivingEntity self = (LivingEntity)(Object)this;
        
        // Проверяем, что атакующий — игрок
        if (source.getAttacker() instanceof PlayerEntity attacker) {
            IStatsComponent stats = NinjaComponents.getStats(attacker);
            if (stats != null) {
                // Определяем тип атаки
                StatType attackStat = getAttackStat(attacker, source);
                
                // XP = 10% от нанесенного урона
                int xpReward = Math.max(1, (int)(amount * 0.1f));
                stats.addXp(attackStat, xpReward);
            }
        }
    }
    
    private StatType getAttackStat(PlayerEntity attacker, DamageSource source) {
        // Если атака оружием
        if (source.getName().equals("player")) {
            ItemStack weapon = attacker.getMainHandStack();
            if (weapon.isOf(Items.IRON_SWORD) || weapon.isOf(Items.DIAMOND_SWORD)) {
                return StatType.KENJUTSU;
            }
            if (weapon.isOf(Items.BOW)) {
                return StatType.SHURIKEN;
            }
        }
        
        // По умолчанию — рукопашный бой
        return StatType.TAIJUTSU;
    }
}
```

### Шаг A6: Админ-команды

**Файл:** `command/ShinobiCommands.java`

**Новые подкоманды:**
```java
.then(CommandManager.literal("stats")
    .then(CommandManager.literal("info").executes(ShinobiCommands::cmdStatsInfo))
    .then(CommandManager.literal("set")
        .then(CommandManager.argument("stat", StringArgumentType.word())
            .then(CommandManager.argument("level", IntegerArgumentType.integer(1, 100))
                .executes(ShinobiCommands::cmdStatsSet))))
    .then(CommandManager.literal("addxp")
        .then(CommandManager.argument("stat", StringArgumentType.word())
            .then(CommandManager.argument("amount", IntegerArgumentType.integer(1, 10000))
                .executes(ShinobiCommands::cmdStatsAddXp))))
    .then(CommandManager.literal("addsp")
        .then(CommandManager.argument("amount", IntegerArgumentType.integer(1, 1000))
            .executes(ShinobiCommands::cmdStatsAddSp))))
```

**Реализация:**
```java
private static int cmdStatsInfo(CommandContext<ServerCommandSource> ctx) {
    ServerCommandSource src = ctx.getSource();
    ServerPlayerEntity player = getExecutingPlayer(ctx);
    if (player == null) return 0;
    
    IStatsComponent stats = NinjaComponents.getStats(player);
    if (stats == null) return 0;
    
    src.sendFeedback(() -> text("=== Stats Info ===", Formatting.GOLD), false);
    for (StatType type : StatType.values()) {
        int level = stats.getStatLevel(type);
        int xp = stats.getStatXp(type);
        int required = stats.getXpForNextLevel(type);
        src.sendFeedback(() -> text(
            String.format("%s: Level %d | XP %d/%d", 
                type.getName(), level, xp, required),
            Formatting.WHITE
        ), false);
    }
    
    int sp = stats.getSp();
    src.sendFeedback(() -> text("SP: " + sp, Formatting.AQUA), false);
    
    return 1;
}

private static int cmdStatsSet(CommandContext<ServerCommandSource> ctx) {
    // Устанавливаем уровень стата
    String statId = StringArgumentType.getString(ctx, "stat");
    int level = IntegerArgumentType.getInteger(ctx, "level");
    
    StatType type = StatType.fromId(statId);
    if (type == null) {
        ctx.getSource().sendError(text("Unknown stat: " + statId));
        return 0;
    }
    
    ServerPlayerEntity player = getExecutingPlayer(ctx);
    IStatsComponent stats = NinjaComponents.getStats(player);
    if (stats == null) return 0;
    
    stats.setStatLevel(type, level);
    ctx.getSource().sendFeedback(() -> text("Set " + statId + " to level " + level, Formatting.GREEN), false);
    return 1;
}

private static int cmdStatsAddXp(CommandContext<ServerCommandSource> ctx) {
    // Добавляем XP
    String statId = StringArgumentType.getString(ctx, "stat");
    int amount = IntegerArgumentType.getInteger(ctx, "amount");
    
    StatType type = StatType.fromId(statId);
    if (type == null) {
        ctx.getSource().sendError(text("Unknown stat: " + statId));
        return 0;
    }
    
    ServerPlayerEntity player = getExecutingPlayer(ctx);
    IStatsComponent stats = NinjaComponents.getStats(player);
    if (stats == null) return 0;
    
    stats.addXp(type, amount);
    ctx.getSource().sendFeedback(() -> text("Added " + amount + " XP to " + statId, Formatting.GREEN), false);
    return 1;
}
```

### Шаг A7: Пакет `LEVEL_UP_EVENT`

**Файл:** `network/ModPackets.java`

**Новый пакет:**
```java
public static final Identifier LEVEL_UP_EVENT = 
    new Identifier(ShinobiConstants.MOD_ID, "level_up_event");
```

**Отправка с сервера:**
```java
public static void sendLevelUpEvent(ServerPlayerEntity player, StatType type, int newLevel) {
    PacketByteBuf buf = PacketByteBufs.create();
    buf.writeString(type.getId());
    buf.writeVarInt(newLevel);
    ServerPlayNetworking.send(player, LEVEL_UP_EVENT, buf);
}
```

**Приём на клиенте:**
```java
ClientPlayNetworking.registerGlobalReceiver(LEVEL_UP_EVENT,
    (client, handler, buf, responseSender) -> {
        final String statId = buf.readString();
        final int newLevel = buf.readVarInt();
        
        client.execute(() -> {
            // Запускаем анимацию повышения уровня
            LevelUpAnimation.start(statId, newLevel);
        });
    });
```

### Шаг A8: Тестирование

**Команды:**
```
/shinobicore stats info
/shinobicore stats set taijutsu 50
/shinobicore stats addxp taijutsu 500
/shinobicore stats addsp 10
```

**Проверки:**
- ✅ Статы отображаются корректно
- ✅ XP начисляется за техники и бой
- ✅ Уровни повышаются автоматически
- ✅ SP выдаются при повышении уровня
- ✅ Прогресс сохраняется после смерти и relog

---

## 📋 СПРИНТ B: PROGRESSION SCREEN (3-4 дня)

**Цель:** Создать главный экран с вкладками (K), отобразить статы с прогресс-барами.

### Шаг B1: Базовые виджеты

**Файл:** `client/gui/widget/ProgressBar.java`

```java
public class ProgressBar extends DrawableHelper {
    private final int x, y, width, height;
    private float progress; // 0.0 to 1.0
    private int backgroundColor = 0xFF404040;
    private int fillColor = 0xFF00FF00;
    
    public ProgressBar(int x, int y, int width, int height) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
    }
    
    public void setProgress(float progress) {
        this.progress = Math.max(0, Math.min(1, progress));
    }
    
    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        // Рисуем фон
        context.fill(x, y, x + width, y + height, backgroundColor);
        
        // Рисуем заполнение
        int fillWidth = (int)(width * progress);
        context.fill(x, y, x + fillWidth, y + height, fillColor);
        
        // Рисуем рамку
        context.drawBorder(x, y, width, height, 0xFFFFFFFF);
    }
}
```

**Файл:** `client/gui/widget/StatRow.java`

```java
public class StatRow extends DrawableHelper {
    private final StatType stat;
    private final int x, y;
    private final ProgressBar progressBar;
    
    public StatRow(StatType stat, int x, int y) {
        this.stat = stat;
        this.x = x;
        this.y = y;
        this.progressBar = new ProgressBar(x + 120, y, 100, 10);
    }
    
    public void render(DrawContext context, IStatsComponent stats, int mouseX, int mouseY, float delta) {
        int level = stats.getStatLevel(stat);
        int xp = stats.getStatXp(stat);
        int required = stats.getXpForNextLevel(stat);
        float progress = (float)xp / required;
        
        // Иконка
        Identifier icon = getIconForStat(stat);
        context.drawTexture(icon, x, y, 0, 0, 16, 16, 16, 16);
        
        // Название и уровень
        String text = stat.getName() + " Lv." + level;
        context.drawText(textRenderer, text, x + 20, y + 4, 0xFFFFFF, false);
        
        // Прогресс-бар
        progressBar.setProgress(progress);
        progressBar.render(context, mouseX, mouseY, delta);
        
        // Текст XP
        String xpText = xp + "/" + required + " XP";
        context.drawText(textRenderer, xpText, x + 225, y + 4, 0xAAAAAA, false);
    }
    
    private Identifier getIconForStat(StatType stat) {
        // Возвращаем текстуру иконки для стата
        return new Identifier(ShinobiConstants.MOD_ID, "textures/gui/stats/" + stat.getId() + ".png");
    }
}
```

### Шаг B2: ProgressionScreen

**Файл:** `client/gui/screen/ProgressionScreen.java`

```java
public class ProgressionScreen extends Screen {
    private static final int TAB_WIDTH = 100;
    private static final int TAB_HEIGHT = 20;
    
    private final List<TabButton> tabs = new ArrayList<>();
    private int activeTabIndex = 0;
    
    private final List<StatRow> statRows = new ArrayList<>();
    
    public ProgressionScreen() {
        super(Text.literal("Progression"));
    }
    
    @Override
    protected void init() {
        super.init();
        
        // Создаем вкладки
        tabs.add(new TabButton(0, 0, TAB_WIDTH, TAB_HEIGHT, "Stats"));
        tabs.add(new TabButton(TAB_WIDTH, 0, TAB_WIDTH, TAB_HEIGHT, "Tree"));
        tabs.add(new TabButton(TAB_WIDTH * 2, 0, TAB_WIDTH, TAB_HEIGHT, "Attunement"));
        tabs.add(new TabButton(TAB_WIDTH * 3, 0, TAB_WIDTH, TAB_HEIGHT, "Settings"));
        
        // Создаем строки статов
        ClientPlayerEntity player = MinecraftClient.getInstance().player;
        IStatsComponent stats = NinjaComponents.getStats(player);
        
        int startY = 40;
        int rowHeight = 25;
        
        for (StatType type : StatType.values()) {
            statRows.add(new StatRow(type, 20, startY));
            startY += rowHeight;
        }
    }
    
    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        renderBackground(context);
        
        // Рисуем вкладки
        for (int i = 0; i < tabs.size(); i++) {
            TabButton tab = tabs.get(i);
            boolean active = (i == activeTabIndex);
            tab.render(context, mouseX, mouseY, delta, active);
        }
        
        // Рисуем содержимое активной вкладки
        if (activeTabIndex == 0) {
            renderStatsTab(context, mouseX, mouseY, delta);
        }
        
        super.render(context, mouseX, mouseY, delta);
    }
    
    private void renderStatsTab(DrawContext context, int mouseX, int mouseY, float delta) {
        ClientPlayerEntity player = MinecraftClient.getInstance().player;
        IStatsComponent stats = NinjaComponents.getStats(player);
        
        if (stats == null) return;
        
        // Рисуем все строки статов
        for (StatRow row : statRows) {
            row.render(context, stats, mouseX, mouseY, delta);
        }
        
        // Рисуем SP
        int sp = stats.getSp();
        context.drawText(textRenderer, "SP: " + sp, 20, height - 30, 0x00FFFF, false);
    }
    
    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        // Проверяем клик по вкладкам
        for (int i = 0; i < tabs.size(); i++) {
            if (tabs.get(i).isMouseOver(mouseX, mouseY)) {
                activeTabIndex = i;
                return true;
            }
        }
        
        return super.mouseClicked(mouseX, mouseY, button);
    }
}
```

### Шаг B3: Регистрация клавиши K

**Файл:** `client/input/KeyBindings.java`

```java
public static KeyBinding PROGRESSION_SCREEN;

// В register():
PROGRESSION_SCREEN = KeyBindingHelper.registerKeyBinding(new KeyBinding(
    "key.shinobicore.progression",
    InputUtil.Type.KEYSYM,
    GLFW.GLFW_KEY_K,
    "key.categories.shinobicore.ui"
));
```

**Файл:** `client/input/KeyInputHandler.java`

```java
public class KeyInputHandler {
    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            if (KeyBindings.PROGRESSION_SCREEN.wasPressed()) {
                MinecraftClient.getInstance().setScreen(new ProgressionScreen());
            }
        });
    }
}
```

### Шаг B4: Тестирование

**Проверки:**
- ✅ Экран открывается по K
- ✅ Вкладки переключаются
- ✅ Статы отображаются с иконками, уровнями, XP
- ✅ Прогресс-бары работают
- ✅ SP отображается

---

## 📋 СПРИНТ C: SKILL TREE SCREEN (4-5 дней)

**Цель:** Реализовать древо навыков с зумом, панорамированием, разблокировкой узлов.

### Шаг C1: Загрузка дерева из JSON

**Файл:** `data/shinobicore/skill_tree/tree.json`

```json
{
  "nodes": {
    "taijutsu_basic": {
      "id": "taijutsu_basic",
      "name": "Basic Taijutsu",
      "description": "Improves unarmed combat",
      "x": 0,
      "y": 0,
      "cost": 1,
      "requirements": {
        "stats": { "taijutsu": 5 }
      },
      "effects": {
        "unarmed_damage": 2
      }
    },
    "taijutsu_advanced": {
      "id": "taijutsu_advanced",
      "name": "Advanced Taijutsu",
      "description": "Unlocks combo attacks",
      "x": 100,
      "y": 0,
      "cost": 2,
      "requirements": {
        "nodes": ["taijutsu_basic"],
        "stats": { "taijutsu": 20 }
      },
      "effects": {
        "combo_damage": 1.2
      }
    }
  },
  "connections": [
    { "from": "taijutsu_basic", "to": "taijutsu_advanced" }
  ]
}
```

**Файл:** `skilltree/SkillTreeRegistry.java`

```java
public class SkillTreeRegistry {
    private static final Map<String, SkillTreeNode> nodes = new HashMap<>();
    private static final List<SkillTreeConnection> connections = new ArrayList<>();
    
    public static void load() {
        // Загружаем из data/shinobicore/skill_tree/tree.json
        // Парсим JSON, создаем узлы и связи
    }
    
    public static SkillTreeNode getNode(String id) {
        return nodes.get(id);
    }
    
    public static Collection<SkillTreeNode> getAllNodes() {
        return nodes.values();
    }
    
    public static List<SkillTreeConnection> getConnections() {
        return connections;
    }
}
```

### Шаг C2: SkillTreeScreen

**Файл:** `client/gui/screen/SkillTreeScreen.java`

```java
public class SkillTreeScreen extends Screen {
    private float cameraX = 0;
    private float cameraY = 0;
    private float zoom = 1.0f;
    
    private boolean dragging = false;
    private double lastMouseX, lastMouseY;
    
    public SkillTreeScreen() {
        super(Text.literal("Skill Tree"));
    }
    
    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        renderBackground(context);
        
        MatrixStack matrices = context.getMatrices();
        matrices.push();
        
        // Применяем трансформацию камеры
        matrices.translate(width / 2.0f, height / 2.0f, 0);
        matrices.scale(zoom, zoom, 1);
        matrices.translate(-cameraX, -cameraY, 0);
        
        // Рисуем связи
        renderConnections(context);
        
        // Рисуем узлы
        renderNodes(context, mouseX, mouseY, delta);
        
        matrices.pop();
        
        // Рисуем UI поверх
        renderUI(context);
        
        super.render(context, mouseX, mouseY, delta);
    }
    
    private void renderConnections(DrawContext context) {
        // Используем BufferBuilder для батчинга линий
        Tessellator tessellator = Tessellator.getInstance();
        BufferBuilder buffer = tessellator.getBuffer();
        
        buffer.begin(VertexFormat.DrawMode.LINES, VertexFormats.POSITION_COLOR);
        
        for (SkillTreeConnection conn : SkillTreeRegistry.getConnections()) {
            SkillTreeNode from = SkillTreeRegistry.getNode(conn.getFrom());
            SkillTreeNode to = SkillTreeRegistry.getNode(conn.getTo());
            
            if (from != null && to != null) {
                int color = isConnectionUnlocked(conn) ? 0xFF00FF00 : 0xFF808080;
                buffer.vertex(from.getX(), from.getY(), 0).color(color).next();
                buffer.vertex(to.getX(), to.getY(), 0).color(color).next();
            }
        }
        
        tessellator.draw();
    }
    
    private void renderNodes(DrawContext context, int mouseX, int mouseY, float delta) {
        ClientPlayerEntity player = MinecraftClient.getInstance().player;
        ISkillTreeComponent tree = NinjaComponents.getSkillTree(player);
        
        for (SkillTreeNode node : SkillTreeRegistry.getAllNodes()) {
            boolean unlocked = tree.hasNode(node.getId());
            boolean canUnlock = canUnlockNode(node);
            
            int color = unlocked ? 0xFF00FF00 : (canUnlock ? 0xFFFFFF00 : 0xFF808080);
            
            // Рисуем круг
            context.fill(
                node.getX() - 20, node.getY() - 20,
                node.getX() + 20, node.getY() + 20,
                color
            );
            
            // Рисуем название
            context.drawText(textRenderer, node.getName(), 
                node.getX() - 30, node.getY() + 25, 0xFFFFFF, false);
        }
    }
    
    @Override
    public boolean mouseScrolled(double mouseX, double mouseY, double amount) {
        // Зум колёсиком
        float oldZoom = zoom;
        zoom += (float)(amount * 0.1f);
        zoom = Math.max(0.5f, Math.min(2.0f, zoom));
        
        // Корректируем камеру, чтобы зум был относительно курсора
        if (zoom != oldZoom) {
            float scale = zoom / oldZoom;
            cameraX = (float)(mouseX - (mouseX - cameraX) * scale);
            cameraY = (float)(mouseY - (mouseY - cameraY) * scale);
        }
        
        return true;
    }
    
    @Override
    public boolean mouseDragged(double mouseX, double mouseY, int button, double deltaX, double deltaY) {
        if (button == 0 && dragging) {
            cameraX -= deltaX / zoom;
            cameraY -= deltaY / zoom;
            return true;
        }
        return super.mouseDragged(mouseX, mouseY, button, deltaX, deltaY);
    }
    
    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        if (button == 0) {
            dragging = true;
            lastMouseX = mouseX;
            lastMouseY = mouseY;
            
            // Проверяем клик по узлу
            SkillTreeNode clickedNode = getNodeAtPosition(mouseX, mouseY);
            if (clickedNode != null) {
                tryUnlockNode(clickedNode);
                return true;
            }
        }
        return super.mouseClicked(mouseX, mouseY, button);
    }
    
    @Override
    public boolean mouseReleased(double mouseX, double mouseY, int button) {
        if (button == 0) {
            dragging = false;
        }
        return super.mouseReleased(mouseX, mouseY, button);
    }
    
    private boolean canUnlockNode(SkillTreeNode node) {
        ClientPlayerEntity player = MinecraftClient.getInstance().player;
        ISkillTreeComponent tree = NinjaComponents.getSkillTree(player);
        IStatsComponent stats = NinjaComponents.getStats(player);
        
        // Проверяем SP
        if (stats.getSp() < node.getCost()) return false;
        
        // Проверяем требования
        SkillTreeNode.Requirements reqs = node.getRequirements();
        if (reqs != null) {
            // Проверяем требуемые узлы
            if (reqs.getNodes() != null) {
                for (String reqNode : reqs.getNodes()) {
                    if (!tree.hasNode(reqNode)) return false;
                }
            }
            
            // Проверяем требуемые статы
            if (reqs.getStats() != null) {
                for (Map.Entry<String, Integer> entry : reqs.getStats().entrySet()) {
                    StatType statType = StatType.fromId(entry.getKey());
                    if (statType != null && stats.getStatLevel(statType) < entry.getValue()) {
                        return false;
                    }
                }
            }
        }
        
        return true;
    }
    
    private void tryUnlockNode(SkillTreeNode node) {
        if (!canUnlockNode(node)) return;
        
        ClientPlayerEntity player = MinecraftClient.getInstance().player;
        ISkillTreeComponent tree = NinjaComponents.getSkillTree(player);
        IStatsComponent stats = NinjaComponents.getStats(player);
        
        // Тратим SP
        stats.addSp(-node.getCost());
        
        // Разблокируем узел
        tree.unlockNode(node.getId());
        
        // Применяем эффекты
        applyNodeEffects(node);
    }
}
```

### Шаг C3: ISkillTreeComponent

**Файл:** `stat/component/ISkillTreeComponent.java`

```java
public interface ISkillTreeComponent extends ComponentV3 {
    Set<String> getUnlockedNodes();
    boolean hasNode(String nodeId);
    void unlockNode(String nodeId);
    int getSpentSp();
}
```

**Файл:** `stat/component/impl/SkillTreeComponentImpl.java`

```java
public class SkillTreeComponentImpl implements ISkillTreeComponent {
    private final Set<String> unlockedNodes = new HashSet<>();
    private int spentSp = 0;
    
    @Override
    public Set<String> getUnlockedNodes() {
        return Collections.unmodifiableSet(unlockedNodes);
    }
    
    @Override
    public boolean hasNode(String nodeId) {
        return unlockedNodes.contains(nodeId);
    }
    
    @Override
    public void unlockNode(String nodeId) {
        unlockedNodes.add(nodeId);
        markDirty();
    }
    
    @Override
    public void readFromNbt(NbtCompound nbt) {
        unlockedNodes.clear();
        if (nbt.contains("UnlockedNodes")) {
            NbtList list = nbt.getList("UnlockedNodes", NbtElement.STRING_TYPE);
            for (NbtElement elem : list) {
                unlockedNodes.add(elem.asString());
            }
        }
        spentSp = nbt.getInt("SpentSp");
    }
    
    @Override
    public void writeToNbt(NbtCompound nbt) {
        NbtList list = new NbtList();
        for (String node : unlockedNodes) {
            list.add(NbtString.of(node));
        }
        nbt.put("UnlockedNodes", list);
        nbt.putInt("SpentSp", spentSp);
    }
}
```

### Шаг C4: Тестирование

**Проверки:**
- ✅ Древо отображается
- ✅ Зум колёсиком работает
- ✅ Панорамирование мышью работает
- ✅ Узлы разблокируются за SP
- ✅ Требования проверяются
- ✅ Прогресс сохраняется

---

## 📋 СПРИНТ D: МИНИ-ИГРЫ (5-6 дней)

**Цель:** Реализовать 4 мини-игры для прокачки с множителями XP.

### Шаг D1: Базовый класс MiniGameScreen

**Файл:** `client/gui/screen/minigame/MiniGameScreen.java`

```java
public abstract class MiniGameScreen extends Screen {
    protected final StatType rewardStat;
    protected final int baseXpReward;
    protected final float xpMultiplier;
    
    protected MiniGameScreen(StatType rewardStat, int baseXpReward, float xpMultiplier) {
        super(Text.literal("Mini Game"));
        this.rewardStat = rewardStat;
        this.baseXpReward = baseXpReward;
        this.xpMultiplier = xpMultiplier;
    }
    
    protected void onSuccess() {
        ClientPlayerEntity player = MinecraftClient.getInstance().player;
        IStatsComponent stats = NinjaComponents.getStats(player);
        
        int xpReward = (int)(baseXpReward * xpMultiplier);
        stats.addXp(rewardStat, xpReward);
        
        // Показываем сообщение
        player.sendMessage(
            Text.literal("Success! +" + xpReward + " XP to " + rewardStat.getName())
                .formatted(Formatting.GREEN),
            false
        );
        
        close();
    }
    
    protected void onFailure() {
        ClientPlayerEntity player = MinecraftClient.getInstance().player;
        
        player.sendMessage(
            Text.literal("Failed! Try again.")
                .formatted(Formatting.RED),
            false
        );
        
        close();
    }
}
```

### Шаг D2: Аттюнмент стихии

**Файл:** `client/gui/screen/minigame/AttunementScreen.java`

```java
public class AttunementScreen extends MiniGameScreen {
    private final String elementId;
    private final float targetAngle;
    private final float speed;
    private final float tolerance;
    
    private float currentAngle = 0;
    private boolean running = true;
    
    public AttunementScreen(String elementId, float targetAngle, float speed, float tolerance) {
        super(StatType.FOCUS, 100, 2.0f); // 2x XP множитель
        this.elementId = elementId;
        this.targetAngle = targetAngle;
        this.speed = speed;
        this.tolerance = tolerance;
    }
    
    @Override
    public void tick() {
        super.tick();
        
        if (running) {
            currentAngle += speed;
            if (currentAngle >= 360) currentAngle -= 360;
        }
    }
    
    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        renderBackground(context);
        
        int centerX = width / 2;
        int centerY = height / 2;
        int radius = 100;
        
        // Рисуем круг
        context.drawTexture(
            new Identifier(ShinobiConstants.MOD_ID, "textures/gui/minigame/circle.png"),
            centerX - radius, centerY - radius,
            0, 0, radius * 2, radius * 2, radius * 2, radius * 2
        );
        
        // Рисуем целевую зону
        float targetRad = (float)Math.toRadians(targetAngle);
        int targetX = centerX + (int)(radius * Math.cos(targetRad));
        int targetY = centerY + (int)(radius * Math.sin(targetRad));
        context.fill(targetX - 10, targetY - 10, targetX + 10, targetY + 10, 0xFF00FF00);
        
        // Рисуем текущую позицию
        float currentRad = (float)Math.toRadians(currentAngle);
        int currentX = centerX + (int)(radius * Math.cos(currentRad));
        int currentY = centerY + (int)(radius * Math.sin(currentRad));
        context.fill(currentX - 5, currentY - 5, currentX + 5, currentY + 5, 0xFFFFFF00);
        
        // Текст
        context.drawText(textRenderer, "Press SPACE when marker is in green zone", 
            centerX - 100, 50, 0xFFFFFF, false);
        
        super.render(context, mouseX, mouseY, delta);
    }
    
    @Override
    public boolean keyPressed(int keyCode, int scanCode, int modifiers) {
        if (keyCode == GLFW.GLFW_KEY_SPACE && running) {
            running = false;
            
            // Проверяем попадание
            float diff = Math.abs(currentAngle - targetAngle);
            if (diff <= tolerance || diff >= 360 - tolerance) {
                onSuccess();
            } else {
                onFailure();
            }
            
            return true;
        }
        return super.keyPressed(keyCode, scanCode, modifiers);
    }
}
```

### Шаг D3: Контроль чакры

**Файл:** `client/gui/screen/minigame/ChakraControlScreen.java`

```java
public class ChakraControlScreen extends MiniGameScreen {
    private final float zoneRadius;
    private final int durationTicks;
    private final float zoneSpeed;
    
    private float zoneX, zoneY;
    private int ticksRemaining;
    private float cursorX, cursorY;
    
    public ChakraControlScreen(float zoneRadius, int durationTicks, float zoneSpeed) {
        super(StatType.CHAKRA_CONTROL, 150, 2.5f); // 2.5x XP множитель
        this.zoneRadius = zoneRadius;
        this.durationTicks = durationTicks;
        this.zoneSpeed = zoneSpeed;
        
        this.zoneX = width / 2.0f;
        this.zoneY = height / 2.0f;
        this.cursorX = width / 2.0f;
        this.cursorY = height / 2.0f;
        this.ticksRemaining = durationTicks;
    }
    
    @Override
    public void tick() {
        super.tick();
        
        ticksRemaining--;
        
        // Двигаем зону
        zoneX += zoneSpeed;
        if (zoneX < 100 || zoneX > width - 100) {
            zoneSpeed = -zoneSpeed;
        }
        
        // Проверяем, что курсор в зоне
        float dx = cursorX - zoneX;
        float dy = cursorY - zoneY;
        float dist = (float)Math.sqrt(dx * dx + dy * dy);
        
        if (dist > zoneRadius) {
            onFailure();
            return;
        }
        
        if (ticksRemaining <= 0) {
            onSuccess();
        }
    }
    
    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        renderBackground(context);
        
        // Рисуем зону
        context.fill(
            (int)(zoneX - zoneRadius), (int)(zoneY - zoneRadius),
            (int)(zoneX + zoneRadius), (int)(zoneY + zoneRadius),
            0x8000FF00
        );
        
        // Рисуем курсор
        context.fill(
            (int)(cursorX - 5), (int)(cursorY - 5),
            (int)(cursorX + 5), (int)(cursorY + 5),
            0xFFFF0000
        );
        
        // Текст
        context.drawText(textRenderer, "Keep cursor in green zone", 
            width / 2 - 80, 50, 0xFFFFFF, false);
        context.drawText(textRenderer, "Time: " + (ticksRemaining / 20) + "s", 
            width / 2 - 30, 70, 0xFFFFFF, false);
        
        super.render(context, mouseX, mouseY, delta);
    }
    
    @Override
    public void mouseMoved(double mouseX, double mouseY) {
        cursorX = (float)mouseX;
        cursorY = (float)mouseY;
    }
}
```

### Шаг D4: Тренировка меткости

**Файл:** `client/gui/screen/minigame/AccuracyScreen.java`

```java
public class AccuracyScreen extends MiniGameScreen {
    private final List<Target> targets = new ArrayList<>();
    private int hitsRequired;
    private int hitsCount = 0;
    
    public AccuracyScreen(int targetCount, int hitsRequired) {
        super(StatType.SHURIKEN, 120, 2.0f); // 2x XP множитель
        this.hitsRequired = hitsRequired;
        
        // Создаем мишени
        for (int i = 0; i < targetCount; i++) {
            targets.add(new Target(
                100 + random.nextInt(width - 200),
                100 + random.nextInt(height - 200)
            ));
        }
    }
    
    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        renderBackground(context);
        
        // Рисуем мишени
        for (Target target : targets) {
            context.fill(
                target.x - 20, target.y - 20,
                target.x + 20, target.y + 20,
                0xFFFF0000
            );
        }
        
        // Текст
        context.drawText(textRenderer, "Hits: " + hitsCount + "/" + hitsRequired, 
            20, 20, 0xFFFFFF, false);
        
        super.render(context, mouseX, mouseY, delta);
    }
    
    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        if (button == 0) {
            // Проверяем клик по мишени
            for (Target target : targets) {
                if (Math.abs(mouseX - target.x) < 20 && Math.abs(mouseY - target.y) < 20) {
                    hitsCount++;
                    targets.remove(target);
                    
                    if (hitsCount >= hitsRequired) {
                        onSuccess();
                    }
                    
                    return true;
                }
            }
        }
        return super.mouseClicked(mouseX, mouseY, button);
    }
    
    private static class Target {
        int x, y;
        Target(int x, int y) {
            this.x = x;
            this.y = y;
        }
    }
}
```

### Шаг D5: Спарринг

**Файл:** `client/gui/screen/minigame/SparringScreen.java`

```java
public class SparringScreen extends MiniGameScreen {
    private final List<String> combo = Arrays.asList("J", "K", "L", "J");
    private int currentStep = 0;
    private long startTime;
    private final int timeLimitMs = 5000;
    
    public SparringScreen() {
        super(StatType.TAIJUTSU, 200, 3.0f); // 3x XP множитель
        this.startTime = System.currentTimeMillis();
    }
    
    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        renderBackground(context);
        
        int centerX = width / 2;
        int y = 100;
        
        // Рисуем комбо
        for (int i = 0; i < combo.size(); i++) {
            String key = combo.get(i);
            int color = (i < currentStep) ? 0xFF00FF00 : 
                        (i == currentStep) ? 0xFFFFFF00 : 0xFF808080;
            
            context.fill(centerX - 150 + i * 80, y, 
                centerX - 110 + i * 80, y + 40, color);
            context.drawText(textRenderer, key, 
                centerX - 140 + i * 80, y + 15, 0x000000, false);
        }
        
        // Таймер
        long elapsed = System.currentTimeMillis() - startTime;
        long remaining = timeLimitMs - elapsed;
        context.drawText(textRenderer, "Time: " + (remaining / 1000) + "s", 
            centerX - 30, 50, 0xFFFFFF, false);
        
        super.render(context, mouseX, mouseY, delta);
    }
    
    @Override
    public void tick() {
        super.tick();
        
        long elapsed = System.currentTimeMillis() - startTime;
        if (elapsed > timeLimitMs) {
            onFailure();
        }
    }
    
    @Override
    public boolean keyPressed(int keyCode, int scanCode, int modifiers) {
        String key = getKeyForCode(keyCode);
        if (key != null && key.equals(combo.get(currentStep))) {
            currentStep++;
            
            if (currentStep >= combo.size()) {
                onSuccess();
            }
            
            return true;
        }
        return super.keyPressed(keyCode, scanCode, modifiers);
    }
    
    private String getKeyForCode(int keyCode) {
        if (keyCode == GLFW.GLFW_KEY_J) return "J";
        if (keyCode == GLFW.GLFW_KEY_K) return "K";
        if (keyCode == GLFW.GLFW_KEY_L) return "L";
        return null;
    }
}
```

### Шаг D6: Тестирование

**Команды:**
```
/shinobicore minigame attunement fire
/shinobicore minigame control
/shinobicore minigame accuracy
/shinobicore minigame sparring
```

**Проверки:**
- ✅ Все 4 мини-игры работают
- ✅ XP начисляется с множителями
- ✅ Успех/неудача обрабатываются
- ✅ Мини-игры доступны из вкладки Attunement

---

## 📋 СПРИНТ E: ВИЗУАЛ И ОПТИМИЗАЦИЯ (3-4 дня)

**Цель:** Добавить звуки, частицы, локализацию, оптимизировать рендеринг.

### Шаг E1: Звуки

**Файлы:**
- `assets/shinobicore/sounds/level_up.ogg`
- `assets/shinobicore/sounds/node_unlock.ogg`
- `assets/shinobicore/sounds/minigame_success.ogg`
- `assets/shinobicore/sounds/minigame_fail.ogg`

**Файл:** `assets/shinobicore/sounds.json`

```json
{
  "level_up": {
    "sounds": ["shinobicore:level_up"]
  },
  "node_unlock": {
    "sounds": ["shinobicore:node_unlock"]
  },
  "minigame_success": {
    "sounds": ["shinobicore:minigame_success"]
  },
  "minigame_fail": {
    "sounds": ["shinobicore:minigame_fail"]
  }
}
```

**Интеграция:**
```java
// В StatsComponentImpl.tryLevelUp()
public boolean tryLevelUp(StatType type) {
    // ...
    
    // Воспроизводим звук
    if (player instanceof ServerPlayerEntity serverPlayer) {
        serverPlayer.getWorld().playSound(
            null, serverPlayer.getBlockPos(),
            ShinobiSounds.LEVEL_UP,
            SoundCategory.PLAYERS,
            1.0f, 1.0f
        );
    }
    
    return true;
}
```

### Шаг E2: Частицы

**Файл:** `client/effect/LevelUpParticle.java`

```java
public class LevelUpParticle extends Particle {
    public LevelUpParticle(ClientWorld world, double x, double y, double z) {
        super(world, x, y, z);
        this.maxAge = 40;
        this.velocityY = 0.1;
    }
    
    @Override
    public void tick() {
        super.tick();
        this.velocityY -= 0.005; // Гравитация
    }
    
    @Override
    public ParticleTextureSheet getType() {
        return ParticleTextureSheet.PARTICLE_SHEET_OPAQUE;
    }
}
```

**Интеграция в клиенте:**
```java
// В LevelUpAnimation.start()
public static void start(String statId, int newLevel) {
    ClientPlayerEntity player = MinecraftClient.getInstance().player;
    
    // Спавним частицы
    for (int i = 0; i < 20; i++) {
        double offsetX = (random.nextDouble() - 0.5) * 2;
        double offsetY = random.nextDouble() * 2;
        double offsetZ = (random.nextDouble() - 0.5) * 2;
        
        MinecraftClient.getInstance().particleManager.addParticle(
            new LevelUpParticle(
                MinecraftClient.getInstance().world,
                player.getX() + offsetX,
                player.getY() + offsetY,
                player.getZ() + offsetZ
            )
        );
    }
    
    // Воспроизводим звук
    MinecraftClient.getInstance().player.playSound(
        ShinobiSounds.LEVEL_UP, 1.0f, 1.0f
    );
}
```

### Шаг E3: Локализация

**Файл:** `assets/shinobicore/lang/en_us.json`

```json
{
  "screen.shinobicore.progression.stats": "Stats",
  "screen.shinobicore.progression.tree": "Skill Tree",
  "screen.shinobicore.progression.attunement": "Attunement",
  "screen.shinobicore.progression.settings": "Settings",
  
  "stat.shinobicore.taijutsu": "Taijutsu",
  "stat.shinobicore.kenjutsu": "Kenjutsu",
  "stat.shinobicore.shuriken": "Shurikenjutsu",
  "stat.shinobicore.genjutsu": "Genjutsu",
  "stat.shinobicore.ninjutsu": "Ninjutsu",
  "stat.shinobicore.chakra_control": "Chakra Control",
  "stat.shinobicore.perception": "Perception",
  "stat.shinobicore.physical": "Physical",
  "stat.shinobicore.spiritual": "Spiritual",
  "stat.shinobicore.focus": "Focus",
  "stat.shinobicore.willpower": "Willpower",
  "stat.shinobicore.insight": "Insight",
  
  "key.shinobicore.progression": "Open Progression Screen",
  
  "message.shinobicore.level_up": "Level Up! %s is now level %d",
  "message.shinobicore.node_unlocked": "Unlocked: %s",
  "message.shinobicore.minigame_success": "Success! +%d XP",
  "message.shinobicore.minigame_fail": "Failed! Try again."
}
```

**Файл:** `assets/shinobicore/lang/ru_ru.json`

```json
{
  "screen.shinobicore.progression.stats": "Статы",
  "screen.shinobicore.progression.tree": "Древо навыков",
  "screen.shinobicore.progression.attunement": "Аттюнмент",
  "screen.shinobicore.progression.settings": "Настройки",
  
  "stat.shinobicore.taijutsu": "Тайдзюцу",
  "stat.shinobicore.kenjutsu": "Кэндзюцу",
  "stat.shinobicore.shuriken": "Сюрикэндзюцу",
  "stat.shinobicore.genjutsu": "Гэндзюцу",
  "stat.shinobicore.ninjutsu": "Ниндзюцу",
  "stat.shinobicore.chakra_control": "Контроль чакры",
  "stat.shinobicore.perception": "Восприятие",
  "stat.shinobicore.physical": "Физическая сила",
  "stat.shinobicore.spiritual": "Духовная сила",
  "stat.shinobicore.focus": "Концентрация",
  "stat.shinobicore.willpower": "Сила воли",
  "stat.shinobicore.insight": "Проницательность",
  
  "key.shinobicore.progression": "Открыть экран прогрессии",
  
  "message.shinobicore.level_up": "Повышение уровня! %s теперь уровня %d",
  "message.shinobicore.node_unlocked": "Разблокировано: %s",
  "message.shinobicore.minigame_success": "Успех! +%d XP",
  "message.shinobicore.minigame_fail": "Неудача! Попробуйте снова."
}
```

### Шаг E4: Оптимизация рендеринга дерева

**Файл:** `client/gui/screen/SkillTreeScreen.java`

**Оптимизации:**
```java
// Кэшируем текстуры
private final Map<String, NativeImageBackedTexture> textureCache = new HashMap<>();

// Не рисуем узлы вне экрана
private void renderNodes(DrawContext context, int mouseX, int mouseY, float delta) {
    float screenLeft = cameraX - width / (2 * zoom);
    float screenRight = cameraX + width / (2 * zoom);
    float screenTop = cameraY - height / (2 * zoom);
    float screenBottom = cameraY + height / (2 * zoom);
    
    for (SkillTreeNode node : SkillTreeRegistry.getAllNodes()) {
        // Проверяем, что узел в пределах экрана
        if (node.getX() < screenLeft - 50 || node.getX() > screenRight + 50 ||
            node.getY() < screenTop - 50 || node.getY() > screenBottom + 50) {
            continue; // Пропускаем
        }
        
        // Рисуем узел
        renderNode(context, node, mouseX, mouseY, delta);
    }
}

// Батчинг линий уже реализован через BufferBuilder
```

### Шаг E5: Тестирование производительности

**Проверки:**
- ✅ Звуки воспроизводятся
- ✅ Частицы не перегружают интерфейс (максимум 50 одновременно)
- ✅ Локализация работает (en_us, ru_ru)
- ✅ 60+ FPS на среднем ПК при открытом древе с 100+ узлами

---

## 🎯 ИТОГОВЫЙ ПЛАН ПО СПРИНТАМ

| Спринт | Длительность | Ключевые артефакты |
|--------|--------------|-------------------|
| **A** | 2-3 дня | 5 новых статов, хуки XP, админ-команды, пакет LEVEL_UP |
| **B** | 3-4 дня | ProgressionScreen, виджеты, экран K |
| **C** | 4-5 дней | SkillTreeScreen, зум, панорамирование, разблокировка |
| **D** | 5-6 дней | 4 мини-игры, множители XP |
| **E** | 3-4 дня | Звуки, частицы, локализация, оптимизация |

**Общая длительность:** 17-22 дня

---

## ✅ ГОТОВ К РЕАЛИЗАЦИИ

План полностью детализирован. Все файлы, методы, логика, JSON-структуры описаны. Осталось только писать синтаксис по этому плану.

**Готов начать со Спринта A?** Если да — генерирую `sprintA_01_extend_stats.ps1`.