package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.core.VisualDefinition;
import com.example.shinobicore.jutsu.enums.ElementType;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.particle.ParticleEffect;
import net.minecraft.particle.ParticleType;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.registry.Registries;
import net.minecraft.util.Identifier;
import org.joml.Vector3f;

/**
 * VISUAL PACK (1.1.2): единая палитра визуала техник.
 *
 * Одна точка правды для цветов и частиц:
 *   1. у каждой стихии — яркая палитра (ядро / подсветка / основные частицы);
 *   2. visual-блок JSON техники (color, particle, trail, scale, glow)
 *      переопределяет палитру — до этого он парсился, но почти не применялся;
 *   3. неизвестные строки частиц безопасно откатываются к стихийным.
 *
 * Все методы Fx v2 работают через Settings этого класса, поэтому достаточно
 * поправить палитру здесь (или visual в JSON), чтобы изменить вид ВСЕХ
 * техник стихии — без правок исполнительных систем.
 */
public final class FxPalette {

    private FxPalette() {}

    /** Полные визуальные настройки одного каста. */
    public static final class Settings {
        public final int color;            // основной цвет (ядро эффекта)
        public final int glowColor;        // цвет подсветки/вспышек
        public final ParticleEffect main;  // основная частица стихии
        public final ParticleEffect trail; // частица трейла
        public final ParticleEffect spark; // акцентная «искра»
        public final ParticleEffect dust;      // окрашенная пыль основного цвета
        public final ParticleEffect dustGlow;  // окрашенная пыль подсветки
        public final double scale;         // множитель размера (visual.scale)
        public final boolean glow;         // добавлять ли светящийся слой (visual.glow)

        Settings(int color, int glowColor, ParticleEffect main, ParticleEffect trail,
                 ParticleEffect spark, double scale, boolean glow) {
            this.color = color;
            this.glowColor = glowColor;
            this.main = main;
            this.trail = trail;
            this.spark = spark;
            this.scale = clampScale(scale);
            this.glow = glow;
            float size = dustSize();
            this.dust = new DustParticleEffect(toVec(color), size);
            this.dustGlow = new DustParticleEffect(toVec(glowColor), Math.max(0.5f, size * 0.8f));
        }

        public float dustSize() {
            return (float) Math.max(0.6, Math.min(2.4, 1.0 * scale));
        }

        public Vector3f colorVec() { return toVec(color); }
        public Vector3f glowVec()  { return toVec(glowColor); }
    }

    public static double clampScale(double s) {
        if (Double.isNaN(s) || s <= 0) return 1.0;
        return Math.max(0.4, Math.min(3.0, s));
    }

    /** Стихийная палитра + переопределения из visual-блока техники. */
    public static Settings of(ElementType el, VisualDefinition vis) {
        if (el == null) el = ElementType.NONE;
        int core;
        int glowC;
        ParticleEffect main;
        ParticleEffect trail;
        ParticleEffect spark;
        switch (el) {
            case FIRE -> {
                core = 0xFF7A1A; glowC = 0xFFD24A;
                main = ParticleTypes.FLAME; trail = ParticleTypes.FLAME; spark = ParticleTypes.LAVA;
            }
            case WATER -> {
                core = 0x3FA9FF; glowC = 0xA8E4FF;
                main = ParticleTypes.SPLASH; trail = ParticleTypes.SPLASH; spark = ParticleTypes.BUBBLE;
            }
            case WIND -> {
                core = 0xB8FFD8; glowC = 0xFFFFFF;
                main = ParticleTypes.CLOUD; trail = ParticleTypes.CLOUD; spark = ParticleTypes.CRIT;
            }
            case EARTH -> {
                core = 0xC98F4E; glowC = 0xE8C088;
                main = ParticleTypes.LARGE_SMOKE; trail = ParticleTypes.LARGE_SMOKE; spark = ParticleTypes.CRIT;
            }
            case LIGHTNING -> {
                core = 0xFFF25E; glowC = 0xFFFFFF;
                main = ParticleTypes.ELECTRIC_SPARK; trail = ParticleTypes.ELECTRIC_SPARK; spark = ParticleTypes.END_ROD;
            }
            case YIN -> {
                core = 0xC56BFF; glowC = 0xE9B8FF;
                main = ParticleTypes.REVERSE_PORTAL; trail = ParticleTypes.REVERSE_PORTAL; spark = ParticleTypes.ENCHANT;
            }
            case YANG -> {
                core = 0xFFF6C8; glowC = 0xFFFFFF;
                main = ParticleTypes.HAPPY_VILLAGER; trail = ParticleTypes.END_ROD; spark = ParticleTypes.HAPPY_VILLAGER;
            }
            default -> {
                // NONE = чистая чакра: сине-голубое пламя духа
                core = 0x5FA8FF; glowC = 0xBFE0FF;
                main = ParticleTypes.SOUL_FIRE_FLAME; trail = ParticleTypes.END_ROD; spark = ParticleTypes.ENCHANT;
            }
        }

        double scale = 1.0;
        boolean glowOn = false;
        if (vis != null) {
            core = parseHex(vis.getColor(), core);
            glowC = brighten(core, 0.55f);
            scale = vis.getScale();
            glowOn = vis.isGlow();
            ParticleEffect p = resolve(vis.getParticle(), core);
            if (p != null) main = p;
            ParticleEffect t = resolve(vis.getTrailParticle(), core);
            if (t != null) trail = t;
        }
        return new Settings(core, glowC, main, trail, spark, scale, glowOn);
    }

    public static Settings of(JutsuDefinition def) {
        if (def == null) return of(ElementType.NONE, null);
        return of(def.getElement(), def.getVisual());
    }

    /** "#RRGGBB" -> int; при любой ошибке — fallback. */
    public static int parseHex(String s, int fallback) {
        if (s == null) return fallback;
        String t = s.trim();
        if (t.startsWith("#")) t = t.substring(1);
        if (t.length() != 6) return fallback;
        try {
            return (int) Long.parseLong(t, 16) & 0xFFFFFF;
        } catch (NumberFormatException ex) {
            return fallback;
        }
    }

    public static Vector3f toVec(int rgb) {
        return new Vector3f(((rgb >> 16) & 0xFF) / 255f, ((rgb >> 8) & 0xFF) / 255f, (rgb & 0xFF) / 255f);
    }

    /** Осветление цвета к белому (f=0..1). */
    public static int brighten(int rgb, float f) {
        if (f < 0) f = 0;
        if (f > 1) f = 1;
        int r = (rgb >> 16) & 0xFF, g = (rgb >> 8) & 0xFF, b = rgb & 0xFF;
        r = (int) (r + (255 - r) * f);
        g = (int) (g + (255 - g) * f);
        b = (int) (b + (255 - b) * f);
        return (r << 16) | (g << 8) | b;
    }

    /**
     * Строка частицы из JSON -> ParticleEffect.
     * Поддерживает короткие имена (как в существующих данных и voxel-моделях)
     * и полные идентификаторы "minecraft:xxx" / "modid:xxx" (только простые
     * частицы без параметров — DustParticleEffect с цветом строится отдельно).
     * Неизвестная строка -> null (вызывающий оставляет стихийный дефолт).
     */
    public static ParticleEffect resolve(String preset, int colorRgb) {
        if (preset == null) return null;
        String p = preset.trim();
        if (p.isEmpty()) return null;
        switch (p) {
            case "flame":            return ParticleTypes.FLAME;
            case "small_flame":      return ParticleTypes.SMALL_FLAME;
            case "soul_fire":
            case "soul_fire_flame":  return ParticleTypes.SOUL_FIRE_FLAME;
            case "smoke":            return ParticleTypes.SMOKE;
            case "large_smoke":      return ParticleTypes.LARGE_SMOKE;
            case "cloud":            return ParticleTypes.CLOUD;
            case "splash":           return ParticleTypes.SPLASH;
            case "falling_water":    return ParticleTypes.FALLING_WATER;
            case "bubble":           return ParticleTypes.BUBBLE;
            case "crit":             return ParticleTypes.CRIT;
            case "end_rod":          return ParticleTypes.END_ROD;
            case "electric_spark":   return ParticleTypes.ELECTRIC_SPARK;
            case "enchant":          return ParticleTypes.ENCHANT;
            case "reverse_portal":   return ParticleTypes.REVERSE_PORTAL;
            case "portal":           return ParticleTypes.PORTAL;
            case "happy_villager":   return ParticleTypes.HAPPY_VILLAGER;
            case "witch":            return ParticleTypes.WITCH;
            case "glow":             return ParticleTypes.GLOW;
            case "snowflake":        return ParticleTypes.SNOWFLAKE;
            case "lava":             return ParticleTypes.LAVA;
            case "dust":             return new DustParticleEffect(toVec(colorRgb), 1.0f);
            default: break;
        }
        if (p.contains(":")) {
            Identifier id = Identifier.tryParse(p);
            if (id != null) {
                ParticleType<?> type = Registries.PARTICLE_TYPE.getOrEmpty(id).orElse(null);
                // Принимаем только ПРОСТЫЕ (беспараметрные) типы частиц: у них тот же
                // рантайм-класс, что у ParticleTypes.FLAME (в Yarn 1.20.1 —
                // DefaultParticleType). Сравнение по getClass() вместо импорта имени
                // класса: в Mojang-маппингах он называется иначе, а при апгрейде MC
                // имя способно снова поменяться. Параметризованные типы (dust и т.п.)
                // сюда не попадут — их класс другой.
                if (type != null && type.getClass() == ParticleTypes.FLAME.getClass()
                        && type instanceof ParticleEffect) {
                    return (ParticleEffect) type;
                }
            }
        }
        return null;
    }
}