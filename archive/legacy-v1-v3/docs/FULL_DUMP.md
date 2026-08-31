# SHINOBI CORE FULL DUMP 2026-08-13 19:47

# ================= src\main\java\com\example\shinobicore\clan\ClanDefinition.java =================
package com.example.shinobicore.clan;

import com.example.shinobicore.stat.ElementType;
import java.util.Map;

public record ClanDefinition(
    String id,
    String name,
    ElementType affinity,
    int extraAffinityCount,
    Map<String, Integer> statBonuses,
    Map<String, Integer> natureBonuses,
    Map<String, Float> costMultiplier,
    float fatigueMultiplier,
    float reserveBonus,
    String dojutsuHook
) {
    public boolean hasDojutsu() {
        return dojutsuHook != null && !dojutsuHook.isEmpty();
    }
}

# ================= src\main\java\com\example\shinobicore\clan\ClanRegistry.java =================
package com.example.shinobicore.clan;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.ElementType;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

public class ClanRegistry {
    private static final Map<String, ClanDefinition> CLANS = new HashMap<>();
    private static final Random RANDOM = new Random();

    public static void reload(ResourceManager manager) {
        CLANS.clear();

        Map<Identifier, List<Resource>> resources = manager.findAllResources("clans",
            id -> id.getNamespace().equals(ShinobiCore.MOD_ID) && id.getPath().endsWith(".json")
        );

        for (Map.Entry<Identifier, List<Resource>> entry : resources.entrySet()) {
            Identifier id = entry.getKey();
            List<Resource> resourceList = entry.getValue();

            if (resourceList.isEmpty()) continue;
            Resource resource = resourceList.get(0);

            try (InputStream stream = resource.getInputStream()) {
                JsonObject json = JsonParser.parseReader(new InputStreamReader(stream)).getAsJsonObject();

                if (!json.has("id")) {
                    String path = id.getPath();
                    String name = path.substring("clans/".length(), path.length() - ".json".length());
                    json.addProperty("id", name);
                }

                ClanDefinition def = parse(json);
                if (def != null) {
                    CLANS.put(def.id(), def);
                    ShinobiCore.LOGGER.info("Loaded clan: {}", def.id());
                }
            } catch (Exception e) {
                ShinobiCore.LOGGER.error("Failed to load clan from {}: {}", id, e.getMessage());
            }
        }

        ShinobiCore.LOGGER.info("Loaded {} clans", CLANS.size());
    }

    private static ClanDefinition parse(JsonObject json) {
        String id = json.get("id").getAsString();
        String name = json.has("name") ? json.get("name").getAsString() : id;

        ElementType affinity = null;
        if (json.has("affinity") && !json.get("affinity").isJsonNull()) {
            String affId = json.get("affinity").getAsString();
            for (ElementType e : ElementType.values()) {
                if (e.getId().equals(affId)) {
                    affinity = e;
                    break;
                }
            }
        }

        int extraAffinityCount = json.has("extraAffinityCount") ? json.get("extraAffinityCount").getAsInt() : 0;

        Map<String, Integer> statBonuses = new HashMap<>();
        if (json.has("statBonuses")) {
            JsonObject obj = json.getAsJsonObject("statBonuses");
            for (String key : obj.keySet()) {
                statBonuses.put(key, obj.get(key).getAsInt());
            }
        }

        Map<String, Integer> natureBonuses = new HashMap<>();
        if (json.has("natureBonuses")) {
            JsonObject obj = json.getAsJsonObject("natureBonuses");
            for (String key : obj.keySet()) {
                natureBonuses.put(key, obj.get(key).getAsInt());
            }
        }

        Map<String, Float> costMultiplier = new HashMap<>();
        if (json.has("costMultiplier")) {
            JsonObject obj = json.getAsJsonObject("costMultiplier");
            for (String key : obj.keySet()) {
                costMultiplier.put(key, obj.get(key).getAsFloat());
            }
        }

        float fatigueMultiplier = json.has("fatigueMultiplier") ? json.get("fatigueMultiplier").getAsFloat() : 1.0f;
        float reserveBonus = json.has("reserveBonus") ? json.get("reserveBonus").getAsFloat() : 0f;
        String dojutsuHook = json.has("dojutsuHook") && !json.get("dojutsuHook").isJsonNull()
            ? json.get("dojutsuHook").getAsString() : null;

        return new ClanDefinition(id, name, affinity, extraAffinityCount,
            statBonuses, natureBonuses, costMultiplier, fatigueMultiplier, reserveBonus, dojutsuHook);
    }

    public static ClanDefinition get(String id) {
        return CLANS.get(id);
    }

    public static Collection<ClanDefinition> getAll() {
        return CLANS.values();
    }

    public static ClanDefinition getRandom() {
        if (CLANS.isEmpty()) return null;
        List<ClanDefinition> list = new java.util.ArrayList<>(CLANS.values());
        return list.get(RANDOM.nextInt(list.size()));
    }
}

# ================= src\main\java\com\example\shinobicore\client\attunement\AttunementScreen.java =================
package com.example.shinobicore.client.attunement;

import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.ElementType;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;
import net.minecraft.client.MinecraftClient;
import net.minecraft.sound.SoundEvents;

public class AttunementScreen extends Screen {

    private final ElementType element;
    private final int spCost;

    private float needleAngle = 0f;
    private float needleSpeed;
    private float zoneCenter;
    private float zoneWidth;
    private int attemptsLeft = 3;
    private int phase = 0;
    private int resultTimer = 0;

    public AttunementScreen(ElementType element, int spCost) {
        super(Text.literal("Attunement"));
        this.element = element;
        this.spCost = spCost;

        int control = ClientNinjaState.statLevels.getOrDefault("control", 0);
        this.zoneWidth = Math.max(15f, 40f - control * 0.25f);
        this.needleSpeed = 4f + control * 0.04f;
        this.zoneCenter = 30f + (float)(Math.random() * 300.0);
    }

    @Override
    public void render(DrawContext ctx, int mx, int my, float delta) {
        renderBackground(ctx);
        super.render(ctx, mx, my, delta);

        int cx = width / 2;
        int cy = height / 2;
        int radius = 60;
        int color = getElementColor(element);

        drawRing(ctx, cx, cy, radius, color);
        drawZone(ctx, cx, cy, radius, zoneCenter, zoneWidth, 0xFF44FF44);
        drawNeedle(ctx, cx, cy, radius, needleAngle);

        for (int i = 0; i < 3; i++) {
            int dotColor = i < attemptsLeft ? 0xFFFFFFFF : 0xFF555555;
            ctx.fill(cx - 30 + i * 25, cy + radius + 20,
                     cx - 20 + i * 25, cy + radius + 30, dotColor);
        }

        drawCentered(ctx, "Attune to " + element.getId(), cx, cy - radius - 30, color);
        drawCentered(ctx, "LMB when needle is in green zone", cx, cy - radius - 18, 0xFFAAAAAA);
        drawCentered(ctx, "SP cost: " + spCost, cx, cy + radius + 36, 0xFF888888);

        if (phase == 1) {
            drawCentered(ctx, "SUCCESS!", cx, cy, 0xFF44FF44);
        } else if (phase == 2) {
            drawCentered(ctx, "FAILED", cx, cy, 0xFFFF4444);
        }
    }

    @Override
    public void tick() {
        if (phase == 0) {
            needleAngle = (needleAngle + needleSpeed) % 360f;
        } else {
            resultTimer++;
            if (resultTimer > 40) close();
        }
    }

    @Override
    public boolean mouseClicked(double mx, double my, int button) {
        if (phase != 0 || button != 0) return true;

        float diff = angleDiff(needleAngle, zoneCenter);
        if (Math.abs(diff) <= zoneWidth / 2f) {
            phase = 1;
            playResultSound(true);
            sendResult(true);
        } else {
            attemptsLeft--;
            if (attemptsLeft <= 0) {
                phase = 2;
                playResultSound(false);
                sendResult(false);
            } else {
                playMissSound();
                zoneCenter = 30f + (float)(Math.random() * 300.0);
            }
        }
        return true;
    }

    private void sendResult(boolean success) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString(element.getId());
        buf.writeBoolean(success);
        ClientPlayNetworking.send(ModPackets.ATTUNEMENT_ID, buf);
    }

    private void playResultSound(boolean success) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        if (success) {
            client.player.playSound(SoundEvents.ENTITY_EXPERIENCE_ORB_PICKUP, 1.0f, 1.2f);
            client.player.playSound(SoundEvents.BLOCK_BEACON_ACTIVATE, 0.8f, 1.0f);
        } else {
            client.player.playSound(SoundEvents.ENTITY_VILLAGER_NO, 1.0f, 0.8f);
        }
    }

    private void playMissSound() {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        client.player.playSound(SoundEvents.ENTITY_VILLAGER_NO, 0.4f, 1.5f);
    }

    private float angleDiff(float a, float b) {
        float d = a - b;
        while (d > 180f) d -= 360f;
        while (d < -180f) d += 360f;
        return d;
    }

    private void drawRing(DrawContext ctx, int cx, int cy, int r, int color) {
        int seg = 36;
        for (int i = 0; i < seg; i++) {
            float a1 = (float)(i * 2 * Math.PI / seg);
            float a2 = (float)((i + 1) * 2 * Math.PI / seg);
            int x1 = cx + (int)(Math.cos(a1) * r);
            int y1 = cy + (int)(Math.sin(a1) * r);
            int x2 = cx + (int)(Math.cos(a2) * r);
            int y2 = cy + (int)(Math.sin(a2) * r);
            drawLine(ctx, x1, y1, x2, y2, color);
        }
    }

    private void drawZone(DrawContext ctx, int cx, int cy, int r,
                          float center, float w, int color) {
        float start = (float)Math.toRadians(center - w / 2f);
        float end   = (float)Math.toRadians(center + w / 2f);
        int seg = 12;
        for (int i = 0; i < seg; i++) {
            float a1 = start + (end - start) * i / seg;
            float a2 = start + (end - start) * (i + 1) / seg;
            int x1 = cx + (int)(Math.cos(a1) * r);
            int y1 = cy + (int)(Math.sin(a1) * r);
            int x2 = cx + (int)(Math.cos(a2) * r);
            int y2 = cy + (int)(Math.sin(a2) * r);
            drawLine(ctx, x1, y1, x2, y2, color);
        }
    }

    private void drawNeedle(DrawContext ctx, int cx, int cy, int r, float angle) {
        float rad = (float)Math.toRadians(angle);
        int x2 = cx + (int)(Math.cos(rad) * r);
        int y2 = cy + (int)(Math.sin(rad) * r);
        drawLine(ctx, cx, cy, x2, y2, 0xFFFFFFFF);
    }

    private void drawLine(DrawContext ctx, int x1, int y1, int x2, int y2, int color) {
        int steps = Math.max(Math.abs(x2 - x1), Math.abs(y2 - y1));
        if (steps == 0) { ctx.fill(x1, y1, x1 + 1, y1 + 1, color); return; }
        for (int i = 0; i <= steps; i++) {
            int x = x1 + (x2 - x1) * i / steps;
            int y = y1 + (y2 - y1) * i / steps;
            ctx.fill(x, y, x + 1, y + 1, color);
        }
    }

    private void drawCentered(DrawContext ctx, String text, int cx, int y, int color) {
        int w = textRenderer.getWidth(text);
        ctx.drawText(textRenderer, text, cx - w / 2, y, color, false);
    }

    private int getElementColor(ElementType e) {
        return switch (e) {
            case FIRE      -> 0xFFFF4400;
            case WATER     -> 0xFF2266FF;
            case WIND      -> 0xFF88DDAA;
            case LIGHTNING -> 0xFFFFFF44;
            case EARTH     -> 0xFF996633;
        };
    }
}

# ================= src\main\java\com\example\shinobicore\client\CastingClientState.java =================
package com.example.shinobicore.client;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
public class CastingClientState {
    public static class Cast {
        public final long start; public final String nature;
        public Cast(long start, String nature) { this.start = start; this.nature = nature; }
    }
    private static final Map<UUID, Cast> CASTS = new HashMap<>();
    public static void startCast(UUID id, String nature) { CASTS.put(id, new Cast(System.currentTimeMillis(), nature)); }
    public static Cast get(AbstractClientPlayerEntity p) {
        Cast c = CASTS.get(p.getUuid());
        if (c == null) return null;
        if (System.currentTimeMillis() - c.start > 500) { CASTS.remove(p.getUuid()); return null; }
        return c;
    }
    public static boolean isCasting(AbstractClientPlayerEntity p) { return get(p) != null; }
    public static int color(String nature) {
        return switch (nature) {
            case "fire" -> 0xFFFF6622;
            case "water" -> 0xFF4488FF;
            case "wind" -> 0xFF88DDAA;
            case "lightning" -> 0xFFFFEE44;
            case "earth" -> 0xFFBB8844;
            default -> 0xFF88AAFF;
        };
    }
}

# ================= src\main\java\com\example\shinobicore\client\CastingClientVisual.java =================
package com.example.shinobicore.client;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.particle.DustParticleEffect;
import net.minecraft.util.math.Vec3d;
import org.joml.Vector3f;
public class CastingClientVisual {
    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(CastingClientVisual::tick);
    }
    private static void tick(MinecraftClient client) {
        if (client.world == null) return;
        for (AbstractClientPlayerEntity p : client.world.getPlayers()) {
            CastingClientState.Cast c = CastingClientState.get(p);
            if (c == null) continue;
            int color = CastingClientState.color(c.nature);
            float r = ((color >> 16) & 0xFF) / 255f;
            float g = ((color >> 8) & 0xFF) / 255f;
            float b = (color & 0xFF) / 255f;
            DustParticleEffect effect = new DustParticleEffect(new Vector3f(r, g, b), 1.0f);
            Vec3d hand = handPos(p);
            for (int i = 0; i < 3; i++) {
                client.world.addParticle(effect,
                    hand.x + (Math.random() - 0.5) * 0.3,
                    hand.y + (Math.random() - 0.5) * 0.3,
                    hand.z + (Math.random() - 0.5) * 0.3,
                    0, 0.03, 0);
            }
        }
    }
    private static Vec3d handPos(AbstractClientPlayerEntity p) {
        Vec3d look = p.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        return p.getEyePos().add(look.multiply(0.6)).add(right.multiply(0.3)).add(0, -0.35, 0);
    }
}

# ================= src\main\java\com\example\shinobicore\client\ChakraHudRenderer.java =================
package com.example.shinobicore.client;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import com.example.shinobicore.client.combat.TaijutsuKickHandler;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.parkour.actions.ChargedJumpAction;
import com.example.shinobicore.combat.TaijutsuStyle;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.entity.LivingEntity;
import net.minecraft.text.Text;
import net.minecraft.util.math.ColorHelper;
import com.example.shinobicore.client.RasenganClientState;
import java.util.ArrayList;
import java.util.List;

public class ChakraHudRenderer {

    public static float currentChakra = 100f;
    public static float maxChakra = 100f;
    public static float fatigue = 0f;
    public static boolean exhausted = false;

    private static final int HEIGHT = 7;
    private static final int SPACING = 1;
    private static final float TEXT_SCALE = 0.65f;

    private static final int HP_LIGHT = 0xFFDD3333;   private static final int HP_DARK = 0xFF991111;
    private static final int CHAKRA_LIGHT = 0xFF4499FF; private static final int CHAKRA_DARK = 0xFF1155CC;
    private static final int FATIGUE_LIGHT = 0xFFEEBB33; private static final int FATIGUE_DARK = 0xFFBB8811;
    private static final int FOOD_LIGHT = 0xFFC77B3A;  private static final int FOOD_DARK = 0xFF8A4E1E;
    private static final int AIR_LIGHT = 0xFF66D9E8;   private static final int AIR_DARK = 0xFF2A97B0;
    private static final int ARMOR_LIGHT = 0xFFB0B0B0; private static final int ARMOR_DARK = 0xFF707070;
    private static final int BORDER = 0xFF000000;
    private static final int BG = 0xCC222222;

    private record BarSpec(float ratio, int light, int dark, boolean pulse, String label, String value) {}

    public static void render(DrawContext context, float tickDelta) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        int sw = client.getWindow().getScaledWidth();
        int sh = client.getWindow().getScaledHeight();

        // === ВЕРХ-ЛЕВО: чакра и прочее ===
        List<BarSpec> bars = new ArrayList<>();
        float chakraRatio = maxChakra > 0 ? currentChakra / maxChakra : 0;
        bars.add(new BarSpec(chakraRatio, CHAKRA_LIGHT, CHAKRA_DARK, chakraRatio < 0.25f && !exhausted,
            "CH", (int) currentChakra + "/" + (int) maxChakra));
        if (fatigue > 0)
            bars.add(new BarSpec(fatigue / 100f, FATIGUE_LIGHT, FATIGUE_DARK, exhausted, "FT", (int) fatigue + "%"));
        if (client.player.getAir() < client.player.getMaxAir())
            bars.add(new BarSpec(client.player.getAir() / (float) client.player.getMaxAir(), AIR_LIGHT, AIR_DARK, false,
                "O2", (int) (client.player.getAir() / 20f) + "s"));
        int armor = client.player.getArmor();
        if (armor > 0)
            bars.add(new BarSpec(armor / 20f, ARMOR_LIGHT, ARMOR_DARK, false, "AR", armor + "/20"));

        int y = 10;
        for (BarSpec b : bars) {
            drawBar(context, client, 10, y, 120, HEIGHT, b.ratio(), b.light(), b.dark(), b.pulse(), b.label(), b.value());
            y += HEIGHT + SPACING;
        }

        if (ClientNinjaState.chakraMode) {
            int alpha = (int) (150 + 105 * Math.sin(System.currentTimeMillis() / 200.0));
            context.drawTextWithShadow(client.textRenderer, Text.literal("CHAKRA MODE"), 10, y,
                ColorHelper.Argb.getArgb(alpha, 255, 136, 0));
            y += 10;
        }
        if (exhausted) {
            context.drawTextWithShadow(client.textRenderer, Text.literal("EXHAUSTED"), 10, y, 0xFF3333);
            y += 10;
        }
        if (ClientNinjaState.unlockedNodes.contains("sen_glow")) {
            context.drawTextWithShadow(client.textRenderer,
                    Text.literal(ClientNinjaState.sensoryEnabled ? "SENSORY ON" : "SENSORY OFF"),
                    10, y, ClientNinjaState.sensoryEnabled ? 0xFF66DDFF : 0xFF666666);
            y += 10;
        }
        if (ClientNinjaState.dangerSense) {
            int alpha = (int) (150 + 105 * Math.sin(System.currentTimeMillis() / 150.0));
            context.drawTextWithShadow(client.textRenderer, Text.literal("!! DANGER !!"), 10, y,
                    ColorHelper.Argb.getArgb(alpha, 255, 60, 60));
            y += 10;
        }
        // === РАСЕНГАН: индикатор зарядки ===
        if (RasenganClientState.charging) {
            float progress = RasenganClientState.chargeProgress;
            int barW = 60, barH = 4;
            context.fill(10, y + 8, 10 + barW, y + 8 + barH, 0xCC222222);
            context.fill(10, y + 8, 10 + (int)(barW * progress), y + 8 + barH, 0xFF44AAFF);
            context.drawTextWithShadow(client.textRenderer, Text.literal("RASENGAN " + (int)(progress * 100) + "%"),
                    10, y + 14, 0xFF44AAFF);
            y += 24;
        }
        if (RasenganClientState.ready) {
            int alpha = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 100.0));
            context.drawTextWithShadow(client.textRenderer, Text.literal("✦ RASENGAN READY — LMB!"),
                    10, y + 8, ColorHelper.Argb.getArgb(alpha, 68, 170, 255));
            y += 18;
        }
        y += 3;

        // === ЛОАУТЫ ===
        y = drawLoadoutLine(context, client, 0, "A", 10, y);
        y = drawLoadoutLine(context, client, 1, "B", 10, y);

        // === КОМБО-СЧЁТЧИК ===
        int comboStep = TaijutsuClientHandler.getComboStep();
        ShinobiCore.LOGGER.debug("[HUD] Combo step: {}", comboStep);
        if (comboStep > 0) {
            String comboText = "COMBO x" + comboStep;
            context.drawTextWithShadow(client.textRenderer, Text.literal(comboText), 10, y + 10, 0xFFFF8800);
            y += 12;
        }

        // === СТИЛЬ ТАЙ-ДЗЮЦУ ===
        TaijutsuStyle currentStyle = TaijutsuClientHandler.getCurrentStyle();
        String styleName = currentStyle == TaijutsuStyle.STRONG_FIST ? "[Strong Fist]" : "[Standard]";
        int styleColor = currentStyle == TaijutsuStyle.STRONG_FIST ? 0xFF44FF44 : 0xFFAAAAAA;
        ShinobiCore.LOGGER.debug("[HUD] Style: {}", currentStyle.getId());
        context.drawTextWithShadow(client.textRenderer, Text.literal(styleName), 10, y + 10, styleColor);
        y += 12;
        if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            String st = ClientNinjaState.kenjutsuStance;
            int stColor = st.equals("seigan") ? 0xFF66AAFF : st.equals("iai") ? 0xFFFFAA00 : 0xFFFF5555;
            context.drawTextWithShadow(client.textRenderer, Text.literal("[" + st.toUpperCase() + "]"), 10, y + 10, stColor);
            y += 12;
        }

        // === КУЛДАУН УДАРА НОГОЙ ===
        boolean kickOnCooldown = TaijutsuKickHandler.isOnCooldown();
        long kickRemaining = TaijutsuKickHandler.getCooldownRemainingMs();
        ShinobiCore.LOGGER.debug("[HUD] Kick cooldown: {}ms, onCooldown={}", kickRemaining, kickOnCooldown);
        if (kickOnCooldown) {
            float cd = TaijutsuKickHandler.getCooldownRatio();
            int cdW = 60, cdH = 4;
            context.drawTextWithShadow(client.textRenderer, Text.literal("KICK [V]"), 10, y + 8, 0xFF44AAFF);
            context.fill(10, y + 18, 10 + cdW, y + 18 + cdH, 0xCC222222);
            context.fill(10, y + 18, 10 + (int) (cdW * (1 - cd)), y + 18 + cdH, 0xFF44AAFF);
            y += 26;
        }

        // === НАД ХОТБАРОМ: HP слева, ГОЛОД справа ===
        int hbLeft = sw / 2 - 91;
        int hbRight = sw / 2 + 91;
        int barW = 91;
        int yHot = sh - 39;

        float hp = client.player.getHealth();
        float maxHp = client.player.getMaxHealth();
        drawBar(context, client, hbLeft, yHot, barW, HEIGHT, hp / maxHp, HP_LIGHT, HP_DARK, false,
            "HP", (int) hp + "/" + (int) maxHp);

        float food = client.player.getHungerManager().getFoodLevel();
        drawBar(context, client, hbRight - barW, yHot, barW, HEIGHT, food / 20f, FOOD_LIGHT, FOOD_DARK, food <= 6,
            "FD", (int) food + "/20");

        // === CHARGED JUMP BAR ===
        ChargedJumpAction chargedJump = ParkourManager.getChargedJumpAction();
        if (chargedJump != null && chargedJump.isCharging()) {
            float charge = chargedJump.getChargeRatio();
            int barWidth = 100, barHeight = 6;
            int barX = (sw - barWidth) / 2;
            int barY = sh - 80;

            context.fill(barX - 1, barY - 1, barX + barWidth + 1, barY + barHeight + 1, 0xCC000000);
            int color = charge >= 0.8f ? 0xFF5555 : 0xFFFF00;
            context.fill(barX, barY, barX + (int) (barWidth * charge), barY + barHeight, color);
            context.drawCenteredTextWithShadow(client.textRenderer,
                String.format("Charge: %.0f%%", charge * 100), barX + barWidth / 2, barY - 10, 0xFFFFFF);
        }
    }

    private static void drawBar(DrawContext context, MinecraftClient client, int x, int y, int width, int height,
                                float ratio, int lightColor, int darkColor, boolean pulse, String label, String value) {
        ratio = Math.max(0, Math.min(1, ratio));
        int filled = (int) (width * ratio);

        int alpha = 255;
        if (pulse) alpha = (int) (150 + 105 * Math.sin(System.currentTimeMillis() / 150.0));

        context.fill(x - 1, y - 1, x + width + 1, y + height + 1, BORDER);
        context.fill(x, y, x + width, y + height, BG);

        int lr = (lightColor >> 16) & 0xFF, lg = (lightColor >> 8) & 0xFF, lb = lightColor & 0xFF;
        int dr = (darkColor >> 16) & 0xFF, dg = (darkColor >> 8) & 0xFF, db = darkColor & 0xFF;
        context.fillGradient(x, y, x + filled, y + height,
            ColorHelper.Argb.getArgb(alpha, lr, lg, lb),
            ColorHelper.Argb.getArgb(alpha, dr, dg, db));
        context.fill(x, y, x + filled, y + 1, ColorHelper.Argb.getArgb(alpha / 3, 255, 255, 255));

        drawScaledText(context, client, label, x + 2, y + 1, 0xFFFFFFFF, TEXT_SCALE);
        int tw = (int) (client.textRenderer.getWidth(value) * TEXT_SCALE);
        drawScaledText(context, client, value, x + width - 2 - tw, y + 1, 0xFFFFFFFF, TEXT_SCALE);
    }

    private static void drawScaledText(DrawContext context, MinecraftClient client, String text,
                                       float x, float y, int color, float scale) {
        context.getMatrices().push();
        context.getMatrices().translate(x, y, 0);
        context.getMatrices().scale(scale, scale, 1f);
        context.drawTextWithShadow(client.textRenderer, text, 0, 0, color);
        context.getMatrices().pop();
    }

    private static int drawLoadoutLine(DrawContext context, MinecraftClient client, int set, String label, int x, int lineY) {
        String current = ClientNinjaState.activeJutsuId(set);
        String name = current == null ? "empty" : ClientNinjaState.name(current);

        context.drawTextWithShadow(client.textRenderer, Text.literal("[" + label + "]"), x, lineY, 0xFF8800);
        context.drawTextWithShadow(client.textRenderer, Text.literal(" " + name), x + 14, lineY, 0xFFFFFF);
        lineY += 10;

        for (int i = 0; i < 5; i++) {
            int color = (i == ClientNinjaState.active(set)) ? 0xFF8800
                : (ClientNinjaState.loadout(set)[i] != null ? 0x55AAFF : 0x555555);
            context.drawTextWithShadow(client.textRenderer, Text.literal("[" + (i + 1) + "]"),
                x + i * 18, lineY, color);
        }
        return lineY + 12;
    }
}

# ================= src\main\java\com\example\shinobicore\client\ChakraPhysicsClient.java =================
package com.example.shinobicore.client;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import com.example.shinobicore.client.parkour.util.WallDetector;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.fluid.FluidState;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

public class ChakraPhysicsClient {

    private static int logTimer = 0;
    private static boolean prevJumping = false;
    private static int airJumpsUsed = 0;
    private static boolean wasStickingToWall = false;
    public static boolean stickingToWall = false;
    private static int wallJumpCooldown = 0;
    private static boolean wasOnGroundOrWater = true;

    // Флаг "стоит на воде" — обновляется в onClientTick, читается в mixin и ChargedJumpAction
    public static boolean standingOnWater = false;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ChakraPhysicsClient::onClientTick);
    }

    private static void onClientTick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        boolean chakraOn = ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0;
        boolean canParkour = ChakraHudRenderer.currentChakra > 0 && !ChakraHudRenderer.exhausted;
        boolean doLog = (logTimer == 0);

        // Состояние "на земле или воде" — из прошлого тика
        boolean onGroundOrWater = player.isOnGround() || standingOnWater;

        // Сброс airJumpsUsed при сходе с земли/воды
        if (wasOnGroundOrWater && !onGroundOrWater) {
            airJumpsUsed = 0;
        }
        wasOnGroundOrWater = onGroundOrWater;

        // Edge detection для Space
        boolean jumpEdge = player.input.jumping && !prevJumping;
        prevJumping = player.input.jumping;

        if (wallJumpCooldown > 0) wallJumpCooldown--;

        // === ПАРКУР ===
        ParkourManager.tick(client);
        if (ParkourManager.isSliding()) {
            logTimer = (logTimer + 1) % 20;
            return;
        }

        // === DOUBLE JUMP (только если НЕ на земле/воде) ===
        if (canParkour && jumpEdge && !onGroundOrWater && airJumpsUsed < 1) {
            player.addVelocity(0, 0.42, 0);
            player.velocityModified = true;
            airJumpsUsed = 1;
            if (doLog) ShinobiCore.LOGGER.debug("[parkour] double jump");
        }

        // === WATER + WALL PHYSICS ===
        if (chakraOn) {
            BlockPos feet = player.getBlockPos();
            double surfaceY = Double.NaN;
            for (int dy = 0; dy <= 3; dy++) {
                FluidState fs = player.getWorld().getFluidState(feet.down(dy));
                if (!fs.isEmpty()) {
                    double h = fs.getHeight(player.getWorld(), feet.down(dy));
                    surfaceY = feet.down(dy).getY() + (h > 0 ? h : 1.0);
                    break;
                }
            }

            if (!Double.isNaN(surfaceY)) {
                // === ВОДА ===
                Vec3d v = player.getVelocity();
                if (player.isSubmergedInWater()) {
                    player.setVelocity(v.x, 0.3, v.z);
                    standingOnWater = false;
                } else {
                    if (player.getY() < surfaceY - 0.001) {
                        player.setPosition(player.getX(), surfaceY, player.getZ());
                        v = player.getVelocity();
                    }
                    boolean nearSurface = player.getY() <= surfaceY + 0.05;
                    if (nearSurface) {
                        if (v.y < 0) {
                            // Гасим падение только если игрок падает
                            player.setVelocity(v.x, 0.0, v.z);
                            v = player.getVelocity();
                        }
                        // КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ:
                        // Не устанавливаем setOnGround если игрок прыгает вверх.
                        // Иначе в следующем тике mixin отменит повторный прыжок с воды.
                        boolean isJumpingUp = v.y > 0.1;
                        if (!isJumpingUp) {
                            player.setOnGround(true);
                            standingOnWater = true;
                        } else {
                            standingOnWater = false;
                        }
                        if (player.input.pressingForward && !player.input.sneaking && !player.isSprinting()) {
                            player.setSprinting(true);
                        }
                    } else {
                        standingOnWater = false;
                    }
                    if (doLog) ShinobiCore.LOGGER.debug("[chakra-water] y={} surfaceY={}", fmt(player.getY()), fmt(surfaceY));
                }
                player.fallDistance = 0f;
            } else if (!player.isOnGround() && !ParkourManager.isWallRunning()) {
                // === СТЕНЫ ===
                standingOnWater = false;
                Vec3d wallNormal = WallDetector.getWallNormal(player);
                boolean stickingNow = wallNormal != null;

                // Wall jump
                if (stickingNow && jumpEdge && wallJumpCooldown == 0) {
                    Vec3d jumpVel = wallNormal.multiply(0.3).add(0, 0.35, 0);
                    player.addVelocity(jumpVel.x, jumpVel.y, jumpVel.z);
                    player.velocityModified = true;
                    wallJumpCooldown = 8;
                    airJumpsUsed = 0;
                    wasStickingToWall = false;
                    ParkourSounds.playWallStick();
                    if (doLog) ShinobiCore.LOGGER.debug("[parkour] wall jump");
                    logTimer = (logTimer + 1) % 20;
                    return;
                }

                if (stickingNow && !wasStickingToWall) {
                    ParkourSounds.playWallStick();
                    if (doLog) ShinobiCore.LOGGER.debug("[chakra-wall] stuck to wall");
                }
                wasStickingToWall = stickingNow;
            stickingToWall = stickingNow;

                if (stickingNow) {
                    Vec3d v = player.getVelocity();

                    // Auto ledge climb
                    BlockPos ledge = WallDetector.getLedgeAbove(player);
                    if (ledge != null && (player.input.pressingForward || player.input.jumping)) {
                        player.setPosition(player.getX(), ledge.getY() + 0.001, player.getZ());
                        player.setVelocity(v.x * 0.5, 0.0, v.z * 0.5);
                        player.setOnGround(true);
                        wasStickingToWall = false;
                        ParkourSounds.playEdgeClimb();
                        if (doLog) ShinobiCore.LOGGER.debug("[parkour] ledge climb");
                        logTimer = (logTimer + 1) % 20;
                        return;
                    }

                    // Плавное прилипание
                    double dotProduct = v.x * wallNormal.x + v.z * wallNormal.z;
                    if (dotProduct < 0) {
                        v = v.subtract(wallNormal.multiply(dotProduct));
                    }

                    float vy;
                    if (player.input.sneaking) vy = -0.05f;
                    else if (player.input.pressingForward || player.input.jumping) vy = 0.05f;
                    else vy = 0f;

                    player.setVelocity(v.x, vy, v.z);
                    player.fallDistance = 0f;
                }
            } else {
                wasStickingToWall = false;
                standingOnWater = false;
            }
        } else {
            wasStickingToWall = false;
            standingOnWater = false;
        }

        logTimer = (logTimer + 1) % 20;
    }

    private static String fmt(double d) { return String.format("%.2f", d); }
}

# ================= src\main\java\com\example\shinobicore\client\CinematicCamera.java =================
package com.example.shinobicore.client;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import com.example.shinobicore.client.combat.TaijutsuKickHandler;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.MathHelper;
import net.minecraft.util.math.Vec3d;

public class CinematicCamera {
    // === OVER-THE-SHOULDER: НАСТРОЙКИ КАМЕРЫ (как в Gears of War / RE4) ===
    // Сильное смещение вправо — камера за правым плечом
    private static final float SHOULDER_OFFSET_RIGHT = 0.75f;
    // Чуть выше плеча (не головы!)
    private static final float SHOULDER_OFFSET_UP = 0.05f;
    // ПРИБЛИЖЕНИЕ камеры (forward offset) — камера ближе к игроку
    private static final float FORWARD_OFFSET = 1.3f;
    // Базовое расстояние — меньше чем ванила (которая 4.0)
    private static final float BASE_DISTANCE_REDUCTION = 0.8f;

    // === ПЛАВНОЕ СЛЕДОВАНИЕ (высокий коэфф = плавно) ===
    private static final float POSITION_SMOOTHING = 0.18f;
    private static final float OFFSET_SMOOTHING = 0.12f;

    // Текущие плавные значения
    private static float currentRightOffset = 0f;
    private static float currentUpOffset = 0f;
    private static float currentForwardOffset = 0f;
    private static float currentDistanceReduction = 0f;

    // Лёгкая тряска
    private static float shakeIntensity = 0f;
    private static final float SHAKE_DECAY = 0.85f;

    private static boolean enabled = true;

    public static void tick(MinecraftClient client) {
        if (!enabled || client.player == null) return;

        ClientPlayerEntity player = client.player;
        boolean chakraMode = ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0;
        boolean sprinting = player.isSprinting();
        boolean attacking = TaijutsuClientHandler.isAttacking() || TaijutsuKickHandler.isOnCooldown();

        // Целевые значения
        float targetRight = SHOULDER_OFFSET_RIGHT;
        float targetUp = SHOULDER_OFFSET_UP;
        float targetForward = FORWARD_OFFSET;
        float targetDistanceRed = BASE_DISTANCE_REDUCTION;

        // В чакра-режиме чуть отдаляем для эпичности (но всё равно ближе ванилы)
        if (chakraMode) {
            targetForward -= 0.3f;
            targetRight += 0.05f;
        }

        // При спринте — чуть шире плечо
        if (sprinting && !chakraMode) {
            targetRight += 0.1f;
            targetForward -= 0.2f;
        }

        // Плавная интерполяция
        currentRightOffset = MathHelper.lerp(OFFSET_SMOOTHING, currentRightOffset, targetRight);
        currentUpOffset = MathHelper.lerp(OFFSET_SMOOTHING, currentUpOffset, targetUp);
        currentForwardOffset = MathHelper.lerp(POSITION_SMOOTHING, currentForwardOffset, targetForward);
        currentDistanceReduction = MathHelper.lerp(POSITION_SMOOTHING, currentDistanceReduction, targetDistanceRed);

        // Тряска при ударе (очень мягкая)
        if (attacking) {
            shakeIntensity = Math.max(shakeIntensity, 0.05f);
        }
        shakeIntensity *= SHAKE_DECAY;
        if (shakeIntensity < 0.001f) shakeIntensity = 0f;
    }

    public static float getRightOffset() {
        return currentRightOffset;
    }

    public static float getUpOffset() {
        return currentUpOffset;
    }

    /**
     * Смещение вперёд (по направлению взгляда) — приближает камеру.
     * Положительное значение = ближе к игроку.
     */
    public static float getForwardOffset() {
        return currentForwardOffset;
    }

    /**
     * На сколько сократить расстояние от игрока (с учётом клипинга стен).
     */
    public static float getDistanceReduction() {
        return currentDistanceReduction;
    }

    public static void addShake(float intensity) {
        shakeIntensity = Math.max(shakeIntensity, intensity);
    }

    public static Vec3d getShakeOffset() {
        if (shakeIntensity < 0.001f) return Vec3d.ZERO;
        double x = (Math.random() - 0.5) * shakeIntensity * 0.05;
        double y = (Math.random() - 0.5) * shakeIntensity * 0.05;
        double z = (Math.random() - 0.5) * shakeIntensity * 0.05;
        return new Vec3d(x, y, z);
    }

    public static boolean isEnabled() {
        return enabled;
    }

    public static void setEnabled(boolean value) {
        enabled = value;
    }

    public static void reset() {
        currentRightOffset = 0f;
        currentUpOffset = 0f;
        currentForwardOffset = 0f;
        currentDistanceReduction = 0f;
        shakeIntensity = 0f;
    }
}

# ================= src\main\java\com\example\shinobicore\client\ClientInputHandler.java =================
package com.example.shinobicore.client;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.combat.TaijutsuKickHandler;
import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import com.example.shinobicore.client.combat.KenjutsuClientHandler;
import com.example.shinobicore.combat.TaijutsuStyle;
import com.example.shinobicore.combat.TaijutsuFormulas;
import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;
public class ClientInputHandler {
    private static boolean prevMeditatePressed = false;
    private static boolean prevDeflectDown = false;
    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ClientInputHandler::onClientTick);
    }
    private static void onClientTick(MinecraftClient client) {
        if (client.player == null) return;
        if (KeyBindings.CHAKRA_MODE.wasPressed()) {
            ClientNinjaState.chakraMode = !ClientNinjaState.chakraMode;
            if (client.getNetworkHandler() != null) {
                PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
                buf.writeBoolean(ClientNinjaState.chakraMode);
                ClientPlayNetworking.send(ModPackets.CHAKRA_MODE_ID, buf);
            }
        }
        boolean meditatePressed = KeyBindings.MEDITATE.isPressed();
        if (meditatePressed && !prevMeditatePressed) sendMeditatePacket(client, true);
        else if (!meditatePressed && prevMeditatePressed) sendMeditatePacket(client, false);
        prevMeditatePressed = meditatePressed;
        boolean hasKatana = client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem;
        if (KeyBindings.KICK.wasPressed()) {
            boolean handEmpty = client.player.getMainHandStack().isEmpty();
            if (handEmpty || hasKatana) TaijutsuKickHandler.tryKick(client.player);
        }
        if (KeyBindings.SWITCH_STANCE.wasPressed() && hasKatana) {
            KenjutsuClientHandler.cycleStance(client.player);
        }
        boolean deflectDown = KeyBindings.KATANA_DEFLECT.isPressed();
        if (deflectDown != prevDeflectDown) {
            prevDeflectDown = deflectDown;
            if (hasKatana) KenjutsuClientHandler.setDeflectHeld(client.player, deflectDown);
        }
        if (KeyBindings.SWITCH_STYLE.wasPressed()) {
            if (hasKatana) {
                KenjutsuClientHandler.cycleStance(client.player);
            } else {
                TaijutsuStyle currentStyle = TaijutsuClientHandler.getCurrentStyle();
                TaijutsuStyle newStyle;
                if (currentStyle == TaijutsuStyle.STANDARD) {
                    int taijutsuLevel = ClientNinjaState.statLevels.getOrDefault("taijutsu", 0);
                    if (!TaijutsuFormulas.canUseStrongFist(taijutsuLevel)) {
                        client.player.sendMessage(Text.literal("В§cYou need Taijutsu level " +
                                TaijutsuFormulas.strongFistUnlockLevel() + " to use Strong Fist!"), false);
                        return;
                    }
                    newStyle = TaijutsuStyle.STRONG_FIST;
                } else {
                    newStyle = TaijutsuStyle.STANDARD;
                }
                TaijutsuClientHandler.setStyle(newStyle);
                client.player.sendMessage(Text.literal("В§aStyle: " + newStyle.getId()), false);
                if (client.getNetworkHandler() != null) {
                    PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
                    buf.writeString(newStyle.getId());
                    ClientPlayNetworking.send(ModPackets.TAIJUTSU_STYLE_ID, buf);
                }
            }
        }
        if (KeyBindings.TOGGLE_SENSORY.wasPressed()) {
            boolean newState = !ClientNinjaState.sensoryEnabled;
            ClientNinjaState.sensoryEnabled = newState;
            if (client.getNetworkHandler() != null) {
                PacketByteBuf senBuf = new PacketByteBuf(Unpooled.buffer());
                senBuf.writeBoolean(newState);
                ClientPlayNetworking.send(ModPackets.SENSORY_TOGGLE_ID, senBuf);
            }
            client.player.sendMessage(Text.literal(newState ? "В§aSensory: ON" : "В§7Sensory: OFF"), false);
        }
        if (KeyBindings.CAST_A.wasPressed()) ClientNinjaState.castActiveJutsu(0);
        if (KeyBindings.CAST_B.wasPressed()) ClientNinjaState.castActiveJutsu(1);
        if (KeyBindings.CYCLE_A.wasPressed()) ClientNinjaState.cycleLoadout(0);
        if (KeyBindings.CYCLE_B.wasPressed()) ClientNinjaState.cycleLoadout(1);
        if (KeyBindings.PROGRESSION.wasPressed()) client.setScreen(new ProgressionScreen());
        if (KeyBindings.CRAWL.wasPressed()) ShinobiCore.LOGGER.info("[INPUT] CRAWL (N) pressed");
    }
    private static void sendMeditatePacket(MinecraftClient client, boolean start) {
        if (client.getNetworkHandler() != null) {
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeBoolean(start);
            ClientPlayNetworking.send(ModPackets.MEDITATE_ID, buf);
        }
    }
}

# ================= src\main\java\com\example\shinobicore\client\ClientNinjaState.java =================
package com.example.shinobicore.client;

import com.example.shinobicore.ShinobiCore;
import io.netty.buffer.Unpooled;
import net.minecraft.client.MinecraftClient;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.network.packet.c2s.play.CustomPayloadC2SPacket;
import net.minecraft.util.Identifier;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class ClientNinjaState {
    public static final String[] loadoutA = new String[5];
    public static final String[] loadoutB = new String[5];
    public static int activeA = 0;
    public static int activeB = 0;

    public static final Map<String, String> catalog = new HashMap<>();
    public static final Set<String> learned = new HashSet<>();

    public static int skillPoints = 0;
    public static int reserveLevel = 1;
    public static int reserveXp = 0;
    public static final Map<String, Integer> statLevels = new HashMap<>();
    public static final Map<String, Integer> statXp = new HashMap<>();
    public static final Map<String, Integer> natureLevels = new HashMap<>();
    public static final Map<String, Integer> natureXp = new HashMap<>();
    public static final Map<String, Boolean> natureUnlocked = new HashMap<>();

    public static int hpLevel = 0;
    public static int speedLevel = 0;
    public static int jumpLevel = 0;
    public static boolean chakraMode = false;
    public static boolean dangerSense = false;
    public static boolean sensoryEnabled = true;
    public static boolean meditating = false;
    public static String kenjutsuStance = "aggressive";
    public static boolean deflectHeld = false;
    public static String clanId = "none";
    public static String affinityId = null;
    public static final Set<String> unlockedNodes = new HashSet<>();

    public static String[] loadout(int set) { return set == 0 ? loadoutA : loadoutB; }
    public static int active(int set) { return set == 0 ? activeA : activeB; }
    public static String activeJutsuId(int set) { return loadout(set)[active(set)]; }

    public static String name(String id) {
        if (id == null) return "";
        return catalog.getOrDefault(id, id);
    }

    public static void cycleLoadout(int set) {
        if (set == 0) {
            int start = activeA;
            do {
                activeA = (activeA + 1) % 5;
                if (loadoutA[activeA] != null) break;
            } while (activeA != start);
            ShinobiCore.LOGGER.debug("[JUTSU] Cycled slot A to: {} ({})", activeA, activeJutsuId(0));
        } else {
            int start = activeB;
            do {
                activeB = (activeB + 1) % 5;
                if (loadoutB[activeB] != null) break;
            } while (activeB != start);
            ShinobiCore.LOGGER.debug("[JUTSU] Cycled slot B to: {} ({})", activeB, activeJutsuId(1));
        }
    }

    public static void castActiveJutsu(int set) {
        String jutsuId = activeJutsuId(set);
        int slotIndex = active(set);
        
        ShinobiCore.LOGGER.debug("[CAST-CLIENT] === CAST JUTSU ===");
        ShinobiCore.LOGGER.debug("[CAST-CLIENT] Set: {} ({}), Slot index: {}", 
            set, set == 0 ? "A" : "B", slotIndex);
        ShinobiCore.LOGGER.debug("[CAST-CLIENT] Jutsu ID: {}", jutsuId);
        ShinobiCore.LOGGER.debug("[CAST-CLIENT] Loadout A: [{}, {}, {}, {}, {}]", 
            loadoutA[0], loadoutA[1], loadoutA[2], loadoutA[3], loadoutA[4]);
        ShinobiCore.LOGGER.debug("[CAST-CLIENT] Loadout B: [{}, {}, {}, {}, {}]", 
            loadoutB[0], loadoutB[1], loadoutB[2], loadoutB[3], loadoutB[4]);
        ShinobiCore.LOGGER.debug("[CAST-CLIENT] Active A: {}, Active B: {}", activeA, activeB);
        
        if (jutsuId == null) {
            ShinobiCore.LOGGER.debug("[CAST-CLIENT] ✗ No jutsu in slot, aborting");
            return;
        }
        
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) {
            ShinobiCore.LOGGER.debug("[CAST-CLIENT] ✗ Player is null, aborting");
            return;
        }
        if (client.getNetworkHandler() == null) {
            ShinobiCore.LOGGER.debug("[CAST-CLIENT] ✗ NetworkHandler is null, aborting");
            return;
        }
        
        ShinobiCore.LOGGER.debug("[CAST-CLIENT] ✓ Sending packet: cast_slot");
        ShinobiCore.LOGGER.debug("[CAST-CLIENT]   Packet data: set={}, slot={}", set, slotIndex);
        
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(set);
        buf.writeInt(slotIndex);
        
        client.getNetworkHandler().sendPacket(new CustomPayloadC2SPacket(
            new Identifier("shinobicore", "cast_slot"), buf));
        
        ShinobiCore.LOGGER.debug("[CAST-CLIENT] ✓ Packet sent successfully");
    }
}

# ================= src\main\java\com\example\shinobicore\client\combat\animations\TaijutsuAnimations.java =================


# ================= src\main\java\com\example\shinobicore\client\combat\KenjutsuAnimations.java =================
package com.example.shinobicore.client.combat;
import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
public class KenjutsuAnimations {
    private static final Map<UUID, SlashState> SLASHES = new HashMap<>();
    private static final Map<UUID, Long> DEFLECTS = new HashMap<>();
    public static class SlashState {
        public final int step; public final long start;
        public SlashState(int step) { this.step = step; this.start = System.currentTimeMillis(); }
        public float getProgress() { return Math.min(1f, (System.currentTimeMillis() - start) / duration(step)); }
        public boolean isFinished() { return System.currentTimeMillis() - start >= duration(step); }
        private float duration(int s) { return switch (s) { case 0, 1 -> 260f; case 2 -> 340f; default -> 520f; }; }
    }
    public static void playSlash(AbstractClientPlayerEntity p, int step) { SLASHES.put(p.getUuid(), new SlashState(step)); }
    public static void playDeflect(AbstractClientPlayerEntity p) { DEFLECTS.put(p.getUuid(), System.currentTimeMillis() + 300); }
    public static boolean isDeflecting(AbstractClientPlayerEntity p) {
        Long t = DEFLECTS.get(p.getUuid());
        if (t == null) return false;
        if (System.currentTimeMillis() >= t) { DEFLECTS.remove(p.getUuid()); return false; }
        return true;
    }
    private static SlashState get(AbstractClientPlayerEntity p) {
        SlashState s = SLASHES.get(p.getUuid());
        if (s != null && s.isFinished()) { SLASHES.remove(p.getUuid()); return null; }
        return s;
    }
    public static boolean isAttacking(AbstractClientPlayerEntity p) { return get(p) != null; }
    private static float curve(float p) {
        if (p < 0.3f) return (float) Math.sin(p / 0.3f * Math.PI / 2);
        if (p < 0.5f) return 1.0f + 0.15f * (float) Math.sin((p - 0.3f) / 0.2f * Math.PI);
        return 1.0f - (float) Math.sin((p - 0.5f) / 0.5f * Math.PI / 2);
    }
    public static void applySlash(AbstractClientPlayerEntity p, ModelPart rArm, ModelPart lArm, ModelPart body, ModelPart head) {
        SlashState s = get(p); if (s == null) return;
        float c = curve(s.getProgress());
        switch (s.step) {
            case 0 -> { rArm.yaw = -1.9f + c * 3.2f; rArm.pitch = -0.85f; rArm.roll = 0.2f; body.yaw += c * 0.6f - 0.3f; lArm.yaw = 0.4f; lArm.pitch = -0.6f; }
            case 1 -> { rArm.yaw = 1.9f - c * 3.2f; rArm.pitch = -0.85f; rArm.roll = -0.2f; body.yaw -= c * 0.6f - 0.3f; lArm.yaw = -0.4f; lArm.pitch = -0.6f; }
            case 2 -> { rArm.pitch = 2.3f - c * 4.0f; rArm.yaw = -0.2f; body.pitch += c * 0.35f; lArm.pitch = -0.9f; lArm.yaw = 0.5f; }
            default -> { body.yaw += s.getProgress() * 6.283f; rArm.pitch = -1.5f; rArm.roll = 0.6f; lArm.pitch = -1.5f; lArm.yaw = -0.6f; head.pitch -= 0.1f; }
        }
    }
    public static void applyDeflect(AbstractClientPlayerEntity p, ModelPart rArm, ModelPart lArm) {
        rArm.pitch = -1.4f; rArm.yaw = -0.3f; lArm.pitch = -1.0f; lArm.yaw = 0.4f;
    }
}

# ================= src\main\java\com\example\shinobicore\client\combat\KenjutsuClientHandler.java =================
package com.example.shinobicore.client.combat;
import com.example.shinobicore.client.CinematicCamera;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.item.KatanaItem;
import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.Hand;
import net.minecraft.util.math.Vec3d;
public class KenjutsuClientHandler {
    private static int comboStep = 0;
    private static long lastAttack = 0;
    private static long cooldownEnd = 0;
    private static final String[] ORDER = {"aggressive", "seigan", "iai"};
    public static boolean tryAttack(ClientPlayerEntity player) {
        if (!(player.getMainHandStack().getItem() instanceof KatanaItem)) return false;
        long now = System.currentTimeMillis();
        if (now < cooldownEnd) return false;
        if (now - lastAttack > 1500) comboStep = 0;
        String stance = ClientNinjaState.kenjutsuStance;
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(comboStep);
        buf.writeString(stance);
        ClientPlayNetworking.send(ModPackets.KATANA_ATTACK_ID, buf);
        KenjutsuAnimations.playSlash(player, comboStep);
        playSlashParticles(player, comboStep);
        TaijutsuSounds.playWhoosh();
        if (comboStep == 3) {
            TaijutsuSounds.playKickSound();
            CinematicCamera.addShake(0.12f);
        }
        player.swingHand(Hand.MAIN_HAND);
        long cd = stance.equals("aggressive") ? 350 : stance.equals("seigan") ? 450 : 500;
        cooldownEnd = now + cd;
        lastAttack = now;
        comboStep = (comboStep + 1) % 4;
        return true;
    }
    public static void setDeflectHeld(ClientPlayerEntity player, boolean held) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeBoolean(held);
        ClientPlayNetworking.send(ModPackets.KATANA_DEFLECT_ID, buf);
        ClientNinjaState.deflectHeld = held;
        if (held) {
            KenjutsuAnimations.playDeflect(player);
            player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 0.4f, 1.5f);
        }
    }
    public static void cycleStance(ClientPlayerEntity player) {
        String cur = ClientNinjaState.kenjutsuStance;
        String next = ORDER[(java.util.Arrays.asList(ORDER).indexOf(cur) + 1) % ORDER.length];
        ClientNinjaState.kenjutsuStance = next;
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString(next);
        ClientPlayNetworking.send(ModPackets.KATANA_STANCE_ID, buf);
        player.sendMessage(Text.literal("В§aStance: " + next), false);
    }
    private static void playSlashParticles(ClientPlayerEntity player, int step) {
        MinecraftClient client = MinecraftClient.getInstance();
        Vec3d look = player.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        Vec3d pos = player.getPos().add(0, 1.2, 0);
        int count = step == 3 ? 24 : 12;
        for (int i = 0; i < count; i++) {
            float t = (i / (float) count) * 2f - 1f;
            Vec3d dir = look.add(right.multiply(step % 2 == 0 ? t : -t)).normalize();
            client.world.addParticle(step == 3 ? ParticleTypes.ENCHANT : ParticleTypes.SWEEP_ATTACK,
                    pos.x + dir.x * 1.5, pos.y + dir.y * 1.5 + t * 0.3, pos.z + dir.z * 1.5,
                    dir.x * 0.1, dir.y * 0.1, dir.z * 0.1);
        }
        if (step == 3) {
            for (int i = 0; i < 12; i++) {
                double a = (i / 12.0) * Math.PI * 2;
                client.world.addParticle(ParticleTypes.CRIT,
                        pos.x + Math.cos(a) * 1.8, pos.y, pos.z + Math.sin(a) * 1.8, 0, 0.1, 0);
            }
        }
    }
}

# ================= src\main\java\com\example\shinobicore\client\combat\TaijutsuAnimations.java =================
package com.example.shinobicore.client.combat;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.combat.TaijutsuStyle;
import net.minecraft.client.network.AbstractClientPlayerEntity;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class TaijutsuAnimations {

    private static final Map<UUID, AttackAnimationState> activeAnimations = new HashMap<>();

    public static class AttackAnimationState {
        public final int comboStep;
        public final TaijutsuStyle style;
        public final long startTime;

        public AttackAnimationState(int comboStep, TaijutsuStyle style) {
            this.comboStep = comboStep;
            this.style = style;
            this.startTime = System.currentTimeMillis();
            ShinobiCore.LOGGER.debug("[ANIM] Created animation state: step={}, style={}", comboStep, style.getId());
        }

        public float getProgress() {
            long elapsed = System.currentTimeMillis() - startTime;
            float duration = getDuration(comboStep);
            float progress = Math.min(1.0f, elapsed / duration);
            return progress;
        }

        public boolean isFinished() {
            long elapsed = System.currentTimeMillis() - startTime;
            float duration = getDuration(comboStep);
            boolean finished = elapsed >= duration;
            return finished;
        }

        private float getDuration(int step) {
            switch (step) {
                case 0: return 280f;
                case 1: return 280f;
                case 2: return 380f;
                case 3: return 500f;
                default: return 300f;
            }
        }
    }

    public static void playAttackAnimation(AbstractClientPlayerEntity player, int comboStep, TaijutsuStyle style) {
        ShinobiCore.LOGGER.debug("[ANIM] playAttackAnimation called: player={}, step={}, style={}",
            player.getName().getString(), comboStep, style.getId());
        activeAnimations.put(player.getUuid(), new AttackAnimationState(comboStep, style));
        ShinobiCore.LOGGER.debug("[ANIM] Animation added to map. Map size: {}", activeAnimations.size());
    }

    public static AttackAnimationState getAnimationState(AbstractClientPlayerEntity player) {
        AttackAnimationState state = activeAnimations.get(player.getUuid());
        if (state != null && state.isFinished()) {
            ShinobiCore.LOGGER.debug("[ANIM] Animation finished, removing from map");
            activeAnimations.remove(player.getUuid());
            return null;
        }
        return state;
    }

    public static float getArmRotation(AbstractClientPlayerEntity player, float tickDelta) {
        AttackAnimationState state = getAnimationState(player);
        if (state == null) {
            return 0f;
        }
        float progress = state.getProgress();
        int step = state.comboStep;
        float maxAngle;
        switch (step) {
            case 0: maxAngle = -85f;  break;
            case 1: maxAngle = -85f;  break;
            case 2: maxAngle = -105f; break;
            case 3: maxAngle = -130f; break;
            default: maxAngle = -85f;
        }
        if (state.style == TaijutsuStyle.STRONG_FIST) {
            maxAngle *= 1.15f;
        }

        // === УЛУЧШЕННАЯ КРИВАЯ: ease-in-out с overshoot ===
        float curve;
        if (progress < 0.3f) {
            // Замах (0 -> 0.3) — ease-in (ускорение)
            float t = progress / 0.3f;
            curve = (float) Math.sin(t * (Math.PI / 2));
        } else if (progress < 0.5f) {
            // Удар (0.3 -> 0.5) — overshoot (небольшой перебор)
            float t = (progress - 0.3f) / 0.2f;
            curve = 1.0f + 0.15f * (float) Math.sin(t * Math.PI);
        } else {
            // Возврат (0.5 -> 1.0) — ease-out (замедление)
            float t = (progress - 0.5f) / 0.5f;
            curve = 1.0f - (float) Math.sin(t * (Math.PI / 2));
        }

        float result = curve * maxAngle;
        return result;
    }

    public static boolean isAttacking(AbstractClientPlayerEntity player) {
        boolean result = getAnimationState(player) != null;
        return result;
    }
    private static final Map<UUID, KickAnimationState> activeKicks = new HashMap<>();

    public static class KickAnimationState {
        public final TaijutsuStyle style;
        public final long startTime;
        public static final long DURATION_MS = 400;

        public KickAnimationState(TaijutsuStyle style) {
            this.style = style;
            this.startTime = System.currentTimeMillis();
        }

        public float getProgress() {
            long elapsed = System.currentTimeMillis() - startTime;
            return Math.min(1.0f, elapsed / (float) DURATION_MS);
        }

        public boolean isFinished() {
            return System.currentTimeMillis() - startTime >= DURATION_MS;
        }
    }

    public static void playKickAnimation(AbstractClientPlayerEntity player, TaijutsuStyle style) {
        ShinobiCore.LOGGER.debug("[ANIM] Playing kick animation, style={}", style.getId());
        activeKicks.put(player.getUuid(), new KickAnimationState(style));
    }

    public static KickAnimationState getKickState(AbstractClientPlayerEntity player) {
        KickAnimationState state = activeKicks.get(player.getUuid());
        if (state != null && state.isFinished()) {
            activeKicks.remove(player.getUuid());
            return null;
        }
        return state;
    }

    public static boolean isKicking(AbstractClientPlayerEntity player) {
        return getKickState(player) != null;
    }

    public static float getLegRotation(AbstractClientPlayerEntity player) {
        KickAnimationState state = getKickState(player);
        if (state == null) return 0f;
        float progress = state.getProgress();
        float maxAngle = -110f;
        if (state.style == TaijutsuStyle.STRONG_FIST) maxAngle *= 1.2f;

        // === УЛУЧШЕННАЯ КРИВАЯ ДЛЯ УДАРА НОГОЙ ===
        float curve;
        if (progress < 0.25f) {
            // Замах (0 -> 0.25) — быстрый ease-in
            float t = progress / 0.25f;
            curve = (float) Math.sin(t * (Math.PI / 2));
        } else if (progress < 0.45f) {
            // Удар (0.25 -> 0.45) — overshoot
            float t = (progress - 0.25f) / 0.2f;
            curve = 1.0f + 0.2f * (float) Math.sin(t * Math.PI);
        } else {
            // Возврат (0.45 -> 1.0) — плавный ease-out
            float t = (progress - 0.45f) / 0.55f;
            curve = 1.0f - (float) Math.sin(t * (Math.PI / 2));
        }

        return curve * maxAngle;
    }
}

# ================= src\main\java\com\example\shinobicore\client\combat\TaijutsuClientHandler.java =================
package com.example.shinobicore.client.combat;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.RasenganClientState;
import com.example.shinobicore.combat.TaijutsuCombo;
import com.example.shinobicore.tree.TreePassives;
import com.example.shinobicore.combat.TaijutsuFormulas;
import com.example.shinobicore.combat.TaijutsuStyle;
import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Hand;
import com.example.shinobicore.client.RasenganClientState;
public class TaijutsuClientHandler {
    private static int comboStep = 0;
    private static long lastAttackTime = 0;
    private static long cooldownEndTime = 0;
    private static TaijutsuStyle currentStyle = TaijutsuStyle.STANDARD;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(TaijutsuClientHandler::onClientTick);
    }

    private static void onClientTick(MinecraftClient client) {
        if (client.player == null) return;
        long now = System.currentTimeMillis();
        long cdTimeout = (long)(TaijutsuCombo.COMBO_TIMEOUT_MS * (1 + TreePassives.collectClient().comboTimeoutBonus));
        if (comboStep > 0 && now - lastAttackTime > cdTimeout) {
            comboStep = 0;
        }
    }

    public static boolean tryAttack(ClientPlayerEntity player) {
        ShinobiCore.LOGGER.debug("[ATTACK] tryAttack called");
        
        if (!player.getMainHandStack().isEmpty()) {
            ShinobiCore.LOGGER.debug("[ATTACK] Hand not empty, returning false");
            return false;
        }

        // === РАСЕНГАН: если готов — удар Расенганом вместо обычной атаки ===
        if (RasenganClientState.ready) {
            ShinobiCore.LOGGER.info("[RASENGAN] Strike! Sending packet to server");
            PacketByteBuf rasenganBuf = new PacketByteBuf(Unpooled.buffer());
            ClientPlayNetworking.send(ModPackets.RASENGAN_STRIKE_ID, rasenganBuf);
            RasenganClientState.ready = false;
            RasenganClientState.charging = false;
            RasenganClientState.chargeProgress = 0f;
            return true;
        }

        long now = System.currentTimeMillis();
        if (now < cooldownEndTime) {
            ShinobiCore.LOGGER.debug("[ATTACK] On cooldown, returning false");
            return false;
        }

        long atkTimeout = (long)(TaijutsuCombo.COMBO_TIMEOUT_MS * (1 + TreePassives.collectClient().comboTimeoutBonus));
        if (now - lastAttackTime > atkTimeout) {
            ShinobiCore.LOGGER.debug("[ATTACK] Combo timeout, resetting to 0");
            comboStep = 0;
        }

        boolean chakraMode = ClientNinjaState.chakraMode;
        int taijutsuLevel = ClientNinjaState.statLevels.getOrDefault("taijutsu", 0);
        int cooldown = TaijutsuFormulas.attackCooldownTicks(currentStyle, chakraMode);

        ShinobiCore.LOGGER.debug("[ATTACK] Sending packet: step={}, style={}", comboStep, currentStyle.getId());
        sendAttackPacket(comboStep, currentStyle);

        ShinobiCore.LOGGER.debug("[ATTACK] Playing animation and particles");
        TaijutsuAnimations.playAttackAnimation(player, comboStep, currentStyle);
        TaijutsuParticleEffects.playAttackParticles(player, comboStep, currentStyle);

        player.swingHand(Hand.MAIN_HAND);
        // === ЗВУКИ УДАРА ===
        TaijutsuSounds.playPunchSound(comboStep);
        TaijutsuSounds.playWhoosh();
        lastAttackTime = now;
        cooldownEndTime = now + (cooldown * 50L);

        int oldStep = comboStep;
        comboStep = (comboStep + 1) % TaijutsuCombo.MAX_STEPS;
        ShinobiCore.LOGGER.debug("[ATTACK] Combo step updated: {} -> {}", oldStep, comboStep);
        
        return true;
    }
    public static boolean isAttacking() {
        return System.currentTimeMillis() - lastAttackTime < 300;
    }
    private static void sendAttackPacket(int step, TaijutsuStyle style) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(step);
        buf.writeString(style.getId());
        ClientPlayNetworking.send(ModPackets.TAIJUTSU_ATTACK_ID, buf);
    }

    public static int getComboStep() { return comboStep; }
    public static TaijutsuStyle getCurrentStyle() { return currentStyle; }
    public static void setStyle(TaijutsuStyle style) { currentStyle = style; }
}

# ================= src\main\java\com\example\shinobicore\client\combat\TaijutsuKickHandler.java =================
package com.example.shinobicore.client.combat;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.combat.TaijutsuStyle;
import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Hand;
public class TaijutsuKickHandler {
    private static long kickCooldownEnd = 0;
    public static final long KICK_COOLDOWN_MS = 500;
    public static boolean tryKick(ClientPlayerEntity player) {
        ShinobiCore.LOGGER.debug("[KICK] tryKick called");
        boolean handEmpty = player.getMainHandStack().isEmpty();
        boolean hasKatana = player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem;
        if (!handEmpty && !hasKatana) {
            ShinobiCore.LOGGER.debug("[KICK] Hand has non-katana item, aborting");
            return false;
        }
        long now = System.currentTimeMillis();
        long remaining = kickCooldownEnd - now;
        if (now < kickCooldownEnd) {
            ShinobiCore.LOGGER.debug("[KICK] On cooldown, {}ms remaining", remaining);
            return false;
        }
        TaijutsuStyle style = TaijutsuClientHandler.getCurrentStyle();
        boolean chakraMode = ClientNinjaState.chakraMode;
        int taijutsuLevel = ClientNinjaState.statLevels.getOrDefault("taijutsu", 0);
        ShinobiCore.LOGGER.debug("[KICK] Performing kick: style={}, chakra={}, level={}",
                style.getId(), chakraMode, taijutsuLevel);
        ShinobiCore.LOGGER.debug("[KICK] Sending packet to server");
        sendKickPacket(style);
        ShinobiCore.LOGGER.debug("[KICK] Playing animation");
        TaijutsuAnimations.playKickAnimation(player, style);
        ShinobiCore.LOGGER.debug("[KICK] Playing particles");
        TaijutsuParticleEffects.playKickParticles(player, style);
        ShinobiCore.LOGGER.debug("[KICK] Swinging hand");
        player.swingHand(Hand.MAIN_HAND);
        TaijutsuSounds.playKickSound();
        TaijutsuSounds.playWhoosh();
        kickCooldownEnd = now + KICK_COOLDOWN_MS;
        ShinobiCore.LOGGER.debug("[KICK] Cooldown set until {}", kickCooldownEnd);
        ShinobiCore.LOGGER.debug("[KICK] SUCCESS");
        return true;
    }
    private static void sendKickPacket(TaijutsuStyle style) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString(style.getId());
        ClientPlayNetworking.send(ModPackets.TAIJUTSU_KICK_ID, buf);
    }
    public static long getCooldownRemainingMs() {
        long now = System.currentTimeMillis();
        return Math.max(0, kickCooldownEnd - now);
    }
    public static float getCooldownRatio() {
        return getCooldownRemainingMs() / (float) KICK_COOLDOWN_MS;
    }
    public static boolean isOnCooldown() {
        return System.currentTimeMillis() < kickCooldownEnd;
    }
}

# ================= src\main\java\com\example\shinobicore\client\combat\TaijutsuParticleEffects.java =================
package com.example.shinobicore.client.combat;

import com.example.shinobicore.combat.TaijutsuStyle;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;

import java.util.Random;

public class TaijutsuParticleEffects {
    
    private static final Random random = new Random();
      public static void playKickParticles(AbstractClientPlayerEntity player, TaijutsuStyle style) {
        MinecraftClient client = MinecraftClient.getInstance();
        Vec3d pos = player.getPos().add(0, 0.5, 0); // ноги
        Vec3d look = player.getRotationVector();
        Vec3d particlePos = pos.add(look.multiply(1.0));

        int count = 15;
        for (int i = 0; i < count; i++) {
            double offsetX = (random.nextDouble() - 0.5) * 0.6;
            double offsetY = random.nextDouble() * 0.3;
            double offsetZ = (random.nextDouble() - 0.5) * 0.6;

            if (style == TaijutsuStyle.STRONG_FIST) {
                client.world.addParticle(ParticleTypes.CLOUD,
                    particlePos.x + offsetX, particlePos.y + offsetY, particlePos.z + offsetZ,
                    0, 0.05, 0);
            } else {
                client.world.addParticle(ParticleTypes.POOF,
                    particlePos.x + offsetX, particlePos.y + offsetY, particlePos.z + offsetZ,
                    0, 0.08, 0);
            }
        }

        // Ударная волна
        for (int i = 0; i < 10; i++) {
            double angle = (i / 10.0) * Math.PI * 2;
            double r = 0.5;
            client.world.addParticle(ParticleTypes.CRIT,
                particlePos.x + Math.cos(angle) * r,
                particlePos.y + 0.2,
                particlePos.z + Math.sin(angle) * r,
                0, 0.1, 0);
        }
    }  
    public static void playAttackParticles(AbstractClientPlayerEntity player, int comboStep, TaijutsuStyle style) {
        MinecraftClient client = MinecraftClient.getInstance();
        Vec3d pos = player.getPos().add(0, player.getHeight() * 0.7, 0);
        Vec3d look = player.getRotationVector();
        Vec3d particlePos = pos.add(look.multiply(1.2));
        
        int count = 3 + comboStep * 2;
        
        for (int i = 0; i < count; i++) {
            double offsetX = (random.nextDouble() - 0.5) * 0.5;
            double offsetY = (random.nextDouble() - 0.5) * 0.5;
            double offsetZ = (random.nextDouble() - 0.5) * 0.5;
            
            if (style == TaijutsuStyle.STRONG_FIST) {
                // Зелёные частицы для Strong Fist
                client.world.addParticle(
                    ParticleTypes.HAPPY_VILLAGER,
                    particlePos.x + offsetX,
                    particlePos.y + offsetY,
                    particlePos.z + offsetZ,
                    0, 0.1, 0
                );
            } else {
                // Обычные критические искры
                client.world.addParticle(
                    ParticleTypes.CRIT,
                    particlePos.x + offsetX,
                    particlePos.y + offsetY,
                    particlePos.z + offsetZ,
                    0, 0.1, 0
                );
            }
        }
        
        // Дополнительные частицы для финишера
        if (comboStep == 3) {
            for (int i = 0; i < 15; i++) {
                client.world.addParticle(
                    ParticleTypes.ENCHANT,
                    particlePos.x + (random.nextDouble() - 0.5) * 1.0,
                    particlePos.y + (random.nextDouble() - 0.5) * 1.0,
                    particlePos.z + (random.nextDouble() - 0.5) * 1.0,
                    0, 0.1, 0
                );
            }
        }
    }
}

# ================= src\main\java\com\example\shinobicore\client\combat\TaijutsuSounds.java =================
package com.example.shinobicore.client.combat;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvent;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.Identifier;

public class TaijutsuSounds {
    // Кастомные звуки (пока используем ванильные как заглушки)
    public static final SoundEvent PUNCH_LIGHT = SoundEvent.of(new Identifier("shinobicore", "punch_light"));
    public static final SoundEvent PUNCH_HEAVY = SoundEvent.of(new Identifier("shinobicore", "punch_heavy"));
    public static final SoundEvent KICK = SoundEvent.of(new Identifier("shinobicore", "kick"));
    public static final SoundEvent WHOOSH = SoundEvent.of(new Identifier("shinobicore", "whoosh"));

    // Флаг для определения, зарегистрированы ли кастомные звуки
    private static boolean customSoundsRegistered = false;

    public static void playPunchSound(int comboStep) {
        MinecraftClient client = MinecraftClient.getInstance();
        ClientPlayerEntity player = client.player;
        if (player == null) {
            ShinobiCore.LOGGER.warn("[SOUND] playPunchSound: player is null");
            return;
        }

        SoundEvent sound;
        String soundName;
        float pitch;

        if (comboStep >= 2) {
            // Тяжёлый удар (шаги 2-3)
            if (customSoundsRegistered) {
                sound = PUNCH_HEAVY;
                soundName = "punch_heavy";
            } else {
                sound = SoundEvents.ENTITY_PLAYER_ATTACK_STRONG;
                soundName = "ENTITY_PLAYER_ATTACK_STRONG (fallback)";
            }
            pitch = 0.9f + (float) Math.random() * 0.2f;
        } else {
            // Лёгкий удар (шаги 0-1)
            if (customSoundsRegistered) {
                sound = PUNCH_LIGHT;
                soundName = "punch_light";
            } else {
                sound = SoundEvents.ENTITY_PLAYER_ATTACK_WEAK;
                soundName = "ENTITY_PLAYER_ATTACK_WEAK (fallback)";
            }
            pitch = 1.0f + (float) Math.random() * 0.2f;
        }

        ShinobiCore.LOGGER.info("[SOUND] Playing punch sound: comboStep={}, sound={}, pitch={:.2f}",
                comboStep, soundName, pitch);

        try {
            player.playSound(sound, SoundCategory.PLAYERS, 1.0f, pitch);
            ShinobiCore.LOGGER.info("[SOUND] ✓ Punch sound played successfully");
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[SOUND] ✗ Failed to play punch sound: {}", e.getMessage());
            e.printStackTrace();
        }
    }

    public static void playKickSound() {
        MinecraftClient client = MinecraftClient.getInstance();
        ClientPlayerEntity player = client.player;
        if (player == null) {
            ShinobiCore.LOGGER.warn("[SOUND] playKickSound: player is null");
            return;
        }

        SoundEvent sound;
        String soundName;

        if (customSoundsRegistered) {
            sound = KICK;
            soundName = "kick";
        } else {
            sound = SoundEvents.ENTITY_PLAYER_ATTACK_CRIT;
            soundName = "ENTITY_PLAYER_ATTACK_CRIT (fallback)";
        }

        float pitch = 0.95f + (float) Math.random() * 0.1f;

        ShinobiCore.LOGGER.info("[SOUND] Playing kick sound: sound={}, pitch={:.2f}", soundName, pitch);

        try {
            player.playSound(sound, SoundCategory.PLAYERS, 1.0f, pitch);
            ShinobiCore.LOGGER.info("[SOUND] ✓ Kick sound played successfully");
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[SOUND] ✗ Failed to play kick sound: {}", e.getMessage());
            e.printStackTrace();
        }
    }

    public static void playWhoosh() {
        MinecraftClient client = MinecraftClient.getInstance();
        ClientPlayerEntity player = client.player;
        if (player == null) {
            ShinobiCore.LOGGER.warn("[SOUND] playWhoosh: player is null");
            return;
        }

        SoundEvent sound;
        String soundName;

        if (customSoundsRegistered) {
            sound = WHOOSH;
            soundName = "whoosh";
        } else {
            sound = SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP;
            soundName = "ENTITY_PLAYER_ATTACK_SWEEP (fallback)";
        }

        float pitch = 0.8f + (float) Math.random() * 0.3f;

        ShinobiCore.LOGGER.info("[SOUND] Playing whoosh sound: sound={}, pitch={:.2f}", soundName, pitch);

        try {
            player.playSound(sound, SoundCategory.PLAYERS, 0.6f, pitch);
            ShinobiCore.LOGGER.info("[SOUND] ✓ Whoosh sound played successfully");
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[SOUND] ✗ Failed to play whoosh sound: {}", e.getMessage());
            e.printStackTrace();
        }
    }

    public static void setCustomSoundsRegistered(boolean registered) {
        customSoundsRegistered = registered;
        ShinobiCore.LOGGER.info("[SOUND] Custom sounds registered: {}", registered);
    }
}

# ================= src\main\java\com\example\shinobicore\client\ControlTrainingScreen.java =================
package com.example.shinobicore.client;

import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;

public class ControlTrainingScreen extends Screen {

    private long startTime;
    private int hits = 0;
    private int attemptsLeft = 5;
    private int endTimer = -1;
    private String lastMsg = "";
    private float speed;
    private float targetCenter;
    private float targetWidth;

    public ControlTrainingScreen() {
        super(Text.literal("Chakra Control Training"));
        startTime = System.currentTimeMillis();
        int control = ClientNinjaState.statLevels.getOrDefault("control", 0);
        speed = 1.2f + control * 0.012f;
        targetWidth = Math.max(0.12f, 0.3f - control * 0.0018f);
        targetCenter = 0.35f + (float)(Math.random() * 0.3);
    }

    private float pulse() {
        float t = (System.currentTimeMillis() - startTime) / 1000f;
        return (float)(0.5 + 0.5 * Math.sin(t * speed * Math.PI * 2));
    }

    @Override
    public void render(DrawContext ctx, int mx, int my, float delta) {
        renderBackground(ctx);
        super.render(ctx, mx, my, delta);
        int cx = width / 2, cy = height / 2;
        int maxR = 70;

        int r1 = (int)(maxR * (targetCenter - targetWidth / 2));
        int r2 = (int)(maxR * (targetCenter + targetWidth / 2));
        for (int r = r1; r <= r2; r += 2) {
            drawCircleOutline(ctx, cx, cy, r, 0x4444FF44);
        }

        float p = pulse();
        int r = Math.max(4, (int)(maxR * p));
        drawCircleOutline(ctx, cx, cy, r, 0xFF44AAFF);
        drawCircleOutline(ctx, cx, cy, r - 1, 0xFF88CCFF);

        drawCentered(ctx, "Chakra Control Training", cx, cy - maxR - 34, 0xFF44AAFF);
        drawCentered(ctx, "LMB when blue circle is in green zone", cx, cy - maxR - 22, 0xFFAAAAAA);
        drawCentered(ctx, "Hits: " + hits + "  |  Left: " + attemptsLeft, cx, cy + maxR + 16, 0xFFFFFFFF);
        drawCentered(ctx, lastMsg, cx, cy + maxR + 30, 0xFF88FF88);
        drawCentered(ctx, "ESC - exit", cx, cy + maxR + 44, 0xFF888888);
    }

    @Override
    public void tick() {
        if (endTimer > 0) {
            endTimer--;
            if (endTimer <= 0) close();
        }
    }

    @Override
    public boolean mouseClicked(double mx, double my, int button) {
        if (button != 0 || attemptsLeft <= 0) return true;
        float p = pulse();
        float diff = Math.abs(p - targetCenter);
        boolean success = diff <= targetWidth / 2f;
        float accuracy = success ? 1f - diff / (targetWidth / 2f) : 0f;
        if (success) hits++;
        attemptsLeft--;
        lastMsg = success ? String.format("HIT! accuracy %.0f%%", accuracy * 100) : "Miss...";
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeBoolean(success);
        buf.writeFloat(accuracy);
        ClientPlayNetworking.send(ModPackets.CONTROL_TRAIN_ID, buf);
        if (attemptsLeft > 0) {
            targetCenter = 0.2f + (float)(Math.random() * 0.6);
            startTime = System.currentTimeMillis();
        } else {
            endTimer = 40;
        }
        return true;
    }

    private void drawCircleOutline(DrawContext ctx, int cx, int cy, int r, int color) {
        if (r <= 0) return;
        int steps = Math.max(24, r * 4);
        for (int i = 0; i < steps; i++) {
            float a = (float)(i * 2 * Math.PI / steps);
            int x = cx + (int)(Math.cos(a) * r);
            int y = cy + (int)(Math.sin(a) * r);
            ctx.fill(x, y, x + 1, y + 1, color);
        }
    }

    private void drawCentered(DrawContext ctx, String text, int cx, int y, int color) {
        int w = textRenderer.getWidth(text);
        ctx.drawText(textRenderer, text, cx - w / 2, y, color, false);
    }

    @Override
    public boolean shouldPause() { return false; }
}

# ================= src\main\java\com\example\shinobicore\client\IdlePoseSystem.java =================
package com.example.shinobicore.client;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import net.minecraft.item.ItemStack;
import net.minecraft.item.SwordItem;
import net.minecraft.util.math.MathHelper;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
public class IdlePoseSystem {
    private static final Map<UUID, FidgetState> STATES = new HashMap<>();
    private static class FidgetState {
        long nextFidgetAt = 0;
        int fidget = -1;
        long fidgetStart = 0;
    }
    public static void apply(AbstractClientPlayerEntity player, BipedEntityModel<?> model,
                             float moveAmount, float animProgress) {
        if (moveAmount > 0.1f) return;
        float breath = MathHelper.sin(animProgress * 0.07f) * 0.03f;
        if (ClientNinjaState.meditating) { applyMeditate(model, breath); return; }
        if (ChakraPhysicsClient.stickingToWall) { applyWallStick(model); return; }
        ItemStack main = player.getMainHandStack();
        if (main.getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            applyKatanaStance(model, breath);
            return;
        }
        boolean isThrowing = main.getItem() instanceof com.example.shinobicore.item.ThrowingWeaponItem;
        boolean weapon = !main.isEmpty() && (main.getItem() instanceof SwordItem || isThrowing);
        boolean chakra = ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0;
        if (weapon) applyWeaponStance(model, breath);
        else if (chakra) applyNinjaGuard(model, breath);
        else applyNormalIdle(model, breath, player);
    }
    private static void applyMeditate(BipedEntityModel<?> m, float breath) {
        m.rightArm.pitch = -0.9f + breath;
        m.leftArm.pitch = -0.9f + breath;
        m.rightArm.yaw = -0.5f;
        m.leftArm.yaw = 0.5f;
        m.head.pitch += 0.25f;
        m.body.pitch += 0.12f;
        m.rightLeg.yaw = 0.5f;
        m.leftLeg.yaw = -0.5f;
        m.rightLeg.pitch = -1.1f;
        m.leftLeg.pitch = -1.1f;
    }
    private static void applyWallStick(BipedEntityModel<?> m) {
        m.rightArm.pitch = -1.5f;
        m.leftArm.pitch = -1.5f;
        m.rightArm.yaw = -0.15f;
        m.leftArm.yaw = 0.15f;
        m.head.pitch -= 0.1f;
    }
    private static void applyWeaponStance(BipedEntityModel<?> m, float breath) {
        m.rightArm.pitch = -1.15f + breath;
        m.rightArm.yaw = -0.25f;
        m.leftArm.pitch = -0.75f + breath;
        m.leftArm.yaw = 0.45f;
        m.body.pitch += 0.10f;
        m.rightLeg.yaw = -0.25f;
        m.leftLeg.yaw = 0.25f;
        m.head.pitch -= 0.08f;
    }
    private static void applyNinjaGuard(BipedEntityModel<?> m, float breath) {
        m.rightArm.pitch = -0.95f + breath;
        m.rightArm.yaw = -0.40f;
        m.leftArm.pitch = -0.70f + breath;
        m.leftArm.yaw = 0.50f;
        m.body.pitch += 0.12f;
        m.rightLeg.yaw = -0.22f;
        m.leftLeg.yaw = 0.22f;
        m.rightLeg.pitch += 0.08f;
        m.leftLeg.pitch += 0.08f;
        m.head.pitch -= 0.10f;
    }
    private static void applyKatanaStance(BipedEntityModel<?> m, float breath) {
        String st = ClientNinjaState.kenjutsuStance;
        switch (st) {
            case "seigan" -> {
                m.rightArm.pitch = -1.2f + breath;
                m.rightArm.yaw = -0.2f;
                m.leftArm.pitch = -0.7f + breath;
                m.leftArm.yaw = 0.3f;
            }
            case "iai" -> {
                m.rightArm.pitch = 0.15f + breath;
                m.rightArm.yaw = -0.5f;
                m.leftArm.pitch = -0.9f + breath;
                m.leftArm.yaw = 0.6f;
            }
            default -> {
                m.rightArm.pitch = -1.1f + breath;
                m.rightArm.yaw = -0.3f;
                m.leftArm.pitch = -1.0f + breath;
                m.leftArm.yaw = 0.2f;
            }
        }
        m.body.pitch += 0.08f;
        m.rightLeg.yaw = -0.2f;
        m.leftLeg.yaw = 0.2f;
        m.head.pitch -= 0.06f;
    }
    private static void applyNormalIdle(BipedEntityModel<?> m, float breath, AbstractClientPlayerEntity player) {
        m.body.pitch += breath * 0.6f;
        m.rightArm.pitch += breath;
        m.leftArm.pitch += breath;
        FidgetState st = STATES.computeIfAbsent(player.getUuid(), u -> new FidgetState());
        long now = System.currentTimeMillis();
        if (st.fidget >= 0) {
            float p = (now - st.fidgetStart) / 2500f;
            if (p >= 1f) {
                st.fidget = -1;
                st.nextFidgetAt = now + 5000 + (long)(Math.random() * 7000);
            } else {
                float f = MathHelper.sin(p * (float) Math.PI);
                switch (st.fidget) {
                    case 0 -> m.head.yaw += f * 0.6f;
                    case 1 -> {
                        m.body.roll += f * 0.06f;
                        m.rightLeg.yaw -= f * 0.15f;
                        m.leftLeg.yaw += f * 0.15f;
                    }
                    case 2 -> {
                        m.rightArm.pitch += f * -1.6f;
                        m.rightArm.yaw += f * -0.5f;
                    }
                }
            }
        } else if (now >= st.nextFidgetAt) {
            st.fidget = (int)(Math.random() * 3);
            st.fidgetStart = now;
        }
    }
}

# ================= src\main\java\com\example\shinobicore\client\KeyBindings.java =================
package com.example.shinobicore.client;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;
public class KeyBindings {
    public static final String CATEGORY = "key.categories.shinobicore";
    public static final String COMBAT_CATEGORY = "key.categories.shinobicore.combat";
    public static KeyBinding MEDITATE;
    public static KeyBinding CAST_A;
    public static KeyBinding CAST_B;
    public static KeyBinding CYCLE_A;
    public static KeyBinding CYCLE_B;
    public static KeyBinding PROGRESSION;
    public static KeyBinding CHAKRA_MODE;
    public static KeyBinding DODGE_LEFT;
    public static KeyBinding DODGE_RIGHT;
    public static KeyBinding CRAWL;
    public static KeyBinding KICK;
    public static KeyBinding SWITCH_STYLE;
    public static KeyBinding SWITCH_STANCE;
    public static KeyBinding KATANA_DEFLECT;
    public static KeyBinding TOGGLE_SENSORY;
    public static void register() {
        MEDITATE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.meditate", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_M, CATEGORY));
        PROGRESSION = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.progression", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_K, CATEGORY));
        CHAKRA_MODE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.chakra_mode", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_L, CATEGORY));
        CAST_A = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cast", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_R, CATEGORY));
        CAST_B = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cast_b", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_T, CATEGORY));
        CYCLE_A = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cycle_slot", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_G, CATEGORY));
        CYCLE_B = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.cycle_b", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_H, CATEGORY));
        DODGE_LEFT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.dodge_left", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Z, CATEGORY));
        DODGE_RIGHT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.dodge_right", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_C, CATEGORY));
        CRAWL = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.crawl", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_N, CATEGORY));
        KICK = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.kick", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_V, COMBAT_CATEGORY));
        SWITCH_STYLE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.switch_style", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_B, COMBAT_CATEGORY));
        SWITCH_STANCE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.switch_stance", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_F, COMBAT_CATEGORY));
        KATANA_DEFLECT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.katana_deflect", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_X, COMBAT_CATEGORY));
        TOGGLE_SENSORY = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.toggle_sensory", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Y, CATEGORY));
    }
}

# ================= src\main\java\com\example\shinobicore\client\parkour\actions\ChargedJumpAction.java =================
package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ChakraPhysicsClient;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import com.example.shinobicore.stat.NinjaFormula;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class ChargedJumpAction implements ParkourAction {
    public static final String ID = "charged_jump";

    private static final int MAX_CHARGE_TICKS = 60;
    private static final int MIN_CHARGE_TICKS = 5;  // 0.25 сек до появления бара
    private static final float CHARGE_MULTIPLIER = 2.0f;

    private int chargeTicks = 0;
    private boolean charging = false;
    private boolean jumpPressed = false;

    @Override
    public String getId() { return ID; }

    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        return false;
    }

    @Override
    public void activate(ClientPlayerEntity player, ParkourContext ctx) {
    }

    @Override
    public void tick(ClientPlayerEntity player, ParkourContext ctx) {
        if (!ClientNinjaState.chakraMode || ChakraHudRenderer.currentChakra <= 0 || ChakraHudRenderer.exhausted) {
            resetCharge();
            return;
        }

        boolean onGround = player.isOnGround() || ChakraPhysicsClient.standingOnWater;
        boolean jumping = player.input.jumping;

        if (onGround && jumping && !jumpPressed) {
            charging = true;
            chargeTicks = 0;
            jumpPressed = true;
        } else if (onGround && jumping && jumpPressed) {
            if (charging) {
                chargeTicks = Math.min(chargeTicks + 1, MAX_CHARGE_TICKS);
                if (chargeTicks >= MIN_CHARGE_TICKS && chargeTicks % 10 == 0) {
                    ParkourSounds.playChargeHum((float) chargeTicks / MAX_CHARGE_TICKS);
                }
            }
        } else if (onGround && !jumping && jumpPressed) {
            if (charging) {
                if (chargeTicks < MIN_CHARGE_TICKS) {
                    // Короткое нажатие — обычный прыжок с прокачкой
                    doVanillaJump(player);
                } else {
                    // Длинное нажатие — заряженный прыжок (x3 от базового + бонусы)
                    float chargeRatio = (float) chargeTicks / MAX_CHARGE_TICKS;
                    float chargeMultiplier = 1.0f + chargeRatio * CHARGE_MULTIPLIER;
                    
                    doVanillaJump(player);
                    
                    // Умножаем вертикальную скорость на множитель заряда
                    Vec3d v = player.getVelocity();
                    player.setVelocity(v.x, v.y * chargeMultiplier, v.z);
                    player.velocityModified = true;
                    
                    ParkourSounds.playChargedJump();
                    sendChargedJumpPacket(chargeRatio);
                }
                resetCharge();
            }
            jumpPressed = false;
        } else if (!onGround) {
            resetCharge();
            jumpPressed = false;
        }
    }

    /**
     * Ванильный прыжок с учётом jumpLevel и чакра-режима.
     * Повторяет логику ChakraPhysicsClient.applyJumpBoost().
     */
    private void doVanillaJump(ClientPlayerEntity player) {
        // Базовая вертикальная скорость ванильного прыжка
        player.setVelocity(player.getVelocity().x, 0.42, player.getVelocity().z);
        player.velocityModified = true;

        int jumpLevel = ClientNinjaState.jumpLevel;
        boolean chakraOn = true;  // мы в чакра-режиме

        // === Горизонтальный буст (от jumpLevel) ===
        float horizMult = NinjaFormula.jumpHorizontalMultiplier(jumpLevel, chakraOn);
        if (horizMult > 1.0f) {
            Vec3d velocity = player.getVelocity();
            double horizSpeed = Math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);
            if (horizSpeed > 0.01) {
                double boost = (horizMult - 1.0) * horizSpeed;
                player.addVelocity(velocity.x / horizSpeed * boost, 0, velocity.z / horizSpeed * boost);
            }
        }

        // === Вертикальный буст (в чакра-режиме) ===
        float vertMult = NinjaFormula.jumpVerticalMultiplier(jumpLevel, true);
        if (vertMult > 1.0f) {
            player.addVelocity(0, 0.42 * (vertMult - 1.0), 0);
        }

        // === Спринт-буст (в чакра-режиме) ===
        if (player.isSprinting()) {
            player.addVelocity(0, 0.3, 0);
            Vec3d velocity = player.getVelocity();
            player.addVelocity(velocity.x * 0.5, 0, velocity.z * 0.5);
        }

        player.velocityModified = true;
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        resetCharge();
    }

    public void resetCharge() {
        charging = false;
        chargeTicks = 0;
    }

    public int getChargeTicks() { return chargeTicks; }
    public float getChargeRatio() { return (float) chargeTicks / MAX_CHARGE_TICKS; }

    public boolean isCharging() { return charging && chargeTicks >= MIN_CHARGE_TICKS; }

    @Override
    public int getCooldownTicks() { return 0; }

    @Override
    public float getFatigueCost() { return 0f; }

    private void sendChargedJumpPacket(float chargeRatio) {
        float fatigue = chargeRatio * 2.0f;
        ParkourManager.sendChargedJumpFatigue(fatigue);
    }
}

# ================= src\main\java\com\example\shinobicore\client\parkour\actions\CrawlAction.java =================
package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.client.KeyBindings;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.parkour.util.PoseHelper;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class CrawlAction implements ParkourAction {
    public static final String ID = "crawl";

    private boolean active = false;

    @Override
    public String getId() { return ID; }

    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        if (!player.isOnGround()) return false;
        if (ParkourManager.isSliding()) return false;
        return KeyBindings.CRAWL.isPressed() || PoseHelper.cannotStand(player);
    }

    @Override
    public void activate(ClientPlayerEntity player, ParkourContext ctx) {
        active = true;
        PoseHelper.forceLowPose(player);
        ctx.resetActive(ID);
    }

    @Override
    public void tick(ClientPlayerEntity player, ParkourContext ctx) {
        if (!active) return;

        boolean wantCrawl = KeyBindings.CRAWL.isPressed();
        boolean forced = PoseHelper.cannotStand(player);

        if (!player.isOnGround() || (!wantCrawl && !forced)) {
            deactivate(player, ctx);
            return;
        }

        Vec3d v = player.getVelocity();
        player.setVelocity(v.x * 0.5, v.y, v.z * 0.5);
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        active = false;
        PoseHelper.releasePose(player);
        ctx.setCooldown(ID, getCooldownTicks());
        ctx.clearActive(ID);
    }

    public boolean isActive() { return active; }

    @Override
    public int getCooldownTicks() { return 5; }

    @Override
    public float getFatigueCost() { return 0f; }
}

# ================= src\main\java\com\example\shinobicore\client\parkour\actions\DodgeAction.java =================
package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.KeyBindings;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class DodgeAction implements ParkourAction {
    public static final String ID = "dodge";

    private static final int DODGE_DURATION = 8;
    private static final int INVULNERABILITY_TICKS = 6;
    private static final float DODGE_IMPULSE = 1.2f;
    private static final long COOLDOWN_MS = 1000;

    private boolean active = false;
    private int dodgeTicks = 0;
    private int pendingDirection = 0;
    
    // ✅ Отслеживаем состояние клавиш КАЖДЫЙ тик (static чтобы работало всегда)
    private static boolean prevLeftDown = false;
    private static boolean prevRightDown = false;
    private static long lastDodgeTime = 0;

    @Override
    public String getId() { return ID; }

    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        // ✅ Читаем текущее состояние клавиш
        boolean leftDown = KeyBindings.DODGE_LEFT.isPressed();
        boolean rightDown = KeyBindings.DODGE_RIGHT.isPressed();
        
        // ✅ Определяем НОВОЕ нажатие (переход false → true)
        boolean leftJustPressed = leftDown && !prevLeftDown;
        boolean rightJustPressed = rightDown && !prevRightDown;
        
        // ✅ ОБНОВЛЯЕМ предыдущее состояние КАЖДЫЙ тик (критично!)
        prevLeftDown = leftDown;
        prevRightDown = rightDown;
        
        // Если нет нового нажатия — выходим
        if (!leftJustPressed && !rightJustPressed) {
            return false;
        }
        
        // Если dodge уже активен — не активируем повторно
        if (active) return false;
        
        // Кулдаун
        long now = System.currentTimeMillis();
        if (now - lastDodgeTime < COOLDOWN_MS) {
            ShinobiCore.LOGGER.debug("[DODGE] Cooldown: {}ms remaining", COOLDOWN_MS - (now - lastDodgeTime));
            return false;
        }
        
        if (!ClientNinjaState.chakraMode) return false;
        if (ChakraHudRenderer.currentChakra <= 0) return false;
        if (ChakraHudRenderer.exhausted) return false;
        
        // Определяем направление
        if (leftJustPressed && !rightJustPressed) {
            pendingDirection = -1;
            ShinobiCore.LOGGER.debug("[DODGE] NEW PRESS: LEFT");
        } else if (rightJustPressed && !leftJustPressed) {
            pendingDirection = 1;
            ShinobiCore.LOGGER.debug("[DODGE] NEW PRESS: RIGHT");
        } else {
            pendingDirection = -1; // Обе нажаты → влево
            ShinobiCore.LOGGER.debug("[DODGE] NEW PRESS: BOTH → LEFT");
        }
        
        return true;
    }

    @Override
    public void activate(ClientPlayerEntity player, ParkourContext ctx) {
        active = true;
        dodgeTicks = 0;
        lastDodgeTime = System.currentTimeMillis();
        
        int direction = pendingDirection != 0 ? pendingDirection : 1;
        
        Vec3d look = player.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();
        
        player.addVelocity(right.x * direction * DODGE_IMPULSE, 0.2, right.z * direction * DODGE_IMPULSE);
        player.velocityModified = true;
        player.timeUntilRegen = INVULNERABILITY_TICKS;
        
        ShinobiCore.LOGGER.debug("[DODGE] Activated: direction={} ({})", 
            direction, direction < 0 ? "LEFT" : "RIGHT");
        
        ctx.resetActive(ID);
        ParkourSounds.playRoll();
    }

    @Override
    public void tick(ClientPlayerEntity player, ParkourContext ctx) {
        if (!active) return;
        
        dodgeTicks++;
        
        if (dodgeTicks > DODGE_DURATION) {
            deactivate(player, ctx);
            return;
        }
        
        if (dodgeTicks <= INVULNERABILITY_TICKS) {
            player.timeUntilRegen = INVULNERABILITY_TICKS - dodgeTicks;
        }
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        active = false;
        dodgeTicks = 0;
        pendingDirection = 0;
        ctx.clearActive(ID);
    }
    
    public boolean isActive() { return active; }

    @Override
    public int getCooldownTicks() { return 20; }

    @Override
    public float getFatigueCost() { return 2.0f; }
}

# ================= src\main\java\com\example\shinobicore\client\parkour\actions\EdgeGrabAction.java =================
package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import com.example.shinobicore.client.parkour.util.WallDetector;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

public class EdgeGrabAction implements ParkourAction {
    public static final String ID = "edge_grab";

    private boolean active = false;
    private BlockPos ledgePos = null;

    @Override
    public String getId() { return ID; }

    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        if (!ClientNinjaState.chakraMode) return false;
        if (ChakraHudRenderer.currentChakra <= 0) return false;
        if (ChakraHudRenderer.exhausted) return false;
        if (ctx.isOnCooldown(ID)) return false;
        
        // Должен падать
        if (player.isOnGround()) return false;
        if (player.getVelocity().y >= 0) return false; // только при падении
        
        // Проверяем наличие края
        BlockPos ledge = WallDetector.getLedgeAbove(player);
        if (ledge == null) return false;
        
        // Сохраняем позицию края для tick()
        this.ledgePos = ledge;
        return true;
    }

    @Override
    public void activate(ClientPlayerEntity player, ParkourContext ctx) {
        active = true;
        
        // Обнуляем скорость (зависаем на краю)
        player.setVelocity(0, 0, 0);
        player.velocityModified = true;
        
        ctx.resetActive(ID);
        ParkourSounds.playEdgeGrab();
    }

    @Override
    public void tick(ClientPlayerEntity player, ParkourContext ctx) {
        if (!active) return;
        
        // Удерживаем игрока на месте
        player.setVelocity(0, 0, 0);
        player.velocityModified = true;
        player.fallDistance = 0f;
        
        // Если нажал Space — подтягивание
        if (player.input.jumping && ledgePos != null) {
            player.setPosition(player.getX(), ledgePos.getY() + 0.001, player.getZ());
            player.setVelocity(player.getVelocity().x * 0.3, 0.42, player.getVelocity().z * 0.3);
            player.velocityModified = true;
            player.setOnGround(true);
            ParkourSounds.playEdgeClimb();
            deactivate(player, ctx);
        }
        
        // Если отпустил все клавиши — продолжаем падать
        if (!player.input.sneaking && !player.input.pressingForward && !player.input.jumping) {
            // Проверяем что всё ещё есть край (может стена исчезла)
            if (WallDetector.getLedgeAbove(player) == null) {
                deactivate(player, ctx);
            }
        }
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        active = false;
        ledgePos = null;
        ctx.setCooldown(ID, getCooldownTicks());
        ctx.clearActive(ID);
    }

    public boolean isActive() { return active; }

    @Override
    public int getCooldownTicks() { return 20; }  // 1 сек

    @Override
    public float getFatigueCost() { return 0.5f; }
}

# ================= src\main\java\com\example\shinobicore\client\parkour\actions\ParkourAction.java =================
package com.example.shinobicore.client.parkour.actions;

import net.minecraft.client.network.ClientPlayerEntity;

public interface ParkourAction {
    String getId();
    
    // Проверяет, можно ли активировать действие сейчас
    boolean canActivate(ClientPlayerEntity player, ParkourContext ctx);
    
    // Активирует действие (применяет эффект)
    void activate(ClientPlayerEntity player, ParkourContext ctx);
    
    // Вызывается каждый тик пока действие активно
    void tick(ClientPlayerEntity player, ParkourContext ctx);
    
    // Деактивирует действие (если активна логика деактивации)
    void deactivate(ClientPlayerEntity player, ParkourContext ctx);
    
    // Кулдаун в тиках после деактивации
    int getCooldownTicks();
    
    // Усталость за активацию
    float getFatigueCost();
}

# ================= src\main\java\com\example\shinobicore\client\parkour\actions\ParkourContext.java =================
package com.example.shinobicore.client.parkour.actions;

import java.util.HashMap;
import java.util.Map;

public class ParkourContext {
    private final Map<String, Integer> cooldowns = new HashMap<>();
    private final Map<String, Integer> activeTicks = new HashMap<>();
    
    public boolean isOnCooldown(String actionId) {
        Integer cd = cooldowns.get(actionId);
        return cd != null && cd > 0;
    }
    
    public void setCooldown(String actionId, int ticks) {
        cooldowns.put(actionId, ticks);
    }
    
    public void tickCooldowns() {
        cooldowns.replaceAll((k, v) -> Math.max(0, v - 1));
        activeTicks.replaceAll((k, v) -> v + 1);
    }
    
    public int getActiveTicks(String actionId) {
        return activeTicks.getOrDefault(actionId, 0);
    }
    
    public void resetActive(String actionId) {
        activeTicks.put(actionId, 0);
    }
    
    public void clearActive(String actionId) {
        activeTicks.remove(actionId);
    }
}

# ================= src\main\java\com\example\shinobicore\client\parkour\actions\RollAction.java =================
package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;
import net.minecraft.util.math.Vec3d;

public class RollAction implements ParkourAction {
    public static final String ID = "roll";

    private static final int ROLL_DURATION = 15;  // 0.75 сек
    private static final int INVULNERABILITY_TICKS = 9;  // 60% от длительности (Dark Souls)
    private static final float ROLL_IMPULSE = 0.4f;
    private static final float ROLL_BOOST_PER_TICK = 0.02f;

    private boolean active = false;
    private int rollTicks = 0;
    private Vec3d rollDirection = Vec3d.ZERO;
    private float startRollAngle = 0f;

    @Override
    public String getId() { return ID; }
    public void updateInput(ClientPlayerEntity player) {
        // Roll не требует edge detection как slide
        // Активируется сразу при нажатии Shift в воздухе
    }
    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        if (player.isOnGround()) return false;
        if (!player.input.sneaking) return false;
        if (ChakraHudRenderer.currentChakra <= 0) return false;
        if (ChakraHudRenderer.exhausted) return false;
        if (ctx.isOnCooldown(ID)) return false;
        
        Vec3d horiz = new Vec3d(player.getVelocity().x, 0, player.getVelocity().z);
        return horiz.length() >= 0.15;  // нужна минимальная скорость
    }

    @Override
    public void activate(ClientPlayerEntity player, ParkourContext ctx) {
        active = true;
        rollTicks = 0;
        
        // Направление = вектор движения (не взгляд!)
        Vec3d horiz = new Vec3d(player.getVelocity().x, 0, player.getVelocity().z);
        rollDirection = horiz.normalize();
        
        // Начальный импульс
        player.addVelocity(rollDirection.x * ROLL_IMPULSE, 0, rollDirection.z * ROLL_IMPULSE);
        player.velocityModified = true;
        
        // Запоминаем угол для визуального эффекта
        startRollAngle = player.getPitch();
        
        // Меняем позу на плавание (визуально ниже)
        player.setPose(EntityPose.SWIMMING);
        
        ctx.resetActive(ID);
        ParkourSounds.playRoll();
    }

    @Override
    public void tick(ClientPlayerEntity player, ParkourContext ctx) {
        if (!active) return;
        
        rollTicks++;
        
        if (rollTicks > ROLL_DURATION || player.isOnGround()) {
            deactivate(player, ctx);
            return;
        }
        
        // Dark Souls i-frames: неуязвимость в первые 60% переката
        if (rollTicks <= INVULNERABILITY_TICKS) {
            player.timeUntilRegen = 5;  // неуязвимость
        }
        
        // Добавляем ускорение каждый тик (Dark Souls roll ускоряется)
        player.addVelocity(
            rollDirection.x * ROLL_BOOST_PER_TICK,
            0,
            rollDirection.z * ROLL_BOOST_PER_TICK
        );
        player.velocityModified = true;
        
        // Визуальный эффект: наклон камеры
        float progress = (float) rollTicks / ROLL_DURATION;
        float rollAngle = (float) Math.sin(progress * Math.PI) * 30f;  // наклон до 30°
        player.setPitch(startRollAngle + rollAngle);
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        active = false;
        rollTicks = 0;
        player.setPose(EntityPose.STANDING);  // Возвращаем нормальную позу
        player.setPitch(startRollAngle);  // Возвращаем угол камеры
        ctx.setCooldown(ID, getCooldownTicks());
        ctx.clearActive(ID);
    }

    public boolean isActive() { return active; }

    @Override
    public int getCooldownTicks() { return 30; }  // 1.5 сек

    @Override
    public float getFatigueCost() { return 1.5f; }
}

# ================= src\main\java\com\example\shinobicore\client\parkour\actions\SlideAction.java =================
package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import com.example.shinobicore.client.parkour.util.PoseHelper;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;
import net.minecraft.util.math.Vec3d;

public class SlideAction implements ParkourAction {
    public static final String ID = "slide";

    private static final int MAX_TICKS = 30;
    private static final float MIN_SPEED = 0.1f;
    private static final float REQUIRED_SPEED = 0.25f;
    private static final float INITIAL_BOOST = 0.35f;

    private boolean active = false;
    private boolean prevSneaking = false;
    private boolean justPressed = false;

    @Override
    public String getId() { return ID; }

    public void updateInput(ClientPlayerEntity player) {
        boolean now = player.input.sneaking;
        justPressed = now && !prevSneaking;
        prevSneaking = now;
    }

    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        if (!justPressed) return false;
        if (!player.isOnGround()) return false;
        if (ChakraHudRenderer.currentChakra <= 0) return false;
        if (ChakraHudRenderer.exhausted) return false;
        if (ctx.isOnCooldown(ID)) return false;
        Vec3d horiz = new Vec3d(player.getVelocity().x, 0, player.getVelocity().z);
        return horiz.length() >= REQUIRED_SPEED;
    }

    @Override
    public void activate(ClientPlayerEntity player, ParkourContext ctx) {
        active = true;
        Vec3d dir = new Vec3d(player.getVelocity().x, 0, player.getVelocity().z).normalize();
        player.addVelocity(dir.x * INITIAL_BOOST, 0, dir.z * INITIAL_BOOST);
        player.velocityModified = true;
        player.setSprinting(true);
        
        PoseHelper.forceLowPose(player);
        
        ctx.resetActive(ID);
        ParkourSounds.playSlide();
    }

    @Override
    public void tick(ClientPlayerEntity player, ParkourContext ctx) {
        if (!active) return;
        int ticks = ctx.getActiveTicks(ID);
        Vec3d horiz = new Vec3d(player.getVelocity().x, 0, player.getVelocity().z);

        if (ticks > MAX_TICKS || !player.isOnGround() || !player.input.sneaking || horiz.length() < MIN_SPEED) {
            deactivate(player, ctx);
            return;
        }

        player.setSprinting(true);
        if (ticks % 6 == 0) ParkourSounds.playSlideLoop();
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        active = false;
        PoseHelper.releasePose(player);
        ctx.setCooldown(ID, getCooldownTicks());
        ctx.clearActive(ID);
    }

    public boolean isActive() { return active; }

    @Override
    public int getCooldownTicks() { return 10; }

    @Override
    public float getFatigueCost() { return 0f; }
}

# ================= src\main\java\com\example\shinobicore\client\parkour\actions\WallRunAction.java =================
package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import com.example.shinobicore.client.parkour.util.WallDetector;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class WallRunAction implements ParkourAction {
    public static final String ID = "wall_run";

    private static final int MAX_TICKS = 40;  // 2 сек максимум
    private static final float MIN_SPEED = 0.15f;  // ниже — wall run заканчивается
    private static final float REQUIRED_SPEED = 0.2f;  // нужен разбег
    private static final float GRAVITY_FACTOR = 0.4f;  // 40% от нормальной гравитации
    private static final float TANGENTIAL_BOOST = 0.08f;  // добавка скорости вдоль стены за тик

    private boolean active = false;
    private int ticksRunning = 0;

    @Override
    public String getId() { return ID; }

    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        // Только в чакра-режиме
        if (!ClientNinjaState.chakraMode) return false;
        if (ChakraHudRenderer.currentChakra <= 0) return false;
        if (ChakraHudRenderer.exhausted) return false;
        if (ctx.isOnCooldown(ID)) return false;
        
        // Должен быть в воздухе и прилипнуть к стене
        if (player.isOnGround()) return false;
        Vec3d wallNormal = WallDetector.getWallNormal(player);
        if (wallNormal == null) return false;
        
        // Должен нажимать W (вперёд)
        if (!player.input.pressingForward) return false;
        
        // Должен иметь достаточную горизонтальную скорость
        Vec3d horiz = new Vec3d(player.getVelocity().x, 0, player.getVelocity().z);
        return horiz.length() >= REQUIRED_SPEED;
    }

    @Override
    public void activate(ClientPlayerEntity player, ParkourContext ctx) {
        active = true;
        ticksRunning = 0;
        ctx.resetActive(ID);
        ParkourSounds.playWallStick();  // звук прилипания при старте
    }

    @Override
    public void tick(ClientPlayerEntity player, ParkourContext ctx) {
        if (!active) return;
        
        ticksRunning++;
        
        // Условия выхода
        if (ticksRunning > MAX_TICKS || player.isOnGround()) {
            deactivate(player, ctx);
            return;
        }
        
        // Проверяем что всё ещё прилип к стене
        Vec3d wallNormal = WallDetector.getWallNormal(player);
        if (wallNormal == null) {
            deactivate(player, ctx);
            return;
        }
        
        // Если игрок отпустил W — переходим в wall slide (деактивируем wall run)
        if (!player.input.pressingForward) {
            deactivate(player, ctx);
            return;
        }
        
        Vec3d v = player.getVelocity();
        double horizSpeed = Math.sqrt(v.x * v.x + v.z * v.z);
        
        if (horizSpeed < MIN_SPEED) {
            deactivate(player, ctx);
            return;
        }
        
        // Вычисляем касательный вектор (вдоль стены)
        Vec3d up = new Vec3d(0, 1, 0);
        Vec3d tangent = wallNormal.crossProduct(up).normalize();
        
        // Определяем направление вдоль стены (по взгляду игрока)
        Vec3d lookHoriz = new Vec3d(player.getRotationVector().x, 0, player.getRotationVector().z).normalize();
        double dot = tangent.dotProduct(lookHoriz);
        if (dot < 0) tangent = tangent.negate();  // инвертируем если смотрит в противоположную сторону
        
        // Применяем движение вдоль стены + буст
        Vec3d newHoriz = tangent.multiply(horizSpeed + TANGENTIAL_BOOST);
        
        // Ослабленная гравитация
        double newVy = v.y - 0.08 * GRAVITY_FACTOR;  // 0.08 * 0.4 = 0.032 вместо 0.08
        
        player.setVelocity(newHoriz.x, newVy, newHoriz.z);
        player.velocityModified = true;
        
        // Звук шагов каждые 8 тиков
        if (ticksRunning % 8 == 0) {
            ParkourSounds.playWallRunStep();
        }
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        active = false;
        ticksRunning = 0;
        ctx.setCooldown(ID, getCooldownTicks());
        ctx.clearActive(ID);
    }

    public boolean isActive() { return active; }

    @Override
    public int getCooldownTicks() { return 20; }  // 1 сек кулдаун

    @Override
    public float getFatigueCost() { return 0.05f; }  // за тик
}

# ================= src\main\java\com\example\shinobicore\client\parkour\ParkourManager.java =================
package com.example.shinobicore.client.parkour;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.KeyBindings;
import com.example.shinobicore.client.parkour.actions.ChargedJumpAction;
import com.example.shinobicore.client.parkour.actions.CrawlAction;
import com.example.shinobicore.client.parkour.actions.DodgeAction;
import com.example.shinobicore.client.parkour.actions.EdgeGrabAction;
import com.example.shinobicore.client.parkour.actions.ParkourAction;
import com.example.shinobicore.client.parkour.actions.ParkourContext;
import com.example.shinobicore.client.parkour.actions.RollAction;
import com.example.shinobicore.client.parkour.actions.SlideAction;
import com.example.shinobicore.client.parkour.actions.WallRunAction;
import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.network.PacketByteBuf;

import java.util.ArrayList;
import java.util.List;

public class ParkourManager {
    private static final List<ParkourAction> actions = new ArrayList<>();
    private static final ParkourContext ctx = new ParkourContext();
    private static int logTimer = 0;
    private static ChargedJumpAction chargedJumpAction;
    private static boolean lastLowPose = false;

    public static void register() {
        actions.add(new SlideAction());
        actions.add(new WallRunAction());
        actions.add(new EdgeGrabAction());
        actions.add(new RollAction());
        actions.add(new CrawlAction());
        actions.add(new DodgeAction());  // ← ДОДЖ
        chargedJumpAction = new ChargedJumpAction();
        ShinobiCore.LOGGER.debug("ParkourManager: registered {} actions", actions.size());
    }

    public static void tick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        ctx.tickCooldowns();
        logTimer = (logTimer + 1) % 200;
        boolean doLog = (logTimer == 0);

        chargedJumpAction.tick(player, ctx);

        // Синхронизация низкой позы с сервером
        boolean needsLow = isSliding() || isCrawling() || isRolling()
            || com.example.shinobicore.client.parkour.util.PoseHelper.cannotStand(player);
        if (needsLow != lastLowPose) {
            lastLowPose = needsLow;
            PacketByteBuf poseBuf = new PacketByteBuf(Unpooled.buffer());
            poseBuf.writeBoolean(needsLow);
            ClientPlayNetworking.send(ModPackets.POSE_SYNC_ID, poseBuf);
        }

        for (ParkourAction action : actions) {
            if (action instanceof SlideAction slide) {
                slide.updateInput(player);
                if (slide.isActive()) {
                    slide.tick(player, ctx);
                } else if (slide.canActivate(player, ctx)) {
                    slide.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.debug("[parkour] slide activated");
                }
            } else if (action instanceof WallRunAction wallRun) {
                if (wallRun.isActive()) {
                    wallRun.tick(player, ctx);
                } else if (wallRun.canActivate(player, ctx)) {
                    wallRun.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.debug("[parkour] wall run activated");
                }
            } else if (action instanceof EdgeGrabAction edgeGrab) {
                if (edgeGrab.isActive()) {
                    edgeGrab.tick(player, ctx);
                } else if (edgeGrab.canActivate(player, ctx)) {
                    edgeGrab.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.debug("[parkour] edge grab activated");
                }
            } else if (action instanceof RollAction roll) {
                if (roll.isActive()) {
                    roll.tick(player, ctx);
                } else if (roll.canActivate(player, ctx)) {
                    roll.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.debug("[parkour] roll activated");
                }
            } else if (action instanceof CrawlAction crawl) {
                if (crawl.isActive()) {
                    crawl.tick(player, ctx);
                } else if (crawl.canActivate(player, ctx)) {
                    crawl.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.debug("[parkour] crawl activated");
                }
            } else if (action instanceof DodgeAction dodge) {
                if (dodge.isActive()) {
                    dodge.tick(player, ctx);
                } else if (dodge.canActivate(player, ctx)) {
                    dodge.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.debug("[parkour] dodge activated");
                    
                    // Отправляем пакет на сервер
                    PacketByteBuf dodgeBuf = new PacketByteBuf(Unpooled.buffer());
                    dodgeBuf.writeInt(KeyBindings.DODGE_LEFT.wasPressed() ? -1 : 1);
                    ClientPlayNetworking.send(ModPackets.DODGE_ID, dodgeBuf);
                }
            }
        }
    }

    public static boolean isSliding() {
        for (ParkourAction a : actions) if (a instanceof SlideAction s && s.isActive()) return true;
        return false;
    }
    
    public static boolean isCrawling() {
        for (ParkourAction a : actions) if (a instanceof CrawlAction c && c.isActive()) return true;
        return false;
    }
    
    public static boolean isRolling() {
        for (ParkourAction a : actions) if (a instanceof RollAction r && r.isActive()) return true;
        return false;
    }
    
    public static boolean isWallRunning() {
        for (ParkourAction a : actions) if (a instanceof WallRunAction w && w.isActive()) return true;
        return false;
    }
    
    public static ChargedJumpAction getChargedJumpAction() {
        return chargedJumpAction;
    }
    
    public static void sendChargedJumpFatigue(float fatigue) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString("charged_jump");
        buf.writeFloat(fatigue);
        ClientPlayNetworking.send(ModPackets.PARKOUR_ACTION_ID, buf);
    }
}

# ================= src\main\java\com\example\shinobicore\client\parkour\util\ParkourSounds.java =================
package com.example.shinobicore.client.parkour.util;

import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;

public class ParkourSounds {
    public static void playSlide() {
        play(SoundEvents.BLOCK_GRAVEL_STEP, 0.6f, 0.8f);
    }
    
    public static void playSlideLoop() {
        play(SoundEvents.BLOCK_SAND_STEP, 0.3f, 1.2f);
    }
    
    public static void playWallStick() {
        play(SoundEvents.BLOCK_STONE_HIT, 0.8f, 1.0f);
    }
    
    public static void playWallRunStep() {
        play(SoundEvents.BLOCK_STONE_STEP, 0.5f, 1.1f);
    }
    
    public static void playEdgeGrab() {
        play(SoundEvents.BLOCK_WOOD_HIT, 0.9f, 0.9f);
    }
    
    public static void playEdgeClimb() {
        play(SoundEvents.ENTITY_PLAYER_ATTACK_STRONG, 0.6f, 1.2f);
    }
    
    public static void playChargeHum(float charge) {
        float pitch = 0.8f + charge * 0.5f;
        play(SoundEvents.BLOCK_BEACON_AMBIENT, 0.3f, pitch);
    }
    
    public static void playChargedJump() {
        play(SoundEvents.ENTITY_GENERIC_EXPLODE, 0.5f, 1.5f);
    }
    
    public static void playRoll() {
        play(SoundEvents.BLOCK_WOOL_FALL, 0.7f, 1.1f);
    }
    
    private static void play(net.minecraft.sound.SoundEvent event, float volume, float pitch) {
        MinecraftClient client = MinecraftClient.getInstance();
        ClientPlayerEntity player = client.player;
        if (player == null) return;
        player.playSound(event, SoundCategory.PLAYERS, volume, pitch);
    }
}

# ================= src\main\java\com\example\shinobicore\client\parkour\util\PoseHelper.java =================
package com.example.shinobicore.client.parkour.util;

import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;
import net.minecraft.util.math.Box;
import net.minecraft.world.World;

public class PoseHelper {

    public static boolean cannotStand(ClientPlayerEntity player) {
        World w = player.getWorld();
        Box current = player.getBoundingBox();
        Box standingBox = new Box(
            current.minX, current.minY, current.minZ,
            current.maxX, current.minY + 1.8, current.maxZ
        ).contract(0.05, 0, 0.05);
        return w.getBlockCollisions(player, standingBox).iterator().hasNext();
    }

    public static void forceLowPose(ClientPlayerEntity player) {
        if (player.getPose() != EntityPose.SWIMMING) {
            player.setPose(EntityPose.SWIMMING);
            player.calculateDimensions();
        }
    }

    public static void releasePose(ClientPlayerEntity player) {
        if (player.getPose() == EntityPose.SWIMMING && !cannotStand(player)) {
            player.setPose(EntityPose.STANDING);
            player.calculateDimensions();
        }
    }
}

# ================= src\main\java\com\example\shinobicore\client\parkour\util\WallDetector.java =================
package com.example.shinobicore.client.parkour.util;

import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;

public class WallDetector {
    
    /**
     * Проверяет, есть ли стена в направлении взгляда (или горизонтальном движении)
     * Использует рейкаст как в моде Wall Jump (genandnic)
     * @return нормаль стены или null, если стены нет
     */
    public static Vec3d getWallNormal(ClientPlayerEntity player) {
        World world = player.getWorld();
        Vec3d eye = player.getEyePos();
        
        // Проверяем 4 горизонтальных направления
        int[][] dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
        for (int[] d : dirs) {
            Vec3d dir = new Vec3d(d[0], 0, d[1]).normalize();
            Vec3d end = eye.add(dir.multiply(0.4)); // 0.4 блока - короткая дистанция
            
            BlockHitResult hit = world.raycast(new RaycastContext(
                eye, end,
                RaycastContext.ShapeType.OUTLINE,
                RaycastContext.FluidHandling.NONE,
                player
            ));
            
            if (hit.getType() == HitResult.Type.BLOCK) {
                // Проверяем что блок твёрдый
                BlockPos pos = hit.getBlockPos();
                if (world.getBlockState(pos).isSolidBlock(world, pos)) {
                    return new Vec3d(-d[0], 0, -d[1]).normalize(); // нормаль от стены
                }
            }
        }
        return null;
    }
    
    /**
     * Проверяет, есть ли стена рядом (без направления)
     */
    public static boolean isNearWall(ClientPlayerEntity player) {
        return getWallNormal(player) != null;
    }
    
    /**
     * Проверяет, есть ли край блока над игроком (для Edge Grab)
     * Возвращает позицию края или null
     */
    public static BlockPos getLedgeAbove(ClientPlayerEntity player) {
        World world = player.getWorld();
        BlockPos head = player.getBlockPos().up();
        
        // Проверяем 4 стороны
        int[][] dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
        for (int[] d : dirs) {
            BlockPos wallPos = head.add(d[0], 0, d[1]);
            BlockPos aboveWall = wallPos.up();
            
            // Должен быть: твёрдый блок сбоку + воздух над ним + воздух над головой
            boolean wallSolid = world.getBlockState(wallPos).isSolidBlock(world, wallPos);
            boolean aboveWallEmpty = !world.getBlockState(aboveWall).isSolidBlock(world, aboveWall);
            boolean headEmpty = !world.getBlockState(head).isSolidBlock(world, head);
            
            if (wallSolid && aboveWallEmpty && headEmpty) {
                return aboveWall; // игрок может подтянуться сюда
            }
        }
        return null;
    }
}

# ================= src\main\java\com\example\shinobicore\client\ProgressionScreen.java =================
package com.example.shinobicore.client;

import com.example.shinobicore.client.attunement.AttunementScreen;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.StatType;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;

import java.util.ArrayList;
import java.util.List;

public class ProgressionScreen extends Screen {

    private record Row(String name, String type, String id, int level, int xp,
                       int need, int cost, boolean locked) {
        public Row(String name, String type, String id, int level, int xp, int need, int cost) {
            this(name, type, id, level, xp, need, cost, false);
        }
    }

    private static final int PARCHMENT      = 0xFFD8C098;
    private static final int PARCHMENT_EDGE = 0xFFC4A87C;
    private static final int WOOD           = 0xFF5A3A1E;
    private static final int WOOD_DARK      = 0xFF3E2812;
    private static final int WOOD_LIGHT     = 0xFF7A5430;
    private static final int INK            = 0xFF2E1F10;
    private static final int INK_LIGHT      = 0xFF6A563C;
    private static final int SEAL_RED       = 0xFFA3221E;
    private static final int SEAL_RED_ACTIVE= 0xFFD0342C;
    private static final int ACCENT         = 0xFFB4470F;
    private static final int ATTUNE_COLOR   = 0xFF44AAFF;

    private int tab = 0;
    private int loadoutSet = 0;
    private int assignSlot = -1;
    private int listOffset = 0;

    public ProgressionScreen() {
        super(Text.literal("Ninja Progression"));
    }

    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        renderBackground(context);
        super.render(context, mouseX, mouseY, delta);

        int w = 300, h = 260;
        int x0 = (width - w) / 2, y0 = (height - h) / 2;

        drawScrollFrame(context, x0, y0, w, h);

        String clanText = ClientNinjaState.clanId.equals("none") ? "No Clan" : ClientNinjaState.clanId;
        String affText  = ClientNinjaState.affinityId != null ? ClientNinjaState.affinityId : "none";
        drawCentered(context, clanText + "  |  " + affText + "  |  SP: " + ClientNinjaState.skillPoints,
                x0 + w / 2, y0 + 8, INK);

        // === Р’РєР»Р°РґРєРё (5 С€С‚СѓРє, СѓРјРµРЅСЊС€РµРЅРЅР°СЏ С€РёСЂРёРЅР°) ===
        int tabW = 54, tabH = 14, tabY = y0 + 22;
        drawSealTab(context, x0 + 8,                  tabY, tabW, tabH, 0, "Stats");
        drawSealTab(context, x0 + 8 + (tabW + 6),     tabY, tabW, tabH, 1, "Nature");
        drawSealTab(context, x0 + 8 + (tabW + 6) * 2, tabY, tabW, tabH, 2, "Body");
        drawSealTab(context, x0 + 8 + (tabW + 6) * 3, tabY, tabW, tabH, 3, "Jutsu");
        drawSealTab(context, x0 + 8 + (tabW + 6) * 4, tabY, tabW, tabH, 4, "Tree");

        int y = y0 + 44;

        if (tab < 3) {
            for (Row row : buildRows()) {
                int nameColor = row.locked() ? INK_LIGHT : INK;
                String displayName = row.locked() ? "* " + row.name() : row.name();
                context.drawText(textRenderer, Text.literal(displayName), x0 + 10, y + 2, nameColor, false);
                context.drawText(textRenderer, Text.literal("Lv " + row.level()), x0 + 100, y + 2,
                        row.locked() ? INK_LIGHT : INK, false);
                if (row.xp() >= 0) {
                    context.drawText(textRenderer, Text.literal(row.xp() + "/" + row.need()),
                            x0 + 140, y + 2, INK_LIGHT, false);
                }

                if (tab == 0 && row.id().equals("control")) {
                    context.drawText(textRenderer, Text.literal("[Train]"),
                            x0 + w - 80, y + 2, 0xFF1F7A1F, false);
                }
                if (!row.locked()) {
                    boolean afford = ClientNinjaState.skillPoints >= row.cost();
                    context.drawText(textRenderer, Text.literal("[+" + row.cost() + "]"),
                            x0 + w - 44, y + 2, afford ? ACCENT : INK_LIGHT, false);
                } else if (tab == 1) {
                    // Р—Р°Р±Р»РѕРєРёСЂРѕРІР°РЅРЅР°СЏ СЃС‚РёС…РёСЏ -> РєРЅРѕРїРєР° Attune
                    int attuneCost = getAttuneCost();
                    boolean afford = ClientNinjaState.skillPoints >= attuneCost;
                    context.drawText(textRenderer, Text.literal("[Attune " + attuneCost + "]"),
                            x0 + w - 80, y + 2, afford ? ATTUNE_COLOR : INK_LIGHT, false);
                }
                y += 14;
            }
        } else if (tab == 3) {
            renderLoadouts(context, x0, y0, w, y);
        } else if (tab == 4) {
            // === Р”Р Р•Р’Рћ РџР РћРљРђР§РљР: РїРѕРґСЃРєР°Р·РєР° ===
            drawCentered(context, "Skill Tree", x0 + w / 2, y + 10, INK);
            drawCentered(context, "Press [J] to open full tree view", x0 + w / 2, y + 26, INK_LIGHT);
            drawCentered(context, "Unlocked nodes: " + ClientNinjaState.unlockedNodes.size(),
                    x0 + w / 2, y + 42, ACCENT);
        }

        drawCentered(context, "K - close", x0 + w / 2, y0 + h - 14, INK_LIGHT);
    }

    private int getAttuneCost() {
        int unlockedCount = 0;
        for (ElementType e : ElementType.values()) {
            if (ClientNinjaState.natureUnlocked.getOrDefault(e.getId(), false)) unlockedCount++;
        }
        return 10 + unlockedCount * 5;
    }

    private void drawScrollFrame(DrawContext context, int x0, int y0, int w, int h) {
        context.fill(x0 - 8, y0 - 10, x0 + w + 8, y0, WOOD);
        context.fill(x0 - 8, y0 - 10, x0 + w + 8, y0 - 8, WOOD_LIGHT);
        context.fill(x0 - 8, y0 - 2, x0 + w + 8, y0, WOOD_DARK);
        context.fill(x0 - 8, y0 + h, x0 + w + 8, y0 + h + 10, WOOD);
        context.fill(x0 - 8, y0 + h, x0 + w + 8, y0 + h + 2, WOOD_LIGHT);
        context.fill(x0 - 8, y0 + h + 8, x0 + w + 8, y0 + h + 10, WOOD_DARK);
        context.fill(x0 - 12, y0 - 12, x0 - 8, y0 + 2, WOOD_DARK);
        context.fill(x0 + w + 8, y0 - 12, x0 + w + 12, y0 + 2, WOOD_DARK);
        context.fill(x0 - 12, y0 + h - 2, x0 - 8, y0 + h + 12, WOOD_DARK);
        context.fill(x0 + w + 8, y0 + h - 2, x0 + w + 12, y0 + h + 12, WOOD_DARK);
        context.fill(x0, y0, x0 + w, y0 + h, PARCHMENT);
        context.fill(x0, y0, x0 + 4, y0 + h, PARCHMENT_EDGE);
        context.fill(x0 + w - 4, y0, x0 + w, y0 + h, PARCHMENT_EDGE);
        context.fill(x0 + 6, y0 + 4, x0 + w - 6, y0 + 5, INK_LIGHT);
        context.fill(x0 + 6, y0 + h - 5, x0 + w - 6, y0 + h - 4, INK_LIGHT);
    }

    private void drawSealTab(DrawContext context, int x, int y, int w, int h, int id, String label) {
        boolean active = tab == id;
        context.fill(x, y, x + w, y + h, active ? SEAL_RED_ACTIVE : SEAL_RED);
        context.fill(x, y, x + w, y + 1, 0xFFE08078);
        context.fill(x, y + h - 1, x + w, y + h, 0xFF6E120E);
        if (active) {
            context.fill(x - 1, y - 1, x + w + 1, y, 0xFF1A1A1A);
            context.fill(x - 1, y + h, x + w + 1, y + h + 1, 0xFF1A1A1A);
            context.fill(x - 1, y, x, y + h, 0xFF1A1A1A);
            context.fill(x + w, y, x + w + 1, y + h, 0xFF1A1A1A);
        }
        drawCentered(context, label, x + w / 2, y + 3, 0xFFFFFFFF);
    }

    private void drawSetButton(DrawContext context, int x, int y, int w, int h, int set, String label) {
        boolean active = loadoutSet == set;
        context.fill(x, y, x + w, y + h, active ? ACCENT : PARCHMENT_EDGE);
        context.fill(x, y, x + w, y + 1, 0xFFE8D8B8);
        context.fill(x, y + h - 1, x + w, y + h, 0xFF8A6A40);
        drawCentered(context, label, x + w / 2, y + 2, active ? 0xFFFFFFFF : INK);
    }

    private void renderLoadouts(DrawContext context, int x0, int y0, int w, int y) {
        drawSetButton(context, x0 + 10, y, 60, 12, 0, "Set A");
        drawSetButton(context, x0 + 78, y, 60, 12, 1, "Set B");
        y += 18;
        if (assignSlot == -1) {
            context.drawText(textRenderer, Text.literal("Click a slot to assign:"), x0 + 10, y, INK, false);
            y += 12;
            for (int i = 0; i < 5; i++) {
                String id = ClientNinjaState.loadout(loadoutSet)[i];
                String name = id == null ? "empty" : ClientNinjaState.name(id);
                context.drawText(textRenderer, Text.literal((i + 1) + ": " + name), x0 + 10, y + 2, INK, false);
                y += 14;
            }
        } else {
            context.drawText(textRenderer, Text.literal("Assign to slot " + (assignSlot + 1) + " (Esc cancel):"),
                    x0 + 10, y, ACCENT, false);
            y += 12;
            List<String> learned = new ArrayList<>(ClientNinjaState.learned);
            java.util.Collections.sort(learned);
            int shown = 0;
            for (int i = listOffset; i < learned.size() && shown < 8; i++, shown++) {
                context.drawText(textRenderer, Text.literal("- " + ClientNinjaState.name(learned.get(i))),
                        x0 + 10, y + 2, INK, false);
                y += 14;
            }
            context.drawText(textRenderer, Text.literal("[X] clear slot"), x0 + 10, y + 2, SEAL_RED_ACTIVE, false);
        }
    }

    private void drawCentered(DrawContext context, String text, int cx, int y, int color) {
        int w = textRenderer.getWidth(text);
        context.drawText(textRenderer, text, cx - w / 2, y, color, false);
    }

    private List<Row> buildRows() {
        List<Row> rows = new ArrayList<>();
        if (tab == 0) {
            for (StatType s : StatType.values()) {
                int lvl = ClientNinjaState.statLevels.getOrDefault(s.getId(), 0);
                int xp  = ClientNinjaState.statXp.getOrDefault(s.getId(), 0);
                rows.add(new Row(s.getId(), "stat", s.getId(), lvl, xp,
                        NinjaFormula.xpToNextLevel(lvl), NinjaFormula.spCostForLevel(lvl)));
            }
            rows.add(new Row("reserve", "reserve", "reserve",
                    ClientNinjaState.reserveLevel, ClientNinjaState.reserveXp,
                    NinjaFormula.xpToNextLevel(ClientNinjaState.reserveLevel),
                    NinjaFormula.spCostForLevel(ClientNinjaState.reserveLevel)));
        } else if (tab == 1) {
            for (ElementType e : ElementType.values()) {
                int lvl = ClientNinjaState.natureLevels.getOrDefault(e.getId(), 0);
                int xp  = ClientNinjaState.natureXp.getOrDefault(e.getId(), 0);
                boolean unlocked = ClientNinjaState.natureUnlocked.getOrDefault(e.getId(), false);
                rows.add(new Row(e.getId(), "nature", e.getId(), lvl, xp,
                        NinjaFormula.xpToNextLevel(lvl), NinjaFormula.spCostForLevel(lvl), !unlocked));
            }
        } else if (tab == 2) {
            rows.add(new Row("HP (max x8)",   "body", "hp",    ClientNinjaState.hpLevel,    -1, 0, NinjaFormula.bodySpCost()));
            rows.add(new Row("Speed (max x2)","body", "speed", ClientNinjaState.speedLevel, -1, 0, NinjaFormula.bodySpCost()));
            rows.add(new Row("Jump (max x2)", "body", "jump",  ClientNinjaState.jumpLevel,  -1, 0, NinjaFormula.bodySpCost()));
        }
        return rows;
    }

    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        int w = 300, h = 260;
        int x0 = (width - w) / 2, y0 = (height - h) / 2;

        // Р’РєР»Р°РґРєРё (5 С€С‚СѓРє)
        int tabW = 54, tabH = 14, tabY = y0 + 22;
        for (int i = 0; i < 5; i++) {
            if (inRect(mouseX, mouseY, x0 + 8 + (tabW + 6) * i, tabY, tabW, tabH)) {
                tab = i;
                assignSlot = -1;
                return true;
            }
        }

        if (tab == 3) {
            int y = y0 + 44;
            if (inRect(mouseX, mouseY, x0 + 10, y, 60, 12)) { loadoutSet = 0; return true; }
            if (inRect(mouseX, mouseY, x0 + 78, y, 60, 12)) { loadoutSet = 1; return true; }
            y += 18;
            if (assignSlot == -1) {
                y += 12;
                for (int i = 0; i < 5; i++) {
                    if (inRect(mouseX, mouseY, x0 + 10, y, w - 20, 12)) {
                        assignSlot = i; listOffset = 0; return true;
                    }
                    y += 14;
                }
            } else {
                y += 12;
                List<String> learned = new ArrayList<>(ClientNinjaState.learned);
                java.util.Collections.sort(learned);
                int shown = 0;
                for (int i = listOffset; i < learned.size() && shown < 8; i++, shown++) {
                    if (inRect(mouseX, mouseY, x0 + 10, y, w - 20, 12)) {
                        sendSetSlot(loadoutSet, assignSlot, learned.get(i));
                        assignSlot = -1;
                        return true;
                    }
                    y += 14;
                }
                if (inRect(mouseX, mouseY, x0 + 10, y, w - 20, 12)) {
                    sendSetSlot(loadoutSet, assignSlot, "");
                    assignSlot = -1;
                    return true;
                }
            }
            return true;
        }

        if (tab == 4) {
            // Р”СЂРµРІРѕ: РєР»РёРє РѕС‚РєСЂС‹РІР°РµС‚ РїРѕР»РЅС‹Р№ СЌРєСЂР°РЅ
            if (this.client != null) {
                this.client.setScreen(new SkillTreeScreen());
            }
            return true;
        }

        // РџСЂРѕРєР°С‡РєР° Рё Р°С‚С‚СЋРЅРјРµРЅС‚ (С‚Р°Р±С‹ 0-2)
        int y = y0 + 44;
        for (Row row : buildRows()) {
            // РљРЅРѕРїРєР° РїСЂРѕРєР°С‡РєРё
            if (tab == 0 && row.id().equals("control") && inRect(mouseX, mouseY, x0 + w - 80, y, 36, 12)) {
                if (this.client != null) this.client.setScreen(new ControlTrainingScreen());
                return true;
            }
            if (!row.locked() && inRect(mouseX, mouseY, x0 + w - 44, y, 40, 12)) {
                sendSpend(row.type(), row.id());
                return true;
            }
            // РљРЅРѕРїРєР° Attune РґР»СЏ Р·Р°Р±Р»РѕРєРёСЂРѕРІР°РЅРЅС‹С… СЃС‚РёС…РёР№
            if (row.locked() && tab == 1 && inRect(mouseX, mouseY, x0 + w - 80, y, 76, 12)) {
                int attuneCost = getAttuneCost();
                if (ClientNinjaState.skillPoints >= attuneCost) {
                    ElementType element = null;
                    for (ElementType e : ElementType.values()) {
                        if (e.getId().equals(row.id())) { element = e; break; }
                    }
                    if (element != null) {
                        // SP deducted server-side on success
                        if (this.client != null) {
                            this.client.setScreen(new AttunementScreen(element, attuneCost));
                        }
                    }
                }
                return true;
            }
            y += 14;
        }
        return super.mouseClicked(mouseX, mouseY, button);
    }

    @Override
    public boolean mouseScrolled(double mouseX, double mouseY, double amount) {
        if (tab == 3 && assignSlot >= 0) {
            listOffset = Math.max(0, (int)(listOffset - amount));
            return true;
        }
        return super.mouseScrolled(mouseX, mouseY, amount);
    }

    @Override
    public boolean keyPressed(int keyCode, int scanCode, int modifiers) {
        if (assignSlot >= 0 && keyCode == 256) {
            assignSlot = -1;
            return true;
        }
        return super.keyPressed(keyCode, scanCode, modifiers);
    }

    private boolean inRect(double mx, double my, int x, int y, int w, int h) {
        return mx >= x && mx <= x + w && my >= y && my <= y + h;
    }

    private void sendSpend(String type, String id) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString(type);
        buf.writeString(id);
        ClientPlayNetworking.send(ModPackets.SPEND_SP_ID, buf);
    }

    private void sendSetSlot(int set, int slot, String id) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(set);
        buf.writeInt(slot);
        buf.writeString(id);
        ClientPlayNetworking.send(ModPackets.SET_SLOT_ID, buf);
    }

    @Override
    public boolean shouldPause() { return false; }
}

# ================= src\main\java\com\example\shinobicore\client\RasenganClientState.java =================
package com.example.shinobicore.client;

public class RasenganClientState {
    public static boolean charging = false;
    public static float chargeProgress = 0f;
    public static boolean ready = false;

    public static void reset() {
        charging = false;
        chargeProgress = 0f;
        ready = false;
    }
}

# ================= src\main\java\com\example\shinobicore\client\RasenganClientVisual.java =================
package com.example.shinobicore.client;

import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.util.math.Vec3d;

public class RasenganClientVisual {
    private static int tickCounter = 0;

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(RasenganClientVisual::onClientTick);
    }

    private static void onClientTick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        tickCounter++;

        if (RasenganClientState.charging) {
            float progress = RasenganClientState.chargeProgress;
            spawnChargingParticles(client, player, progress);
        }

        if (RasenganClientState.ready) {
            spawnReadyParticles(client, player);
        }
    }

    /**
     * Частицы во время зарядки — маленькая сфера из синего огня + белые искры
     */
    private static void spawnChargingParticles(MinecraftClient client, ClientPlayerEntity player, float progress) {
        Vec3d handPos = getHandPosition(player);
        // Маленькая сфера: 0.12 → 0.35 блоков
        float radius = 0.12f + progress * 0.23f;
        int count = (int)(3 + progress * 8);

        for (int i = 0; i < count; i++) {
            float theta = (float)Math.random() * (float)(Math.PI * 2);
            float phi = (float)Math.acos(2 * Math.random() - 1);

            double x = handPos.x + radius * Math.sin(phi) * Math.cos(theta);
            double y = handPos.y + radius * Math.cos(phi);
            double z = handPos.z + radius * Math.sin(phi) * Math.sin(theta);

            // SOUL_FIRE_FLAME — синее пламя (основной визуал)
            client.world.addParticle(ParticleTypes.SOUL_FIRE_FLAME, x, y, z,
                    (Math.random() - 0.5) * 0.02,
                    (Math.random() - 0.5) * 0.02,
                    (Math.random() - 0.5) * 0.02);
        }

        // Белые искры при зарядке > 30%
        if (progress > 0.3f && tickCounter % 3 == 0) {
            client.world.addParticle(ParticleTypes.CRIT,
                    handPos.x + (Math.random() - 0.5) * radius * 1.5,
                    handPos.y + (Math.random() - 0.5) * radius * 1.5,
                    handPos.z + (Math.random() - 0.5) * radius * 1.5,
                    (Math.random() - 0.5) * 0.04,
                    Math.random() * 0.04,
                    (Math.random() - 0.5) * 0.04);
        }

        // END_ROD — белые стержни при зарядке > 60%
        if (progress > 0.6f && tickCounter % 4 == 0) {
            client.world.addParticle(ParticleTypes.END_ROD,
                    handPos.x + (Math.random() - 0.5) * radius,
                    handPos.y + (Math.random() - 0.5) * radius,
                    handPos.z + (Math.random() - 0.5) * radius,
                    0, 0.01, 0);
        }
    }

    /**
     * Частицы когда Расенган готов — яркая вращающаяся сфера
     */
    private static void spawnReadyParticles(MinecraftClient client, ClientPlayerEntity player) {
        Vec3d handPos = getHandPosition(player);
        float radius = 0.35f;
        float rotation = tickCounter * 0.2f;

        // === СИНЕЕ ПЛАМЯ: вращающаяся сфера ===
        for (int i = 0; i < 12; i++) {
            float angle = rotation + (i / 12.0f) * (float)(Math.PI * 2);
            float phi = (float)Math.acos(2 * ((i * 0.618f) % 1.0f) - 1);

            double x = handPos.x + radius * Math.sin(phi) * Math.cos(angle);
            double y = handPos.y + radius * Math.cos(phi);
            double z = handPos.z + radius * Math.sin(phi) * Math.sin(angle);

            client.world.addParticle(ParticleTypes.SOUL_FIRE_FLAME, x, y, z,
                    0, 0, 0);
        }

        // === БЕЛЫЕ СПИРАЛИ: END_ROD ===
        for (int i = 0; i < 6; i++) {
            float t = i / 6.0f;
            float spiralAngle = rotation * 3 + t * (float)(Math.PI * 4);

            double x = handPos.x + radius * 0.7 * Math.cos(spiralAngle);
            double y = handPos.y + (t - 0.5) * radius * 1.2;
            double z = handPos.z + radius * 0.7 * Math.sin(spiralAngle);

            client.world.addParticle(ParticleTypes.END_ROD, x, y, z,
                    0, 0.01, 0);
        }

        // === БЕЛЫЕ ИСКРЫ: CRIT (каждые 2 тика) ===
        if (tickCounter % 2 == 0) {
            client.world.addParticle(ParticleTypes.CRIT,
                    handPos.x + (Math.random() - 0.5) * radius * 2,
                    handPos.y + (Math.random() - 0.5) * radius * 2,
                    handPos.z + (Math.random() - 0.5) * radius * 2,
                    0, 0.04, 0);
        }

        // === СИНЕЕ СВЕЧЕНИЕ: DRAGON_BREATH (каждые 5 тиков) ===
        if (tickCounter % 5 == 0) {
            client.world.addParticle(ParticleTypes.DRAGON_BREATH,
                    handPos.x + (Math.random() - 0.5) * radius,
                    handPos.y + (Math.random() - 0.5) * radius,
                    handPos.z + (Math.random() - 0.5) * radius,
                    0, 0.005, 0);
        }
    }

    private static Vec3d getHandPosition(ClientPlayerEntity player) {
        Vec3d look = player.getRotationVector();
        Vec3d right = new Vec3d(-look.z, 0, look.x).normalize();

        return player.getEyePos()
                .add(look.multiply(0.8))
                .add(right.multiply(0.4))
                .add(0, -0.3, 0);
    }
}

# ================= src\main\java\com\example\shinobicore\client\ShinobiCoreClient.java =================
package com.example.shinobicore.client;

import com.example.shinobicore.client.RasenganClientState;
import com.example.shinobicore.client.RasenganClientVisual;
import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import com.example.shinobicore.client.combat.TaijutsuSounds;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.entity.ModEntities;
import com.example.shinobicore.entity.NinjaProjectileRenderer;
import com.example.shinobicore.entity.ShurikenRenderer;
import com.example.shinobicore.network.ChakraSyncPacket;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.StatType;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.client.rendering.v1.EntityRendererRegistry;
import net.fabricmc.fabric.api.client.rendering.v1.HudRenderCallback;
import net.minecraft.registry.Registries;
import com.example.shinobicore.client.combat.TaijutsuSounds;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import com.example.shinobicore.client.parkour.ParkourManager;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import com.example.shinobicore.client.combat.TaijutsuSounds;
import com.example.shinobicore.client.CinematicCamera;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.combat.TaijutsuAnimations;
import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import net.minecraft.client.network.AbstractClientPlayerEntity;
public class ShinobiCoreClient implements ClientModInitializer {

    @Override
    public void onInitializeClient() {
        KeyBindings.register();
        ClientInputHandler.register();
        ChakraPhysicsClient.register();
        ParkourManager.register();
        TaijutsuClientHandler.register();
        RasenganClientVisual.register();
        // === РЕГИСТРАЦИЯ РЕНДЕРЕРОВ (было потеряно!) ===
        EntityRendererRegistry.register(ModEntities.NINJA_PROJECTILE, NinjaProjectileRenderer::new);
        EntityRendererRegistry.register(ModEntities.SHURIKEN, ShurikenRenderer::new);
        
        // === РЕГИСТРАЦИЯ ЗВУКОВ ===
        Registry.register(Registries.SOUND_EVENT, TaijutsuSounds.PUNCH_LIGHT.getId(), TaijutsuSounds.PUNCH_LIGHT);
        Registry.register(Registries.SOUND_EVENT, TaijutsuSounds.PUNCH_HEAVY.getId(), TaijutsuSounds.PUNCH_HEAVY);
        Registry.register(Registries.SOUND_EVENT, TaijutsuSounds.KICK.getId(), TaijutsuSounds.KICK);
        Registry.register(Registries.SOUND_EVENT, TaijutsuSounds.WHOOSH.getId(), TaijutsuSounds.WHOOSH);
        TaijutsuSounds.setCustomSoundsRegistered(true);
        ShinobiCore.LOGGER.info("Registered taijutsu sounds");

        // === РЕГИСТРАЦИЯ КИНЕМАТОГРАФИЧНОЙ КАМЕРЫ ===
        ClientTickEvents.END_CLIENT_TICK.register(CinematicCamera::tick);
        ShinobiCore.LOGGER.info("Registered cinematic camera");

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.CHAKRA_SYNC_ID, (client, handler, buf, responseSender) -> {
            ChakraSyncPacket packet = ChakraSyncPacket.read(buf);
            client.execute(() -> {
                ChakraHudRenderer.currentChakra = packet.currentChakra();
                ChakraHudRenderer.maxChakra = packet.maxChakra();
                ChakraHudRenderer.fatigue = packet.fatigue();
                ChakraHudRenderer.exhausted = packet.exhausted();
                ClientNinjaState.meditating = packet.meditating();
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.CATALOG_SYNC_ID, (client, handler, buf, responseSender) -> {
            Map<String, String> cat = new HashMap<>();
            int n = buf.readInt();
            for (int i = 0; i < n; i++) cat.put(buf.readString(), buf.readString());
            client.execute(() -> {
                ClientNinjaState.catalog.clear();
                ClientNinjaState.catalog.putAll(cat);
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.LOADOUT_SYNC_ID, (client, handler, buf, responseSender) -> {
            int aA = buf.readInt(); int aB = buf.readInt();
            String[] la = new String[5]; String[] lb = new String[5];
            for (int i = 0; i < 5; i++) { String s = buf.readString(); la[i] = s.isEmpty() ? null : s; }
            for (int i = 0; i < 5; i++) { String s = buf.readString(); lb[i] = s.isEmpty() ? null : s; }
            Set<String> learned = new HashSet<>();
            int lc = buf.readInt();
            for (int i = 0; i < lc; i++) learned.add(buf.readString());
            client.execute(() -> {
                ClientNinjaState.activeA = aA; ClientNinjaState.activeB = aB;
                for (int i = 0; i < 5; i++) { ClientNinjaState.loadoutA[i] = la[i]; ClientNinjaState.loadoutB[i] = lb[i]; }
                ClientNinjaState.learned.clear();
                ClientNinjaState.learned.addAll(learned);
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.RASENGAN_SYNC_ID, (client, handler, buf, responseSender) -> {
            boolean charging = buf.readBoolean();
            float progress = buf.readFloat();
            boolean ready = buf.readBoolean();
            client.execute(() -> {
                RasenganClientState.charging = charging;
                RasenganClientState.chargeProgress = progress;
                RasenganClientState.ready = ready;
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.STATS_SYNC_ID, (client, handler, buf, responseSender) -> {
            int sp = buf.readInt(); int resLvl = buf.readInt(); int resXp = buf.readInt();
            Map<String, Integer> sl = new HashMap<>(); Map<String, Integer> sx = new HashMap<>();
            for (StatType s : StatType.values()) { sl.put(s.getId(), buf.readInt()); sx.put(s.getId(), buf.readInt()); }
            Map<String, Integer> nl = new HashMap<>(); Map<String, Integer> nx = new HashMap<>(); Map<String, Boolean> nu = new HashMap<>();
            for (ElementType e : ElementType.values()) { nl.put(e.getId(), buf.readInt()); nx.put(e.getId(), buf.readInt()); }
            for (ElementType e : ElementType.values()) nu.put(e.getId(), buf.readBoolean());
        boolean sen = buf.readBoolean();
            client.execute(() -> {
                ClientNinjaState.skillPoints = sp;
                ClientNinjaState.reserveLevel = resLvl;
                ClientNinjaState.reserveXp = resXp;
                ClientNinjaState.statLevels.clear(); ClientNinjaState.statLevels.putAll(sl);
                ClientNinjaState.statXp.clear(); ClientNinjaState.statXp.putAll(sx);
                ClientNinjaState.natureLevels.clear(); ClientNinjaState.natureLevels.putAll(nl);
                ClientNinjaState.natureXp.clear(); ClientNinjaState.natureXp.putAll(nx);
                ClientNinjaState.natureUnlocked.clear(); ClientNinjaState.natureUnlocked.putAll(nu);
                ClientNinjaState.sensoryEnabled = sen;
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.BODY_SYNC_ID, (client, handler, buf, responseSender) -> {
            int hp = buf.readInt(); int speed = buf.readInt(); int jump = buf.readInt();
            boolean chakra = buf.readBoolean(); String clan = buf.readString(); String affinity = buf.readString();
            client.execute(() -> {
                ClientNinjaState.hpLevel = hp;
                ClientNinjaState.speedLevel = speed;
                ClientNinjaState.jumpLevel = jump;
                ClientNinjaState.chakraMode = chakra;
                ClientNinjaState.clanId = clan.isEmpty() ? "none" : clan;
                ClientNinjaState.affinityId = affinity.isEmpty() ? null : affinity;
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.TREE_SYNC_ID, (client, handler, buf, responseSender) -> {
            int count = buf.readInt();
            Set<String> nodes = new HashSet<>();
            for (int i = 0; i < count; i++) nodes.add(buf.readString());
            client.execute(() -> {
                ClientNinjaState.unlockedNodes.clear();
                ClientNinjaState.unlockedNodes.addAll(nodes);
            });
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.DANGER_SYNC_ID, (client, handler, buf, responseSender) -> {
            boolean danger = buf.readBoolean();
            client.execute(() -> ClientNinjaState.dangerSense = danger);
        });

        ClientPlayNetworking.registerGlobalReceiver(ModPackets.CAST_FX_ID, (client, handler, buf, responseSender) -> {
            int entityId = buf.readInt();
            String nature = buf.readString();
            client.execute(() -> {
                if (client.world != null && client.world.getEntityById(entityId) instanceof AbstractClientPlayerEntity p) {
                    CastingClientState.startCast(p.getUuid(), nature);
                }
            });
        });
        CastingClientVisual.register();
        HudRenderCallback.EVENT.register(ChakraHudRenderer::render);
    }
}


# ================= src\main\java\com\example\shinobicore\client\SkillTreeScreen.java =================
package com.example.shinobicore.client;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.tree.SkillTreeNode;
import com.example.shinobicore.tree.SkillTreeRegistry;
import com.example.shinobicore.tree.SkillTreeRegistry.BranchDef;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;
import java.util.*;

public class SkillTreeScreen extends Screen {

    private static final int NODE = 26;
    private static final int HALF = NODE / 2;
    private static final int COL_W = 120;
    private static final int ROW_H = 70;
    private static final int TOP = 70;

    private static final int BG = 0xFF161616;
    private static final int GRID = 0xFF1D1D1D;
    private static final int SLOT_BG = 0xFF212121;
    private static final int SLOT_HI = 0xFF373737;
    private static final int SLOT_LO = 0xFF0C0C0C;
    private static final int LINE_DONE = 0xFF9B9B9B;
    private static final int LINE_LOCK = 0xFF3F3F3F;

    private static final String[] BASE_ORDER = {
        "taijutsu", "earth", "water", "general", "medical", "fire", "wind", "lightning",
        "sensory", "space", "shuriken", "kekkei"
    };

    private double viewX, viewY;
    private float zoom = 1.0f;
    private boolean dragging = false;
    private int dragStartX, dragStartY;
    private double dragViewX, dragViewY;
    private SkillTreeNode hovered = null;
    private boolean centered = false;

    public SkillTreeScreen() { super(Text.literal("Skill Tree")); }

    private List<String> branchOrder() {
        List<String> order = new ArrayList<>(Arrays.asList(BASE_ORDER));
        String clan = ClientNinjaState.clanId;
        if (clan != null && !clan.equals("none") && SkillTreeRegistry.getBranch(clan) != null) {
            order.add(clan);
        }
        order.add("forbidden");
        return order;
    }

    private int colX(String branch) {
        List<String> order = branchOrder();
        int i = order.indexOf(branch);
        if (i < 0) i = order.size() - 1;
        return i * COL_W;
    }

    private int[] worldPos(SkillTreeNode n) {
        return new int[]{ colX(n.branch()) + (int)(n.angleOffset() * 5), TOP + n.distance() * ROW_H };
    }

    private int sx(int wx) { return (int)(width / 2f + (wx - viewX) * zoom); }
    private int sy(int wy) { return (int)(height / 2f + (wy - viewY) * zoom); }

    @Override
    public void render(DrawContext ctx, int mx, int my, float delta) {
        if (!centered) {
            viewX = colX("general");
            viewY = TOP + 2 * ROW_H;
            centered = true;
        }

        ctx.fill(0, 0, width, height, BG);
        renderGrid(ctx);
        renderUzumakiSpiral(ctx);

        hovered = null;
        List<String> order = branchOrder();

        // === Р—РђР“РћР›РћР’РљР Р’Р•РўРћРљ ===
        for (String b : order) {
            BranchDef def = SkillTreeRegistry.getBranch(b);
            if (def == null || !isBranchVisible(def)) continue;
            int x = sx(colX(b));
            int y = sy(TOP - 50);
            if (x < -100 || x > width + 100) continue;
            int w = textRenderer.getWidth(def.label()) + 12;
            ctx.fill(x - w / 2, y - 4, x + w / 2, y + 10, 0xFF2A2A2A);
            ctx.fill(x - w / 2, y - 4, x + w / 2, y - 3, 0xFF4A4A4A);
            ctx.fill(x - w / 2, y + 9, x + w / 2, y + 10, 0xFF111111);
            vLine(ctx, x, y + 10, sy(TOP - HALF), 0xFF3A3A3A);
            drawCentered(ctx, def.label(), x, y - 1, def.color());
        }

        // === РљРћРќРќР•РљРўРћР Р« (СѓРіР»РѕРІР°С‚С‹Рµ, РєР°Рє РІ РґРѕСЃС‚РёР¶РµРЅРёСЏС…) ===
        for (SkillTreeNode n : SkillTreeRegistry.getAll()) {
            if (!SkillTreeRegistry.isVisibleClient(n)) continue;
            int[] c = worldPos(n);
            for (String req : n.requires()) {
                SkillTreeNode p = SkillTreeRegistry.get(req);
                if (p == null || !SkillTreeRegistry.isVisibleClient(p)) continue;
                int[] pw = worldPos(p);
                boolean done = ClientNinjaState.unlockedNodes.contains(n.id())
                        && ClientNinjaState.unlockedNodes.contains(req);
                int color = done ? LINE_DONE : LINE_LOCK;
                int px = sx(pw[0]), py = sy(pw[1]);
                int cx2 = sx(c[0]), cy2 = sy(c[1]);
                if (px == cx2) {
                    vLine(ctx, px, py + HALF, cy2 - HALF, color);
                } else if (py == cy2) {
                    hLine(ctx, px, cx2, py, color);
                } else {
                    int startY = py + (cy2 > py ? HALF : -HALF);
                    int endY = cy2 + (cy2 > py ? -HALF : HALF);
                    vLine(ctx, px, startY, endY, color);
                    hLine(ctx, px, cx2, endY, color);
                }
            }
        }

        // === РЈР—Р›Р«-РЎР›РћРўР« ===
        for (SkillTreeNode n : SkillTreeRegistry.getAll()) {
            if (!SkillTreeRegistry.isVisibleClient(n)) continue;
            int[] w = worldPos(n);
            int x = sx(w[0]), y = sy(w[1]);
            if (x < -40 || x > width + 40 || y < -40 || y > height + 40) continue;

            boolean unlocked = ClientNinjaState.unlockedNodes.contains(n.id());
            boolean available = canUnlock(n);
            BranchDef def = SkillTreeRegistry.getBranch(n.branch());
            int bc = def != null ? (0xFF000000 | (def.color() & 0xFFFFFF)) : 0xFFAAAAAA;

            if (mx >= x - HALF - 2 && mx <= x + HALF + 2 && my >= y - HALF - 2 && my <= y + HALF + 2) {
                hovered = n;
            }

            // Р¤РѕРЅ СЃР»РѕС‚Р°
            ctx.fill(x - HALF, y - HALF, x + HALF, y + HALF, SLOT_BG);
            ctx.fill(x - HALF, y - HALF, x + HALF, y - HALF + 1, SLOT_HI);
            ctx.fill(x - HALF, y + HALF - 1, x + HALF, y + HALF, SLOT_LO);

            // Р Р°РјРєР° 2px
            int border;
            if (unlocked) {
                border = bc;
            } else if (available) {
                int pulse = (int)(150 + 105 * Math.sin(System.currentTimeMillis() / 250.0));
                border = (pulse << 24) | 0xFFFF00;
            } else {
                border = 0xFF555555;
            }
            ctx.fill(x - HALF - 2, y - HALF - 2, x + HALF + 2, y - HALF, border);
            ctx.fill(x - HALF - 2, y + HALF, x + HALF + 2, y + HALF + 2, border);
            ctx.fill(x - HALF - 2, y - HALF, x - HALF, y + HALF, border);
            ctx.fill(x + HALF, y - HALF, x + HALF + 2, y + HALF, border);

            // РРєРѕРЅРєР°
            int iconColor = unlocked ? 0xFFFFFFFF : (available ? 0xFFDDDDDD : 0xFF777777);
            drawCentered(ctx, n.icon(), x, y - 4, iconColor);

            // РњРµС‚РєР° СЂР°Р·Р±Р»РѕРєРёСЂРѕРІРєРё
            if (unlocked) {
                ctx.fill(x + HALF - 6, y + HALF - 6, x + HALF - 2, y + HALF - 2, bc);
            }
        }

        // === Р’Р•Р РҐРќРЇРЇ РџР›РђРЁРљРђ (РІР°Р№Р± РќР°СЂСѓС‚Рѕ) ===
        ctx.fill(0, 0, width, 22, 0xCC000000);
        ctx.fill(0, 22, width, 23, 0xFFB4470F);
        drawCentered(ctx, "SHINOBI PATH  |  SP: " + ClientNinjaState.skillPoints
                + "  |  Clan: " + ClientNinjaState.clanId + "  |  ESC - close",
                width / 2, 7, 0xFFFFAA00);

        if (hovered != null) renderTooltip(ctx, hovered, mx, my);

        ctx.fill(0, height - 14, width, height, 0xCC000000);
        drawCentered(ctx, "LMB - unlock | RMB - move | Wheel - zoom " + (int)(zoom * 100) + "%",
                width / 2, height - 11, 0xFF888888);
    }

    // === РЎР•РўРљРђ Р¤РћРќРђ (РєР°Рє РІ РґРѕСЃС‚РёР¶РµРЅРёСЏС…) ===
    private void renderGrid(DrawContext ctx) {
        int step = 32;
        double wl = viewX - width / (2.0 * zoom);
        double wr = viewX + width / (2.0 * zoom);
        double wt = viewY - height / (2.0 * zoom);
        double wb = viewY + height / (2.0 * zoom);
        for (double gx = Math.floor(wl / step) * step; gx <= wr; gx += step) {
            int x = sx((int) gx);
            ctx.fill(x, 0, x + 1, height, GRID);
        }
        for (double gy = Math.floor(wt / step) * step; gy <= wb; gy += step) {
            int y = sy((int) gy);
            ctx.fill(0, y, width, y + 1, GRID);
        }
    }

    // === РЎРџРР РђР›Р¬ РЈР—РЈРњРђРљР (С„РѕРЅРѕРІР°СЏ РїРµС‡Р°С‚СЊ) ===
    private void renderUzumakiSpiral(DrawContext ctx) {
        int cxw = colX("general");
        int cyw = TOP + 2 * ROW_H;
        int prevX = -1, prevY = -1;
        for (int i = 0; i <= 160; i++) {
            float t = i / 160.0f * (float)(Math.PI * 6);
            float r = 8 + t * 9;
            int x = sx((int)(cxw + Math.cos(t) * r));
            int y = sy((int)(cyw + Math.sin(t) * r));
            if (prevX >= 0) {
                int steps = Math.max(Math.abs(x - prevX), Math.abs(y - prevY));
                if (steps > 0) {
                    for (int s = 0; s <= steps; s++) {
                        int ix = prevX + (x - prevX) * s / steps;
                        int iy = prevY + (y - prevY) * s / steps;
                        ctx.fill(ix, iy, ix + 2, iy + 2, 0x22FF7700);
                    }
                }
            }
            prevX = x; prevY = y;
        }
    }

    private boolean isBranchVisible(BranchDef b) {
        if (b.clan() != null && !b.clan().equals(ClientNinjaState.clanId)) return false;
        if (b.hidden()) {
            for (SkillTreeNode n : SkillTreeRegistry.getAll()) {
                if (n.branch().equals(b.id()) && SkillTreeRegistry.isVisibleClient(n)) return true;
            }
            return false;
        }
        return true;
    }

    private boolean canUnlock(SkillTreeNode node) {
        if (ClientNinjaState.unlockedNodes.contains(node.id())) return false;
        if (ClientNinjaState.skillPoints < node.spCost()) return false;
        for (String r : node.requires()) {
            if (!ClientNinjaState.unlockedNodes.contains(r)) return false;
        }
        return true;
    }

    // === РўРЈР›РўРРџ-РЎР’РРўРћРљ (РїРµСЂРіР°РјРµРЅС‚, РІР°Р№Р± РќР°СЂСѓС‚Рѕ) ===
    private void renderTooltip(DrawContext ctx, SkillTreeNode node, int mx, int my) {
        List<String> lines = new ArrayList<>();
        lines.add(node.displayName());
        lines.add("Branch: " + node.branch());
        if (node.jutsuId() != null) lines.add("Teaches: " + ClientNinjaState.name(node.jutsuId()));
        if (node.description() != null && !node.description().isEmpty()) lines.add(node.description());
        lines.add("SP: " + node.spCost());
        if (!node.requires().isEmpty()) lines.add("Requires: " + String.join(", ", node.requires()));
        boolean unlocked = ClientNinjaState.unlockedNodes.contains(node.id());
        boolean available = canUnlock(node);
        if (unlocked) lines.add("[UNLOCKED]");
        else if (available) lines.add("[Click to unlock]");
        else lines.add("[Locked]");

        int tw = 0;
        for (String l : lines) tw = Math.max(tw, textRenderer.getWidth(l));
        int th = lines.size() * 10 + 10;
        int tx = Math.min(mx + 12, width - tw - 20);
        int ty = Math.max(my - th - 8, 4);

        // РџРµСЂРіР°РјРµРЅС‚ + РґРµСЂРµРІСЏРЅРЅР°СЏ СЂР°РјРєР°
        ctx.fill(tx - 3, ty - 3, tx + tw + 15, ty + th + 3, 0xFF5A3A1E);
        ctx.fill(tx, ty, tx + tw + 12, ty + th, 0xFFD8C098);
        ctx.fill(tx, ty, tx + tw + 12, ty + 1, 0xFFE8D8B8);
        ctx.fill(tx, ty + th - 1, tx + tw + 12, ty + th, 0xFFC4A87C);

        BranchDef b = SkillTreeRegistry.getBranch(node.branch());
        int barColor = b != null ? (0xFF000000 | (b.color() & 0xFFFFFF)) : 0xFF2E1F10;
        ctx.fill(tx + 4, ty + 4, tx + 7, ty + 12, barColor);

        int ly = ty + 5;
        ctx.drawText(textRenderer, lines.get(0), tx + 10, ly, 0xFF2E1F10, false);
        ly += 11;
        for (int i = 1; i < lines.size(); i++) {
            String l = lines.get(i);
            int col = 0xFF6A563C;
            if (l.startsWith("[")) col = unlocked ? 0xFF1F7A1F : (available ? 0xFFB4470F : 0xFFA3221E);
            ctx.drawText(textRenderer, l, tx + 6, ly, col, false);
            ly += 10;
        }
    }

    @Override public boolean mouseClicked(double mx, double my, int btn) {
        if (btn == 1) {
            dragging = true;
            dragStartX = (int) mx; dragStartY = (int) my;
            dragViewX = viewX; dragViewY = viewY;
            return true;
        }
        if (btn == 0 && hovered != null && canUnlock(hovered)) {
            PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
            buf.writeString(hovered.id());
            ClientPlayNetworking.send(ModPackets.UNLOCK_NODE_ID, buf);
            return true;
        }
        return super.mouseClicked(mx, my, btn);
    }

    @Override public boolean mouseReleased(double mx, double my, int btn) {
        if (btn == 1) dragging = false;
        return super.mouseReleased(mx, my, btn);
    }

    @Override public boolean mouseDragged(double mx, double my, int btn, double dx, double dy) {
        if (dragging) {
            viewX = dragViewX - (mx - dragStartX) / zoom;
            viewY = dragViewY - (my - dragStartY) / zoom;
            return true;
        }
        return super.mouseDragged(mx, my, btn, dx, dy);
    }

    @Override public boolean mouseScrolled(double mx, double my, double amount) {
        zoom = (float)Math.max(0.5, Math.min(1.6, zoom + amount * 0.1));
        return true;
    }

    private void vLine(DrawContext ctx, int x, int y1, int y2, int c) {
        if (y2 < y1) { int t = y1; y1 = y2; y2 = t; }
        ctx.fill(x - 1, y1, x + 1, y2, c);
    }

    private void hLine(DrawContext ctx, int x1, int x2, int y, int c) {
        if (x2 < x1) { int t = x1; x1 = x2; x2 = t; }
        ctx.fill(x1, y - 1, x2, y + 1, c);
    }

    private void drawCentered(DrawContext ctx, String text, int cx, int y, int color) {
        int w = textRenderer.getWidth(text);
        ctx.drawText(textRenderer, text, cx - w / 2, y, color, false);
    }

    @Override public boolean shouldPause() { return false; }
}

# ================= src\main\java\com\example\shinobicore\combat\KenjutsuFormulas.java =================
package com.example.shinobicore.combat;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
import java.util.ArrayList;
import java.util.List;
public class KenjutsuFormulas {
    private static final float[] STEP_MULT = {1.0f, 1.0f, 1.2f, 1.8f};
    private static final float[] STEP_KB = {0.3f, 0.3f, 0.4f, 1.2f};
    public static float baseDamage(int taiLevel) { return 6.0f + taiLevel * 0.35f; }
    public static float computeDamage(int taiLevel, KenjutsuStance stance, boolean chakraMode, int step, boolean exhausted) {
        float d = baseDamage(taiLevel) * STEP_MULT[Math.max(0, Math.min(3, step))] * stance.getDamageMult();
        if (chakraMode) d *= 1.2f;
        if (exhausted) d *= 0.5f;
        return d;
    }
    public static long cooldownMs(KenjutsuStance stance) {
        return Math.max(200, (long)(450 / stance.getSpeedMult()));
    }
    public static float getKnockback(int step) { return STEP_KB[Math.max(0, Math.min(3, step))]; }
    public static List<LivingEntity> findTargetsInCone(ServerWorld world, LivingEntity attacker, Vec3d look, double range, double angleDeg) {
        List<LivingEntity> out = new ArrayList<>();
        Vec3d dir = look.normalize();
        for (LivingEntity e : world.getEntitiesByClass(LivingEntity.class, attacker.getBoundingBox().expand(range + 1),
                t -> t != attacker && t.isAlive())) {
            Vec3d to = e.getPos().add(0, e.getHeight() / 2.0, 0).subtract(attacker.getPos().add(0, attacker.getEyeHeight(attacker.getPose()), 0));
            if (to.length() > range) continue;
            double dot = dir.dotProduct(to.normalize());
            if (Math.toDegrees(Math.acos(Math.max(-1, Math.min(1, dot)))) <= angleDeg / 2) out.add(e);
        }
        return out;
    }
    public static List<LivingEntity> findInRadius(ServerWorld world, LivingEntity attacker, double range) {
        List<LivingEntity> out = new ArrayList<>();
        for (LivingEntity e : world.getEntitiesByClass(LivingEntity.class, attacker.getBoundingBox().expand(range),
                t -> t != attacker && t.isAlive())) {
            if (e.getPos().distanceTo(attacker.getPos()) <= range) out.add(e);
        }
        return out;
    }
}

# ================= src\main\java\com\example\shinobicore\combat\KenjutsuStance.java =================
package com.example.shinobicore.combat;
public enum KenjutsuStance {
    AGGRESSIVE("aggressive", 1.15f, 1.15f, true, 1.0f),
    SEIGAN("seigan", 0.85f, 1.0f, true, 0.5f),
    IAI("iai", 1.0f, 0.9f, false, 1.0f);
    private final String id;
    private final float damageMult;
    private final float speedMult;
    private final boolean canDeflect;
    private final float shieldSlow;
    KenjutsuStance(String id, float damageMult, float speedMult, boolean canDeflect, float shieldSlow) {
        this.id = id; this.damageMult = damageMult; this.speedMult = speedMult;
        this.canDeflect = canDeflect; this.shieldSlow = shieldSlow;
    }
    public String getId() { return id; }
    public float getDamageMult() { return damageMult; }
    public float getSpeedMult() { return speedMult; }
    public boolean canDeflect() { return canDeflect; }
    public float getShieldSlow() { return shieldSlow; }
    public static KenjutsuStance fromId(String id) {
        for (KenjutsuStance s : values()) if (s.id.equals(id)) return s;
        return AGGRESSIVE;
    }
}

# ================= src\main\java\com\example\shinobicore\combat\MarkTracker.java =================
package com.example.shinobicore.combat;
import net.minecraft.entity.LivingEntity;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
public class MarkTracker {
    private static final Map<UUID, Long> MARKS = new ConcurrentHashMap<>();
    public static void mark(LivingEntity e, long ms) { MARKS.put(e.getUuid(), System.currentTimeMillis() + ms); }
    public static boolean isMarked(LivingEntity e) {
        Long t = MARKS.get(e.getUuid());
        return t != null && t > System.currentTimeMillis();
    }
    public static float boost(LivingEntity e, float dmg) { return isMarked(e) ? dmg * 1.2f : dmg; }
}

# ================= src\main\java\com\example\shinobicore\combat\MeleeHitDetection.java =================
package com.example.shinobicore.combat;

import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.List;

public class MeleeHitDetection {
    public static final double RANGE = 3.0;
    public static final double CONE_ANGLE_DEG = 120.0;

    public static List<LivingEntity> findTargetsInCone(ServerWorld world, PlayerEntity attacker, Vec3d lookDir) {
        List<LivingEntity> targets = new ArrayList<>();
        if (lookDir.lengthSquared() < 0.001) return targets;
        Vec3d dir = lookDir.normalize();

        Box searchBox = attacker.getBoundingBox().expand(RANGE + 1.0);
        List<LivingEntity> entities = world.getEntitiesByClass(LivingEntity.class, searchBox,
            e -> e != attacker && e.isAlive());

        for (LivingEntity target : entities) {
            Vec3d toTarget = target.getPos().add(0, target.getHeight() / 2.0, 0)
                .subtract(attacker.getPos().add(0, attacker.getEyeHeight(attacker.getPose()), 0));
            if (toTarget.length() > RANGE) continue;
            double dot = dir.dotProduct(toTarget.normalize());
            double angle = Math.toDegrees(Math.acos(Math.max(-1.0, Math.min(1.0, dot))));
            if (angle <= CONE_ANGLE_DEG / 2.0) {
                targets.add(target);
            }
        }
        return targets;
    }

    public static void applyDamage(ServerWorld world, PlayerEntity attacker,
                                   List<LivingEntity> targets, float damage, float knockback) {
        for (LivingEntity target : targets) {
            target.damage(world.getDamageSources().playerAttack(attacker), damage);
            Vec3d kb = target.getPos().subtract(attacker.getPos()).normalize().multiply(knockback);
            target.addVelocity(kb.x, 0.15, kb.z);
            target.velocityModified = true;
        }
    }
}

# ================= src\main\java\com\example\shinobicore\combat\TaijutsuCombo.java =================
package com.example.shinobicore.combat;

public class TaijutsuCombo {
    public static final int MAX_STEPS = 4;
    public static final long COMBO_TIMEOUT_MS = 1500;

    private static final float[] STEP_DAMAGE = {1.0f, 1.0f, 1.2f, 1.8f};
    private static final float[] STEP_KNOCKBACK = {0.3f, 0.3f, 0.4f, 1.2f};

    public static float getDamageMult(int step) {
        if (step < 0) step = 0;
        if (step >= MAX_STEPS) step = MAX_STEPS - 1;
        return STEP_DAMAGE[step];
    }

    public static float getKnockback(int step) {
        if (step < 0) step = 0;
        if (step >= MAX_STEPS) step = MAX_STEPS - 1;
        return STEP_KNOCKBACK[step];
    }

    public static boolean isFinisher(int step) {
        return step == MAX_STEPS - 1;
    }
}

# ================= src\main\java\com\example\shinobicore\combat\TaijutsuFormulas.java =================
package com.example.shinobicore.combat;

import com.example.shinobicore.config.ModConfig;

public class TaijutsuFormulas {
    public static float baseDamage(int taijutsuLevel) {
        return ModConfig.instance.taijutsu.baseDamage + taijutsuLevel * ModConfig.instance.taijutsu.damagePerLevel;
    }

    public static float computeDamage(int taijutsuLevel, TaijutsuStyle style,
                                       boolean chakraMode, int comboStep, boolean exhausted) {
        float base = baseDamage(taijutsuLevel);
        float comboMult = TaijutsuCombo.getDamageMult(comboStep);
        float styleMult = style.getDamageMult();
        float chakraMult = chakraMode ? ModConfig.instance.taijutsu.chakraModeDamageMult : 1.0f;
        float exhaustMult = exhausted ? 0.5f : 1.0f;
        return base * comboMult * styleMult * chakraMult * exhaustMult;
    }

    public static int attackCooldownTicks(TaijutsuStyle style, boolean chakraMode) {
        float baseCooldown = 12.0f;
        float speedMult = style.getSpeedMult() * (chakraMode ? ModConfig.instance.taijutsu.chakraModeSpeedMult : 1.0f);
        return Math.max(4, (int) (baseCooldown / speedMult));
    }

    // === НОВОЕ: уровень разблокировки Strong Fist из конфига ===
    public static int strongFistUnlockLevel() {
        return ModConfig.instance.taijutsu.strongFistUnlockLevel;
    }

    public static boolean canUseStrongFist(int taijutsuLevel) {
        return taijutsuLevel >= strongFistUnlockLevel();
    }
}

# ================= src\main\java\com\example\shinobicore\combat\TaijutsuStyle.java =================
package com.example.shinobicore.combat;

public enum TaijutsuStyle {
    STANDARD("standard", 1.0f, 1.0f, 0.3f),
    STRONG_FIST("strong_fist", 1.6f, 1.3f, 0.5f);
    // GENTLE_FIST добавим с кланом Хьюга

    private final String id;
    private final float damageMult;
    private final float speedMult;
    private final float fatiguePerHit;

    TaijutsuStyle(String id, float damageMult, float speedMult, float fatiguePerHit) {
        this.id = id;
        this.damageMult = damageMult;
        this.speedMult = speedMult;
        this.fatiguePerHit = fatiguePerHit;
    }

    public String getId() { return id; }
    public float getDamageMult() { return damageMult; }
    public float getSpeedMult() { return speedMult; }
    public float getFatiguePerHit() { return fatiguePerHit; }

    public static TaijutsuStyle fromId(String id) {
        for (TaijutsuStyle s : values()) {
            if (s.id.equals(id)) return s;
        }
        return STANDARD;
    }
}

# ================= src\main\java\com\example\shinobicore\combat\ThrowingHelper.java =================
package com.example.shinobicore.combat;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Vec3d;
public class ThrowingHelper {
    public static double assistConeDeg(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        double cone = 3.0 + data.getStatLevel(StatType.PERCEPTION) * 0.12;
        if (data.isNodeUnlocked("shuriken_accuracy")) cone += 5.0;
        return cone;
    }
    public static float assistBlend(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        return (float) Math.min(1.0, 0.5 + data.getStatLevel(StatType.PERCEPTION) / 200.0);
    }
    public static long markDurationMs(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        return data.isNodeUnlocked("shuriken_mark") ? 15000 : 10000;
    }
    public static boolean doubleThrow(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        return data.isNodeUnlocked("shuriken_double");
    }
    public static Vec3d aimAssist(ServerPlayerEntity player, Vec3d dir, double range) {
        double coneRad = Math.toRadians(assistConeDeg(player));
        Vec3d eye = player.getEyePos();
        Vec3d flat = dir.normalize();
        LivingEntity best = null;
        double bestAngle = Double.MAX_VALUE;
        for (LivingEntity e : player.getWorld().getEntitiesByClass(LivingEntity.class,
                player.getBoundingBox().expand(range), t -> t != player && t.isAlive())) {
            Vec3d to = e.getPos().add(0, e.getHeight() * 0.6, 0).subtract(eye);
            double dist = to.length();
            if (dist > range || dist < 0.5) continue;
            double angle = Math.acos(Math.max(-1, Math.min(1, flat.dotProduct(to.normalize()))));
            if (angle <= coneRad && angle < bestAngle) { bestAngle = angle; best = e; }
        }
        if (best == null) return dir;
        Vec3d toTarget = best.getPos().add(0, best.getHeight() * 0.6, 0).subtract(eye).normalize();
        return flat.lerp(toTarget, assistBlend(player)).normalize();
    }
}

# ================= src\main\java\com\example\shinobicore\command\NinjaCommand.java =================
package com.example.shinobicore.command;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuRegistry;
import com.example.shinobicore.jutsu.JutsuCaster;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.FloatArgumentType;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.builder.ArgumentBuilder;
import com.mojang.brigadier.context.CommandContext;
import com.mojang.brigadier.suggestion.Suggestions;
import com.mojang.brigadier.suggestion.SuggestionsBuilder;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

import java.util.concurrent.CompletableFuture;

public class NinjaCommand {
    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("ninja")
                .then(CommandManager.literal("info").executes(ctx -> info(ctx.getSource())))
                .then(setBranch())
                .then(giveBranch())
                .then(jutsuBranch())
                .then(CommandManager.literal("learn")
                        .then(CommandManager.argument("id", StringArgumentType.greedyString())
                                .suggests(NinjaCommand::suggestJutsu)
                                .executes(ctx -> learn(ctx.getSource(), StringArgumentType.getString(ctx, "id")))))
                .then(CommandManager.literal("cast")
                        .then(CommandManager.argument("id", StringArgumentType.greedyString())
                                .executes(ctx -> {
                                    ServerPlayerEntity p = ctx.getSource().getPlayer();
                                    return JutsuCaster.cast(p, normalizeId(StringArgumentType.getString(ctx, "id"))) ? 1 : 0;
                                })))
                .then(slotBranch())
                .then(clanBranch())
                .then(CommandManager.literal("reloadconfig").executes(ctx -> {
                    ModConfig.load();
                    ctx.getSource().sendFeedback(() -> Text.literal("§aConfig reloaded"), false);
                    return 1;
                }))
        );
    }

    private static ArgumentBuilder<ServerCommandSource, ?> setBranch() {
        return CommandManager.literal("set")
                .then(CommandManager.literal("chakra").then(CommandManager.argument("value", FloatArgumentType.floatArg(0, 100000))
                        .executes(ctx -> {
                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                            data(p).setCurrentChakra(FloatArgumentType.getFloat(ctx, "value"));
                            ShinobiCore.sendChakraSync(p);
                            return feedback(ctx.getSource(), "Chakra set");
                        })))
                .then(CommandManager.literal("fatigue").then(CommandManager.argument("value", FloatArgumentType.floatArg(0, 100))
                        .executes(ctx -> {
                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                            data(p).setFatigue(FloatArgumentType.getFloat(ctx, "value"));
                            ShinobiCore.sendChakraSync(p);
                            return feedback(ctx.getSource(), "Fatigue set");
                        })))
                .then(CommandManager.literal("stat").then(CommandManager.argument("id", StringArgumentType.word())
                        .suggests(NinjaCommand::suggestStats)
                        .then(CommandManager.argument("value", IntegerArgumentType.integer(0, 100))
                                .executes(ctx -> {
                                    ServerPlayerEntity p = ctx.getSource().getPlayer();
                                    StatType s = statById(StringArgumentType.getString(ctx, "id"));
                                    if (s == null) return feedback(ctx.getSource(), "§cUnknown stat");
                                    data(p).setStatLevel(s, IntegerArgumentType.getInteger(ctx, "value"));
                                    ShinobiCore.sendStatsSync(p);
                                    return feedback(ctx.getSource(), "Set " + s.getId());
                                }))))
                .then(CommandManager.literal("nature").then(CommandManager.argument("id", StringArgumentType.word())
                        .suggests(NinjaCommand::suggestElements)
                        .then(CommandManager.argument("value", IntegerArgumentType.integer(0, 100))
                                .executes(ctx -> {
                                    ServerPlayerEntity p = ctx.getSource().getPlayer();
                                    ElementType e = elementById(StringArgumentType.getString(ctx, "id"));
                                    if (e == null) return feedback(ctx.getSource(), "§cUnknown nature");
                                    int v = IntegerArgumentType.getInteger(ctx, "value");
                                    data(p).setNatureLevel(e, v);
                                    if (v > 0) data(p).setNatureUnlocked(e, true);
                                    ShinobiCore.sendStatsSync(p);
                                    return feedback(ctx.getSource(), "Set " + e.getId());
                                }))))
                // === ИЗМЕНЕНО: принимаем строку, проверяем существование в ClanRegistry ===
                .then(CommandManager.literal("clan").then(CommandManager.argument("id", StringArgumentType.word())
                        .suggests(NinjaCommand::suggestClans)
                        .executes(ctx -> {
                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                            String id = StringArgumentType.getString(ctx, "id");
                            ClanDefinition clan = ClanRegistry.get(id);
                            if (clan == null) return feedback(ctx.getSource(), "§cUnknown clan: " + id);
                            data(p).setClanId(id);
                            ShinobiCore.sendBodySync(p);
                            return feedback(ctx.getSource(), "Clan set to " + id);
                        })))
                .then(CommandManager.literal("affinity").then(CommandManager.argument("id", StringArgumentType.word())
                        .suggests(NinjaCommand::suggestElements)
                        .executes(ctx -> {
                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                            data(p).setAffinity(elementById(StringArgumentType.getString(ctx, "id")));
                            ShinobiCore.sendBodySync(p);
                            return feedback(ctx.getSource(), "Affinity set");
                        })));
    }

    private static ArgumentBuilder<ServerCommandSource, ?> giveBranch() {
        return CommandManager.literal("give")
                .then(CommandManager.literal("xp")
                        .then(CommandManager.literal("stat").then(CommandManager.argument("id", StringArgumentType.word())
                                .suggests(NinjaCommand::suggestStats)
                                .then(CommandManager.argument("amount", IntegerArgumentType.integer(1, 100000))
                                        .executes(ctx -> {
                                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                                            StatType s = statById(StringArgumentType.getString(ctx, "id"));
                                            if (s == null) return feedback(ctx.getSource(), "§cUnknown stat");
                                            NinjaFormula.addStatXp(data(p), s, IntegerArgumentType.getInteger(ctx, "amount"));
                                            ShinobiCore.sendStatsSync(p);
                                            return feedback(ctx.getSource(), "XP given");
                                        }))))
                        .then(CommandManager.literal("nature").then(CommandManager.argument("id", StringArgumentType.word())
                                .suggests(NinjaCommand::suggestElements)
                                .then(CommandManager.argument("amount", IntegerArgumentType.integer(1, 100000))
                                        .executes(ctx -> {
                                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                                            ElementType e = elementById(StringArgumentType.getString(ctx, "id"));
                                            if (e == null) return feedback(ctx.getSource(), "§cUnknown nature");
                                            NinjaFormula.addNatureXp(data(p), e, IntegerArgumentType.getInteger(ctx, "amount"));
                                            ShinobiCore.sendStatsSync(p);
                                            return feedback(ctx.getSource(), "XP given");
                                        }))))
                        .then(CommandManager.literal("reserve").then(CommandManager.argument("amount", IntegerArgumentType.integer(1, 100000))
                                .executes(ctx -> {
                                    ServerPlayerEntity p = ctx.getSource().getPlayer();
                                    NinjaFormula.addReserveXp(data(p), IntegerArgumentType.getInteger(ctx, "amount"));
                                    ShinobiCore.sendStatsSync(p);
                                    ShinobiCore.sendChakraSync(p);
                                    return feedback(ctx.getSource(), "XP given");
                                }))))
                .then(CommandManager.literal("sp").then(CommandManager.argument("amount", IntegerArgumentType.integer(1, 100000))
                        .executes(ctx -> {
                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                            data(p).addSkillPoints(IntegerArgumentType.getInteger(ctx, "amount"));
                            ShinobiCore.sendStatsSync(p);
                            return feedback(ctx.getSource(), "SP added");
                        })));
    }

    private static ArgumentBuilder<ServerCommandSource, ?> jutsuBranch() {
        return CommandManager.literal("jutsu")
                .then(CommandManager.literal("list").executes(ctx -> {
                    StringBuilder sb = new StringBuilder("=== Jutsu ===\n");
                    for (JutsuDefinition def : JutsuRegistry.getAll()) {
                        sb.append("- ").append(def.id()).append(" [").append(def.type()).append("]\n");
                    }
                    ctx.getSource().sendFeedback(() -> Text.literal(sb.toString()), false);
                    return 1;
                }))
                .then(CommandManager.literal("info").then(CommandManager.argument("id", StringArgumentType.greedyString())
                        .executes(ctx -> {
                            JutsuDefinition def = JutsuRegistry.get(normalizeId(StringArgumentType.getString(ctx, "id")));
                            if (def == null) return feedback(ctx.getSource(), "§cNot found");
                            ctx.getSource().sendFeedback(() -> Text.literal(
                                    def.name() + "\n" +
                                            "§7type=" + def.type() +
                                            " nature=" + (def.hasNature() ? def.nature().getId() : "none") +
                                            " cost=" + def.baseCost() + " dmg=" + def.baseDamage()), false);
                            return 1;
                        })));
    }

    private static ArgumentBuilder<ServerCommandSource, ?> slotBranch() {
        return CommandManager.literal("slot")
                .then(CommandManager.literal("a").then(slotSet(0)))
                .then(CommandManager.literal("b").then(slotSet(1)));
    }

    private static ArgumentBuilder<ServerCommandSource, ?> slotSet(int set) {
        return CommandManager.argument("num", IntegerArgumentType.integer(1, 5))
                .then(CommandManager.argument("id", StringArgumentType.greedyString())
                        .suggests((ctx, b) -> {
                            b.suggest("none");
                            for (JutsuDefinition def : JutsuRegistry.getAll()) b.suggest(def.id());
                            return b.buildFuture();
                        })
                        .executes(ctx -> {
                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                            String id = StringArgumentType.getString(ctx, "id");
                            String clean = id.equals("none") ? null : normalizeId(id);
                            if (clean != null && !data(p).getLearnedJutsus().contains(clean)) {
                                return feedback(ctx.getSource(), "§cLearn it first!");
                            }
                            data(p).setLoadoutSlot(set, IntegerArgumentType.getInteger(ctx, "num") - 1, clean);
                            ShinobiCore.sendLoadoutSync(p);
                            return feedback(ctx.getSource(), "Slot set");
                        }));
    }

    private static ArgumentBuilder<ServerCommandSource, ?> clanBranch() {
        return CommandManager.literal("clan")
                .then(CommandManager.literal("list").executes(ctx -> {
                    StringBuilder sb = new StringBuilder("=== Clans ===\n");
                    for (ClanDefinition c : ClanRegistry.getAll()) {
                        sb.append("- ").append(c.id()).append(" (").append(c.name()).append(")\n");
                    }
                    ctx.getSource().sendFeedback(() -> Text.literal(sb.toString()), false);
                    return 1;
                }))
                // === ИЗМЕНЕНО: принимаем строку, проверяем существование ===
                .then(CommandManager.literal("choose").then(CommandManager.argument("id", StringArgumentType.word())
                        .suggests(NinjaCommand::suggestClans)
                        .executes(ctx -> {
                            ServerPlayerEntity p = ctx.getSource().getPlayer();
                            String id = StringArgumentType.getString(ctx, "id");
                            ClanDefinition clan = ClanRegistry.get(id);
                            if (clan == null) return feedback(ctx.getSource(), "§cUnknown clan: " + id);
                            data(p).setClanId(id);
                            data(p).setClanChosen(true);
                            ShinobiCore.sendBodySync(p);
                            return feedback(ctx.getSource(), "Clan chosen: " + id);
                        })));
    }

    private static int learn(ServerCommandSource source, String id) {
        ServerPlayerEntity p = source.getPlayer();
        NinjaPlayerData d = data(p);
        id = normalizeId(id);
        if (JutsuRegistry.get(id) == null) return feedback(source, "§cJutsu not found: " + id);
        if (d.getLearnedJutsus().contains(id)) return feedback(source, "§cAlready learned");
        d.learnJutsu(id);
        String placed = null;
        for (int set = 0; set < 2 && placed == null; set++) {
            for (int i = 0; i < 5; i++) {
                if (d.getLoadoutSlot(set, i) == null) {
                    d.setLoadoutSlot(set, i, id);
                    placed = (set == 0 ? "A" : "B") + (i + 1);
                    break;
                }
            }
        }
        ShinobiCore.sendLoadoutSync(p);
        ShinobiCore.sendStatsSync(p);
        String msg = "§aLearned " + id + (placed != null ? " §7-> slot " + placed : "");
        source.sendFeedback(() -> Text.literal(msg), false);
        return 1;
    }

    private static int info(ServerCommandSource source) {
        ServerPlayerEntity p = source.getPlayer();
        NinjaPlayerData d = data(p);
        source.sendFeedback(() -> Text.literal(
                "=== NINJA STATS ===\n" +
                        "Chakra: " + (int) d.getCurrentChakra() + "/" + (int) NinjaFormula.maxChakra(d) + "\n" +
                        "Reserve: Lv " + d.getReserveLevel() + "\n" +
                        "Fatigue: " + (int) d.getFatigue() + "\n" +
                        "SP: " + d.getSkillPoints() + "\n" +
                        "Clan: " + d.getClanId() + "\n" +
                        "Affinity: " + (d.getAffinity() != null ? d.getAffinity().getId() : "none") + "\n" +
                        "Learned Jutsu: " + d.getLearnedJutsus().size()), false);
        return 1;
    }

    private static NinjaPlayerData data(ServerPlayerEntity p) {
        return ((NinjaDataHolder) p).shinobicore_getData();
    }

    private static String normalizeId(String raw) {
        String id = raw.trim();
        if (!id.contains(":")) id = "shinobicore:" + id;
        return id;
    }

    private static int feedback(ServerCommandSource source, String msg) {
        source.sendFeedback(() -> Text.literal(msg), false);
        return msg.startsWith("§c") ? 0 : 1;
    }

    private static StatType statById(String id) {
        for (StatType s : StatType.values()) if (s.getId().equals(id)) return s;
        return null;
    }

    private static ElementType elementById(String id) {
        for (ElementType e : ElementType.values()) if (e.getId().equals(id)) return e;
        return null;
    }

    private static CompletableFuture<Suggestions> suggestStats(CommandContext<ServerCommandSource> ctx, SuggestionsBuilder b) {
        for (StatType s : StatType.values()) b.suggest(s.getId());
        return b.buildFuture();
    }

    private static CompletableFuture<Suggestions> suggestElements(CommandContext<ServerCommandSource> ctx, SuggestionsBuilder b) {
        for (ElementType e : ElementType.values()) b.suggest(e.getId());
        return b.buildFuture();
    }

    // === ДОБАВЛЕНО: подсказки кланов из ClanRegistry ===
    private static CompletableFuture<Suggestions> suggestClans(CommandContext<ServerCommandSource> ctx, SuggestionsBuilder b) {
        for (ClanDefinition c : ClanRegistry.getAll()) b.suggest(c.id());
        return b.buildFuture();
    }

    private static CompletableFuture<Suggestions> suggestJutsu(CommandContext<ServerCommandSource> ctx, SuggestionsBuilder b) {
        for (JutsuDefinition def : JutsuRegistry.getAll()) b.suggest(def.id());
        return b.buildFuture();
    }
}

# ================= src\main\java\com\example\shinobicore\config\ModConfig.java =================
package com.example.shinobicore.config;
import java.util.HashMap;
import java.util.Map;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;

import java.io.FileReader;
import java.io.FileWriter;
import java.nio.file.Files;
import java.nio.file.Path;

public class ModConfig {

    public static class Chakra {
        public float baseChakra = 100f;
        public float chakraPerReserveLevel = 12f;
        public float baseRegen = 1.0f;
        public float regenPerReserveLevel = 0.03f;
        public float regenPerControlLevel = 0.02f;
        public float regenHardFatigueMultiplier = 0.35f;
        public float regenExhaustedMultiplier = 0.2f;
    }

    public Parkour parkour = new Parkour();

    public static class Parkour {
        public float doubleJumpFatigue = 0.5f;
        public float wallJumpFatigue = 0.5f;
        public float vaultFatigue = 0.3f;
        
        // Slide
        public float slideFatigue = 0.3f;
        
        // Wall Run (для шага C)
        public float wallRunFatiguePerTick = 0.02f;
        public int wallRunMaxTicks = 40;
        
        // Edge Grab (для шага D)
        public float edgeGrabFatigue = 0.5f;
        
        // Roll (для шага F)
        public float rollFatigue = 1.0f;
        
        // Charged Jump (для шага E)
        public float chargedJumpFatiguePerCharge = 2.0f;

        public float dodgeFatigue = 2.0f;
    }
    
    public static class Fatigue {
        public float decayPerSecond = 2.0f;
        public float softThreshold = 50f;
        public float hardThreshold = 70f;
        public float costPenaltyMax = 1.0f;
    }

    public static class Taijutsu {
        public float baseDamage = 2.0f;
        public float damagePerLevel = 0.3f;
        public float chakraModeDamageMult = 1.5f;
        public float chakraModeSpeedMult = 1.3f;
        public int strongFistUnlockLevel = 50;
        public double range = 3.0;
        public double coneAngle = 120.0;
    }

    public Taijutsu taijutsu = new Taijutsu();

    public static class Meditation {
        public float regenMultiplier = 4.0f;
        public float fatigueDecayMultiplier = 2.0f;
        public int reserveXpPerSecond = 2;
        public int controlXpPerSecond = 1;
        public int slownessBase = 3;
        public float slownessControlReduction = 2.5f;
    }

    public static class Progression {
        public int xpBase = 100;
        public int xpPerLevel = 25;
        public int xpSquared = 5;
        public int spPerLevelUp = 1;
        public int spBaseCost = 1;
        public int spExtraCostEvery10 = 1;
        public int maxXpPerMinute = 500;
        public int maxUsagePerMinute = 10;
    }

    public static class Combat {
        public float masteryUsageWeight = 0.25f;
        public float masteryStatWeight = 0.75f;
        public float damageBaseMultiplier = 0.6f;
        public float damageMasteryScale = 0.8f;
        public float costControlReductionMax = 0.20f;
        public float costNatureReductionMax = 0.15f;
        public float affinityCostMultiplier = 0.85f;
        public float affinityDamageMultiplier = 1.10f;
        public float affinityXpMultiplier = 1.25f;
        public float costMasteryReductionMax = 0.25f;
        public Map<String, Map<String, Float>> categoryWeights = defaultCategoryWeights();
    }

    public static class Hud {
        public int x = 10;
        public int y = 10;
        public int width = 180;
        public int height = 14;
    }

    public Chakra chakra = new Chakra();
    public Fatigue fatigue = new Fatigue();
    public Meditation meditation = new Meditation();
    public Progression progression = new Progression();
    public Combat combat = new Combat();
    public Hud hud = new Hud();

    public static ModConfig instance = new ModConfig();
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

    public static Path path() {
        return FabricLoader.getInstance().getConfigDir().resolve("shinobicore").resolve("main.json");
    }

    public static void load() {
        try {
            Path p = path();
            if (!Files.exists(p)) {
                Files.createDirectories(p.getParent());
                instance = new ModConfig();
                save();
            } else {
                try (FileReader reader = new FileReader(p.toFile())) {
                    ModConfig loaded = GSON.fromJson(reader, ModConfig.class);
                    if (loaded != null) instance = loaded;
                }
                save(); // дописываем в файл новые поля с дефолтами
            }
            ShinobiCore.LOGGER.info("Config loaded from {}", path());
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("Failed to load config, using defaults", e);
            instance = new ModConfig();
        }
    }

    public static void save() {
        try (FileWriter writer = new FileWriter(path().toFile())) {
            GSON.toJson(instance, writer);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("Failed to save config", e);
        }
    }
        private static Map<String, Map<String, Float>> defaultCategoryWeights() {
        Map<String, Map<String, Float>> w = new HashMap<>();

        Map<String, Float> elemental = new HashMap<>();
        elemental.put("nature", 0.40f);
        elemental.put("control", 0.25f);
        elemental.put("ninjutsu", 0.25f);
        elemental.put("reserve", 0.10f);
        w.put("elemental_ninjutsu", elemental);

        Map<String, Float> shape = new HashMap<>();
        shape.put("control", 0.45f);
        shape.put("ninjutsu", 0.30f);
        shape.put("reserve", 0.15f);
        shape.put("perception", 0.10f);
        w.put("shape_ninjutsu", shape);

        Map<String, Float> tai = new HashMap<>();
        tai.put("taijutsu", 0.55f);
        tai.put("control", 0.20f);
        tai.put("reserve", 0.15f);
        tai.put("space_time", 0.10f);
        w.put("taijutsu", tai);

        Map<String, Float> gen = new HashMap<>();
        gen.put("genjutsu", 0.45f);
        gen.put("control", 0.25f);
        gen.put("perception", 0.20f);
        gen.put("reserve", 0.10f);
        w.put("genjutsu", gen);

        Map<String, Float> med = new HashMap<>();
        med.put("medical", 0.40f);
        med.put("control", 0.35f);
        med.put("reserve", 0.15f);
        med.put("perception", 0.10f);
        w.put("medical", med);

        Map<String, Float> space = new HashMap<>();
        space.put("space_time", 0.45f);
        space.put("control", 0.30f);
        space.put("reserve", 0.15f);
        space.put("ninjutsu", 0.10f);
        w.put("space_time", space);

        Map<String, Float> sensory = new HashMap<>();
        sensory.put("perception", 0.50f);
        sensory.put("control", 0.25f);
        sensory.put("genjutsu", 0.15f);
        sensory.put("reserve", 0.10f);
        w.put("sensory", sensory);

        return w;
    }
}

# ================= src\main\java\com\example\shinobicore\entity\ModEntities.java =================
package com.example.shinobicore.entity;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.object.builder.v1.entity.FabricEntityTypeBuilder;
import net.minecraft.entity.EntityDimensions;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.SpawnGroup;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;

public class ModEntities {
    public static final EntityType<NinjaProjectileEntity> NINJA_PROJECTILE = Registry.register(
            Registries.ENTITY_TYPE,
            new Identifier(ShinobiCore.MOD_ID, "ninja_projectile"),
            FabricEntityTypeBuilder.<NinjaProjectileEntity>create(SpawnGroup.MISC, NinjaProjectileEntity::new)
                    .dimensions(EntityDimensions.fixed(0.5f, 0.5f))
                    .trackRangeChunks(32)
                    .trackedUpdateRate(4)
                    .build()
    );

    public static final EntityType<ShurikenEntity> SHURIKEN = Registry.register(
            Registries.ENTITY_TYPE,
            new Identifier(ShinobiCore.MOD_ID, "shuriken"),
            FabricEntityTypeBuilder.<ShurikenEntity>create(SpawnGroup.MISC, ShurikenEntity::new)
                    .dimensions(EntityDimensions.fixed(0.25f, 0.25f))
                    .trackRangeChunks(16)
                    .trackedUpdateRate(1)
                    .build()
    );

    public static void register() {
        ShinobiCore.LOGGER.info("Registered entities");
    }
}

# ================= src\main\java\com\example\shinobicore\entity\NinjaProjectileEntity.java =================
package com.example.shinobicore.entity;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.combat.MarkTracker;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.data.DataTracker;
import net.minecraft.entity.data.TrackedData;
import net.minecraft.entity.data.TrackedDataHandlerRegistry;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.particle.ParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;
import net.minecraft.particle.ParticleEffect;
import java.util.List;
import java.util.UUID;
import net.minecraft.particle.ParticleEffect;
public class NinjaProjectileEntity extends Entity {
    private static final TrackedData<Float> DAMAGE = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<Float> RADIUS = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.FLOAT);
    private static final TrackedData<String> PARTICLE_TYPE = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.STRING);
    private static final TrackedData<Integer> LIFETIME = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<Boolean> HAS_GRAVITY = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.BOOLEAN);
    private static final TrackedData<Integer> PIERCE_COUNT = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);
    private static final TrackedData<Integer> BOUNCE_COUNT = DataTracker.registerData(NinjaProjectileEntity.class, TrackedDataHandlerRegistry.INTEGER);
    // === ПУБЛИЧНЫЕ ГЕТТЕРЫ ДЛЯ РЕНДЕРЕРА ===
    public float getRadius() { return this.dataTracker.get(RADIUS); }
    public String getParticleType() { return this.dataTracker.get(PARTICLE_TYPE); }
    private UUID ownerId;
    public Entity getOwner() {
        if (ownerId == null) return null;
        if (this.getWorld() instanceof ServerWorld sw) return sw.getPlayerByUuid(ownerId);
        return null;
    }
    private int age = 0;
    private int pierceRemaining = 0;
    private int bounceRemaining = 0;

    public NinjaProjectileEntity(EntityType<?> type, World world) {
        super(type, world);
    }

    public NinjaProjectileEntity(World world, LivingEntity owner, Vec3d velocity, float damage, float radius, String particle, int lifetime) {
        super(ModEntities.NINJA_PROJECTILE, world);
        this.ownerId = owner.getUuid();
        this.setPosition(owner.getX(), owner.getEyeY() - 0.2, owner.getZ());
        this.setVelocity(velocity);
        this.velocityDirty = true;
        this.noClip = false;

        this.dataTracker.set(DAMAGE, damage);
        this.dataTracker.set(RADIUS, radius);
        this.dataTracker.set(PARTICLE_TYPE, particle);
        this.dataTracker.set(LIFETIME, lifetime);
    }

    public void setHasGravity(boolean gravity) {
        this.dataTracker.set(HAS_GRAVITY, gravity);
    }

    public void setPierceCount(int count) {
        this.dataTracker.set(PIERCE_COUNT, count);
        this.pierceRemaining = count;
    }

    public void reflect(ServerPlayerEntity newOwner) {
        this.ownerId = newOwner.getUuid();
        Vec3d v = this.getVelocity();
        this.setVelocity(v.multiply(-1.3));
        this.velocityDirty = true;
    }

    public void setBounceCount(int count) {
        this.dataTracker.set(BOUNCE_COUNT, count);
        this.bounceRemaining = count;
    }

    @Override
    protected void initDataTracker() {
        this.dataTracker.startTracking(DAMAGE, 5f);
        this.dataTracker.startTracking(RADIUS, 1f);
        this.dataTracker.startTracking(PARTICLE_TYPE, "flame");
        this.dataTracker.startTracking(LIFETIME, 100);
        this.dataTracker.startTracking(HAS_GRAVITY, false);
        this.dataTracker.startTracking(PIERCE_COUNT, 0);
        this.dataTracker.startTracking(BOUNCE_COUNT, 0);
    }

    @Override
    public void tick() {
        super.tick();
        age++;

        if (age == 1) {
            ShinobiCore.LOGGER.info("[PROJECTILE] Tick 1: pos=({}, {}, {}), vel=({}, {}, {}), world={}",
                    String.format("%.2f", this.getX()),
                    String.format("%.2f", this.getY()),
                    String.format("%.2f", this.getZ()),
                    String.format("%.2f", this.getVelocity().x),
                    String.format("%.2f", this.getVelocity().y),
                    String.format("%.2f", this.getVelocity().z),
                    this.getWorld().isClient ? "CLIENT" : "SERVER");
        }

        if (age > this.dataTracker.get(LIFETIME)) {
            ShinobiCore.LOGGER.info("[PROJECTILE] Lifetime expired, discarding");
            this.discard();
            return;
        }

        Vec3d vel = this.getVelocity();

        // Гравитация
        if (this.dataTracker.get(HAS_GRAVITY)) {
            vel = new Vec3d(vel.x, vel.y - 0.04, vel.z);
            this.setVelocity(vel);
        }

        // === РУЧНОЙ РЕЙКАСТ БЛОКОВ ===
        Vec3d startPos = this.getPos();
        Vec3d endPos = startPos.add(vel);
        
        HitResult blockHit = this.getWorld().raycast(new RaycastContext(
                startPos, endPos,
                RaycastContext.ShapeType.COLLIDER,
                RaycastContext.FluidHandling.NONE,
                this
        ));

        // === РУЧНОЙ ПОИСК СУЩНОСТЕЙ ===
        LivingEntity hitEntity = null;
        double closestDist = Double.MAX_VALUE;
        
        Box searchBox = this.getBoundingBox().stretch(vel).expand(0.15);
        List<Entity> entities = this.getWorld().getOtherEntities(this, searchBox);
        
        for (Entity entity : entities) {
            if (entity instanceof LivingEntity living && !living.getUuid().equals(this.ownerId)) {
                Box entityBox = entity.getBoundingBox().expand(0.3);
                // Проверяем пересечение линии движения с bounding box сущности
                var optionalHit = entityBox.raycast(startPos, endPos);
                if (optionalHit.isPresent()) {
                    double dist = startPos.squaredDistanceTo(optionalHit.get());
                    if (dist < closestDist) {
                        closestDist = dist;
                        hitEntity = living;
                    }
                }
            }
        }

        boolean hit = false;

        // Попадание по сущности
        if (hitEntity != null) {
            float damage = this.dataTracker.get(DAMAGE);
            hitEntity.damage(this.getDamageSources().magic(), MarkTracker.boost(hitEntity, damage));
            ShinobiCore.LOGGER.info("[PROJECTILE] Hit entity: {}, damage={}", hitEntity.getName().getString(), damage);

            if (pierceRemaining > 0) {
                pierceRemaining--;
                ShinobiCore.LOGGER.info("[PROJECTILE] Piercing, remaining={}", pierceRemaining);
            } else {
                hit = true;
            }
        }

        // Попадание по блоку
        if (blockHit.getType() == HitResult.Type.BLOCK && !hit) {
            BlockHitResult bhr = (BlockHitResult) blockHit;
            ShinobiCore.LOGGER.info("[PROJECTILE] Hit block at {}", bhr.getPos());

            if (bounceRemaining > 0) {
                bounceRemaining--;
                Vec3d normal = Vec3d.of(bhr.getSide().getVector());
                double dot = vel.dotProduct(normal);
                Vec3d reflected = vel.subtract(normal.multiply(2 * dot)).multiply(0.7);
                this.setVelocity(reflected);
                this.setPosition(bhr.getPos().add(normal.multiply(0.01)));
                ShinobiCore.LOGGER.info("[PROJECTILE] Bouncing, remaining={}", bounceRemaining);
                return;
            } else {
                hit = true;
            }
        }

        if (hit) {
            // AOE урон при уничтожении
            float radius = this.dataTracker.get(RADIUS);
            float damage = this.dataTracker.get(DAMAGE);
            if (radius > 0.5f) {
                for (Entity entity : this.getWorld().getOtherEntities(this, this.getBoundingBox().expand(radius))) {
                    if (entity instanceof LivingEntity living && !living.getUuid().equals(this.ownerId)) {
                        living.damage(this.getDamageSources().magic(), damage * 0.5f);
                    }
                }
            }
            this.discard();
            return;
        }

        // Перемещение
        this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);

         // Частицы — количество зависит от размера снаряда
        if (this.getWorld() instanceof ServerWorld serverWorld) {
            String particle = this.dataTracker.get(PARTICLE_TYPE);
            float radius = this.dataTracker.get(RADIUS);
            net.minecraft.particle.ParticleEffect particleType = switch (particle) {
                case "water" -> net.minecraft.particle.ParticleTypes.FALLING_WATER;
                case "smoke" -> net.minecraft.particle.ParticleTypes.SMOKE;
                case "lightning" -> net.minecraft.particle.ParticleTypes.ELECTRIC_SPARK;
                case "wind" -> net.minecraft.particle.ParticleTypes.CLOUD;
                case "earth" -> net.minecraft.particle.ParticleTypes.POOF;
                default -> net.minecraft.particle.ParticleTypes.FLAME;
            };

            // Больше частиц для больших снарядов
            int count = Math.max(5, (int)(radius * 2));
            float spread = radius * 0.3f;

            for (int i = 0; i < count; i++) {
                double ox = (Math.random() - 0.5) * spread;
                double oy = (Math.random() - 0.5) * spread;
                double oz = (Math.random() - 0.5) * spread;
                serverWorld.spawnParticles(particleType,
                        this.getX() + ox, this.getY() + oy, this.getZ() + oz,
                        1, 0.03, 0.03, 0.03, 0.02);
            }

            // Дымовой шлейф для больших снарядов
            if (radius > 4.0f) {
                serverWorld.spawnParticles(net.minecraft.particle.ParticleTypes.LARGE_SMOKE,
                        this.getX(), this.getY(), this.getZ(),
                        (int)(radius * 0.3), 0.2, 0.2, 0.2, 0.005);
            }
        }
    }

    @Override
    protected void readCustomDataFromNbt(NbtCompound nbt) {
        this.dataTracker.set(DAMAGE, nbt.getFloat("Damage"));
        this.dataTracker.set(RADIUS, nbt.getFloat("Radius"));
        this.dataTracker.set(PARTICLE_TYPE, nbt.getString("Particle"));
        this.dataTracker.set(LIFETIME, nbt.getInt("Lifetime"));
        this.dataTracker.set(HAS_GRAVITY, nbt.getBoolean("HasGravity"));
        this.dataTracker.set(PIERCE_COUNT, nbt.getInt("PierceCount"));
        this.dataTracker.set(BOUNCE_COUNT, nbt.getInt("BounceCount"));
        this.pierceRemaining = this.dataTracker.get(PIERCE_COUNT);
        this.bounceRemaining = this.dataTracker.get(BOUNCE_COUNT);
        if (nbt.containsUuid("OwnerUUID")) {
            ownerId = nbt.getUuid("OwnerUUID");
        }
    }

    @Override
    protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putFloat("Damage", this.dataTracker.get(DAMAGE));
        nbt.putFloat("Radius", this.dataTracker.get(RADIUS));
        nbt.putString("Particle", this.dataTracker.get(PARTICLE_TYPE));
        nbt.putInt("Lifetime", this.dataTracker.get(LIFETIME));
        nbt.putBoolean("HasGravity", this.dataTracker.get(HAS_GRAVITY));
        nbt.putInt("PierceCount", this.dataTracker.get(PIERCE_COUNT));
        nbt.putInt("BounceCount", this.dataTracker.get(BOUNCE_COUNT));
        if (ownerId != null) nbt.putUuid("OwnerUUID", ownerId);
    }
}

# ================= src\main\java\com\example\shinobicore\entity\NinjaProjectileRenderer.java =================
package com.example.shinobicore.entity;

import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

public class NinjaProjectileRenderer extends EntityRenderer<NinjaProjectileEntity> {
    private static final Identifier WHITE_TEXTURE = new Identifier("textures/misc/white.png");
    private static final Identifier LAVA_TEXTURE = new Identifier("textures/block/lava_still.png");
    private static final Identifier WATER_TEXTURE = new Identifier("textures/block/water_still.png");

    public NinjaProjectileRenderer(EntityRendererFactory.Context ctx) {
        super(ctx);
    }

    @Override
    public void render(NinjaProjectileEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vertexConsumers, int light) {
        super.render(entity, yaw, tickDelta, matrices, vertexConsumers, light);

        float radius = entity.getRadius() * 0.25f;
        if (radius < 0.1f) radius = 0.1f;
        String particle = entity.getParticleType();

        // Выбираем текстуру и цвет в зависимости от стихии
        Identifier texture = getTextureForParticle(particle);
        int innerColor = getInnerColor(particle);
        int outerColor = getOuterColor(particle);

        matrices.push();
        matrices.translate(0, entity.getHeight() / 2.0, 0);

        // Внутреннее ядро с текстурой
        renderSphereQuads(matrices, vertexConsumers, radius, innerColor, light, texture);

        // Внешнее свечение (полупрозрачное, белая текстура + tint)
        renderSphereQuads(matrices, vertexConsumers, radius * 1.4f, outerColor, light, WHITE_TEXTURE);

        // Третий слой для очень больших снарядов
        if (entity.getRadius() > 6.0f) {
            renderSphereQuads(matrices, vertexConsumers, radius * 1.8f, outerColor, light, WHITE_TEXTURE);
        }

        matrices.pop();
    }

    private Identifier getTextureForParticle(String particle) {
        return switch (particle) {
            case "fire" -> LAVA_TEXTURE;      // Текстура лавы для огня
            case "water" -> WATER_TEXTURE;    // Текстура воды для воды
            default -> WHITE_TEXTURE;         // Белая + tint для остальных
        };
    }

    private int getInnerColor(String particle) {
        return switch (particle) {
            case "fire" -> 0xFFFFFFFF;       // Белый (текстура лавы сама оранжевая)
            case "water" -> 0xFFFFFFFF;      // Белый (текстура воды сама синяя)
            case "lightning" -> 0xFFFFFF44;  // Жёлтый
            case "wind" -> 0xFFDDDDDD;       // Светло-серый
            case "earth" -> 0xFF996633;      // Коричневый
            case "smoke" -> 0xFF888888;      // Серый
            default -> 0xFFFF6600;
        };
    }

    private int getOuterColor(String particle) {
        return switch (particle) {
            case "fire" -> 0x66FF4400;       // Полупрозрачный красный (свечение)
            case "water" -> 0x662266FF;      // Полупрозрачный синий
            case "lightning" -> 0x66FFFF00;  // Полупрозрачный жёлтый
            case "wind" -> 0x66CCCCCC;       // Полупрозрачный серый
            case "earth" -> 0x66774422;      // Полупрозрачный коричневый
            case "smoke" -> 0x66666666;      // Полупрозрачный тёмно-серый
            default -> 0x66FF4400;
        };
    }

    /**
     * Рисует 6 квадов под разными углами для создания объемного шара.
     */
    private void renderSphereQuads(MatrixStack matrices, VertexConsumerProvider vc,
                                    float size, int color, int light, Identifier texture) {
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(texture));

        float r = ((color >> 16) & 0xFF) / 255f;
        float g = ((color >> 8) & 0xFF) / 255f;
        float b = (color & 0xFF) / 255f;
        float a = ((color >> 24) & 0xFF) / 255f;

        float half = size;

        // 3 вертикальных квада (0°, 60°, 120°)
        for (int i = 0; i < 3; i++) {
            float angle = i * 60f;
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(angle));
            Matrix4f m = matrices.peek().getPositionMatrix();
            emitQuad(consumer, m,
                    -half, -half, 0,   half, -half, 0,   half, half, 0,   -half, half, 0,
                    r, g, b, a, light);
            matrices.pop();
        }

        // Горизонтальный квад
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
        Matrix4f mH = matrices.peek().getPositionMatrix();
        emitQuad(consumer, mH,
                -half, -half, 0,   half, -half, 0,   half, half, 0,   -half, half, 0,
                r, g, b, a, light);
        matrices.pop();

        // 2 диагональных квада (±45°)
        for (int i = 0; i < 2; i++) {
            float yAngle = i * 90f;
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(yAngle));
            matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(45));
            Matrix4f mD = matrices.peek().getPositionMatrix();
            emitQuad(consumer, mD,
                    -half, -half, 0,   half, -half, 0,   half, half, 0,   -half, half, 0,
                    r, g, b, a, light);
            matrices.pop();
        }
    }

    private void emitQuad(VertexConsumer consumer, Matrix4f matrix,
                           float x1, float y1, float z1,
                           float x2, float y2, float z2,
                           float x3, float y3, float z3,
                           float x4, float y4, float z4,
                           float r, float g, float b, float a, int light) {
        // Передняя сторона
        vertex(consumer, matrix, x1, y1, z1, 0, 1, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 0, 0, r, g, b, a, light);
        // Задняя сторона
        vertex(consumer, matrix, x2, y2, z2, 0, 1, r, g, b, a, light);
        vertex(consumer, matrix, x1, y1, z1, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 0, 0, r, g, b, a, light);
    }

    private void vertex(VertexConsumer consumer, Matrix4f matrix,
                         float x, float y, float z, float u, float v,
                         float r, float g, float b, float a, int light) {
        consumer.vertex(matrix, x, y, z)
                .color(r, g, b, a)
                .texture(u, v)
                .overlay(OverlayTexture.DEFAULT_UV)
                .light(light)
                .normal(0, 1, 0)
                .next();
    }

    @Override
    public Identifier getTexture(NinjaProjectileEntity entity) {
        return getTextureForParticle(entity.getParticleType());
    }
}

# ================= src\main\java\com\example\shinobicore\entity\ShurikenEntity.java =================
package com.example.shinobicore.entity;
import com.example.shinobicore.combat.MarkTracker;
import com.example.shinobicore.combat.ThrowingHelper;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;
import java.util.UUID;
public class ShurikenEntity extends Entity {
    private UUID ownerId;
    private float damage = 3f;
    private boolean stuck = false;
    private int age = 0;
    public ShurikenEntity(EntityType<?> type, World world) { super(type, world); }
    public ShurikenEntity(World world, LivingEntity owner, Vec3d velocity, float damage) {
        super(ModEntities.SHURIKEN, world);
        this.ownerId = owner.getUuid();
        this.damage = damage;
        this.setPosition(owner.getX(), owner.getEyeY() - 0.2, owner.getZ());
        this.setVelocity(velocity);
        this.velocityDirty = true;
    }
    @Override protected void initDataTracker() {}
    @Override public void tick() {
        super.tick();
        age++;
        if (stuck) { if (age > 400) discard(); return; }
        if (age > 160) { discard(); return; }
        Vec3d vel = this.getVelocity();
        vel = new Vec3d(vel.x, vel.y - 0.035, vel.z);
        this.setVelocity(vel);
        Vec3d start = this.getPos();
        Vec3d end = start.add(vel);
        HitResult blockHit = this.getWorld().raycast(new RaycastContext(start, end,
                RaycastContext.ShapeType.COLLIDER, RaycastContext.FluidHandling.NONE, this));
        LivingEntity hitEntity = null;
        double closest = Double.MAX_VALUE;
        Box searchBox = this.getBoundingBox().stretch(vel).expand(0.15);
        for (Entity entity : this.getWorld().getOtherEntities(this, searchBox)) {
            if (entity instanceof LivingEntity living
                    && (ownerId == null || !living.getUuid().equals(ownerId))) {
                var opt = living.getBoundingBox().expand(0.3).raycast(start, end);
                if (opt.isPresent()) {
                    double d = start.squaredDistanceTo(opt.get());
                    if (d < closest) { closest = d; hitEntity = living; }
                }
            }
        }
        if (hitEntity != null) {
            hitEntity.damage(this.getDamageSources().magic(), MarkTracker.boost(hitEntity, damage));
            Entity owner = getOwner();
            if (owner instanceof ServerPlayerEntity sp) {
                MarkTracker.mark(hitEntity, ThrowingHelper.markDurationMs(sp));
            } else {
                MarkTracker.mark(hitEntity, 10000);
            }
            hitEntity.addStatusEffect(new StatusEffectInstance(StatusEffects.GLOWING, 100, 0, false, false));
            if (this.getWorld() instanceof ServerWorld sw) {
                sw.spawnParticles(ParticleTypes.CRIT, hitEntity.getX(), hitEntity.getY() + 1,
                        hitEntity.getZ(), 8, 0.3, 0.3, 0.3, 0.05);
            }
            this.playSound(SoundEvents.ENTITY_ARROW_HIT, 0.8f, 1.2f);
            this.discard();
            return;
        }
        if (blockHit.getType() == HitResult.Type.BLOCK) {
            if (this.getWorld() instanceof ServerWorld swHit) {
                swHit.spawnParticles(ParticleTypes.POOF, this.getX(), this.getY(), this.getZ(), 4, 0.1, 0.1, 0.1, 0.02);
            }
            this.playSound(SoundEvents.BLOCK_WOOD_HIT, 0.5f, 1.4f);
            this.discard();
            return;
        }
        this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);
    }
    public void reflect(ServerPlayerEntity newOwner) {
        this.ownerId = newOwner.getUuid();
        Vec3d v = this.getVelocity();
        this.setVelocity(v.multiply(-1.3));
        this.velocityDirty = true;
    }

    public Entity getOwner() {
        if (ownerId == null) return null;
        if (this.getWorld() instanceof ServerWorld sw) return sw.getPlayerByUuid(ownerId);
        return null;
    }
    public int getAge() { return age; }
    public boolean isStuck() { return stuck; }
    @Override protected void readCustomDataFromNbt(NbtCompound nbt) {
        damage = nbt.getFloat("Damage");
        if (nbt.containsUuid("OwnerUUID")) ownerId = nbt.getUuid("OwnerUUID");
    }
    @Override protected void writeCustomDataToNbt(NbtCompound nbt) {
        nbt.putFloat("Damage", damage);
        if (ownerId != null) nbt.putUuid("OwnerUUID", ownerId);
    }
}

# ================= src\main\java\com\example\shinobicore\entity\ShurikenRenderer.java =================
package com.example.shinobicore.entity;
import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;
public class ShurikenRenderer extends EntityRenderer<ShurikenEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");
    public ShurikenRenderer(EntityRendererFactory.Context ctx) { super(ctx); }
    @Override public void render(ShurikenEntity entity, float yaw, float tickDelta,
                                 MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        matrices.push();
        matrices.translate(0, 0.25, 0);
        if (!entity.isStuck()) {
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees((entity.getAge() + tickDelta) * 25f));
            matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
        }
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        float s = 0.22f;
        for (int q = 0; q < 2; q++) {
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(q * 90f));
            Matrix4f m = matrices.peek().getPositionMatrix();
            vertex(consumer, m, -s, 0, -s, light); vertex(consumer, m, -s, 0, s, light);
            vertex(consumer, m, s, 0, s, light);   vertex(consumer, m, s, 0, -s, light);
            matrices.pop();
        }
        matrices.pop();
    }
    private void vertex(VertexConsumer c, Matrix4f m, float x, float y, float z, int light) {
        c.vertex(m, x, y, z).color(0.75f, 0.75f, 0.78f, 1f).texture(0, 0)
                .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }
    @Override public Identifier getTexture(ShurikenEntity entity) { return TEX; }
}

# ================= src\main\java\com\example\shinobicore\event\NinjaTickHandler.java =================
package com.example.shinobicore.event;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.jutsu.WallRemovalTask;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.combat.KenjutsuStance;
import net.minecraft.entity.attribute.EntityAttributeModifier;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import java.util.UUID;
import com.example.shinobicore.jutsu.JutsuLogger;
public class NinjaTickHandler {
    private static int tickCounter = 0;
    private static final UUID SPEED_UUID = UUID.fromString("9e1a5b6c-7d8f-4a2b-9c3d-1e2f3a4b5c6d");
    private static final UUID SPRINT_UUID = UUID.fromString("8f7a6b5c-4d3e-2f1a-0b9c-8d7e6f5a4b3c");
    public static void onServerTick(MinecraftServer server) {
        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            var speedAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
            if (speedAttr != null) {
                speedAttr.removeModifier(SPRINT_UUID);
                if (data.isChakraMode() && data.getCurrentChakra() > 0 && player.isSprinting()) {
                    speedAttr.addPersistentModifier(new EntityAttributeModifier(
                            SPRINT_UUID, "shinobicore_sprint", 0.5,
                            EntityAttributeModifier.Operation.MULTIPLY_BASE));
                }
            }
        }
        tickCounter++;
        if (tickCounter < 20) return;
        tickCounter = 0;
        for (var world : server.getWorlds()) {
            WallRemovalTask.tick(world);
        }
        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            if (data.isMeditating() && !canMeditate(player, data)) {
                data.setMeditating(false);
            }
            float maxChakra = NinjaFormula.maxChakra(data);
            if (data.getCurrentChakra() < maxChakra) {
                float regen = NinjaFormula.regenPerSecond(data);
                if (data.isMeditating()) regen *= NinjaFormula.meditationRegenMultiplier();
                if (data.isRasenganCharging()) {
                    data.setRasenganChargeTicks(data.getRasenganChargeTicks() + 1);
                    if (data.getRasenganChargeTicks() >= data.getRasenganChargeTarget()) {
                        data.setRasenganCharging(false);
                        data.setRasenganReady(true);
                        player.sendMessage(Text.literal("\u00a7b\u2726 Rasengan ready! Press LMB to strike!"), false);
                        ShinobiCore.sendRasenganSync(player);
                    }
                    if (data.getRasenganChargeTicks() % 5 == 0) {
                        ShinobiCore.sendRasenganSync(player);
                    }
                } else if (data.isChakraMode()) regen *= NinjaFormula.chakraModeRegenMultiplier();
                data.setCurrentChakra(Math.min(data.getCurrentChakra() + regen, maxChakra));
            }
            if (data.getFatigue() > 0) {
                float decay = NinjaFormula.fatigueDecayPerSecond(data);
                if (data.isMeditating()) decay *= NinjaFormula.meditationFatigueDecayMultiplier();
                data.setFatigue(Math.max(0, data.getFatigue() - decay));
            }
            if (data.isMeditating()) {
                NinjaFormula.grantReserveXp(data, NinjaFormula.meditationReserveXpPerSecond());
                NinjaFormula.grantStatXp(data, StatType.CONTROL, NinjaFormula.meditationControlXpPerSecond());
                int baseAmp = (int) ModConfig.instance.meditation.slownessBase;
                float red = data.getStatLevel(StatType.CONTROL) / 100f * ModConfig.instance.meditation.slownessControlReduction;
                int amp = Math.max(0, (int) (baseAmp - red));
                if (amp > 0) {
                    player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 40, amp, false, false, true));
                }
            }
            if (data.isChakraMode()) {
                float drain = NinjaFormula.chakraModeDrainPerSecond(data);
                if (data.getCurrentChakra() >= drain) {
                    data.setCurrentChakra(data.getCurrentChakra() - drain);
                } else {
                    data.setChakraMode(false);
                    ShinobiCore.sendBodySync(player);
                    player.sendMessage(Text.literal("\u00a7cChakra depleted!"), false);
                }
            }
            // === SEIGAN SHIELD SLOW ===
            boolean seiganShield = data.isKatanaDeflectHeld()
                    && KenjutsuStance.fromId(data.getKatanaStanceId()) == KenjutsuStance.SEIGAN;
            if (seiganShield) {
                player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 5, 2, false, false, false));
            }
            double maxHp = NinjaFormula.maxHealth(data.getHpLevel());
            var hpAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MAX_HEALTH);
            if (hpAttr != null) {
                hpAttr.setBaseValue(maxHp);
                if (player.getHealth() > maxHp) player.setHealth((float) maxHp);
            }
            float speedMult = NinjaFormula.speedMultiplier(data.getSpeedLevel(), data.isChakraMode());
            var speedAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MOVEMENT_SPEED);
            if (speedAttr != null) {
                speedAttr.removeModifier(SPEED_UUID);
                if (speedMult != 1.0f) {
                    speedAttr.addPersistentModifier(new EntityAttributeModifier(
                            SPEED_UUID, "shinobicore_speed", speedMult - 1.0,
                            EntityAttributeModifier.Operation.MULTIPLY_BASE));
                }
            }
            ShinobiCore.sendChakraSync(player);
            if (data.consumeStatsDirty()) {
                ShinobiCore.sendStatsSync(player);
            }
        }
    }
    private static boolean canMeditate(ServerPlayerEntity player, NinjaPlayerData data) {
        if (data.isExhausted()) return false;
        if (!player.isOnGround()) return false;
        if (player.getHungerManager().getFoodLevel() < 6) return false;
        double dx = player.getX() - player.prevX;
        double dz = player.getZ() - player.prevZ;
        if (dx * dx + dz * dz > 0.01) return false;
        return true;
    }
}

# ================= src\main\java\com\example\shinobicore\item\KatanaItem.java =================
package com.example.shinobicore.item;
import net.minecraft.item.Item;
import net.minecraft.item.SwordItem;
import net.minecraft.item.ToolMaterials;
public class KatanaItem extends SwordItem {
    public KatanaItem() {
        super(ToolMaterials.IRON, 4, -2.0f, new Item.Settings().maxCount(1));
    }
}

# ================= src\main\java\com\example\shinobicore\item\ModItems.java =================
package com.example.shinobicore.item;
import com.example.shinobicore.ShinobiCore;
import net.minecraft.item.Item;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;
public class ModItems {
    public static final Item KATANA = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "katana"), new KatanaItem());
    public static final Item SHURIKEN = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "shuriken"),
            new ThrowingWeaponItem(new Item.Settings().maxCount(16), 3f, 3.0f, 8));
    public static final Item KUNAI = Registry.register(Registries.ITEM,
            new Identifier(ShinobiCore.MOD_ID, "kunai"),
            new ThrowingWeaponItem(new Item.Settings().maxCount(16), 5f, 2.2f, 12));
    public static void register() {
        ShinobiCore.LOGGER.info("Registered katana/shuriken/kunai items");
    }
}

# ================= src\main\java\com\example\shinobicore\item\ThrowingWeaponItem.java =================
package com.example.shinobicore.item;
import com.example.shinobicore.combat.ThrowingHelper;
import com.example.shinobicore.entity.ShurikenEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.Hand;
import net.minecraft.util.TypedActionResult;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;
public class ThrowingWeaponItem extends Item {
    private final float damage;
    private final float speed;
    private final int cooldown;
    public ThrowingWeaponItem(Settings settings, float damage, float speed, int cooldown) {
        super(settings);
        this.damage = damage; this.speed = speed; this.cooldown = cooldown;
    }
    @Override public TypedActionResult<ItemStack> use(World world, PlayerEntity user, Hand hand) {
        ItemStack stack = user.getStackInHand(hand);
        if (!world.isClient && user instanceof ServerPlayerEntity sp) {
            Vec3d dir = ThrowingHelper.aimAssist(sp, user.getRotationVector(), 24.0);
            world.spawnEntity(new ShurikenEntity(world, user, dir.multiply(speed), damage));
            if (ThrowingHelper.doubleThrow(sp)) {
                world.spawnEntity(new ShurikenEntity(world, user, rotate(dir, 4.0).multiply(speed), damage));
            }
            user.playSound(SoundEvents.ENTITY_ARROW_SHOOT, 0.8f, 1.4f);
            if (!user.getAbilities().creativeMode) stack.decrement(1);
            user.getItemCooldownManager().set(this, cooldown);
        }
        return TypedActionResult.success(stack, world.isClient());
    }
    private Vec3d rotate(Vec3d v, double deg) {
        double rad = Math.toRadians(deg), cos = Math.cos(rad), sin = Math.sin(rad);
        return new Vec3d(v.x * cos - v.z * sin, v.y, v.x * sin + v.z * cos).normalize();
    }
}

# ================= src\main\java\com\example\shinobicore\jutsu\AoeBehavior.java =================
package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.combat.MarkTracker;
import com.example.shinobicore.tree.TreePassives;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffect;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public class AoeBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 3.0f;
        String particle = params.has("particle") ? params.get("particle").getAsString() : "explosion";
        int particleCount = params.has("particleCount") ? params.get("particleCount").getAsInt() : 30;
        float knockback = params.has("knockback") ? params.get("knockback").getAsFloat() : 0.3f;

        // Статус-эффект
        String statusEffect = params.has("statusEffect") ? params.get("statusEffect").getAsString() : null;
        int statusDuration = params.has("statusDuration") ? params.get("statusDuration").getAsInt() : 60;
        int statusAmplifier = params.has("statusAmplifier") ? params.get("statusAmplifier").getAsInt() : 0;

        // Оглушение (slowness 255 + mining_fatigue 255 + nausea)
        boolean stun = params.has("stun") && params.get("stun").getAsBoolean();
        int stunDuration = params.has("stunDuration") ? params.get("stunDuration").getAsInt() : 20;
        if (stun) {
            stunDuration = (int)(stunDuration * (1 + TreePassives.collectServer(data).kekkeiStun));
        }

        if (!(player.getWorld() instanceof ServerWorld serverWorld)) return;

        Vec3d center = player.getPos().add(0, player.getHeight() / 2.0, 0);

        // Визуальные эффекты
        spawnParticles(serverWorld, center, radius, particle, particleCount);

        // Урон и эффекты по области
        for (Entity entity : serverWorld.getOtherEntities(player, player.getBoundingBox().expand(radius))) {
            if (entity instanceof LivingEntity living && !living.equals(player)) {
                // Урон (может быть 0 для волн без урона)
                if (damage > 0) {
                    living.damage(player.getDamageSources().magic(), MarkTracker.boost(living, damage));
                }

                // Отброс от центра
                if (knockback > 0) {
                    Vec3d toEntity = living.getPos().subtract(center).normalize();
                    Vec3d kb = toEntity.multiply(knockback).add(0, 0.2, 0);
                    living.addVelocity(kb.x, kb.y, kb.z);
                    living.velocityModified = true;
                }

                // Статус-эффект
                if (statusEffect != null) {
                    StatusEffect effect = parseStatusEffect(statusEffect);
                    if (effect != null) {
                        living.addStatusEffect(new StatusEffectInstance(
                                effect, statusDuration, statusAmplifier, false, true));
                    }
                }

                // Оглушение
                if (stun) {
                    living.addStatusEffect(new StatusEffectInstance(
                            StatusEffects.SLOWNESS, stunDuration, 255, false, false));
                    living.addStatusEffect(new StatusEffectInstance(
                            StatusEffects.MINING_FATIGUE, stunDuration, 255, false, false));
                    living.addStatusEffect(new StatusEffectInstance(
                            StatusEffects.NAUSEA, stunDuration, 0, false, false));
                }
            }
        }

        JutsuLogger.logBehavior("aoe", String.format(
                "player=%s, radius=%.1f, damage=%.2f, knockback=%.2f, stun=%b, status=%s",
                player.getName().getString(), radius, damage, knockback, stun, statusEffect));
    }

    private StatusEffect parseStatusEffect(String id) {
        return switch (id) {
            case "slowness" -> StatusEffects.SLOWNESS;
            case "weakness" -> StatusEffects.WEAKNESS;
            case "poison" -> StatusEffects.POISON;
            case "wither" -> StatusEffects.WITHER;
            case "blindness" -> StatusEffects.BLINDNESS;
            case "nausea" -> StatusEffects.NAUSEA;
            case "mining_fatigue" -> StatusEffects.MINING_FATIGUE;
            case "levitation" -> StatusEffects.LEVITATION;
            case "glowing" -> StatusEffects.GLOWING;
            default -> null;
        };
    }

    private void spawnParticles(ServerWorld world, Vec3d center, float radius,
                                 String particle, int count) {
        ParticleEffect particleType = switch (particle) {
            case "fire" -> ParticleTypes.FLAME;
            case "water" -> ParticleTypes.FALLING_WATER;
            case "lightning" -> ParticleTypes.ELECTRIC_SPARK;
            case "wind" -> ParticleTypes.CLOUD;
            case "earth" -> ParticleTypes.POOF;
            case "smoke" -> ParticleTypes.LARGE_SMOKE;
            default -> ParticleTypes.EXPLOSION;
        };

        for (int i = 0; i < count; i++) {
            double angle = (i / (double) count) * Math.PI * 2;
            double r = radius * (0.3 + 0.7 * Math.random());
            double x = center.x + Math.cos(angle) * r;
            double z = center.z + Math.sin(angle) * r;
            double y = center.y + (Math.random() - 0.5) * radius;

            world.spawnParticles(particleType, x, y, z, 1,
                    (Math.random() - 0.5) * 0.2,
                    Math.random() * 0.3,
                    (Math.random() - 0.5) * 0.2,
                    0.05);
        }
    }
}

# ================= src\main\java\com\example\shinobicore\jutsu\BehaviorRegistry.java =================
package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;

import java.util.HashMap;
import java.util.Map;

public class BehaviorRegistry {
    private static final Map<String, JutsuBehavior> BEHAVIORS = new HashMap<>();
    private static final Map<String, JutsuBehavior> CUSTOM_CACHE = new HashMap<>();

    public static void register(String type, JutsuBehavior behavior) {
        BEHAVIORS.put(type, behavior);
        ShinobiCore.LOGGER.info("Registered jutsu behavior: {}", type);
    }

    public static JutsuBehavior get(String type) {
        return BEHAVIORS.getOrDefault(type, new DefaultBehavior());
    }

    public static JutsuBehavior getFor(JutsuDefinition def) {
        if ("custom".equals(def.type()) && def.behaviorClass() != null) {
            return CUSTOM_CACHE.computeIfAbsent(def.behaviorClass(), cls -> {
                try {
                    Class<?> c = Class.forName(cls);
                    return (JutsuBehavior) c.getDeclaredConstructor().newInstance();
                } catch (Exception e) {
                    ShinobiCore.LOGGER.error("Failed to load custom behavior {}: {}", cls, e.getMessage());
                    return new DefaultBehavior();
                }
            });
        }
        return get(def.type());
    }
}

# ================= src\main\java\com\example\shinobicore\jutsu\custom\RasenganBehavior.java =================
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

public class RasenganBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        if (data.isRasenganCharging() || data.isRasenganReady()) {
            player.sendMessage(Text.literal("§7Rasengan is already active!"), false);
            return;
        }

        int controlLevel = data.getStatLevel(StatType.CONTROL);

        // === ИСПРАВЛЕНО: быстрая зарядка ===
        // baseChargeTicks=120 (6 сек), minChargeTicks=40 (2 сек)
        // Формула: chargeTicks = max(min, base - control * 0.8)
        // control=0 → 120 тиков (6 сек), за 3 сек = 50%
        // control=50 → 80 тиков (4 сек)
        // control=100 → max(40, 40) = 40 тиков (2 сек)
        int baseChargeTicks = params.has("baseChargeTicks") ? params.get("baseChargeTicks").getAsInt() : 120;
        int minChargeTicks = params.has("minChargeTicks") ? params.get("minChargeTicks").getAsInt() : 40;
        int chargeTicks = Math.max(minChargeTicks, baseChargeTicks - (int)(controlLevel * 0.8));

        data.setRasenganCharging(true);
        data.setRasenganChargeTicks(0);
        data.setRasenganChargeTarget(chargeTicks);
        data.setRasenganReady(false);

        float chargeSeconds = chargeTicks / 20.0f;
        player.sendMessage(Text.literal("§bRasengan charging... " + String.format("%.1f", chargeSeconds) + "s"), false);

        JutsuLogger.logBehavior("rasengan", String.format(
                "CHARGE START: player=%s, control=%d, chargeTicks=%d (%.1fs)",
                player.getName().getString(), controlLevel, chargeTicks, chargeSeconds));
    }
}

# ================= src\main\java\com\example\shinobicore\jutsu\custom\test_custom.json =================
{
  "id": "shinobicore:test_custom",
  "name": "Test Custom Jutsu",
  "category": "elemental_ninjutsu",
  "type": "custom",
  "behaviorClass": "com.example.shinobicore.jutsu.custom.TestCustomBehavior",
  "params": {},
  "baseCost": 10,
  "baseDamage": 5,
  "strain": 2,
  "requiredUsesForFullProficiency": 10,
  "requirements": {}
}

# ================= src\main\java\com\example\shinobicore\jutsu\custom\TestCustomBehavior.java =================
package com.example.shinobicore.jutsu.custom;

import com.example.shinobicore.jutsu.JutsuBehavior;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

public class TestCustomBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        player.sendMessage(Text.literal("§6[Custom Behavior] Работает! damage=" + damage), false);
    }
}

# ================= src\main\java\com\example\shinobicore\jutsu\DashBehavior.java =================
package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.combat.MarkTracker;
import com.google.gson.JsonObject;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffect;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.List;

public class DashBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        float distance = params.has("distance") ? params.get("distance").getAsFloat() : 5.0f;
        float knockback = params.has("knockback") ? params.get("knockback").getAsFloat() : 0.5f;
        float hitRadius = params.has("hitRadius") ? params.get("hitRadius").getAsFloat() : 1.0f;
        float waveWidth = params.has("waveWidth") ? params.get("waveWidth").getAsFloat() : 0f;

        // Статус-эффект
        String statusEffect = params.has("statusEffect") ? params.get("statusEffect").getAsString() : null;
        int statusDuration = params.has("statusDuration") ? params.get("statusDuration").getAsInt() : 60;
        int statusAmplifier = params.has("statusAmplifier") ? params.get("statusAmplifier").getAsInt() : 0;

        // Частицы вдоль пути
        String particle = params.has("particle") ? params.get("particle").getAsString() : null;
        int particleCount = params.has("particleCount") ? params.get("particleCount").getAsInt() : 20;

        // === НОВОЕ: Trail-частицы (брызги воды) ===
        String trailParticle = params.has("trailParticle") ? params.get("trailParticle").getAsString() : null;
        int trailCount = params.has("trailCount") ? params.get("trailCount").getAsInt() : 0;

        // === НОВОЕ: Splash при приземлении ===
        boolean splashOnLand = params.has("splashOnLand") && params.get("splashOnLand").getAsBoolean();
        float splashRadius = params.has("splashRadius") ? params.get("splashRadius").getAsFloat() : 3.0f;
        float splashDamage = params.has("splashDamage") ? params.get("splashDamage").getAsFloat() : 0f;

        Vec3d look = player.getRotationVector();
        Vec3d startPos = player.getPos();
        Vec3d endPos = startPos.add(look.multiply(distance));

        // Перемещаем игрока
        player.addVelocity(look.x * distance * 0.5, 0.1, look.z * distance * 0.5);
        player.velocityModified = true;

        if (!(player.getWorld() instanceof ServerWorld serverWorld)) return;

        // Ищем мобов на пути рывка
        List<LivingEntity> targets = findEntitiesOnPath(
                serverWorld, player, startPos, endPos, hitRadius, waveWidth);

        for (LivingEntity target : targets) {
            if (damage > 0) {
                target.damage(player.getDamageSources().magic(), MarkTracker.boost(target, damage));
            }

            Vec3d toTarget = target.getPos().subtract(startPos).normalize();
            Vec3d kb = toTarget.multiply(knockback).add(0, 0.3, 0);
            target.addVelocity(kb.x, kb.y, kb.z);
            target.velocityModified = true;

            if (statusEffect != null) {
                StatusEffect effect = parseStatusEffect(statusEffect);
                if (effect != null) {
                    target.addStatusEffect(new StatusEffectInstance(
                            effect, statusDuration, statusAmplifier, false, true));
                }
            }
        }

        // === НОВОЕ: Trail-частицы (брызги вдоль пути) ===
        if (trailParticle != null && trailCount > 0) {
            spawnTrailParticles(serverWorld, startPos, endPos, trailParticle, trailCount);
        }

        // Частицы вдоль траектории
        if (particle != null) {
            spawnDashParticles(serverWorld, startPos, endPos, particle, particleCount);
        }

        // === НОВОЕ: Splash при приземлении ===
        if (splashOnLand) {
            spawnSplashAtEnd(serverWorld, endPos, splashRadius, splashDamage, player);
        }

        JutsuLogger.logBehavior("dash", String.format(
                "player=%s, targets=%d, distance=%.1f, knockback=%.2f, waveWidth=%.1f, trail=%b, splash=%b",
                player.getName().getString(), targets.size(), distance, knockback,
                waveWidth, trailParticle != null, splashOnLand));
    }

    private List<LivingEntity> findEntitiesOnPath(ServerWorld world, ServerPlayerEntity attacker,
                                                   Vec3d start, Vec3d end,
                                                   float radius, float waveWidth) {
        List<LivingEntity> targets = new ArrayList<>();
        Vec3d dir = end.subtract(start).normalize();
        float length = (float) start.distanceTo(end);
        float effectiveRadius = radius + waveWidth;

        for (float d = 0; d <= length; d += 0.5f) {
            Vec3d checkPos = start.add(dir.multiply(d));
            for (Entity entity : world.getOtherEntities(attacker,
                    attacker.getBoundingBox().expand(effectiveRadius + 1.0)
                            .offset(checkPos.subtract(attacker.getPos())))) {
                if (entity instanceof LivingEntity living
                        && !living.equals(attacker) && living.isAlive()) {
                    if (living.getPos().distanceTo(checkPos) <= effectiveRadius + 0.5) {
                        if (!targets.contains(living)) {
                            targets.add(living);
                        }
                    }
                }
            }
        }
        return targets;
    }

    // === НОВОЕ: Trail-частицы (брызги воды вдоль пути) ===
    private void spawnTrailParticles(ServerWorld world, Vec3d start, Vec3d end,
                                      String particle, int count) {
        ParticleEffect particleType = switch (particle) {
            case "water" -> ParticleTypes.FALLING_WATER;
            case "fire" -> ParticleTypes.FLAME;
            case "wind" -> ParticleTypes.CLOUD;
            case "earth" -> ParticleTypes.POOF;
            case "lightning" -> ParticleTypes.ELECTRIC_SPARK;
            default -> ParticleTypes.FALLING_WATER;
        };

        Vec3d dir = end.subtract(start).normalize();
        float length = (float) start.distanceTo(end);

        for (int i = 0; i < count; i++) {
            float progress = (float) i / count;
            Vec3d pos = start.add(dir.multiply(progress * length));

            // Разброс в стороны (брызги летят вбок)
            double spreadX = (Math.random() - 0.5) * 2.5;
            double spreadY = Math.random() * 1.5;
            double spreadZ = (Math.random() - 0.5) * 2.5;

            world.spawnParticles(particleType,
                    pos.x + spreadX, pos.y + 0.3 + spreadY, pos.z + spreadZ,
                    1, 0.15, 0.3, 0.15, 0.08);
        }

        // Дополнительные "брызги вверх" для эффекта водопада
        for (int i = 0; i < count / 3; i++) {
            float progress = (float) i / (count / 3);
            Vec3d pos = start.add(dir.multiply(progress * length));

            world.spawnParticles(ParticleTypes.SPLASH,
                    pos.x + (Math.random() - 0.5) * 2.0,
                    pos.y + 0.5,
                    pos.z + (Math.random() - 0.5) * 2.0,
                    2, 0.3, 0.5, 0.3, 0.1);
        }
    }

    // === НОВОЕ: Splash при приземлении ===
    private void spawnSplashAtEnd(ServerWorld world, Vec3d endPos, float radius,
                                   float splashDamage, ServerPlayerEntity player) {
        // Визуал: кольцо брызг
        int ringCount = 30;
        for (int i = 0; i < ringCount; i++) {
            double angle = (i / (double) ringCount) * Math.PI * 2;
            double x = endPos.x + Math.cos(angle) * radius;
            double z = endPos.z + Math.sin(angle) * radius;

            world.spawnParticles(ParticleTypes.FALLING_WATER, x, endPos.y + 0.5, z,
                    3, 0.2, 0.4, 0.2, 0.1);
            world.spawnParticles(ParticleTypes.SPLASH, x, endPos.y + 0.3, z,
                    2, 0.3, 0.5, 0.3, 0.12);
        }

        // Урон по области при приземлении
        if (splashDamage > 0) {
            for (Entity entity : world.getOtherEntities(player,
                    player.getBoundingBox().expand(radius))) {
                if (entity instanceof LivingEntity living && !living.equals(player)) {
                    living.damage(player.getDamageSources().magic(), splashDamage);
                    Vec3d kb = living.getPos().subtract(endPos).normalize().multiply(0.8);
                    living.addVelocity(kb.x, 0.4, kb.z);
                    living.velocityModified = true;
                }
            }
        }
    }

    private StatusEffect parseStatusEffect(String id) {
        return switch (id) {
            case "slowness" -> StatusEffects.SLOWNESS;
            case "weakness" -> StatusEffects.WEAKNESS;
            case "poison" -> StatusEffects.POISON;
            case "wither" -> StatusEffects.WITHER;
            case "blindness" -> StatusEffects.BLINDNESS;
            case "nausea" -> StatusEffects.NAUSEA;
            case "mining_fatigue" -> StatusEffects.MINING_FATIGUE;
            case "levitation" -> StatusEffects.LEVITATION;
            case "glowing" -> StatusEffects.GLOWING;
            default -> null;
        };
    }

    private void spawnDashParticles(ServerWorld world, Vec3d start, Vec3d end,
                                     String particle, int count) {
        ParticleEffect particleType = switch (particle) {
            case "fire" -> ParticleTypes.FLAME;
            case "water" -> ParticleTypes.FALLING_WATER;
            case "lightning" -> ParticleTypes.ELECTRIC_SPARK;
            case "wind" -> ParticleTypes.CLOUD;
            case "earth" -> ParticleTypes.POOF;
            case "smoke" -> ParticleTypes.LARGE_SMOKE;
            default -> ParticleTypes.CLOUD;
        };

        Vec3d dir = end.subtract(start).normalize();
        float length = (float) start.distanceTo(end);

        for (int i = 0; i < count; i++) {
            float progress = (float) i / count;
            Vec3d pos = start.add(dir.multiply(progress * length));

            double offsetX = (Math.random() - 0.5) * 1.5;
            double offsetY = (Math.random() - 0.5) * 0.8;
            double offsetZ = (Math.random() - 0.5) * 1.5;

            world.spawnParticles(particleType,
                    pos.x + offsetX, pos.y + 0.5 + offsetY, pos.z + offsetZ,
                    2, 0.1, 0.15, 0.1, 0.06);
        }
    }
}

# ================= src\main\java\com\example\shinobicore\jutsu\DefaultBehavior.java =================
package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

public class DefaultBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        player.sendMessage(Text.literal("§7[Jutsu effect placeholder]"), false);
    }
}

# ================= src\main\java\com\example\shinobicore\jutsu\JutsuBehavior.java =================
package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;

public interface JutsuBehavior {
    void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage);
}

# ================= src\main\java\com\example\shinobicore\jutsu\JutsuCaster.java =================
package com.example.shinobicore.jutsu;

import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.StatType;
import net.minecraft.server.network.ServerPlayerEntity;
import com.example.shinobicore.tree.TreePassives;
import com.example.shinobicore.stat.ElementType;
import net.minecraft.text.Text;

public class JutsuCaster {
    public static boolean cast(ServerPlayerEntity player, String jutsuId) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        TreePassives.Bonuses pbs = TreePassives.collectServer(data);
        if (!data.getLearnedJutsus().contains(jutsuId)) {
            player.sendMessage(Text.literal("§cYou haven't learned this jutsu!"), false);
            return false;
        }
        JutsuDefinition def = JutsuRegistry.get(jutsuId);
        if (def == null) {
            player.sendMessage(Text.literal("§cJutsu not found!"), false);
            return false;
        }
        if (!NinjaFormula.checkRequirements(def, data)) {
            player.sendMessage(Text.literal("§cYour stats are too low for this jutsu!"), false);
            JutsuLogger.logBehavior("caster",
                    String.format("REJECTED requirements: player=%s, jutsu=%s",
                            player.getName().getString(), jutsuId));
            return false;
        }
        float cost = NinjaFormula.calculateCost(def, data);
        if (data.getCurrentChakra() < cost) {
            player.sendMessage(Text.literal("§cNot enough chakra!"), false);
            JutsuLogger.logBehavior("caster",
                    String.format("REJECTED chakra: player=%s, need=%.1f, have=%.1f",
                            player.getName().getString(), cost, data.getCurrentChakra()));
            return false;
        }

        // Списываем чакру
        data.setCurrentChakra(data.getCurrentChakra() - cost);

        // Усталость с учётом клана
        float strain = def.strain() * (1f - pbs.fatigueReduction);
        ClanDefinition clan = ClanRegistry.get(data.getClanId());
        if (clan != null) {
            strain *= clan.fatigueMultiplier();
        }
        data.setFatigue(data.getFatigue() + strain);

        // Опыт
        NinjaFormula.grantUsage(data, jutsuId, 1);
        if (def.hasNature() && data.isNatureUnlocked(def.nature())) {
            float xpMult = (data.getAffinity() == def.nature())
                    ? ModConfig.instance.combat.affinityXpMultiplier
                    : 1f;
            int natureXp = Math.max(1, Math.round(cost * 0.2f * xpMult));
            NinjaFormula.grantNatureXp(data, def.nature(), natureXp);
        }
        int ninjutsuXp = Math.max(1, Math.round(cost * 0.1f));
        NinjaFormula.grantStatXp(data, StatType.NINJUTSU, ninjutsuXp);

        // Урон
        float damage = def.baseDamage() * NinjaFormula.damageMultiplier(data, def);
        if (def.hasNature()) {
            String nid = def.nature().getId();
            float elemBonus = 0f;
            if (nid.equals("fire")) {
                elemBonus += pbs.kekkeiFire;
                if (pbs.fireWindSynergy > 0 && data.isNatureUnlocked(ElementType.WIND)) elemBonus += pbs.fireWindSynergy;
            } else if (nid.equals("earth")) {
                elemBonus += pbs.kekkeiEarth;
            } else if (nid.equals("lightning")) {
                elemBonus += pbs.kekkeiLightning;
            }
            if (elemBonus > 0) damage *= (1f + elemBonus);
        }

        // === ЛОГИРОВАНИЕ ===
        JutsuLogger.logCast(player, def, data, damage, cost);

        // Вызываем behavior
        ShinobiCore.broadcastCastFx(player, def.hasNature() ? def.nature().getId() : "none");
        JutsuBehavior behavior = BehaviorRegistry.getFor(def);
        behavior.cast(player, def, data, def.params(), damage);

        return true;
    }
}

# ================= src\main\java\com\example\shinobicore\jutsu\JutsuDefinition.java =================
package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.ElementType;
import com.google.gson.JsonObject;

import java.util.Map;

public record JutsuDefinition(
    String id,
    String name,
    String category,
    ElementType nature,
    String type,
    String behaviorClass,
    JsonObject params,
    float baseCost,
    float baseDamage,
    float strain,
    int requiredUsesForFullProficiency,
    Map<String, Integer> requirements
) {
    public boolean hasNature() {
        return nature != null;
    }
}

# ================= src\main\java\com\example\shinobicore\jutsu\JutsuLogger.java =================
package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.network.ServerPlayerEntity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Отдельный логгер для техник.
 * Пишет в файл: config/shinobicore/jutsu_debug.log
 * Также дублирует в консоль через SLF4J.
 */
public class JutsuLogger {
    private static final Logger CONSOLE = LoggerFactory.getLogger("ShinobiCore-Jutsu");
    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS");
    private static Path logPath;
    private static boolean enabled = true;

    /**
     * Инициализация логгера. Вызывать ОДИН РАЗ в ShinobiCore.onInitialize().
     */
    public static void init() {
        logPath = Path.of("config", "shinobicore", "jutsu_debug.log");
        try {
            Files.createDirectories(logPath.getParent());
            if (!Files.exists(logPath)) {
                Files.createFile(logPath);
                writeHeader();
            }
            CONSOLE.info("Jutsu debug log initialized: {}", logPath.toAbsolutePath());
        } catch (IOException e) {
            CONSOLE.error("Failed to create jutsu debug log: {}", e.getMessage());
            enabled = false;
        }
    }

    private static void writeHeader() {
        try (PrintWriter pw = new PrintWriter(new FileWriter(logPath.toFile(), true))) {
            pw.println("=== ShinobiCore Jutsu Debug Log ===");
            pw.println("Started: " + LocalDateTime.now().format(FMT));
            pw.println();
        } catch (IOException ignored) {}
    }

    /**
     * Логирование каста техники. Вызывается из JutsuCaster.cast().
     */
    public static void logCast(ServerPlayerEntity player, JutsuDefinition def,
                                NinjaPlayerData data, float damage, float cost) {
        if (!enabled) return;
        String msg = String.format(
                "[CAST] player=%s | jutsu=%s | type=%s | nature=%s | cost=%.1f | damage=%.2f | chakra=%.1f/%.1f | fatigue=%.1f",
                player.getName().getString(),
                def.id(),
                def.type(),
                def.hasNature() ? def.nature().getId() : "none",
                cost,
                damage,
                data.getCurrentChakra(),
                NinjaFormula.maxChakra(data),
                data.getFatigue()
        );
        write(msg);
    }

    /**
     * Логирование behavior'а. Вызывается из behaviors.
     */
    public static void logBehavior(String behaviorType, String message) {
        if (!enabled) return;
        write(String.format("[BEHAVIOR:%s] %s", behaviorType, message));
    }

    /**
     * Логирование снаряда. Вызывается из NinjaProjectileEntity.
     */
    public static void logProjectile(String event, double x, double y, double z, String details) {
        if (!enabled) return;
        write(String.format("[PROJECTILE:%s] pos=(%.2f, %.2f, %.2f) | %s", event, x, y, z, details));
    }

    /**
     * Логирование столкновения. Вызывается из NinjaProjectileEntity.
     */
    public static void logCollision(String type, String target, float damage) {
        if (!enabled) return;
        write(String.format("[COLLISION] type=%s | target=%s | damage=%.2f", type, target, damage));
    }

    /**
     * Логирование ошибки.
     */
    public static void logError(String context, Exception e) {
        if (!enabled) return;
        write(String.format("[ERROR:%s] %s", context, e.getMessage()));
        CONSOLE.error("[JutsuError:{}] {}", context, e.getMessage());
    }

    /**
     * Произвольное информационное сообщение.
     */
    public static void logInfo(String message) {
        if (!enabled) return;
        write(String.format("[INFO] %s", message));
    }

    private static void write(String message) {
        String timestamp = LocalDateTime.now().format(FMT);
        String line = timestamp + " " + message;

        // В консоль (debug уровень чтобы не засорять)
        CONSOLE.debug(line);

        // В файл
        try (PrintWriter pw = new PrintWriter(new FileWriter(logPath.toFile(), true))) {
            pw.println(line);
        } catch (IOException ignored) {
            // Тихо игнорируем ошибки записи
        }
    }

    /**
     * Включение/выключение логирования.
     */
    public static void setEnabled(boolean value) {
        enabled = value;
        CONSOLE.info("Jutsu debug logging {}", value ? "ENABLED" : "DISABLED");
    }
}

# ================= src\main\java\com\example\shinobicore\jutsu\JutsuRegistry.java =================
package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.ElementType;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class JutsuRegistry {

    private static final Map<String, JutsuDefinition> JUTSUS = new HashMap<>();

    public static void reload(ResourceManager manager) {
        JUTSUS.clear();

        Map<Identifier, List<Resource>> resources = manager.findAllResources("jutsu",
            id -> id.getNamespace().equals(ShinobiCore.MOD_ID) && id.getPath().endsWith(".json"));

        for (Map.Entry<Identifier, List<Resource>> entry : resources.entrySet()) {
            for (Resource resource : entry.getValue()) {
                try (InputStream stream = resource.getInputStream()) {
                    JsonObject json = JsonParser.parseReader(
                        new InputStreamReader(stream, StandardCharsets.UTF_8)).getAsJsonObject();
                    JutsuDefinition def = parse(json);
                    JUTSUS.put(def.id(), def);
                    ShinobiCore.LOGGER.info("Loaded jutsu: {}", def.id());
                } catch (Exception e) {
                    ShinobiCore.LOGGER.error("Failed to load jutsu from {}: {}", entry.getKey(), e.getMessage());
                }
            }
        }

        ShinobiCore.LOGGER.info("Loaded {} jutsu", JUTSUS.size());
    }

    public static JutsuDefinition get(String id) {
        return JUTSUS.get(id);
    }

    public static Collection<JutsuDefinition> getAll() {
        return JUTSUS.values();
    }

    private static JutsuDefinition parse(JsonObject json) {
        String id = json.get("id").getAsString();
        String name = json.has("name") ? json.get("name").getAsString() : id;
        String category = json.has("category") ? json.get("category").getAsString() : "unknown";

        ElementType nature = null;
        if (json.has("nature") && !json.get("nature").isJsonNull()) {
            String natureId = json.get("nature").getAsString();
            for (ElementType e : ElementType.values()) {
                if (e.getId().equals(natureId)) {
                    nature = e;
                    break;
                }
            }
        }

        String type = json.has("type") ? json.get("type").getAsString() : "projectile";

        String behaviorClass = json.has("behaviorClass") && !json.get("behaviorClass").isJsonNull()
            ? json.get("behaviorClass").getAsString() : null;

        JsonObject params = json.has("params") ? json.getAsJsonObject("params") : new JsonObject();

        float baseCost = json.has("baseCost") ? json.get("baseCost").getAsFloat() : 0f;
        float baseDamage = json.has("baseDamage") ? json.get("baseDamage").getAsFloat() : 0f;
        float strain = json.has("strain") ? json.get("strain").getAsFloat() : 0f;
        int requiredUses = json.has("requiredUsesForFullProficiency")
            ? json.get("requiredUsesForFullProficiency").getAsInt()
            : 50;

        Map<String, Integer> requirements = new HashMap<>();
        if (json.has("requirements")) {
            JsonObject reqObj = json.getAsJsonObject("requirements");
            for (String key : reqObj.keySet()) {
                requirements.put(key, reqObj.get(key).getAsInt());
            }
        }

        return new JutsuDefinition(
            id, name, category, nature, type, behaviorClass, params,
            baseCost, baseDamage, strain,
            requiredUses, requirements
        );
    }
}

# ================= src\main\java\com\example\shinobicore\jutsu\MeleeBehavior.java =================
package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.combat.MarkTracker;
import com.google.gson.JsonObject;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffect;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleEffect;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.List;

public class MeleeBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        float range = params.has("range") ? params.get("range").getAsFloat() : 3.0f;
        float coneAngleDeg = params.has("coneAngle") ? params.get("coneAngle").getAsFloat() : 120.0f;
        float knockback = params.has("knockback") ? params.get("knockback").getAsFloat() : 0.4f;
        boolean fullCircle = params.has("fullCircle") && params.get("fullCircle").getAsBoolean();

        // Поджиг
        boolean ignite = params.has("ignite") && params.get("ignite").getAsBoolean();
        int igniteDuration = params.has("igniteDuration") ? params.get("igniteDuration").getAsInt() : 3;

        // Статус-эффект
        String statusEffect = params.has("statusEffect") ? params.get("statusEffect").getAsString() : null;
        int statusDuration = params.has("statusDuration") ? params.get("statusDuration").getAsInt() : 60;
        int statusAmplifier = params.has("statusAmplifier") ? params.get("statusAmplifier").getAsInt() : 0;

        // Частицы
        String particle = params.has("particle") ? params.get("particle").getAsString() : null;
        int particleCount = params.has("particleCount") ? params.get("particleCount").getAsInt() : 20;

        if (!(player.getWorld() instanceof ServerWorld serverWorld)) return;

        Vec3d lookDir = player.getRotationVector();

        // Ищем цели
        List<LivingEntity> targets;
        if (fullCircle) {
            targets = findTargetsInRadius(serverWorld, player, range);
        } else {
            targets = findTargetsInCone(serverWorld, player, lookDir, range, coneAngleDeg);
        }

        for (LivingEntity target : targets) {
            // Урон
            target.damage(player.getDamageSources().magic(), MarkTracker.boost(target, damage));

            // Отброс
            Vec3d kb = target.getPos().subtract(player.getPos()).normalize().multiply(knockback);
            target.addVelocity(kb.x, 0.2, kb.z);
            target.velocityModified = true;

            // Поджиг
            if (ignite) {
                target.setOnFireFor(igniteDuration);
            }

            // Статус-эффект
            if (statusEffect != null) {
                StatusEffect effect = parseStatusEffect(statusEffect);
                if (effect != null) {
                    target.addStatusEffect(new StatusEffectInstance(
                            effect, statusDuration, statusAmplifier, false, true));
                }
            }
        }

        // Частицы
        if (particle != null) {
            spawnMeleeParticles(serverWorld, player, lookDir, range, particle, particleCount);
        }

        JutsuLogger.logBehavior("melee", String.format(
                "player=%s, targets=%d, range=%.1f, cone=%.0f, fullCircle=%b, ignite=%b",
                player.getName().getString(), targets.size(), range, coneAngleDeg, fullCircle, ignite));
    }

    private List<LivingEntity> findTargetsInCone(ServerWorld world, ServerPlayerEntity attacker,
                                                  Vec3d lookDir, float range, float coneAngleDeg) {
        List<LivingEntity> targets = new ArrayList<>();
        if (lookDir.lengthSquared() < 0.001) return targets;

        Vec3d dir = lookDir.normalize();
        var searchBox = attacker.getBoundingBox().expand(range + 1.0);
        List<LivingEntity> entities = world.getEntitiesByClass(LivingEntity.class, searchBox,
                e -> e != attacker && e.isAlive());

        for (LivingEntity target : entities) {
            Vec3d toTarget = target.getPos().add(0, target.getHeight() / 2.0, 0)
                    .subtract(attacker.getPos().add(0, attacker.getEyeHeight(attacker.getPose()), 0));
            if (toTarget.length() > range) continue;

            double dot = dir.dotProduct(toTarget.normalize());
            double angle = Math.toDegrees(Math.acos(Math.max(-1.0, Math.min(1.0, dot))));

            if (angle <= coneAngleDeg / 2.0) {
                targets.add(target);
            }
        }
        return targets;
    }

    private List<LivingEntity> findTargetsInRadius(ServerWorld world, ServerPlayerEntity attacker,
                                                    float range) {
        List<LivingEntity> targets = new ArrayList<>();
        var searchBox = attacker.getBoundingBox().expand(range);
        List<LivingEntity> entities = world.getEntitiesByClass(LivingEntity.class, searchBox,
                e -> e != attacker && e.isAlive());
        for (LivingEntity target : entities) {
            if (target.getPos().distanceTo(attacker.getPos()) <= range) {
                targets.add(target);
            }
        }
        return targets;
    }

    private StatusEffect parseStatusEffect(String id) {
        return switch (id) {
            case "slowness" -> StatusEffects.SLOWNESS;
            case "weakness" -> StatusEffects.WEAKNESS;
            case "poison" -> StatusEffects.POISON;
            case "wither" -> StatusEffects.WITHER;
            case "blindness" -> StatusEffects.BLINDNESS;
            case "nausea" -> StatusEffects.NAUSEA;
            case "mining_fatigue" -> StatusEffects.MINING_FATIGUE;
            case "levitation" -> StatusEffects.LEVITATION;
            case "glowing" -> StatusEffects.GLOWING;
            default -> null;
        };
    }

    private void spawnMeleeParticles(ServerWorld world, ServerPlayerEntity player, Vec3d lookDir,
                                      float range, String particle, int count) {
        ParticleEffect particleType = switch (particle) {
            case "fire" -> ParticleTypes.FLAME;
            case "water" -> ParticleTypes.FALLING_WATER;
            case "lightning" -> ParticleTypes.ELECTRIC_SPARK;
            case "wind" -> ParticleTypes.CLOUD;
            case "earth" -> ParticleTypes.POOF;
            case "smoke" -> ParticleTypes.LARGE_SMOKE;
            default -> ParticleTypes.CRIT;
        };

        Vec3d startPos = player.getPos().add(0, player.getHeight() * 0.7, 0);
        Vec3d dir = lookDir.normalize();

        for (int i = 0; i < count; i++) {
            float progress = (float) i / count;
            float distance = progress * range;
            Vec3d pos = startPos.add(dir.multiply(distance));

            double offsetX = (Math.random() - 0.5) * 0.8;
            double offsetY = (Math.random() - 0.5) * 0.8;
            double offsetZ = (Math.random() - 0.5) * 0.8;

            world.spawnParticles(particleType,
                    pos.x + offsetX, pos.y + offsetY, pos.z + offsetZ,
                    1, 0, 0, 0, 0.02);
        }
    }
}

# ================= src\main\java\com\example\shinobicore\jutsu\ProjectileBehavior.java =================
package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.entity.NinjaProjectileEntity;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class ProjectileBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        float speed = params.has("speed") ? params.get("speed").getAsFloat() : 1.5f;
        float radius = params.has("radius") ? params.get("radius").getAsFloat() : 1.0f;
        String particle = params.has("particle") ? params.get("particle").getAsString() : "flame";
        int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 100;
        boolean hasGravity = params.has("gravity") && params.get("gravity").getAsBoolean();
        int pierceCount = params.has("pierce") ? params.get("pierce").getAsInt() : 0;
        int bounceCount = params.has("bounce") ? params.get("bounce").getAsInt() : 0;
        int projectileCount = params.has("count") ? params.get("count").getAsInt() : 1;
        float spread = params.has("spread") ? params.get("spread").getAsFloat() : 0f;

        Vec3d baseDir = player.getRotationVector().normalize();

        // === ЛОГИРОВАНИЕ: начало каста ===
        ShinobiCore.LOGGER.info("[PROJECTILE-BEHAVIOR] Cast: speed={}, radius={}, particle={}, lifetime={}, gravity={}, pierce={}, bounce={}, count={}, spread={}",
                speed, radius, particle, lifetime, hasGravity, pierceCount, bounceCount, projectileCount, spread);
        ShinobiCore.LOGGER.info("[PROJECTILE-BEHAVIOR] Player pos: ({}, {}, {}), lookDir: ({}, {}, {})",
                String.format("%.2f", player.getX()),
                String.format("%.2f", player.getY()),
                String.format("%.2f", player.getZ()),
                String.format("%.2f", baseDir.x),
                String.format("%.2f", baseDir.y),
                String.format("%.2f", baseDir.z));

        for (int i = 0; i < projectileCount; i++) {
            Vec3d dir = baseDir;

            // Разброс для нескольких снарядов
            if (projectileCount > 1 && spread > 0) {
                float angle = (float) ((i - (projectileCount - 1) / 2.0) * spread * Math.PI / 180.0);
                double cos = Math.cos(angle);
                double sin = Math.sin(angle);
                dir = new Vec3d(
                        baseDir.x * cos - baseDir.z * sin,
                        baseDir.y,
                        baseDir.x * sin + baseDir.z * cos
                ).normalize();
            }

            Vec3d velocity = dir.multiply(speed);
            
            // === ИСПРАВЛЕНО: спавн на 3 блока впереди игрока (было 2) ===
            Vec3d spawnOffset = dir.multiply(3.0);
            double spawnX = player.getX() + spawnOffset.x;
            double spawnY = player.getEyeY() - 0.2 + spawnOffset.y;
            double spawnZ = player.getZ() + spawnOffset.z;
            
            // === ЛОГИРОВАНИЕ: позиция спавна ===
            ShinobiCore.LOGGER.info("[PROJECTILE-BEHAVIOR] Spawn offset: ({}, {}, {}), final pos: ({}, {}, {})",
                    String.format("%.2f", spawnOffset.x),
                    String.format("%.2f", spawnOffset.y),
                    String.format("%.2f", spawnOffset.z),
                    String.format("%.2f", spawnX),
                    String.format("%.2f", spawnY),
                    String.format("%.2f", spawnZ));
            
            NinjaProjectileEntity projectile = new NinjaProjectileEntity(
                    player.getWorld(), player, velocity, damage, radius, particle, lifetime
            );
            projectile.setPosition(spawnX, spawnY, spawnZ);

            // Устанавливаем дополнительные параметры
            projectile.setHasGravity(hasGravity);
            projectile.setPierceCount(pierceCount);
            projectile.setBounceCount(bounceCount);

            player.getWorld().spawnEntity(projectile);
            
            ShinobiCore.LOGGER.info("[PROJECTILE-BEHAVIOR] Entity spawned, id={}", projectile.getId());
        }
    }
}

# ================= src\main\java\com\example\shinobicore\jutsu\UtilityBehavior.java =================
package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.entity.effect.StatusEffect;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;

public class UtilityBehavior implements JutsuBehavior {

    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data,
                     JsonObject params, float damage) {
        String effect = params.has("effect") ? params.get("effect").getAsString() : "heal";
        int amplifier = params.has("amplifier") ? params.get("amplifier").getAsInt() : 0;
        int duration = params.has("duration") ? params.get("duration").getAsInt() : 200;
        boolean showParticles = !params.has("showParticles") || params.get("showParticles").getAsBoolean();

        if (!(player.getWorld() instanceof ServerWorld serverWorld)) return;

        Vec3d center = player.getPos().add(0, player.getHeight() / 2.0, 0);

        switch (effect) {
            case "heal" -> {
                float healAmount = params.has("healAmount") ? params.get("healAmount").getAsFloat() : 6.0f;
                float actualHeal = Math.min(healAmount, player.getMaxHealth() - player.getHealth());
                player.heal(actualHeal);

                spawnParticles(serverWorld, center, ParticleTypes.HAPPY_VILLAGER, 20);
                JutsuLogger.logBehavior("utility",
                        String.format("HEAL: player=%s, amount=%.1f, actual=%.1f",
                                player.getName().getString(), healAmount, actualHeal));
            }

            case "chakra_heal" -> {
                float chakraAmount = params.has("chakraAmount") ? params.get("chakraAmount").getAsFloat() : 30.0f;
                float maxChakra = com.example.shinobicore.stat.NinjaFormula.maxChakra(data);
                float actualRestore = Math.min(chakraAmount, maxChakra - data.getCurrentChakra());
                data.setCurrentChakra(data.getCurrentChakra() + actualRestore);

                spawnParticles(serverWorld, center, ParticleTypes.ENCHANT, 15);
                JutsuLogger.logBehavior("utility",
                        String.format("CHAKRA_HEAL: player=%s, amount=%.1f, actual=%.1f",
                                player.getName().getString(), chakraAmount, actualRestore));
            }

            case "regen" -> {
                player.addStatusEffect(new StatusEffectInstance(
                        StatusEffects.REGENERATION, duration, amplifier, false, showParticles));

                spawnParticles(serverWorld, center, ParticleTypes.HAPPY_VILLAGER, 12);
                JutsuLogger.logBehavior("utility",
                        String.format("REGEN: player=%s, amp=%d, dur=%d",
                                player.getName().getString(), amplifier, duration));
            }

            case "speed" -> {
                player.addStatusEffect(new StatusEffectInstance(
                        StatusEffects.SPEED, duration, amplifier, false, showParticles));

                spawnParticles(serverWorld, center, ParticleTypes.ENCHANT, 10);
                JutsuLogger.logBehavior("utility",
                        String.format("SPEED: player=%s, amp=%d, dur=%d",
                                player.getName().getString(), amplifier, duration));
            }

            case "strength" -> {
                player.addStatusEffect(new StatusEffectInstance(
                        StatusEffects.STRENGTH, duration, amplifier, false, showParticles));

                spawnParticles(serverWorld, center, ParticleTypes.ENCHANT, 10);
                JutsuLogger.logBehavior("utility",
                        String.format("STRENGTH: player=%s, amp=%d, dur=%d",
                                player.getName().getString(), amplifier, duration));
            }

            case "resistance" -> {
                player.addStatusEffect(new StatusEffectInstance(
                        StatusEffects.RESISTANCE, duration, amplifier, false, showParticles));

                spawnParticles(serverWorld, center, ParticleTypes.ENCHANT, 10);
                JutsuLogger.logBehavior("utility",
                        String.format("RESISTANCE: player=%s, amp=%d, dur=%d",
                                player.getName().getString(), amplifier, duration));
            }

            case "clear" -> {
                int removed = 0;
                removed += removeIfPresent(player, StatusEffects.POISON);
                removed += removeIfPresent(player, StatusEffects.WITHER);
                removed += removeIfPresent(player, StatusEffects.SLOWNESS);
                removed += removeIfPresent(player, StatusEffects.WEAKNESS);
                removed += removeIfPresent(player, StatusEffects.BLINDNESS);
                removed += removeIfPresent(player, StatusEffects.NAUSEA);
                removed += removeIfPresent(player, StatusEffects.HUNGER);
                removed += removeIfPresent(player, StatusEffects.MINING_FATIGUE);
                removed += removeIfPresent(player, StatusEffects.LEVITATION);

                spawnParticles(serverWorld, center, ParticleTypes.CLOUD, 25);
                JutsuLogger.logBehavior("utility",
                        String.format("CLEAR: player=%s, removed=%d effects",
                                player.getName().getString(), removed));

                if (removed > 0) {
                    player.sendMessage(Text.literal("§aCleared " + removed + " negative effect(s)!"), false);
                } else {
                    player.sendMessage(Text.literal("§7No negative effects to clear."), false);
                }
            }

            default -> {
                player.sendMessage(Text.literal("§cUnknown utility effect: " + effect), false);
                JutsuLogger.logBehavior("utility", "UNKNOWN effect: " + effect);
            }
        }
    }

    private int removeIfPresent(ServerPlayerEntity player, StatusEffect effect) {
        if (player.hasStatusEffect(effect)) {
            player.removeStatusEffect(effect);
            return 1;
        }
        return 0;
    }

    private void spawnParticles(ServerWorld world, Vec3d center,
                                 net.minecraft.particle.ParticleEffect particle, int count) {
        for (int i = 0; i < count; i++) {
            double angle = (i / (double) count) * Math.PI * 2;
            double r = 0.5 + Math.random() * 0.3;
            double x = center.x + Math.cos(angle) * r;
            double z = center.z + Math.sin(angle) * r;
            double y = center.y + (Math.random() - 0.5) * 1.0;

            world.spawnParticles(particle, x, y, z, 1,
                    (Math.random() - 0.5) * 0.1,
                    Math.random() * 0.1,
                    (Math.random() - 0.5) * 0.1,
                    0.05);
        }
    }
}

# ================= src\main\java\com\example\shinobicore\jutsu\WallBehavior.java =================
package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.google.gson.JsonObject;
import net.minecraft.block.BlockState;
import net.minecraft.block.Blocks;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Direction;
import net.minecraft.util.math.Vec3d;

import java.util.ArrayList;
import java.util.List;

public class WallBehavior implements JutsuBehavior {
    @Override
    public void cast(ServerPlayerEntity player, JutsuDefinition def, NinjaPlayerData data, JsonObject params, float damage) {
        // Стена только на земле
        if (!player.isOnGround()) {
            player.sendMessage(Text.literal("§cYou must be on the ground to create a wall!"), false);
            return;
        }

        int width = params.has("width") ? params.get("width").getAsInt() : 3;
        int height = params.has("height") ? params.get("height").getAsInt() : 3;
        int lifetime = params.has("lifetime") ? params.get("lifetime").getAsInt() : 100;
        String blockType = params.has("block") ? params.get("block").getAsString() : "earth";

        if (!(player.getWorld() instanceof ServerWorld serverWorld)) return;

        // === ИСПРАВЛЕНО: используем вектор взгляда напрямую для диагональных направлений ===
        Vec3d look = player.getRotationVector();
        look = new Vec3d(look.x, 0, look.z).normalize();

        // Позиция перед игроком (2 блока вперёд)
        BlockPos centerPos = player.getBlockPos().add(
                (int) Math.round(look.x * 2),
                0,
                (int) Math.round(look.z * 2)
        );

        // === ИСПРАВЛЕНО: перпендикуляр через векторное произведение ===
        // Это работает для ЛЮБОГО направления, включая диагонали
        Vec3d up = new Vec3d(0, 1, 0);
        Vec3d perpendicular = look.crossProduct(up).normalize();

        // Блок для стены
        BlockState wallBlock = switch (blockType) {
            case "earth" -> Blocks.DIRT.getDefaultState();
            case "stone" -> Blocks.STONE.getDefaultState();
            case "cobblestone" -> Blocks.COBBLESTONE.getDefaultState();
            case "ice" -> Blocks.PACKED_ICE.getDefaultState();
            case "water" -> Blocks.ICE.getDefaultState();
            default -> Blocks.DIRT.getDefaultState();
        };

        // === ЛОГИРОВАНИЕ: параметры стены ===
        ShinobiCore.LOGGER.info("[WALL] Cast: width={}, height={}, lifetime={}, block={}, look=({}, {}), perp=({}, {})",
                width, height, lifetime, blockType,
                String.format("%.2f", look.x), String.format("%.2f", look.z),
                String.format("%.2f", perpendicular.x), String.format("%.2f", perpendicular.z));

        // Создаём стену
        List<BlockPos> placedBlocks = new ArrayList<>();
        int halfWidth = width / 2;

        for (int w = -halfWidth; w <= halfWidth; w++) {
            for (int h = 0; h < height; h++) {
                // === ИСПРАВЛЕНО: используем вектор перпендикуляра напрямую ===
                BlockPos pos = centerPos.add(
                        (int) Math.round(perpendicular.x * w),
                        h,
                        (int) Math.round(perpendicular.z * w)
                );

                // Проверяем что блок пустой
                if (serverWorld.getBlockState(pos).isAir()) {
                    serverWorld.setBlockState(pos, wallBlock, 3);
                    placedBlocks.add(pos);
                }
            }
        }

        // Планируем удаление стены через lifetime тиков
        if (!placedBlocks.isEmpty()) {
            WallRemovalTask.schedule(serverWorld, placedBlocks, lifetime);
            ShinobiCore.LOGGER.info("[WALL] Created wall with {} blocks, lifetime={} ticks",
                    placedBlocks.size(), lifetime);
        }
    }
}

# ================= src\main\java\com\example\shinobicore\jutsu\WallRemovalTask.java =================
package com.example.shinobicore.jutsu;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.block.Blocks;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.BlockPos;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

public class WallRemovalTask {
    // === ИСПРАВЛЕНО: String ключ вместо UUID ===
    private static final Map<String, List<PendingWall>> pendingWalls = new ConcurrentHashMap<>();

    public static void schedule(ServerWorld world, List<BlockPos> blocks, int lifetimeTicks) {
        // Используем registry key как строковый ключ
        String worldId = world.getRegistryKey().getValue().toString();
        pendingWalls.computeIfAbsent(worldId, k -> new ArrayList<>())
                .add(new PendingWall(blocks, lifetimeTicks));
    }

    // Вызывается из NinjaTickHandler каждую секунду (20 тиков)
    public static void tick(ServerWorld world) {
        String worldId = world.getRegistryKey().getValue().toString();
        List<PendingWall> walls = pendingWalls.get(worldId);
        if (walls == null || walls.isEmpty()) return;

        List<PendingWall> toRemove = new ArrayList<>();
        for (PendingWall wall : walls) {
            wall.ticksRemaining -= 20; // Вычитаем 20 тиков (1 секунду)
            if (wall.ticksRemaining <= 0) {
                // Удаляем стену
                for (BlockPos pos : wall.blocks) {
                    if (world.isChunkLoaded(pos)) {
                        world.setBlockState(pos, Blocks.AIR.getDefaultState(), 3);
                    }
                }
                toRemove.add(wall);
                ShinobiCore.LOGGER.debug("[Wall] Removed wall with {} blocks", wall.blocks.size());
            }
        }
        walls.removeAll(toRemove);
    }

    private static class PendingWall {
        final List<BlockPos> blocks;
        int ticksRemaining;

        PendingWall(List<BlockPos> blocks, int lifetimeTicks) {
            this.blocks = new ArrayList<>(blocks);
            this.ticksRemaining = lifetimeTicks;
        }
    }
}

# ================= src\main\java\com\example\shinobicore\lang\en_us.json =================
{
  "key.categories.shinobicore": "Shinobi Core",
  "key.categories.shinobicore.combat": "Shinobi Combat",
  "key.shinobicore.meditate": "Meditate",
  "key.shinobicore.cast": "Cast Jutsu (Slot A)",
  "key.shinobicore.cast_b": "Cast Jutsu (Slot B)",
  "key.shinobicore.cycle_slot": "Cycle Slot A",
  "key.shinobicore.cycle_b": "Cycle Slot B",
  "key.shinobicore.progression": "Progression Menu",
  "key.shinobicore.chakra_mode": "Toggle Chakra Mode",
  "key.shinobicore.dodge_left": "Dodge Left",
  "key.shinobicore.dodge_right": "Dodge Right",
  "key.shinobicore.crawl": "Crawl",
  "key.shinobicore.kick": "Kick Attack",
  "key.shinobicore.switch_style": "Switch Fighting Style"
}

# ================= src\main\java\com\example\shinobicore\lang\ru_ru.json =================
{
  "key.categories.shinobicore": "Shinobi Core",
  "key.categories.shinobicore.combat": "Бой шиноби",
  "key.shinobicore.meditate": "Медитация",
  "key.shinobicore.cast": "Техника (Слот A)",
  "key.shinobicore.cast_b": "Техника (Слот B)",
  "key.shinobicore.cycle_slot": "Переключить слот A",
  "key.shinobicore.cycle_b": "Переключить слот B",
  "key.shinobicore.progression": "Меню прокачки",
  "key.shinobicore.chakra_mode": "Чакра-режим",
  "key.shinobicore.dodge_left": "Додж влево",
  "key.shinobicore.dodge_right": "Додж вправо",
  "key.shinobicore.crawl": "Ползание",
  "key.shinobicore.kick": "Удар ногой",
  "key.shinobicore.switch_style": "Переключить стиль боя"
}

# ================= src\main\java\com\example\shinobicore\mixin\CameraMixin.java =================
package com.example.shinobicore.mixin;

import com.example.shinobicore.client.CinematicCamera;
import net.minecraft.client.render.Camera;
import net.minecraft.entity.Entity;
import net.minecraft.util.math.MathHelper;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.BlockView;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(Camera.class)
public abstract class CameraMixin {

    @Shadow private float yaw;
    @Shadow private float pitch;

    @Shadow public abstract void setPos(double x, double y, double z);
    @Shadow public abstract Vec3d getPos();

    @Inject(method = "update", at = @At("TAIL"))
    private void shinobicore_applyOverShoulderCamera(BlockView area, Entity focusedEntity,
                                                      boolean thirdPerson, boolean inverseView,
                                                      float tickDelta, CallbackInfo ci) {
        if (!CinematicCamera.isEnabled() || !thirdPerson || inverseView) return;
        if (focusedEntity == null) return;

        Vec3d currentPos = this.getPos();

        float rightOffset = CinematicCamera.getRightOffset();
        float upOffset = CinematicCamera.getUpOffset();
        float forwardOffset = CinematicCamera.getForwardOffset();
        float distanceReduction = CinematicCamera.getDistanceReduction();

        // === Вычисляем векторы на основе yaw/pitch камеры ===
        float yawRad = this.yaw * 0.017453292F;
        float pitchRad = this.pitch * 0.017453292F;

        // Forward vector (куда смотрит камера)
        double forwardX = -MathHelper.sin(yawRad) * MathHelper.cos(pitchRad);
        double forwardY = -MathHelper.sin(pitchRad);
        double forwardZ = MathHelper.cos(yawRad) * MathHelper.cos(pitchRad);

        // Right vector (перпендикуляр вправо в горизонтальной плоскости)
        double rightX = Math.cos(yawRad + Math.PI / 2.0);
        double rightZ = Math.sin(yawRad + Math.PI / 2.0);

        // Применяем смещения
        double newX = currentPos.x;
        double newY = currentPos.y;
        double newZ = currentPos.z;

        // 1. Смещение вправо (за правое плечо)
        newX += rightX * rightOffset;
        newZ += rightZ * rightOffset;

        // 2. Смещение вверх (чуть выше плеча)
        newY += upOffset;

        // 3. Смещение ВПЕРЁД (приближение камеры)
        // Forward вектор указывает ОТ камеры К игроку, поэтому вычитаем
        // (камера "отодвинута" от игрока в направлении противоположном взгляду)
        newX -= forwardX * forwardOffset;
        newY -= forwardY * forwardOffset;
        newZ -= forwardZ * forwardOffset;

        // 4. Сокращение дистанции (если ванила поставила слишком далеко)
        // Вектор от текущей позиции к игроку
        Vec3d toPlayer = new Vec3d(
                focusedEntity.getX() - newX,
                focusedEntity.getEyeY() - newY,
                focusedEntity.getZ() - newZ
        );
        double distToPlayer = toPlayer.length();
        if (distToPlayer > distanceReduction + 0.5) {
            Vec3d norm = toPlayer.normalize();
            newX += norm.x * distanceReduction * 0.5;
            newY += norm.y * distanceReduction * 0.5;
            newZ += norm.z * distanceReduction * 0.5;
        }

        // === Лёгкая тряска ===
        Vec3d shake = CinematicCamera.getShakeOffset();
        newX += shake.x;
        newY += shake.y;
        newZ += shake.z;

        setPos(newX, newY, newZ);
    }
}

# ================= src\main\java\com\example\shinobicore\mixin\ChakraWaterTouchMixin.java =================
package com.example.shinobicore.mixin;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.Entity;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(Entity.class)
public abstract class ChakraWaterTouchMixin {

    @Inject(method = "isTouchingWater", at = @At("HEAD"), cancellable = true)
    private void shinobicore_noWaterPhysics(CallbackInfoReturnable<Boolean> cir) {
        Entity self = (Entity) (Object) this;

        if (self instanceof ServerPlayerEntity player) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            if (data != null && data.isChakraMode() && data.getCurrentChakra() > 0) {
                cir.setReturnValue(false);
            }
        } else if (self instanceof ClientPlayerEntity) {
            if (ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0) {
                cir.setReturnValue(false);
            }
        }
    }
}

# ================= src\main\java\com\example\shinobicore\mixin\ChargedJumpMixin.java =================
package com.example.shinobicore.mixin;

import com.example.shinobicore.client.ChakraPhysicsClient;
import com.example.shinobicore.client.ClientNinjaState;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.LivingEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(LivingEntity.class)
public abstract class ChargedJumpMixin {

    @Inject(method = "jump", at = @At("HEAD"), cancellable = true)
    private void shinobicore_cancelVanillaJump(CallbackInfo ci) {
        LivingEntity self = (LivingEntity) (Object) this;
        if (!(self instanceof ClientPlayerEntity player)) return;
        
        if (ClientNinjaState.chakraMode && (player.isOnGround() || ChakraPhysicsClient.standingOnWater)) {
            ci.cancel();
        }
    }
}

# ================= src\main\java\com\example\shinobicore\mixin\FallDamageMixin.java =================
package com.example.shinobicore.mixin;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.entity.player.PlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(LivingEntity.class)
public abstract class FallDamageMixin {

    @Inject(method = "handleFallDamage", at = @At("HEAD"), cancellable = true)
    private void shinobicore_reduceFallDamage(float fallDistance, float damageMultiplier, DamageSource damageSource, CallbackInfoReturnable<Boolean> cir) {
        LivingEntity self = (LivingEntity) (Object) this;
        if (self instanceof PlayerEntity player) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            if (data != null && data.isChakraMode() && data.getCurrentChakra() > 0) {
                // До 40 блоков — 0 урона
                if (fallDistance <= 40.0f) {
                    cir.setReturnValue(false); // Нет урона
                    return;
                }
                
                // Дальше каждые 5 блоков = 1 урон (0.5 сердца)
                float extraBlocks = fallDistance - 40.0f;
                float damage = (extraBlocks / 5.0f);
                
                // Применяем уменьшенный урон
                if (damage >= 1.0f) {
                    player.damage(player.getDamageSources().fall(), damage);
                }
                cir.setReturnValue(true); // Урон обработан
            }
        }
    }
}

# ================= src\main\java\com\example\shinobicore\mixin\GameRendererMixin.java =================
package com.example.shinobicore.mixin;

import com.example.shinobicore.client.CinematicCamera;
import net.minecraft.client.render.GameRenderer;
import net.minecraft.client.util.math.MatrixStack;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(GameRenderer.class)
public abstract class GameRendererMixin {
    // === УБРАЛИ getFov mixin (больше не трогаем FOV) ===
    // === УБРАЛИ renderWorld mixin (тряска теперь в CameraMixin) ===
    
    // Оставляем класс пустым для будущих расширений
    // или можно полностью удалить файл
}

# ================= src\main\java\com\example\shinobicore\mixin\HideVanillaStatusMixin.java =================
package com.example.shinobicore.mixin;

import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.hud.InGameHud;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(InGameHud.class)
public abstract class HideVanillaStatusMixin {

    // Полностью скрываем ванильную панель статусов (сердца, голод, броня, воздух)
    @Inject(method = "renderStatusBars", at = @At("HEAD"), cancellable = true)
    private void shinobicore_hideStatusBars(DrawContext context, CallbackInfo ci) {
        ci.cancel();
    }
}

# ================= src\main\java\com\example\shinobicore\mixin\KatanaDeflectMixin.java =================
package com.example.shinobicore.mixin;
import com.example.shinobicore.combat.KenjutsuStance;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.entity.projectile.PersistentProjectileEntity;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundEvents;
import net.minecraft.text.Text;
import net.minecraft.util.math.Vec3d;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;
@Mixin(LivingEntity.class)
public abstract class KatanaDeflectMixin {
    @Inject(method = "damage", at = @At("HEAD"), cancellable = true)
    private void shinobicore_katanaDeflect(DamageSource source, float amount, CallbackInfoReturnable<Boolean> cir) {
        LivingEntity self = (LivingEntity) (Object) this;
        if (!(self instanceof ServerPlayerEntity player)) return;
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (data == null) return;
        long now = System.currentTimeMillis();
        KenjutsuStance stance = KenjutsuStance.fromId(data.getKatanaStanceId());
        boolean tapActive = now < data.getKatanaDeflectUntil();
        boolean holdActive = data.isKatanaDeflectHeld() && stance.canDeflect();
        
        // === РћРўР›РђР”РљРђ: Р»РѕРіРёСЂСѓРµРј СЃРѕСЃС‚РѕСЏРЅРёРµ ===
        Entity projectile = source.getSource();
        if (projectile instanceof PersistentProjectileEntity) {
            ShinobiCore.LOGGER.info("[DEFLECT] Damage tick: stance={}, tapActive={}, holdActive={}, canDeflect={}",
                    stance.getId(), tapActive, holdActive, stance.canDeflect());
        }
        
        if (!tapActive && !holdActive) return;
        if (now - data.getLastDeflectReflectMs() < 200) return;
        
        if (projectile == null) return;
        if (projectile instanceof ServerPlayerEntity) return;
        
        // === РљР›Р®Р§Р•Р’РћР•: Seigan + Hold = 360В° Р·Р°С‰РёС‚Р° (РїРѕР»РЅРѕСЃС‚СЊСЋ РїСЂРѕРїСѓСЃРєР°РµРј РїСЂРѕРІРµСЂРєСѓ С„СЂРѕРЅС‚Р°) ===
        boolean isSeiganShield = holdActive && stance == KenjutsuStance.SEIGAN;
        
        if (!isSeiganShield) {
            // РўРѕР»СЊРєРѕ РґР»СЏ Aggressive tap РёР»Рё Seigan tap РїСЂРѕРІРµСЂСЏРµРј С„СЂРѕРЅС‚ 180В°
            Vec3d toProj = projectile.getPos().subtract(player.getPos());
            Vec3d look = player.getRotationVector();
            Vec3d lookFlat = new Vec3d(look.x, 0, look.z);
            if (lookFlat.lengthSquared() > 0.001 && toProj.lengthSquared() > 0.001) {
                double dot = lookFlat.normalize().dotProduct(new Vec3d(toProj.x, 0, toProj.z).normalize());
                ShinobiCore.LOGGER.info("[DEFLECT] Front check: dot={}, threshold=-0.2", dot);
                if (dot < -0.2) {
                    ShinobiCore.LOGGER.info("[DEFLECT] Rejected: behind player");
                    return;
                }
            }
        } else {
            ShinobiCore.LOGGER.info("[DEFLECT] Seigan 360В° shield ACTIVE - skipping front check");
        }
        
        LivingEntity shooter = null;
        boolean reflected = false;
        
        if (projectile instanceof PersistentProjectileEntity proj) {
            Entity owner = proj.getOwner();
            if (owner == player) return;
            if (owner instanceof LivingEntity l) shooter = l;
            proj.setVelocity(proj.getVelocity().multiply(-1.3));
            proj.setOwner(player);
            proj.velocityDirty = true;
            reflected = true;
            ShinobiCore.LOGGER.info("[DEFLECT] PersistentProjectile reflected!");
        }
        
        if (!reflected) return;
        
        data.setLastDeflectReflectMs(now);
        player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 1.0f, 1.2f);
        if (player.getWorld() instanceof ServerWorld sw) {
            sw.spawnParticles(ParticleTypes.CRIT, player.getX(), player.getY() + 1, player.getZ(), 12, 0.4, 0.4, 0.4, 0.05);
        }
        if (shooter != null) {
            shooter.damage(player.getDamageSources().playerAttack(player), 4f);
        }
        player.sendMessage(Text.literal("В§eDEFLECTED!"), false);
        ShinobiCore.LOGGER.info("[DEFLECT] SUCCESS: projectile reflected back to shooter");
        cir.setReturnValue(false);
    }
}

# ================= src\main\java\com\example\shinobicore\mixin\PlayerAttackMixin.java =================
package com.example.shinobicore.mixin;

import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.Entity;
import net.minecraft.entity.player.PlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(PlayerEntity.class)
public abstract class PlayerAttackMixin {

    @Inject(method = "attack", at = @At("HEAD"), cancellable = true)
    private void shinobicore_taijutsuAttack(Entity target, CallbackInfo ci) {
        PlayerEntity self = (PlayerEntity) (Object) this;
        if (!(self instanceof ClientPlayerEntity player)) return;
        
        if (player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            if (com.example.shinobicore.client.combat.KenjutsuClientHandler.tryAttack(player)) {
                ci.cancel();
                return;
            }
        }
        if (player.getMainHandStack().isEmpty()) {
            if (TaijutsuClientHandler.tryAttack(player)) {
                ci.cancel();
            }
        }
    }
}

# ================= src\main\java\com\example\shinobicore\mixin\PlayerCopyMixin.java =================
package com.example.shinobicore.mixin;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(ServerPlayerEntity.class)
public abstract class PlayerCopyMixin {
    @Inject(method = "copyFrom", at = @At("TAIL"))
    private void shinobicore_copyNinjaData(ServerPlayerEntity oldPlayer, boolean alive, CallbackInfo ci) {
        NinjaPlayerData oldData = ((NinjaDataHolder) oldPlayer).shinobicore_getData();
        NinjaPlayerData newData = ((NinjaDataHolder) (Object) this).shinobicore_getData();
        newData.readNbt(oldData.writeNbt());
    }
}

# ================= src\main\java\com\example\shinobicore\mixin\PlayerParryMixin.java =================
package com.example.shinobicore.mixin;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.tree.TreePassives;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(LivingEntity.class)
public abstract class PlayerParryMixin {
    @Inject(method = "damage", at = @At("HEAD"), cancellable = true)
    private void shinobicore_autoParry(DamageSource source, float amount, CallbackInfoReturnable<Boolean> cir) {
        LivingEntity self = (LivingEntity) (Object) this;
        if (!(self instanceof ServerPlayerEntity player)) return;
        if (amount <= 0) return;
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        TreePassives.Bonuses b = TreePassives.collectServer(data);
        if (b.autoParryChance <= 0) return;
        if (player.getWorld().getRandom().nextFloat() < b.autoParryChance) {
            if (player.getWorld() instanceof ServerWorld sw) {
                sw.spawnParticles(ParticleTypes.CRIT, player.getX(), player.getY() + 1, player.getZ(),
                        12, 0.3, 0.3, 0.3, 0.05);
            }
            player.sendMessage(Text.literal("В§ePARRIED!"), false);
            cir.setReturnValue(false);
        }
    }
}

# ================= src\main\java\com\example\shinobicore\mixin\PlayerRenderAnimationMixin.java =================
package com.example.shinobicore.mixin;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.combat.TaijutsuAnimations;
import com.example.shinobicore.client.combat.KenjutsuAnimations;
import com.example.shinobicore.client.IdlePoseSystem;
import com.example.shinobicore.client.combat.TaijutsuAnimations.AttackAnimationState;
import com.example.shinobicore.client.parkour.ParkourManager;
import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.client.render.entity.model.BipedEntityModel;
import net.minecraft.entity.LivingEntity;
import net.minecraft.util.math.MathHelper;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(BipedEntityModel.class)
public abstract class PlayerRenderAnimationMixin {
    @Shadow public ModelPart rightArm;
    @Shadow public ModelPart leftArm;
    @Shadow public ModelPart rightLeg;
    @Shadow public ModelPart leftLeg;
    @Shadow public ModelPart body;
    @Shadow public ModelPart head;

    @Inject(method = "setAngles", at = @At("TAIL"))
    private void shinobicore_applyAnimations(LivingEntity entity, float limbAngle, float limbDistance,
                                              float animationProgress, float headYaw, float headPitch,
                                              CallbackInfo ci) {
        if (!(entity instanceof AbstractClientPlayerEntity player)) return;

        boolean chakraMode = ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0;
        boolean sprinting = player.isSprinting();
        boolean sliding = ParkourManager.isSliding();
        boolean rolling = ParkourManager.isRolling();

        // === НАРУТО-РАН в чакра-режиме ===
        if (chakraMode && sprinting && !sliding && !rolling) {
            applyNarutoRun(limbAngle, limbDistance);
            return; // Не применяем обычную анимацию
        }

        // === Обычная ходьба/бег ===
        if (!sliding && !rolling) {
            applyEnhancedWalkRunAnimations(player, limbAngle, limbDistance, sprinting);
        }

        // === АНИМАЦИЯ ТАЙ-ДЗЮЦУ (удары руками) ===
        AttackAnimationState attackState = TaijutsuAnimations.getAnimationState(player);
        if (attackState != null) {
            applyTaijutsuAttackAnimation(player, attackState);
        }

        // === АНИМАЦИЯ УДАРА НОГОЙ ===
        // === РџР•Р§РђРўР РџР Р РљРђРЎРўР• ===
        if (com.example.shinobicore.client.CastingClientState.isCasting(player)) {
            rightArm.pitch = -1.25f; rightArm.yaw = -0.45f;
            leftArm.pitch = -1.25f; leftArm.yaw = 0.45f;
            head.pitch += 0.1f;
        }
        // === KENJUTSU: SLASH / DEFLECT ===
        if (KenjutsuAnimations.isDeflecting(player) || ClientNinjaState.deflectHeld) {
            KenjutsuAnimations.applyDeflect(player, rightArm, leftArm);
        }
        if (KenjutsuAnimations.isAttacking(player)) {
            KenjutsuAnimations.applySlash(player, rightArm, leftArm, body, head);
        }
        if (TaijutsuAnimations.isKicking(player)) {
            applyKickAnimation(player);
        }
        // === IDLE POSE SYSTEM ===
        if (!TaijutsuAnimations.isAttacking(player) && !TaijutsuAnimations.isKicking(player)) {
            IdlePoseSystem.apply(player, (BipedEntityModel<?>) (Object) this, limbDistance, animationProgress);
        }
    }

    /**
     * === НАРУТО-РАН: руки вытянуты назад, корпус наклонён ===
     * Каноничная анимация бега из аниме:
     * - Руки почти горизонтально назад
     * - Ладони направлены назад (yaw разведён в стороны)
     * - Корпус сильно наклонён вперёд
     * - Голова слегка задрана (компенсация наклона тела)
     */
    private void applyNarutoRun(float limbAngle, float limbDistance) {
        // Небольшая болтанка рук (руки не статичны, а слегка качаются при беге)
        float bobbing = MathHelper.sin(limbAngle * 2.0f) * 0.08f * limbDistance;

        // === РУКИ: горизонтально назад ===
        // -1.5f рад ≈ -86° (почти горизонтально назад)
        // -1.3f рад ≈ -74° (чуть согнуты, более естественно)
        float armPitchBack = 1.35f + bobbing;

        rightArm.pitch = armPitchBack;
        leftArm.pitch = armPitchBack;

        // Руки разведены в стороны (ладони смотрят назад)
        // yaw > 0 для правой руки = рука вправо
        // yaw < 0 для левой руки = рука влево
        rightArm.yaw = -0.35f;  // правая рука чуть влево (к центру спины)
        leftArm.yaw = 0.35f;    // левая рука чуть вправо (к центру спины)

        // Лёгкий roll чтобы руки выглядели расслабленными
        rightArm.roll = 0.15f;
        leftArm.roll = -0.15f;

        // === КОРПУС: сильный наклон вперёд ===
        body.pitch = 0.55f;
        body.yaw = 0f;
        body.roll = 0f;

        // === ГОЛОВА: компенсируем наклон тела ===
        // Голова должна смотреть вперёд, поэтому "задираем" её вверх
        // относительно тела (head.pitch уменьшается)
        head.pitch -= 0.15f;

        // === НОГИ: более размашистые движения при быстром беге ===
        // Ноги остаются от ванильной анимации, но добавим больше амплитуды
        float legSwing = MathHelper.cos(limbAngle) * limbDistance * 1.4f;
        rightLeg.pitch = legSwing;
        leftLeg.pitch = -legSwing;
    }

    private void applyEnhancedWalkRunAnimations(AbstractClientPlayerEntity player, float limbAngle, float limbDistance,
                                                 boolean sprinting) {
        float speedMultiplier = sprinting ? 1.5f : 1.0f;
        float armSwingAmplitude = limbDistance * 0.8f * speedMultiplier;
        float legSwingAmplitude = limbDistance * 1.2f * speedMultiplier;

        if (sprinting) {
            // Обычный спринт (не чакра-режим) — динамичный бег с согнутыми руками
            rightArm.pitch = MathHelper.cos(limbAngle + (float) Math.PI) * armSwingAmplitude * 1.3f;
            leftArm.pitch = MathHelper.cos(limbAngle) * armSwingAmplitude * 1.3f;

            body.pitch = 0.15f;

            rightLeg.pitch = MathHelper.cos(limbAngle) * legSwingAmplitude * 1.2f;
            leftLeg.pitch = MathHelper.cos(limbAngle + (float) Math.PI) * legSwingAmplitude * 1.2f;

            rightArm.yaw = 0.1f;
            leftArm.yaw = -0.1f;

        } else {
            // Обычная ходьба
            rightArm.pitch = MathHelper.cos(limbAngle + (float) Math.PI) * armSwingAmplitude * 0.8f;
            leftArm.pitch = MathHelper.cos(limbAngle) * armSwingAmplitude * 0.8f;

            body.pitch = 0.05f;

            rightLeg.pitch = MathHelper.cos(limbAngle) * legSwingAmplitude;
            leftLeg.pitch = MathHelper.cos(limbAngle + (float) Math.PI) * legSwingAmplitude;

            body.yaw = MathHelper.sin(limbAngle) * 0.05f;
        }
    }

    private void applyTaijutsuAttackAnimation(AbstractClientPlayerEntity player, AttackAnimationState attackState) {
        int step = attackState.comboStep;
        float progress = attackState.getProgress();

        float armRotation = 0f;
        if (progress < 0.3f) {
            armRotation = (float) Math.sin(progress / 0.3f * Math.PI / 2) * -120f;
        } else if (progress < 0.6f) {
            armRotation = -120f;
        } else {
            float returnProgress = (progress - 0.6f) / 0.4f;
            armRotation = -120f * (1f - returnProgress);
        }

        boolean useRightArm = (step % 2 == 0);
        float armRadians = armRotation * 0.0174533f;

        if (useRightArm) {
            rightArm.pitch += armRadians;
        } else {
            leftArm.pitch += armRadians;
        }

        float bodyYaw = armRotation * 0.2f * 0.0174533f;
        body.yaw += bodyYaw;
    }

    private void applyKickAnimation(AbstractClientPlayerEntity player) {
        TaijutsuAnimations.KickAnimationState kickState = TaijutsuAnimations.getKickState(player);
        if (kickState == null) return;

        float kickProgress = kickState.getProgress();
        float kickAngle = 0f;
        float bodyLean = 0f;

        if (kickProgress < 0.3f) {
            float p = kickProgress / 0.3f;
            kickAngle = (float) Math.sin(p * Math.PI / 2) * -90f;
            bodyLean = (float) Math.sin(p * Math.PI / 2) * 20f;
        } else if (kickProgress < 0.6f) {
            kickAngle = -90f;
            bodyLean = 20f;
        } else {
            float returnProgress = (kickProgress - 0.6f) / 0.4f;
            kickAngle = -90f * (1f - returnProgress);
            bodyLean = 20f * (1f - returnProgress);
        }

        float kickRadians = kickAngle * 0.0174533f;
        float bodyRadians = bodyLean * 0.0174533f;

        rightLeg.pitch += kickRadians;
        rightLeg.roll += kickRadians * 0.2f;
        leftLeg.pitch -= kickRadians * 0.3f;
        body.pitch += bodyRadians;
        rightArm.pitch -= kickRadians * 0.3f;
        leftArm.pitch += kickRadians * 0.4f;
    }
}

# ================= src\main\java\com\example\shinobicore\mixin\RollPoseMixin.java =================
package com.example.shinobicore.mixin;

import com.example.shinobicore.client.parkour.ParkourManager;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;
import net.minecraft.entity.player.PlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(PlayerEntity.class)
public abstract class RollPoseMixin {

    // Дополнительная проверка: если ролл активен, принудительно держим SWIMMING
    @Inject(method = "updatePose", at = @At("RETURN"))
    private void shinobicore_forceRollPose(CallbackInfo ci) {
        PlayerEntity self = (PlayerEntity) (Object) this;
        if (self instanceof ClientPlayerEntity && ParkourManager.isRolling()) {
            if (self.getPose() != EntityPose.SWIMMING) {
                self.setPose(EntityPose.SWIMMING);
            }
        }
    }
}

# ================= src\main\java\com\example\shinobicore\mixin\ServerPlayerEntityMixin.java =================
package com.example.shinobicore.mixin;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.nbt.NbtCompound;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Unique;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(PlayerEntity.class)
public abstract class ServerPlayerEntityMixin implements NinjaDataHolder {

    @Unique
    private final NinjaPlayerData shinobicore_data = new NinjaPlayerData();

    @Override
    public NinjaPlayerData shinobicore_getData() {
        return shinobicore_data;
    }

    @Inject(method = "writeCustomDataToNbt", at = @At("TAIL"))
    private void shinobicore_writeData(NbtCompound nbt, CallbackInfo ci) {
        nbt.put("ShinobiCoreData", shinobicore_data.writeNbt());
    }

    @Inject(method = "readCustomDataFromNbt", at = @At("TAIL"))
    private void shinobicore_readData(NbtCompound nbt, CallbackInfo ci) {
        if (nbt.contains("ShinobiCoreData")) {
            shinobicore_data.readNbt(nbt.getCompound("ShinobiCoreData"));
        }
    }
}

# ================= src\main\java\com\example\shinobicore\mixin\SlideDimensionsMixin.java =================
package com.example.shinobicore.mixin;

import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.pose.LowPoseTracker;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityDimensions;
import net.minecraft.entity.EntityPose;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(Entity.class)
public abstract class SlideDimensionsMixin {

    @Inject(method = "getDimensions", at = @At("HEAD"), cancellable = true)
    private void shinobicore_slideDimensions(EntityPose pose, CallbackInfoReturnable<EntityDimensions> cir) {
        Entity self = (Entity) (Object) this;

        // === КЛИЕНТ: локальный игрок ===
        if (self instanceof ClientPlayerEntity) {
            if (ParkourManager.isSliding()) {
                cir.setReturnValue(EntityDimensions.fixed(0.6f, 1.0f));
            }
            return;
        }

        // === СЕРВЕР: все игроки через LowPoseTracker ===
        if (self instanceof ServerPlayerEntity sp) {
            if (LowPoseTracker.isLow(sp.getUuid())) {
                cir.setReturnValue(EntityDimensions.fixed(0.6f, 1.0f));
            }
        }
    }
}

# ================= src\main\java\com\example\shinobicore\mixin\SlidePoseMixin.java =================
package com.example.shinobicore.mixin;

import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.parkour.util.PoseHelper;
import com.example.shinobicore.pose.LowPoseTracker;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Redirect;

@Mixin(PlayerEntity.class)
public abstract class SlidePoseMixin {

    @Redirect(
        method = "updatePose",
        at = @At(value = "INVOKE", target = "Lnet/minecraft/entity/player/PlayerEntity;setPose(Lnet/minecraft/entity/EntityPose;)V")
    )
    private void shinobicore_overridePose(PlayerEntity self, EntityPose vanillaPose) {
        // === СЕРВЕРНАЯ ЧАСТЬ: читаем флаг из трекера ===
        if (self instanceof ServerPlayerEntity sp) {
            if (LowPoseTracker.isLow(sp.getUuid())) {
                if (self.getPose() != EntityPose.SWIMMING) {
                    self.setPose(EntityPose.SWIMMING);
                    self.calculateDimensions();
                }
            } else {
                self.setPose(vanillaPose);
            }
            return;
        }

        // === КЛИЕНТСКАЯ ЧАСТЬ ===
        if (self instanceof ClientPlayerEntity cp) {
            boolean needsLow = ParkourManager.isSliding()
                || ParkourManager.isCrawling()
                || ParkourManager.isRolling()
                || PoseHelper.cannotStand(cp);

            if (needsLow) {
                PoseHelper.forceLowPose(cp);
            } else {
                self.setPose(vanillaPose);
            }
        } else {
            self.setPose(vanillaPose);
        }
    }
}

# ================= src\main\java\com\example\shinobicore\mixin\SlideTravelMixin.java =================
package com.example.shinobicore.mixin;

import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.parkour.util.PoseHelper;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.MovementType;
import net.minecraft.util.math.Vec3d;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(LivingEntity.class)
public abstract class SlideTravelMixin {

    @Inject(method = "travel", at = @At("HEAD"), cancellable = true)
    private void shinobicore_slideTravel(Vec3d movementInput, CallbackInfo ci) {
        if ((Object) this instanceof ClientPlayerEntity player && ParkourManager.isSliding()) {
            PoseHelper.forceLowPose(player);

            Vec3d v = player.getVelocity();
            double friction = player.isOnGround() ? 0.985 : 0.99;
            player.setVelocity(v.x * friction, v.y - 0.08, v.z * friction);
            player.move(MovementType.SELF, player.getVelocity());
            ci.cancel();
        }
    }
}

# ================= src\main\java\com\example\shinobicore\network\ChakraSyncPacket.java =================
package com.example.shinobicore.network;

import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.network.PacketByteBuf;

public record ChakraSyncPacket(
        float currentChakra,
        float maxChakra,
        float fatigue,
        boolean exhausted,
        boolean meditating,
        int reserveLevel,
        String clanId,
        String affinityId
) {
    public void write(PacketByteBuf buf) {
        buf.writeFloat(currentChakra);
        buf.writeFloat(maxChakra);
        buf.writeFloat(fatigue);
        buf.writeBoolean(exhausted);
        buf.writeBoolean(meditating);
        buf.writeInt(reserveLevel);
        buf.writeString(clanId != null ? clanId : "");
        buf.writeString(affinityId != null ? affinityId : "");
    }

    public static ChakraSyncPacket read(PacketByteBuf buf) {
        float chakra = buf.readFloat();
        float max = buf.readFloat();
        float fatigue = buf.readFloat();
        boolean exhausted = buf.readBoolean();
        boolean meditating = buf.readBoolean();
        int reserve = buf.readInt();
        String clan = buf.readString();
        String affinity = buf.readString();
        return new ChakraSyncPacket(
                chakra,
                max,
                fatigue,
                exhausted,
                meditating,
                reserve,
                clan.isEmpty() ? null : clan,
                affinity.isEmpty() ? null : affinity
        );
    }

    // === ИЗМЕНЕНО: используем getClanId() ===
    public static ChakraSyncPacket fromData(NinjaPlayerData data) {
        return new ChakraSyncPacket(
                data.getCurrentChakra(),
                NinjaFormula.maxChakra(data),
                data.getFatigue(),
                data.isExhausted(),
                data.isMeditating(),
                data.getReserveLevel(),
                data.getClanId(),
                data.getAffinity() != null ? data.getAffinity().getId() : null
        );
    }
}

# ================= src\main\java\com\example\shinobicore\network\MeditatePacket.java =================
package com.example.shinobicore.network;

import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

public record MeditatePacket(boolean start) {
    public static final Identifier ID = new Identifier("shinobicore", "meditate");

    public void write(PacketByteBuf buf) {
        buf.writeBoolean(start);
    }

    public static MeditatePacket read(PacketByteBuf buf) {
        return new MeditatePacket(buf.readBoolean());
    }
}

# ================= src\main\java\com\example\shinobicore\network\ModPackets.java =================
package com.example.shinobicore.network;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.combat.MeleeHitDetection;
import com.example.shinobicore.combat.TaijutsuCombo;
import com.example.shinobicore.combat.TaijutsuFormulas;
import com.example.shinobicore.combat.TaijutsuStyle;
import com.example.shinobicore.combat.KenjutsuFormulas;
import com.example.shinobicore.combat.KenjutsuStance;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.jutsu.JutsuCaster;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;
import com.example.shinobicore.combat.TaijutsuStyle;
import com.example.shinobicore.combat.KenjutsuFormulas;
import com.example.shinobicore.combat.KenjutsuStance;
import com.example.shinobicore.combat.TaijutsuFormulas;
import com.example.shinobicore.combat.TaijutsuCombo;
import com.example.shinobicore.combat.MeleeHitDetection;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
import com.example.shinobicore.pose.LowPoseTracker;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.tree.TreePassives;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
public class ModPackets {
    public static final Identifier CHAKRA_SYNC_ID = new Identifier("shinobicore", "chakra_sync");
    public static final Identifier MEDITATE_ID = new Identifier("shinobicore", "meditate");
    public static final Identifier SELECT_SLOT_ID = new Identifier("shinobicore", "select_slot");
    public static final Identifier CAST_SLOT_ID = new Identifier("shinobicore", "cast_slot");
    public static final Identifier SET_SLOT_ID = new Identifier("shinobicore", "set_slot");
    public static final Identifier LOADOUT_SYNC_ID = new Identifier("shinobicore", "loadout_sync");
    public static final Identifier CATALOG_SYNC_ID = new Identifier("shinobicore", "catalog_sync");
    public static final Identifier STATS_SYNC_ID = new Identifier("shinobicore", "stats_sync");
    public static final Identifier SPEND_SP_ID = new Identifier("shinobicore", "spend_sp");
    public static final Identifier BODY_SYNC_ID = new Identifier("shinobicore", "body_sync");
    public static final Identifier CHAKRA_MODE_ID = new Identifier("shinobicore", "chakra_mode");
    public static final Identifier PARKOUR_ACTION_ID = new Identifier("shinobicore", "parkour_action");
    public static final Identifier DODGE_ID = new Identifier("shinobicore", "dodge");
    public static final Identifier POSE_SYNC_ID = new Identifier("shinobicore", "pose_sync");
    public static final Identifier TAIJUTSU_ATTACK_ID = new Identifier("shinobicore", "taijutsu_attack");
    public static final Identifier TAIJUTSU_KICK_ID = new Identifier("shinobicore", "taijutsu_kick");
    public static final Identifier TAIJUTSU_STYLE_ID = new Identifier("shinobicore", "taijutsu_style");
    public static final Identifier RASENGAN_SYNC_ID = new Identifier("shinobicore", "rasengan_sync");
    public static final Identifier RASENGAN_STRIKE_ID = new Identifier("shinobicore", "rasengan_strike");
    public static final Identifier KATANA_ATTACK_ID = new Identifier("shinobicore", "katana_attack");
    public static final Identifier KATANA_STANCE_ID = new Identifier("shinobicore", "katana_stance");
    public static final Identifier KATANA_DEFLECT_ID = new Identifier("shinobicore", "katana_deflect");
    public static final Identifier CAST_FX_ID = new Identifier("shinobicore", "cast_fx");
    public static final Identifier ATTUNEMENT_ID = new Identifier("shinobicore", "attunement");
    public static final Identifier TREE_SYNC_ID = new Identifier("shinobicore", "tree_sync");
    public static final Identifier UNLOCK_NODE_ID = new Identifier("shinobicore", "unlock_node");
    public static final Identifier CONTROL_TRAIN_ID = new Identifier("shinobicore", "control_train");
    public static final Identifier DANGER_SYNC_ID = new Identifier("shinobicore", "danger_sync");
    public static final Identifier SENSORY_TOGGLE_ID = new Identifier("shinobicore", "sensory_toggle");
    
    public static void register() {
        ServerPlayNetworking.registerGlobalReceiver(MEDITATE_ID, (server, player, handler, buf, responseSender) -> {
            boolean start = buf.readBoolean();
            server.execute(() -> ((NinjaDataHolder) player).shinobicore_getData().setMeditating(start));
        });

        // === РАСЕНГАН: удар (клиент → сервер) ===
        ServerPlayNetworking.registerGlobalReceiver(RASENGAN_STRIKE_ID, (server, player, handler, buf, responseSender) -> {
            server.execute(() -> {
                ShinobiCore.handleRasenganStrike(player);
            });
        });

        // === РђРўРўР®РќРњР•РќРў (РєР»РёРµРЅС‚ -> СЃРµСЂРІРµСЂ) ===
        ServerPlayNetworking.registerGlobalReceiver(ATTUNEMENT_ID, (server, player, handler, buf, responseSender) -> {
            String elementId = buf.readString();
            boolean success = buf.readBoolean();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                ElementType element = null;
                for (ElementType e : ElementType.values()) {
                    if (e.getId().equals(elementId)) { element = e; break; }
                }
                if (element == null) return;

                if (success) {
                    int unlockedCount = 0;
                    for (ElementType e2 : ElementType.values()) {
                        if (data.isNatureUnlocked(e2)) unlockedCount++;
                    }
                    int cost = 10 + unlockedCount * 5;
                    if (data.getSkillPoints() < cost) {
                        player.sendMessage(Text.literal("В§cNot enough SP! Need " + cost), false);
                        return;
                    }
                    data.addSkillPoints(-cost);
                    data.setNatureUnlocked(element, true);
                    if (data.getNatureLevel(element) < 1) {
                        data.setNatureLevel(element, 1);
                    }
                    ShinobiCore.sendStatsSync(player);
                    player.sendMessage(Text.literal("В§aAttuned to " + elementId + "! (-" + cost + " SP)"), false);
                } else {
                    player.sendMessage(Text.literal("В§cAttunement failed."), false);
                }
            });
        });

        // === Р”Р Р•Р’Рћ: СЂР°Р·Р±Р»РѕРєРёСЂРѕРІРєР° СѓР·Р»Р° (РєР»РёРµРЅС‚ -> СЃРµСЂРІРµСЂ) ===
        ServerPlayNetworking.registerGlobalReceiver(CONTROL_TRAIN_ID, (server, player, handler, buf, responseSender) -> {
            boolean success = buf.readBoolean();
            float accuracy = buf.readFloat();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                int xp = success ? Math.round(15 + accuracy * 25) : 3;
                NinjaFormula.grantStatXp(data, StatType.CONTROL, xp);
                ShinobiCore.sendStatsSync(player);
                player.sendMessage(Text.literal(success
                    ? String.format("В§aControl training: +%d XP (%.0f%%)", xp, accuracy * 100)
                    : "В§7Training: +" + xp + " XP"), false);
            });
        });
        ServerPlayNetworking.registerGlobalReceiver(UNLOCK_NODE_ID, (server, player, handler, buf, responseSender) -> {
            String nodeId = buf.readString();
            server.execute(() -> ShinobiCore.handleUnlockNode(player, nodeId));
        });

        ServerPlayNetworking.registerGlobalReceiver(SELECT_SLOT_ID, (server, player, handler, buf, responseSender) -> {
            int set = buf.readInt(); int slot = buf.readInt();
            server.execute(() -> ((NinjaDataHolder) player).shinobicore_getData().setActiveSlot(set, slot));
        });

        ServerPlayNetworking.registerGlobalReceiver(CAST_SLOT_ID, (server, player, handler, buf, responseSender) -> {
            int set = buf.readInt(); 
            int slot = buf.readInt();
            
            ShinobiCore.LOGGER.info("[CAST-SERVER] === RECEIVED PACKET ===");
            ShinobiCore.LOGGER.info("[CAST-SERVER] Player: {}", player.getName().getString());
            ShinobiCore.LOGGER.info("[CAST-SERVER] Set: {}, Slot: {}", set, slot);
            
            server.execute(() -> {
                ShinobiCore.LOGGER.info("[CAST-SERVER] Processing on server thread...");
                
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data == null) {
                    ShinobiCore.LOGGER.info("[CAST-SERVER] ✗ NinjaPlayerData is null");
                    return;
                }
                
                int s = Math.max(0, Math.min(4, slot));
                String id = data.getLoadoutSlot(set == 0 ? 0 : 1, s);
                
                ShinobiCore.LOGGER.info("[CAST-SERVER] Loadout slot lookup: set={}, slot={} → id={}", 
                    set == 0 ? 0 : 1, s, id);
                
                if (id != null) {
                    ShinobiCore.LOGGER.info("[CAST-SERVER] ✓ Calling JutsuCaster.cast(player, {})", id);
                    boolean success = JutsuCaster.cast(player, id);
                    ShinobiCore.LOGGER.info("[CAST-SERVER] JutsuCaster.cast returned: {}", success);
                } else {
                    ShinobiCore.LOGGER.info("[CAST-SERVER] ✗ Slot {} is empty!", s + 1);
                    player.sendMessage(Text.literal("§cSlot " + (s + 1) + " is empty!"), false);
                }
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(TAIJUTSU_ATTACK_ID, (server, player, handler, buf, responseSender) -> {
            // === ИСПРАВЛЕНО: серверная валидация комбо (анти-чит) ===
            int clientComboStep = buf.readInt();
            String styleId = buf.readString();

            server.execute(() -> {
                if (player.getWorld().isClient()) return;
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.isExhausted()) return;
                if (data.getCurrentChakra() <= 0) return;

                // === ВАЛИДАЦИЯ: проверяем что стиль валиден ===
                TaijutsuStyle style = TaijutsuStyle.fromId(styleId);
                
                // === ВАЛИДАЦИЯ: проверяем что comboStep совпадает с серверным ===
                int serverStep = data.getServerComboStep();
                if (clientComboStep != serverStep) {
                    ShinobiCore.LOGGER.warn("[ANTICHEAT] Player {} sent comboStep={}, expected={}",
                            player.getName().getString(), clientComboStep, serverStep);
                    return; // Отклоняем
                }

                // === ВАЛИДАЦИЯ: проверяем кулдаун между ударами ===
                long now = System.currentTimeMillis();
                long lastAttack = data.getLastAttackTimeMs();
                int cooldownMs = TaijutsuFormulas.attackCooldownTicks(style, data.isChakraMode()) * 50;
                
                // Разрешаем небольшой допуск (50мс) для пинга
                if (now - lastAttack < cooldownMs - 50) {
                    ShinobiCore.LOGGER.warn("[ANTICHEAT] Player {} attacked too fast: {}ms since last (cooldown={}ms)",
                            player.getName().getString(), now - lastAttack, cooldownMs);
                    return; // Отклоняем
                }

                // === ВАЛИДАЦИЯ: сбрасываем комбо если прошло слишком много времени ===
                long timeoutMs = (long)(TaijutsuCombo.COMBO_TIMEOUT_MS * (1 + TreePassives.collectServer(data).comboTimeoutBonus));
                if (now - lastAttack > timeoutMs && serverStep > 0) {
                    data.resetCombo();
                    serverStep = 0;
                }

                // Всё ок — применяем урон
                int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);
                boolean chakraMode = data.isChakraMode();
                float damage = TaijutsuFormulas.computeDamage(taijutsuLevel, style, chakraMode, serverStep, data.isExhausted());
                float knockback = TaijutsuCombo.getKnockback(serverStep);
                Vec3d look = player.getRotationVector();
                java.util.List<LivingEntity> targets = MeleeHitDetection.findTargetsInCone(
                        (ServerWorld) player.getWorld(), player, look);
                MeleeHitDetection.applyDamage((ServerWorld) player.getWorld(), player, targets, damage, knockback);
                data.setFatigue(data.getFatigue() + style.getFatiguePerHit());

                // Обновляем серверное состояние
                data.setLastAttackTimeMs(now);
                data.advanceComboStep();
                data.setCurrentStyleId(styleId);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(TAIJUTSU_STYLE_ID, (server, player, handler, buf, responseSender) -> {
            String newStyleId = buf.readString();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                TaijutsuStyle style = TaijutsuStyle.fromId(newStyleId);
                
                // Проверяем разблокировку Strong Fist
                int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);
                if (style == TaijutsuStyle.STRONG_FIST && !TaijutsuFormulas.canUseStrongFist(taijutsuLevel)) {
                    player.sendMessage(Text.literal("§cYou need Taijutsu level " + 
                            TaijutsuFormulas.strongFistUnlockLevel() + " to use Strong Fist!"), false);
                    return;
                }
                
                data.setCurrentStyleId(newStyleId);
                ShinobiCore.sendBodySync(player);
                player.sendMessage(Text.literal("§aStyle changed to: " + style.getId()), false);
            });
        });

        
        ServerPlayNetworking.registerGlobalReceiver(TAIJUTSU_KICK_ID, (server, player, handler, buf, responseSender) -> {
            String styleId = buf.readString();
            server.execute(() -> {
                if (player.getWorld().isClient()) return;
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.isExhausted()) return;

                TaijutsuStyle style = TaijutsuStyle.fromId(styleId);
                int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);
                boolean chakraMode = data.isChakraMode();

                // Удар ногой = x1.5 урона обычного удара
                float baseDamage = TaijutsuFormulas.computeDamage(taijutsuLevel, style, chakraMode, 2, data.isExhausted());
                float damage = baseDamage * 1.5f;
                float knockback = 1.5f;

                Vec3d look = player.getRotationVector();
                java.util.List<LivingEntity> targets = MeleeHitDetection.findTargetsInCone(
                    (ServerWorld) player.getWorld(), player, look);
                MeleeHitDetection.applyDamage((ServerWorld) player.getWorld(), player, targets, damage, knockback);

                data.setFatigue(data.getFatigue() + style.getFatiguePerHit() * 1.5f);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(SENSORY_TOGGLE_ID, (server, player, handler, buf, responseSender) -> {
            boolean enabled = buf.readBoolean();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                data.setSensoryEnabled(enabled);
                ShinobiCore.sendStatsSync(player);
            });
        });
        
        ServerPlayNetworking.registerGlobalReceiver(KATANA_ATTACK_ID, (server, player, handler, buf, responseSender) -> {
            final int stepParam = buf.readInt();
            final String stanceParam = buf.readString();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.isExhausted()) return;
                KenjutsuStance stance = KenjutsuStance.fromId(stanceParam);
                long now = System.currentTimeMillis();
                int step = stepParam;
                if (data.isKatanaDeflectHeld()) return;
                if (step != data.getKatanaComboStep()) return;
                if (now - data.getKatanaLastAttackMs() < KenjutsuFormulas.cooldownMs(stance) - 50) return;
                if (now - data.getKatanaLastAttackMs() > 1500) { data.setKatanaComboStep(0); step = 0; }
                int tai = data.getStatLevel(StatType.TAIJUTSU);
                float damage = KenjutsuFormulas.computeDamage(tai, stance, data.isChakraMode(), step, data.isExhausted());
                if (stance == KenjutsuStance.IAI && now - data.getKatanaLastAttackMs() > 2000) damage *= 2.2f;
                Vec3d look = player.getRotationVector();
                java.util.List<LivingEntity> targets = step == 3
                        ? KenjutsuFormulas.findInRadius((ServerWorld) player.getWorld(), player, 3.5)
                        : KenjutsuFormulas.findTargetsInCone((ServerWorld) player.getWorld(), player, look, 3.75, 100);
                for (LivingEntity t : targets) {
                    t.damage(player.getDamageSources().playerAttack(player), damage);
                    Vec3d kb = t.getPos().subtract(player.getPos()).normalize().multiply(KenjutsuFormulas.getKnockback(step));
                    t.addVelocity(kb.x, 0.2, kb.z);
                    t.velocityModified = true;
                }
                data.setFatigue(data.getFatigue() + 1.5f);
                data.setKatanaLastAttackMs(now);
                data.setKatanaComboStep((step + 1) % 4);
                data.setKatanaStanceId(stanceParam);
            });
        });
        ServerPlayNetworking.registerGlobalReceiver(KATANA_STANCE_ID, (server, player, handler, buf, responseSender) -> {
            String stanceId = buf.readString();
            server.execute(() -> ((NinjaDataHolder) player).shinobicore_getData().setKatanaStanceId(stanceId));
        });
        ServerPlayNetworking.registerGlobalReceiver(KATANA_DEFLECT_ID, (server, player, handler, buf, responseSender) -> {
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (KenjutsuStance.fromId(data.getKatanaStanceId()).canDeflect()) {
                    data.setKatanaDeflectUntil(System.currentTimeMillis() + 300);
                }
            });
        });
        ServerPlayNetworking.registerGlobalReceiver(DODGE_ID, (server, player, handler, buf, responseSender) -> {
            int direction = buf.readInt(); // -1 = влево, 1 = вправо
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.getCurrentChakra() <= 0 || data.isExhausted()) return;
                
                // Усталость за dodge
                data.setFatigue(data.getFatigue() + ModConfig.instance.parkour.dodgeFatigue);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(POSE_SYNC_ID, (server, player, handler, buf, responseSender) -> {
            boolean low = buf.readBoolean();
            server.execute(() -> LowPoseTracker.set(player.getUuid(), low));
        });

        ServerPlayConnectionEvents.DISCONNECT.register((handler, server) ->
            LowPoseTracker.set(handler.player.getUuid(), false));

        ServerPlayNetworking.registerGlobalReceiver(SET_SLOT_ID, (server, player, handler, buf, responseSender) -> {
            int set = buf.readInt(); int slot = buf.readInt(); String id = buf.readString();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                String clean = id.isEmpty() ? null : id;
                if (clean != null && !data.getLearnedJutsus().contains(clean)) {
                    player.sendMessage(Text.literal("§cLearn it first!"), false);
                    return;
                }
                data.setLoadoutSlot(set, Math.max(0, Math.min(4, slot)), clean);
                ShinobiCore.sendLoadoutSync(player);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(SPEND_SP_ID, (server, player, handler, buf, responseSender) -> {
            String type = buf.readString(); String id = buf.readString();
            server.execute(() -> ShinobiCore.handleSpendSp(player, type, id));
        });

        ServerPlayNetworking.registerGlobalReceiver(CHAKRA_MODE_ID, (server, player, handler, buf, responseSender) -> {
            boolean enable = buf.readBoolean();
            ShinobiCore.LOGGER.info("[CHAKRA-SERVER] Packet received: player={}, enable={}", 
                player.getName().getString(), enable);
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                data.setChakraMode(enable);
                ShinobiCore.LOGGER.info("[CHAKRA-SERVER] Server chakraMode set to: {}", enable);
                ShinobiCore.sendBodySync(player);
            });
        });
        // === АТТЮНМЕНТ (клиент → сервер) ===
ServerPlayNetworking.registerGlobalReceiver(ATTUNEMENT_ID, (server, player, handler, buf, responseSender) -> {
    String elementId = buf.readString();
    boolean success = buf.readBoolean();
    server.execute(() -> {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        ElementType element = null;
        for (ElementType e : ElementType.values()) {
            if (e.getId().equals(elementId)) { element = e; break; }
        }
        if (element == null) return;

        if (success) {
            data.setNatureUnlocked(element, true);
            if (data.getNatureLevel(element) < 1) {
                data.setNatureLevel(element, 1);
            }
            ShinobiCore.sendStatsSync(player);
            player.sendMessage(Text.literal("§aAttuned to " + elementId + "!"), false);
        } else {
            player.sendMessage(Text.literal("§cAttunement failed."), false);
        }
    });
});
        ServerPlayNetworking.registerGlobalReceiver(PARKOUR_ACTION_ID, (server, player, handler, buf, responseSender) -> {
            // === ИСПРАВЛЕНО: читаем ВСЕ данные ИЗ буфера СРАЗУ, ДО server.execute() ===
            String actionId = buf.readString();
            float fatigueValue = 0;
            if (actionId.equals("charged_jump")) {
                fatigueValue = buf.readFloat();
            }
            // Копируем значение в final переменную для использования в server.execute()
            final float finalFatigue = fatigueValue;
            final String finalActionId = actionId;

            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.getCurrentChakra() <= 0 || data.isExhausted()) return;
                float f = 0;
                if (finalActionId.equals("charged_jump")) {
                    f = finalFatigue;
                } else {
                    switch (finalActionId) {
                        case "slide": f = ModConfig.instance.parkour.slideFatigue; break;
                        case "double_jump": f = ModConfig.instance.parkour.doubleJumpFatigue; break;
                        case "wall_jump": f = ModConfig.instance.parkour.wallJumpFatigue; break;
                        case "vault": f = ModConfig.instance.parkour.vaultFatigue; break;
                        case "wall_run": f = ModConfig.instance.parkour.wallRunFatiguePerTick; break;
                        case "edge_grab": f = ModConfig.instance.parkour.edgeGrabFatigue; break;
                        case "roll": f = ModConfig.instance.parkour.rollFatigue; break;
                    }
                }
                if (f > 0) data.setFatigue(data.getFatigue() + f);
            });
        });
    }
}

# ================= src\main\java\com\example\shinobicore\pose\LowPoseTracker.java =================
package com.example.shinobicore.pose;

import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public class LowPoseTracker {
    private static final Set<UUID> LOW = ConcurrentHashMap.newKeySet();

    public static void set(UUID id, boolean low) {
        if (low) LOW.add(id);
        else LOW.remove(id);
    }

    public static boolean isLow(UUID id) {
        return LOW.contains(id);
    }
}

# ================= src\main\java\com\example\shinobicore\ShinobiCore.java =================
package com.example.shinobicore;

import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.command.NinjaCommand;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.entity.ModEntities;
import com.example.shinobicore.item.ModItems;
import com.example.shinobicore.event.NinjaTickHandler;
import com.example.shinobicore.jutsu.AoeBehavior;
import com.example.shinobicore.jutsu.BehaviorRegistry;
import com.example.shinobicore.jutsu.DashBehavior;
import com.example.shinobicore.jutsu.JutsuLogger;
import com.example.shinobicore.jutsu.JutsuRegistry;
import com.example.shinobicore.jutsu.MeleeBehavior;
import com.example.shinobicore.jutsu.ProjectileBehavior;
import com.example.shinobicore.jutsu.UtilityBehavior;
import com.example.shinobicore.jutsu.WallBehavior;
import com.example.shinobicore.network.ChakraSyncPacket;
import com.example.shinobicore.network.ModPackets;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.tree.SkillTreeNode;
import com.example.shinobicore.tree.SkillTreeRegistry;
import com.example.shinobicore.stat.StatType;
import io.netty.buffer.Unpooled;
import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.entity.attribute.EntityAttributes;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Random;

public class ShinobiCore implements ModInitializer {
    public static final String MOD_ID = "shinobicore";
    public static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);
    private static final Random RANDOM = new Random();

    @Override
    public void onInitialize() {
        LOGGER.info("Shinobi Core загружается...");
        ModConfig.load();
        JutsuLogger.init();
        ModEntities.register();
        ModItems.register();

        BehaviorRegistry.register("projectile", new ProjectileBehavior());
        BehaviorRegistry.register("aoe", new AoeBehavior());
        BehaviorRegistry.register("dash", new DashBehavior());
        BehaviorRegistry.register("melee", new MeleeBehavior());
        BehaviorRegistry.register("wall", new WallBehavior());
        BehaviorRegistry.register("utility", new UtilityBehavior());

        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> NinjaCommand.register(dispatcher));
        ServerTickEvents.END_SERVER_TICK.register(NinjaTickHandler::onServerTick);
        ModPackets.register();

        ServerPlayConnectionEvents.JOIN.register((handler, sender, server) -> {
            ServerPlayerEntity player = handler.getPlayer();
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();

            if (!data.isClanChosen()) {
                ClanDefinition randomClan = ClanRegistry.getRandom();
                if (randomClan != null) {
                    // === ИЗМЕНЕНО: сохраняем строку ===
                    data.setClanId(randomClan.id());
                    data.setAffinity(randomClan.affinity());
                    // === Р¤РРљРЎ: СЂР°Р·Р±Р»РѕРєРёСЂРѕРІР°С‚СЊ affinity РєР°Рє nature ===
                    if (randomClan.affinity() != null) {
                        data.setNatureUnlocked(randomClan.affinity(), true);
                        if (data.getNatureLevel(randomClan.affinity()) < 5) {
                            data.setNatureLevel(randomClan.affinity(), 5);
                        }
                    }
                    // === ФИКС: разблокировать affinity как nature ===
                    if (randomClan.affinity() != null) {
                        data.setNatureUnlocked(randomClan.affinity(), true);
                        if (data.getNatureLevel(randomClan.affinity()) < 5) {
                        data.setNatureLevel(randomClan.affinity(), 5);
                        }
                    }
                    data.setClanChosen(true);

                    if (randomClan.extraAffinityCount() > 0) {
                        ElementType[] elements = ElementType.values();
                        ElementType second = elements[RANDOM.nextInt(elements.length)];
                        if (second != randomClan.affinity()) {
                            data.setNatureLevel(second, 10);
                            data.setNatureUnlocked(second, true);
                        }
                    }

                    LOGGER.info("Auto-assigned clan {} to {}", randomClan.id(), player.getName().getString());
                }
            }

            sendChakraSync(player);
            sendCatalogSync(player);
            sendLoadoutSync(player);
            sendStatsSync(player);
            sendBodySync(player);
                sendTreeSync(player);
        });

        ServerLifecycleEvents.SERVER_STARTED.register(server -> {
            JutsuRegistry.reload(server.getResourceManager());
            ClanRegistry.reload(server.getResourceManager());
            SkillTreeRegistry.reload(server.getResourceManager());
        });

        ServerLifecycleEvents.END_DATA_PACK_RELOAD.register((server, resourceManager, success) -> {
            if (success) {
                JutsuRegistry.reload(server.getResourceManager());
                ClanRegistry.reload(server.getResourceManager());
            SkillTreeRegistry.reload(server.getResourceManager());
                for (ServerPlayerEntity p : server.getPlayerManager().getPlayerList()) sendCatalogSync(p);
            }
        });

        LOGGER.info("Shinobi Core загружен!");
    }

    public static void sendChakraSync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        ChakraSyncPacket.fromData(data).write(buf);
        ServerPlayNetworking.send(player, ModPackets.CHAKRA_SYNC_ID, buf);
    }

    public static void sendCatalogSync(ServerPlayerEntity player) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        var all = JutsuRegistry.getAll();
        buf.writeInt(all.size());
        for (var def : all) {
            buf.writeString(def.id());
            buf.writeString(def.name());
        }
        ServerPlayNetworking.send(player, ModPackets.CATALOG_SYNC_ID, buf);
    }

    public static void sendLoadoutSync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(data.getActiveSlot(0));
        buf.writeInt(data.getActiveSlot(1));
        for (int i = 0; i < 5; i++) buf.writeString(data.getLoadoutSlot(0, i) == null ? "" : data.getLoadoutSlot(0, i));
        for (int i = 0; i < 5; i++) buf.writeString(data.getLoadoutSlot(1, i) == null ? "" : data.getLoadoutSlot(1, i));
        buf.writeInt(data.getLearnedJutsus().size());
        for (String id : data.getLearnedJutsus()) buf.writeString(id);
        ServerPlayNetworking.send(player, ModPackets.LOADOUT_SYNC_ID, buf);
    }

    public static void sendStatsSync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(data.getSkillPoints());
        buf.writeInt(data.getReserveLevel());
        buf.writeInt(data.getReserveXp());
        for (StatType s : StatType.values()) { buf.writeInt(data.getStatLevel(s)); buf.writeInt(data.getStatXp(s)); }
        for (ElementType e : ElementType.values()) { buf.writeInt(data.getNatureLevel(e)); buf.writeInt(data.getNatureXp(e)); }
        for (ElementType e : ElementType.values()) buf.writeBoolean(data.isNatureUnlocked(e));
        buf.writeBoolean(data.isSensoryEnabled());
        ServerPlayNetworking.send(player, ModPackets.STATS_SYNC_ID, buf);
    }

    public static void sendBodySync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(data.getHpLevel());
        buf.writeInt(data.getSpeedLevel());
        buf.writeInt(data.getJumpLevel());
        buf.writeBoolean(data.isChakraMode());
        
        // === ИЗМЕНЕНО: отправляем строку ===
        buf.writeString(data.getClanId());
        buf.writeString(data.getAffinity() != null ? data.getAffinity().getId() : "");
        
        ServerPlayNetworking.send(player, ModPackets.BODY_SYNC_ID, buf);
    }

        public static void broadcastCastFx(ServerPlayerEntity player, String natureId) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(player.getId());
        buf.writeString(natureId);
        for (ServerPlayerEntity p : net.fabricmc.fabric.api.networking.v1.PlayerLookup.tracking(player)) {
            ServerPlayNetworking.send(p, ModPackets.CAST_FX_ID, buf);
        }
        ServerPlayNetworking.send(player, ModPackets.CAST_FX_ID, buf);
    }

    public static void sendRasenganSync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeBoolean(data.isRasenganCharging());
        buf.writeFloat(data.getRasenganChargeProgress());
        buf.writeBoolean(data.isRasenganReady());
        ServerPlayNetworking.send(player, ModPackets.RASENGAN_SYNC_ID, buf);
    }

    public static void handleRasenganStrike(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        if (!data.isRasenganReady()) return;

        data.setRasenganReady(false);
        data.setRasenganCharging(false);

        // Параметры из JSON
        float dashDistance = 6.0f;
        float hitRadius = 2.5f;
        float knockback = 3.5f;
        float damage = 16.0f;

        // Читаем из JutsuDefinition если есть
        var def = com.example.shinobicore.jutsu.JutsuRegistry.get("shinobicore:rasengan");
        if (def != null) {
            damage = def.baseDamage() * com.example.shinobicore.stat.NinjaFormula.damageMultiplier(data, def);
            if (def.params().has("dashDistance")) dashDistance = def.params().get("dashDistance").getAsFloat();
            if (def.params().has("hitRadius")) hitRadius = def.params().get("hitRadius").getAsFloat();
            if (def.params().has("knockback")) knockback = def.params().get("knockback").getAsFloat();
        }

        net.minecraft.util.math.Vec3d look = player.getRotationVector();
        net.minecraft.util.math.Vec3d startPos = player.getPos();
        net.minecraft.util.math.Vec3d endPos = startPos.add(look.multiply(dashDistance));

        // Рывок вперёд
        player.addVelocity(look.x * dashDistance * 0.6, 0.15, look.z * dashDistance * 0.6);
        player.velocityModified = true;

        // Урон по пути
        if (player.getWorld() instanceof net.minecraft.server.world.ServerWorld serverWorld) {
            java.util.List<net.minecraft.entity.LivingEntity> targets =
                    findRasenganTargets(serverWorld, player, startPos, endPos, hitRadius);

            for (net.minecraft.entity.LivingEntity target : targets) {
                target.damage(player.getDamageSources().magic(), damage);

                // Мощный отброс (Расенган подбрасывает)
                net.minecraft.util.math.Vec3d kb = target.getPos().subtract(player.getPos()).normalize();
                target.addVelocity(kb.x * knockback, knockback * 0.4, kb.z * knockback);
                target.velocityModified = true;
            }

            // Визуал: взрыв частиц при ударе
            if (!targets.isEmpty()) {
                net.minecraft.util.math.Vec3d hitPos = targets.get(0).getPos();
                spawnRasenganImpact(serverWorld, hitPos);
            }

            // Визуал: след вдоль пути
            spawnRasenganTrail(serverWorld, startPos, endPos, 80);
        }

        sendRasenganSync(player);
        com.example.shinobicore.jutsu.JutsuLogger.logBehavior("rasengan",
                String.format("STRIKE: player=%s, damage=%.2f, knockback=%.2f",
                        player.getName().getString(), damage, knockback));
    }

    private static java.util.List<net.minecraft.entity.LivingEntity> findRasenganTargets(
            net.minecraft.server.world.ServerWorld world, ServerPlayerEntity attacker,
            net.minecraft.util.math.Vec3d start, net.minecraft.util.math.Vec3d end, float radius) {
        java.util.List<net.minecraft.entity.LivingEntity> targets = new java.util.ArrayList<>();
        net.minecraft.util.math.Vec3d dir = end.subtract(start).normalize();
        float length = (float) start.distanceTo(end);

        for (float d = 0; d <= length; d += 0.5f) {
            net.minecraft.util.math.Vec3d checkPos = start.add(dir.multiply(d));
            for (net.minecraft.entity.Entity entity : world.getOtherEntities(attacker,
                    attacker.getBoundingBox().expand(radius + 1.0).offset(checkPos.subtract(attacker.getPos())))) {
                if (entity instanceof net.minecraft.entity.LivingEntity living
                        && !living.equals(attacker) && living.isAlive()) {
                    if (living.getPos().distanceTo(checkPos) <= radius + 0.5) {
                        if (!targets.contains(living)) {
                            targets.add(living);
                        }
                    }
                }
            }
        }
        return targets;
    }

    private static void spawnRasenganTrail(net.minecraft.server.world.ServerWorld world,
                                            net.minecraft.util.math.Vec3d start,
                                            net.minecraft.util.math.Vec3d end, int count) {
        net.minecraft.util.math.Vec3d dir = end.subtract(start).normalize();
        float length = (float) start.distanceTo(end);

        for (int i = 0; i < count; i++) {
            float progress = (float) i / count;
            net.minecraft.util.math.Vec3d center = start.add(dir.multiply(progress * length));

            // Вращающиеся спирали
            float angle = progress * (float)(Math.PI * 6);
            float spiralRadius = 0.4f + (float)Math.sin(progress * Math.PI) * 0.4f;

            double x = center.x + Math.cos(angle) * spiralRadius;
            double y = center.y + 1.0 + Math.sin(angle * 2) * spiralRadius * 0.3;
            double z = center.z + Math.sin(angle) * spiralRadius;

            world.spawnParticles(net.minecraft.particle.ParticleTypes.ENCHANT, x, y, z,
                    2, 0.08, 0.08, 0.08, 0.08);

            if (i % 3 == 0) {
                world.spawnParticles(net.minecraft.particle.ParticleTypes.CRIT, x, y, z,
                        1, 0.15, 0.15, 0.15, 0.12);
            }
        }
    }

    private static void spawnRasenganImpact(net.minecraft.server.world.ServerWorld world,
                                             net.minecraft.util.math.Vec3d pos) {
        // Кольцо частиц
        for (int i = 0; i < 40; i++) {
            double angle = (i / 40.0) * Math.PI * 2;
            double r = 1.0 + Math.random() * 2.0;

            world.spawnParticles(net.minecraft.particle.ParticleTypes.ENCHANT,
                    pos.x + Math.cos(angle) * r,
                    pos.y + 0.5 + Math.random() * 1.5,
                    pos.z + Math.sin(angle) * r,
                    3, 0.2, 0.3, 0.2, 0.1);
        }

        // Взрывная волна
        for (int i = 0; i < 30; i++) {
            world.spawnParticles(net.minecraft.particle.ParticleTypes.CRIT,
                    pos.x + (Math.random() - 0.5) * 4.0,
                    pos.y + Math.random() * 2.5,
                    pos.z + (Math.random() - 0.5) * 4.0,
                    2, 0.3, 0.3, 0.3, 0.2);
        }

        // Облако
        for (int i = 0; i < 15; i++) {
            world.spawnParticles(net.minecraft.particle.ParticleTypes.CLOUD,
                    pos.x + (Math.random() - 0.5) * 2.0,
                    pos.y + 1.0,
                    pos.z + (Math.random() - 0.5) * 2.0,
                    3, 0.3, 0.2, 0.3, 0.01);
        }
    }
    
    public static void handleSpendSp(ServerPlayerEntity player, String type, String id) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        int currentLevel;
        boolean isBody = type.equals("body");
        if (type.equals("stat")) {
            StatType s = statById(id); if (s == null) return;
            currentLevel = data.getStatLevel(s);
        } else if (type.equals("nature")) {
            ElementType e = elementById(id); if (e == null) return;
            if (!data.isNatureUnlocked(e)) { player.sendMessage(Text.literal("§cUnlock this nature first!"), false); return; }
            currentLevel = data.getNatureLevel(e);
        } else if (type.equals("reserve")) {
            currentLevel = data.getReserveLevel();
        } else if (isBody) {
            if (id.equals("hp")) currentLevel = data.getHpLevel();
            else if (id.equals("speed")) currentLevel = data.getSpeedLevel();
            else if (id.equals("jump")) currentLevel = data.getJumpLevel();
            else return;
        } else return;

        int maxLevel = isBody ? 7 : NinjaPlayerData.MAX_LEVEL;
        if (currentLevel >= maxLevel) { player.sendMessage(Text.literal("§cMax level reached!"), false); return; }

        int cost = isBody ? NinjaFormula.bodySpCost() : NinjaFormula.spCostForLevel(currentLevel);
        if (data.getSkillPoints() < cost) { player.sendMessage(Text.literal("§cNot enough SP! Need " + cost), false); return; }

        data.addSkillPoints(-cost);
        if (type.equals("stat")) data.setStatLevel(statById(id), currentLevel + 1);
        else if (type.equals("nature")) { ElementType e = elementById(id); data.setNatureLevel(e, currentLevel + 1); data.setNatureUnlocked(e, true); }
        else if (type.equals("reserve")) data.setReserveLevel(currentLevel + 1);
        else if (isBody) {
            if (id.equals("hp")) data.setHpLevel(currentLevel + 1);
            else if (id.equals("speed")) data.setSpeedLevel(currentLevel + 1);
            else if (id.equals("jump")) data.setJumpLevel(currentLevel + 1);
            if (id.equals("hp")) {
                var hpAttr = player.getAttributeInstance(EntityAttributes.GENERIC_MAX_HEALTH);
                if (hpAttr != null) hpAttr.setBaseValue(NinjaFormula.maxHealth(data.getHpLevel()));
            }
        }

        sendStatsSync(player);
        sendBodySync(player);
                sendTreeSync(player);
        sendChakraSync(player);
        player.sendMessage(Text.literal("§aLevel up!"), false);
    }

    public static void sendTreeSync(ServerPlayerEntity player) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(data.getUnlockedNodes().size());
        for (String nodeId : data.getUnlockedNodes()) buf.writeString(nodeId);
        ServerPlayNetworking.send(player, ModPackets.TREE_SYNC_ID, buf);
    }

    public static void handleUnlockNode(ServerPlayerEntity player, String nodeId) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        SkillTreeNode node = SkillTreeRegistry.get(nodeId);
        if (node == null) {
            player.sendMessage(Text.literal("В§cUnknown node: " + nodeId), false);
            return;
        }
        if (data.isNodeUnlocked(nodeId)) {
            player.sendMessage(Text.literal("В§cAlready unlocked!"), false);
            return;
        }
        if (!SkillTreeRegistry.isVisibleServer(node, data)) {
            player.sendMessage(Text.literal("В§cThis node is not available to you!"), false);
            return;
        }
        for (String req : node.requires()) {
            if (!data.isNodeUnlocked(req)) {
                player.sendMessage(Text.literal("В§cRequires: " + req), false);
                return;
            }
        }
        if (data.getSkillPoints() < node.spCost()) {
            player.sendMessage(Text.literal("В§cNot enough SP! Need " + node.spCost()), false);
            return;
        }
        if (!node.branch().equals("general") && !node.branch().equals("taijutsu")
            && !node.branch().equals("medical")) {
            ElementType nature = null;
            for (ElementType e : ElementType.values()) {
                if (e.getId().equals(node.branch())) { nature = e; break; }
            }
            if (nature != null && !data.isNatureUnlocked(nature)) {
                player.sendMessage(Text.literal("В§cUnlock this nature first!"), false);
                return;
            }
        }

        data.addSkillPoints(-node.spCost());
        data.unlockNode(nodeId);

        if ("jutsu".equals(node.type()) && node.jutsuId() != null) {
            if (!data.getLearnedJutsus().contains(node.jutsuId())) {
                data.learnJutsu(node.jutsuId());
            }
        }

        sendStatsSync(player);
        sendLoadoutSync(player);
        sendTreeSync(player);
        player.sendMessage(Text.literal("В§aUnlocked: " + nodeId), false);
    }

    private static StatType statById(String id) {
        for (StatType s : StatType.values()) if (s.getId().equals(id)) return s;
        return null;
    }

    private static ElementType elementById(String id) {
        for (ElementType e : ElementType.values()) if (e.getId().equals(id)) return e;
        return null;
    }
}

# ================= src\main\java\com\example\shinobicore\stat\ClanType.java =================
package com.example.shinobicore.stat;

public enum ClanType {
    NONE("none"),
    UCHIHA("uchiha"),
    HYUGA("hyuga"),
    UZUMAKI("uzumaki"),
    NARA("nara"),
    HATAKE("hatake"),
    SARUTOBI("sarutobi");

    private final String id;

    ClanType(String id) {
        this.id = id;
    }

    public String getId() {
        return id;
    }
}

# ================= src\main\java\com\example\shinobicore\stat\ElementType.java =================
package com.example.shinobicore.stat;

public enum ElementType {
    FIRE("fire"),
    WATER("water"),
    WIND("wind"),
    LIGHTNING("lightning"),
    EARTH("earth");

    private final String id;

    ElementType(String id) {
        this.id = id;
    }

    public String getId() {
        return id;
    }
}

# ================= src\main\java\com\example\shinobicore\stat\NinjaDataHolder.java =================
package com.example.shinobicore.stat;

import com.example.shinobicore.stat.NinjaPlayerData;

public interface NinjaDataHolder {
    NinjaPlayerData shinobicore_getData();
}

# ================= src\main\java\com\example\shinobicore\stat\NinjaFormula.java =================
package com.example.shinobicore.stat;

import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.tree.TreePassives;

import java.util.Map;

public class NinjaFormula {
    private static ModConfig cfg() { return ModConfig.instance; }

    public static float maxChakra(NinjaPlayerData data) {
        return cfg().chakra.baseChakra
                + (data.getReserveLevel() - 1) * cfg().chakra.chakraPerReserveLevel
                + getClanReserveBonus(data.getClanId());
    }

    public static float regenPerSecond(NinjaPlayerData data) {
        float regen = cfg().chakra.baseRegen
                + data.getReserveLevel() * cfg().chakra.regenPerReserveLevel
                + data.getStatLevel(StatType.CONTROL) * cfg().chakra.regenPerControlLevel;
        if (data.getFatigue() > cfg().fatigue.hardThreshold)
            regen *= cfg().chakra.regenHardFatigueMultiplier;
        if (data.isExhausted())
            regen *= cfg().chakra.regenExhaustedMultiplier;
        return regen;
    }

    public static float fatigueDecayPerSecond(NinjaPlayerData data) {
        return cfg().fatigue.decayPerSecond;
    }

    public static float characterScore(JutsuDefinition def, NinjaPlayerData data) {
        Map<String, Float> weights = cfg().combat.categoryWeights.get(def.category());
        if (weights == null)
            weights = cfg().combat.categoryWeights.get("elemental_ninjutsu");
        float score = 0f;
        for (Map.Entry<String, Float> e : weights.entrySet()) {
            score += statValue(e.getKey(), def, data) * e.getValue();
        }
        return Math.max(0f, Math.min(100f, score));
    }

    private static float statValue(String key, JutsuDefinition def, NinjaPlayerData data) {
        if (key.equals("nature")) return def.hasNature() ? data.getNatureLevel(def.nature()) : 0;
        if (key.equals("reserve")) return data.getReserveLevel();
        for (StatType s : StatType.values()) {
            if (s.getId().equals(key)) return data.getStatLevel(s);
        }
        return 0f;
    }

    public static float usageScore(JutsuDefinition def, NinjaPlayerData data) {
        int uses = data.getJutsuUsage(def.id());
        float req = Math.max(1, def.requiredUsesForFullProficiency());
        return Math.min(100f, uses * 100f / req);
    }

    public static float mastery(JutsuDefinition def, NinjaPlayerData data) {
        float m = usageScore(def, data) * cfg().combat.masteryUsageWeight
                + characterScore(def, data) * cfg().combat.masteryStatWeight;
        return Math.max(0f, Math.min(100f, m));
    }

    public static float calculateCost(JutsuDefinition def, NinjaPlayerData data) {
        float cost = def.baseCost();
        float m = mastery(def, data) / 100f;
        float controlRed = data.getStatLevel(StatType.CONTROL) / 100f * cfg().combat.costControlReductionMax;
        float natureRed = 0f;
        if (def.hasNature()) {
            natureRed = data.getNatureLevel(def.nature()) / 100f * cfg().combat.costNatureReductionMax;
            if (data.getAffinity() == def.nature()) {
                cost *= cfg().combat.affinityCostMultiplier;
            }
        }
        float masteryRed = m * cfg().combat.costMasteryReductionMax;
        float totalRed = Math.min(0.8f, controlRed + natureRed + masteryRed);
        cost *= (1f - totalRed);

        // === НОВОЕ: costMultiplier клана ===
        ClanDefinition clan = ClanRegistry.get(data.getClanId());
        if (clan != null && def.hasNature()) {
            Float mult = clan.costMultiplier().get(def.nature().getId());
            if (mult != null) {
                cost *= mult;
            }
        }

        float soft = cfg().fatigue.softThreshold;
        if (data.getFatigue() > soft) {
            float over = (data.getFatigue() - soft) / (100f - soft);
            cost *= 1f + over * cfg().fatigue.costPenaltyMax;
        }
        return Math.max(1f, cost);
    }

    public static float damageMultiplier(NinjaPlayerData data, JutsuDefinition def) {
        float m = mastery(def, data) / 100f;
        float mult = cfg().combat.damageBaseMultiplier + m * cfg().combat.damageMasteryScale;
        if (def.hasNature() && data.getAffinity() == def.nature()) {
            mult *= cfg().combat.affinityDamageMultiplier;
        }
        return mult;
    }

    public static boolean checkRequirements(JutsuDefinition def, NinjaPlayerData data) {
        for (Map.Entry<String, Integer> req : def.requirements().entrySet()) {
            String key = req.getKey();
            int required = req.getValue();
            if (key.equals("control")) {
                if (data.getStatLevel(StatType.CONTROL) < required) return false;
            } else if (key.equals("ninjutsu")) {
                if (data.getStatLevel(StatType.NINJUTSU) < required) return false;
            } else if (key.startsWith("nature_")) {
                String natureId = key.substring(7);
                for (ElementType e : ElementType.values()) {
                    if (e.getId().equals(natureId)) {
                        if (data.getNatureLevel(e) < required) return false;
                        break;
                    }
                }
            }
        }
        return true;
    }

    public static float meditationRegenMultiplier() { return cfg().meditation.regenMultiplier; }
    public static float meditationFatigueDecayMultiplier() { return cfg().meditation.fatigueDecayMultiplier; }
    public static int meditationReserveXpPerSecond() { return cfg().meditation.reserveXpPerSecond; }
    public static int meditationControlXpPerSecond() { return cfg().meditation.controlXpPerSecond; }

    public static int xpToNextLevel(int level) {
        return cfg().progression.xpBase
                + level * cfg().progression.xpPerLevel
                + level * level * cfg().progression.xpSquared;
    }

    public static int spCostForLevel(int level) {
        return cfg().progression.spBaseCost + (level / 10) * cfg().progression.spExtraCostEvery10;
    }

    public static int maxHealth(int hpLevel) {
        return 20 + hpLevel * 20;
    }

    public static float speedMultiplier(int speedLevel, boolean chakraMode) {
        float base = 1.0f + speedLevel * 0.125f;
        if (chakraMode) base *= 2.0f;
        return Math.min(base, chakraMode ? 4.0f : 2.0f);
    }

    public static float jumpMultiplier(int jumpLevel, boolean chakraMode) {
        float base = 1.0f + jumpLevel * 0.125f;
        if (chakraMode) base *= 2.0f;
        return Math.min(base, chakraMode ? 4.0f : 2.0f);
    }

    public static float jumpHorizontalMultiplier(int jumpLevel, boolean chakraMode) {
        if (!chakraMode) return 1.0f + jumpLevel * 0.125f;
        return 2.0f + jumpLevel * 0.5f;
    }

    public static float jumpVerticalMultiplier(int jumpLevel, boolean chakraMode) {
        if (!chakraMode) return 1.0f;
        return 1.5f + jumpLevel * 0.15f;
    }

    public static int bodySpCost() {
        return cfg().progression.spBaseCost * 2;
    }

    public static float chakraModeDrainPerSecond(NinjaPlayerData data) {
        float controlReduction = data.getStatLevel(StatType.CONTROL) / 100f * 0.9f;
        return 2.0f * (1.0f - controlReduction);
    }

    public static float chakraModeRegenMultiplier() {
        return 0.2f;
    }

    public static boolean addStatXp(NinjaPlayerData data, StatType stat, int amount) {
        int startLevel = data.getStatLevel(stat);
        int currentXp = data.getStatXp(stat) + amount;
        int level = startLevel;
        boolean leveled = false;
        while (level < NinjaPlayerData.MAX_LEVEL && currentXp >= xpToNextLevel(level)) {
            currentXp -= xpToNextLevel(level);
            level++;
            leveled = true;
        }
        data.setStatLevel(stat, level);
        data.setStatXp(stat, currentXp);
        if (leveled) {
            data.addSkillPoints((level - startLevel) * cfg().progression.spPerLevelUp);
        }
        return leveled;
    }

    public static boolean addReserveXp(NinjaPlayerData data, int amount) {
        int startLevel = data.getReserveLevel();
        int currentXp = data.getReserveXp() + amount;
        int level = startLevel;
        boolean leveled = false;
        while (level < NinjaPlayerData.MAX_LEVEL && currentXp >= xpToNextLevel(level)) {
            currentXp -= xpToNextLevel(level);
            level++;
            leveled = true;
        }
        data.setReserveLevel(level);
        data.setReserveXp(currentXp);
        if (leveled) {
            data.addSkillPoints((level - startLevel) * cfg().progression.spPerLevelUp);
        }
        return leveled;
    }

    public static boolean addNatureXp(NinjaPlayerData data, ElementType element, int amount) {
        int startLevel = data.getNatureLevel(element);
        int currentXp = data.getNatureXp(element) + amount;
        int level = startLevel;
        boolean leveled = false;
        while (level < NinjaPlayerData.MAX_LEVEL && currentXp >= xpToNextLevel(level)) {
            currentXp -= xpToNextLevel(level);
            level++;
            leveled = true;
        }
        data.setNatureLevel(element, level);
        data.setNatureXp(element, currentXp);
        if (leveled) {
            data.addSkillPoints((level - startLevel) * cfg().progression.spPerLevelUp);
        }
        return leveled;
    }

    public static boolean grantStatXp(NinjaPlayerData data, StatType stat, int amount) {
        if (!data.tryConsumeXpBudget("stat_" + stat.getId(), amount, cfg().progression.maxXpPerMinute)) return false;
        return addStatXp(data, stat, amount);
    }

    public static boolean grantNatureXp(NinjaPlayerData data, ElementType element, int amount) {
        if (!data.tryConsumeXpBudget("nature_" + element.getId(), amount, cfg().progression.maxXpPerMinute)) return false;
        return addNatureXp(data, element, amount);
    }

    public static boolean grantReserveXp(NinjaPlayerData data, int amount) {
        if (!data.tryConsumeXpBudget("reserve", amount, cfg().progression.maxXpPerMinute)) return false;
        return addReserveXp(data, amount);
    }

    public static boolean grantUsage(NinjaPlayerData data, String jutsuId, int amount) {
        if (!data.tryConsumeXpBudget("usage_" + jutsuId, amount, cfg().progression.maxUsagePerMinute)) return false;
        data.addJutsuUsage(jutsuId, amount);
        return true;
    }

    private static float getClanReserveBonus(String clanId) {
        if (clanId == null || clanId.equals("none")) return 0f;
        ClanDefinition clan = ClanRegistry.get(clanId);
        if (clan == null) return 0f;
        return clan.reserveBonus();
    }
}

# ================= src\main\java\com\example\shinobicore\stat\NinjaPlayerData.java =================
package com.example.shinobicore.stat;

import net.minecraft.nbt.NbtCompound;
import net.minecraft.nbt.NbtList;
import net.minecraft.nbt.NbtString;

import java.util.EnumMap;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class NinjaPlayerData {
    public static final int MAX_LEVEL = 100;

    private float currentChakra = 100f;
    private int reserveLevel = 1;
    private int reserveXp = 0;
    private float fatigue = 0f;
    private boolean exhausted = false;
    private boolean meditating = false;
    private final EnumMap<StatType, Integer> statLevels = new EnumMap<>(StatType.class);
    private final EnumMap<StatType, Integer> statXp = new EnumMap<>(StatType.class);
    private final EnumMap<ElementType, Integer> natureLevels = new EnumMap<>(ElementType.class);
    private final EnumMap<ElementType, Integer> natureXp = new EnumMap<>(ElementType.class);
    private final EnumMap<ElementType, Boolean> natureUnlocked = new EnumMap<>(ElementType.class);
    private ElementType affinity = null;
    // === РАСЕНГАН: состояние зарядки ===
    private boolean rasenganCharging = false;
    private int rasenganChargeTicks = 0;
    private int rasenganChargeTarget = 300; // 15 сек по умолчанию
    private boolean rasenganReady = false;
    private String clanId = "none";
    private boolean clanChosen = false;

    private final Map<String, Integer> appliedClanStatBonuses = new HashMap<>();
    private final Map<String, Integer> appliedClanNatureBonuses = new HashMap<>();

    private int skillPoints = 0;
    private int hpLevel = 0;
    private int speedLevel = 0;
    private int jumpLevel = 0;
    private boolean chakraMode = false;
    private boolean sensoryEnabled = true;

    // === НОВОЕ: серверное состояние тай-дзюцу ===
    private int serverComboStep = 0;
    private long lastAttackTimeMs = 0;
    private String currentStyleId = "standard";
    private int katanaComboStep = 0;
    private long katanaLastAttackMs = 0;
    private String katanaStanceId = "aggressive";
    private long katanaDeflectUntil = 0;
    private boolean katanaDeflectHeld = false;
    private long lastDeflectReflectMs = 0;

    private final String[] loadoutA = new String[5];
    private final String[] loadoutB = new String[5];
    private int activeSlotA = 0;
    private int activeSlotB = 0;
    private final Set<String> learnedJutsus = new HashSet<>();
    private final Map<String, Integer> jutsuUsage = new HashMap<>();

    private final Map<String, Integer> xpBudget = new HashMap<>();
    private long xpWindowStart = System.currentTimeMillis();

    private boolean statsDirty = true;
    private boolean wasOnGround = true;
    private final Set<String> unlockedNodes = new HashSet<>();

    public NinjaPlayerData() {
        for (StatType s : StatType.values()) { statLevels.put(s, 0); statXp.put(s, 0); }
        for (ElementType e : ElementType.values()) { natureLevels.put(e, 0); natureXp.put(e, 0); natureUnlocked.put(e, false); }
    }

    // === Геттеры ===
    public float getCurrentChakra() { return currentChakra; }
    public int getReserveLevel() { return reserveLevel; }
    public int getReserveXp() { return reserveXp; }
    public float getFatigue() { return fatigue; }
    public boolean isExhausted() { return exhausted; }
    public boolean isMeditating() { return meditating; }
    public String getClanId() { return clanId; }
    public ElementType getAffinity() { return affinity; }
    public boolean isClanChosen() { return clanChosen; }
    public int getSkillPoints() { return skillPoints; }
    public int getHpLevel() { return hpLevel; }
    public int getSpeedLevel() { return speedLevel; }
    public int getJumpLevel() { return jumpLevel; }
    public boolean isChakraMode() { return chakraMode; }
    public boolean isSensoryEnabled() { return sensoryEnabled; }
    public void setSensoryEnabled(boolean v) { this.sensoryEnabled = v; statsDirty = true; }
        // === РАСЕНГАН: геттеры/сеттеры ===
    public boolean isRasenganCharging() { return rasenganCharging; }
    public void setRasenganCharging(boolean v) { this.rasenganCharging = v; }
    public int getRasenganChargeTicks() { return rasenganChargeTicks; }
    public void setRasenganChargeTicks(int v) { this.rasenganChargeTicks = v; }
    public int getRasenganChargeTarget() { return rasenganChargeTarget; }
    public void setRasenganChargeTarget(int v) { this.rasenganChargeTarget = v; }
    public boolean isRasenganReady() { return rasenganReady; }
    public void setRasenganReady(boolean v) { this.rasenganReady = v; }

    public float getRasenganChargeProgress() {
        if (rasenganChargeTarget <= 0) return 1.0f;
        return Math.min(1.0f, (float) rasenganChargeTicks / rasenganChargeTarget);
    }
    public boolean wasOnGround() { return wasOnGround; }
    public Set<String> getLearnedJutsus() { return learnedJutsus; }
    public int getStatLevel(StatType s) { return statLevels.getOrDefault(s, 0); }
    public int getStatXp(StatType s) { return statXp.getOrDefault(s, 0); }
    public int getNatureLevel(ElementType e) { return natureLevels.getOrDefault(e, 0); }
    public int getNatureXp(ElementType e) { return natureXp.getOrDefault(e, 0); }
    public boolean isNatureUnlocked(ElementType e) { return natureUnlocked.getOrDefault(e, false); }
    public int getJutsuUsage(String id) { return jutsuUsage.getOrDefault(id, 0); }
    public String getLoadoutSlot(int set, int i) { return (set == 0 ? loadoutA : loadoutB)[i]; }
    public int getActiveSlot(int set) { return set == 0 ? activeSlotA : activeSlotB; }

    // === НОВОЕ: геттеры для тай-дзюцу ===
    public int getServerComboStep() { return serverComboStep; }
    public long getLastAttackTimeMs() { return lastAttackTimeMs; }
    public String getCurrentStyleId() { return currentStyleId; }
    public Set<String> getUnlockedNodes() { return unlockedNodes; }
    public boolean isNodeUnlocked(String nodeId) { return unlockedNodes.contains(nodeId); }
    public void unlockNode(String nodeId) { unlockedNodes.add(nodeId); statsDirty = true; }

    // === Сеттеры ===
    public void setCurrentChakra(float v) { this.currentChakra = Math.max(0, Math.min(v, NinjaFormula.maxChakra(this))); }
    public void setReserveLevel(int v) { reserveLevel = Math.max(1, Math.min(v, MAX_LEVEL)); statsDirty = true; }
    public void setReserveXp(int v) { reserveXp = Math.max(0, v); statsDirty = true; }
    public void setFatigue(float v) { this.fatigue = Math.max(0, Math.min(v, 100f)); this.exhausted = this.fatigue >= 100f; }
    public void setMeditating(boolean v) { this.meditating = v; }

    public void setClanId(String id) {
        String newId = id != null ? id : "none";
        String oldId = this.clanId;
        if (oldId != null && !oldId.equals("none")) {
            removeClanBonuses();
        }
        this.clanId = newId;
        if (!newId.equals("none")) {
            applyClanBonuses(newId);
        }
        statsDirty = true;
    }

    public void setAffinity(ElementType e) { this.affinity = e; statsDirty = true; }
    public void setClanChosen(boolean v) { this.clanChosen = v; }
    public void addSkillPoints(int n) { this.skillPoints = Math.max(0, this.skillPoints + n); statsDirty = true; }
    public void setHpLevel(int v) { hpLevel = Math.max(0, Math.min(v, 7)); statsDirty = true; }
    public void setSpeedLevel(int v) { speedLevel = Math.max(0, Math.min(v, 7)); statsDirty = true; }
    public void setJumpLevel(int v) { jumpLevel = Math.max(0, Math.min(v, 7)); statsDirty = true; }
    public void setChakraMode(boolean v) { this.chakraMode = v; }
    public void setWasOnGround(boolean v) { this.wasOnGround = v; }
    public void setStatLevel(StatType s, int v) { statLevels.put(s, Math.max(0, Math.min(v, MAX_LEVEL))); statsDirty = true; }
    public void setStatXp(StatType s, int v) { statXp.put(s, Math.max(0, v)); statsDirty = true; }
    public void setNatureLevel(ElementType e, int v) { natureLevels.put(e, Math.max(0, Math.min(v, MAX_LEVEL))); statsDirty = true; }
    public void setNatureXp(ElementType e, int v) { natureXp.put(e, Math.max(0, v)); statsDirty = true; }
    public void setNatureUnlocked(ElementType e, boolean v) { natureUnlocked.put(e, v); statsDirty = true; }
    public void addJutsuUsage(String id, int n) { jutsuUsage.put(id, getJutsuUsage(id) + n); statsDirty = true; }
    public void learnJutsu(String id) { learnedJutsus.add(id); statsDirty = true; }
    public void setLoadoutSlot(int set, int i, String id) { (set == 0 ? loadoutA : loadoutB)[i] = id; }
    public void setActiveSlot(int set, int s) { if (set == 0) activeSlotA = Math.max(0, Math.min(4, s)); else activeSlotB = Math.max(0, Math.min(4, s)); }
    public boolean consumeStatsDirty() { boolean d = statsDirty; statsDirty = false; return d; }

    // === НОВОЕ: сеттеры для тай-дзюцу ===
    public void setServerComboStep(int step) { this.serverComboStep = step; }
    public void advanceComboStep() {
        this.serverComboStep = (this.serverComboStep + 1) % com.example.shinobicore.combat.TaijutsuCombo.MAX_STEPS;
    }
    public void resetCombo() { this.serverComboStep = 0; }
    public void setLastAttackTimeMs(long time) { this.lastAttackTimeMs = time; }
    public void setCurrentStyleId(String id) { this.currentStyleId = id != null ? id : "standard"; }
    public int getKatanaComboStep() { return katanaComboStep; }
    public void setKatanaComboStep(int v) { this.katanaComboStep = v; }
    public long getKatanaLastAttackMs() { return katanaLastAttackMs; }
    public void setKatanaLastAttackMs(long v) { this.katanaLastAttackMs = v; }
    public String getKatanaStanceId() { return katanaStanceId; }
    public void setKatanaStanceId(String v) { this.katanaStanceId = v != null ? v : "aggressive"; }
    public long getKatanaDeflectUntil() { return katanaDeflectUntil; }
    public void setKatanaDeflectUntil(long v) { this.katanaDeflectUntil = v; }
    public boolean isKatanaDeflectHeld() { return katanaDeflectHeld; }
    public void setKatanaDeflectHeld(boolean v) { this.katanaDeflectHeld = v; }
    public long getLastDeflectReflectMs() { return lastDeflectReflectMs; }
    public void setLastDeflectReflectMs(long v) { this.lastDeflectReflectMs = v; }

    // === Бонусы клана ===
    private void applyClanBonuses(String clanId) {
        com.example.shinobicore.clan.ClanDefinition clan = com.example.shinobicore.clan.ClanRegistry.get(clanId);
        if (clan == null) return;

        for (Map.Entry<String, Integer> entry : clan.statBonuses().entrySet()) {
            String key = entry.getKey();
            int bonus = entry.getValue();
            for (StatType s : StatType.values()) {
                if (s.getId().equals(key)) {
                    int current = statLevels.getOrDefault(s, 0);
                    statLevels.put(s, current + bonus);
                    appliedClanStatBonuses.put(key, bonus);
                    break;
                }
            }
        }

        for (Map.Entry<String, Integer> entry : clan.natureBonuses().entrySet()) {
            String key = entry.getKey();
            int bonus = entry.getValue();
            for (ElementType e : ElementType.values()) {
                if (e.getId().equals(key)) {
                    int current = natureLevels.getOrDefault(e, 0);
                    natureLevels.put(e, current + bonus);
                    natureUnlocked.put(e, true);
                    appliedClanNatureBonuses.put(key, bonus);
                    break;
                }
            }
        }
    }

    private void removeClanBonuses() {
        for (Map.Entry<String, Integer> entry : appliedClanStatBonuses.entrySet()) {
            String key = entry.getKey();
            int bonus = entry.getValue();
            for (StatType s : StatType.values()) {
                if (s.getId().equals(key)) {
                    int current = statLevels.getOrDefault(s, 0);
                    statLevels.put(s, Math.max(0, current - bonus));
                    break;
                }
            }
        }
        for (Map.Entry<String, Integer> entry : appliedClanNatureBonuses.entrySet()) {
            String key = entry.getKey();
            int bonus = entry.getValue();
            for (ElementType e : ElementType.values()) {
                if (e.getId().equals(key)) {
                    int current = natureLevels.getOrDefault(e, 0);
                    natureLevels.put(e, Math.max(0, current - bonus));
                    break;
                }
            }
        }
        appliedClanStatBonuses.clear();
        appliedClanNatureBonuses.clear();
    }

    // === Анти-абуз ===
    public boolean tryConsumeXpBudget(String key, int amount, int cap) {
        long now = System.currentTimeMillis();
        if (now - xpWindowStart > 60_000L) { xpBudget.clear(); xpWindowStart = now; }
        int used = xpBudget.getOrDefault(key, 0);
        if (used + amount > cap) return false;
        xpBudget.put(key, used + amount);
        return true;
    }

    // === NBT ===
    public NbtCompound writeNbt() {
        NbtCompound nbt = new NbtCompound();
        nbt.putFloat("Chakra", currentChakra);
        nbt.putInt("ReserveLevel", reserveLevel);
        nbt.putInt("ReserveXp", reserveXp);
        nbt.putFloat("Fatigue", fatigue);
        nbt.putBoolean("Exhausted", exhausted);
        nbt.putBoolean("Meditating", meditating);
        nbt.putString("Clan", clanId);
        nbt.putBoolean("ClanChosen", clanChosen);
        nbt.putInt("SkillPoints", skillPoints);
        nbt.putInt("HpLevel", hpLevel);
        nbt.putInt("SpeedLevel", speedLevel);
        nbt.putInt("JumpLevel", jumpLevel);
        nbt.putBoolean("ChakraMode", chakraMode);
        nbt.putBoolean("SensoryEnabled", sensoryEnabled);
        nbt.putBoolean("RasenganCharging", rasenganCharging);
        nbt.putInt("RasenganChargeTicks", rasenganChargeTicks);
        nbt.putInt("RasenganChargeTarget", rasenganChargeTarget);
        nbt.putBoolean("RasenganReady", rasenganReady);
        // === НОВОЕ: сохраняем стиль ===
        nbt.putString("Style", currentStyleId);
        nbt.putString("KatanaStance", katanaStanceId);
        
        if (affinity != null) nbt.putString("Affinity", affinity.getId());
        NbtCompound stats = new NbtCompound();
        for (StatType s : StatType.values()) {
            NbtCompound c = new NbtCompound();
            c.putInt("Level", statLevels.get(s)); c.putInt("Xp", statXp.get(s));
            stats.put(s.getId(), c);
        }
        nbt.put("Stats", stats);
        NbtCompound natures = new NbtCompound();
        for (ElementType e : ElementType.values()) {
            NbtCompound c = new NbtCompound();
            c.putInt("Level", natureLevels.get(e)); c.putInt("Xp", natureXp.get(e)); c.putBoolean("Unlocked", natureUnlocked.get(e));
            natures.put(e.getId(), c);
        }
        nbt.put("Natures", natures);
        NbtList learned = new NbtList();
        for (String id : learnedJutsus) learned.add(NbtString.of(id));
        nbt.put("LearnedJutsus", learned);
        NbtCompound usage = new NbtCompound();
        for (Map.Entry<String, Integer> en : jutsuUsage.entrySet()) usage.putInt(en.getKey(), en.getValue());
        nbt.put("JutsuUsage", usage);
        nbt.put("LoadoutA", writeLoadout(loadoutA));
        nbt.put("LoadoutB", writeLoadout(loadoutB));
        nbt.putInt("ActiveSlotA", activeSlotA);
        nbt.putInt("ActiveSlotB", activeSlotB);
        NbtCompound csb = new NbtCompound();
        for (Map.Entry<String, Integer> en : appliedClanStatBonuses.entrySet()) csb.putInt(en.getKey(), en.getValue());
        nbt.put("ClanStatBonuses", csb);
        NbtCompound cnb = new NbtCompound();
        for (Map.Entry<String, Integer> en : appliedClanNatureBonuses.entrySet()) cnb.putInt(en.getKey(), en.getValue());
        nbt.put("ClanNatureBonuses", cnb);
        NbtList nodes = new NbtList();
        for (String nodeId : unlockedNodes) nodes.add(NbtString.of(nodeId));
        nbt.put("UnlockedNodes", nodes);
        return nbt;
    }

    private NbtList writeLoadout(String[] arr) {
        NbtList list = new NbtList();
        for (String s : arr) list.add(NbtString.of(s == null ? "" : s));
        return list;
    }

    private void readLoadout(NbtList list, String[] arr) {
        for (int i = 0; i < 5 && i < list.size(); i++) {
            String s = list.getString(i);
            arr[i] = s.isEmpty() ? null : s;
        }
    }

    public void readNbt(NbtCompound nbt) {
        if (nbt == null) return;
        currentChakra = nbt.getFloat("Chakra");
        reserveLevel = Math.max(1, nbt.getInt("ReserveLevel"));
        reserveXp = nbt.getInt("ReserveXp");
        fatigue = nbt.getFloat("Fatigue");
        exhausted = nbt.getBoolean("Exhausted");
        meditating = nbt.getBoolean("Meditating");

        String clanIdRead = nbt.getString("Clan");
        this.clanId = clanIdRead.isEmpty() ? "none" : clanIdRead;

        clanChosen = nbt.getBoolean("ClanChosen");
        skillPoints = nbt.getInt("SkillPoints");
        hpLevel = nbt.getInt("HpLevel");
        speedLevel = nbt.getInt("SpeedLevel");
        jumpLevel = nbt.getInt("JumpLevel");
        chakraMode = nbt.getBoolean("ChakraMode");
        sensoryEnabled = !nbt.contains("SensoryEnabled") || nbt.getBoolean("SensoryEnabled");
        rasenganCharging = nbt.getBoolean("RasenganCharging");
        rasenganChargeTicks = nbt.getInt("RasenganChargeTicks");
        rasenganChargeTarget = nbt.getInt("RasenganChargeTarget");
        rasenganReady = nbt.getBoolean("RasenganReady");
        // === НОВОЕ: читаем стиль ===
        if (nbt.contains("Style")) {
            currentStyleId = nbt.getString("Style");
        }
        
        if (nbt.contains("KatanaStance")) katanaStanceId = nbt.getString("KatanaStance");
        if (nbt.contains("Affinity")) {
            String a = nbt.getString("Affinity");
            for (ElementType e : ElementType.values()) if (e.getId().equals(a)) { affinity = e; break; }
        }
        if (nbt.contains("Stats")) {
            NbtCompound stats = nbt.getCompound("Stats");
            for (StatType s : StatType.values()) if (stats.contains(s.getId())) {
                NbtCompound c = stats.getCompound(s.getId());
                statLevels.put(s, c.getInt("Level")); statXp.put(s, c.getInt("Xp"));
            }
        }
        if (nbt.contains("Natures")) {
            NbtCompound nat = nbt.getCompound("Natures");
            for (ElementType e : ElementType.values()) if (nat.contains(e.getId())) {
                NbtCompound c = nat.getCompound(e.getId());
                natureLevels.put(e, c.getInt("Level")); natureXp.put(e, c.getInt("Xp")); natureUnlocked.put(e, c.getBoolean("Unlocked"));
            }
        }
        if (nbt.contains("LearnedJutsus")) {
            NbtList list = nbt.getList("LearnedJutsus", 8);
            for (int i = 0; i < list.size(); i++) learnedJutsus.add(list.getString(i));
        }
        if (nbt.contains("JutsuUsage")) {
            NbtCompound u = nbt.getCompound("JutsuUsage");
            for (String k : u.getKeys()) jutsuUsage.put(k, u.getInt(k));
        }
        if (nbt.contains("LoadoutA")) readLoadout(nbt.getList("LoadoutA", 8), loadoutA);
        else if (nbt.contains("Loadout")) readLoadout(nbt.getList("Loadout", 8), loadoutA);
        if (nbt.contains("LoadoutB")) readLoadout(nbt.getList("LoadoutB", 8), loadoutB);
        activeSlotA = nbt.getInt("ActiveSlotA");
        activeSlotB = nbt.getInt("ActiveSlotB");
        if (nbt.contains("UnlockedNodes")) {
            NbtList nodeList = nbt.getList("UnlockedNodes", 8);
            for (int i = 0; i < nodeList.size(); i++) unlockedNodes.add(nodeList.getString(i));
        }

        appliedClanStatBonuses.clear();
        if (nbt.contains("ClanStatBonuses")) {
            NbtCompound csb = nbt.getCompound("ClanStatBonuses");
            for (String k : csb.getKeys()) appliedClanStatBonuses.put(k, csb.getInt(k));
        }
        appliedClanNatureBonuses.clear();
        if (nbt.contains("ClanNatureBonuses")) {
            NbtCompound cnb = nbt.getCompound("ClanNatureBonuses");
            for (String k : cnb.getKeys()) appliedClanNatureBonuses.put(k, cnb.getInt(k));
        }
    }
}

# ================= src\main\java\com\example\shinobicore\stat\StatType.java =================
package com.example.shinobicore.stat;

public enum StatType {
    CONTROL("control"),
    NINJUTSU("ninjutsu"),
    TAIJUTSU("taijutsu"),
    GENJUTSU("genjutsu"),
    MEDICAL("medical"),
    SPACE_TIME("space_time"),
    PERCEPTION("perception");

    private final String id;

    StatType(String id) {
        this.id = id;
    }

    public String getId() {
        return id;
    }
}

# ================= src\main\java\com\example\shinobicore\tree\SkillTreeNode.java =================
package com.example.shinobicore.tree;
import java.util.List;
public record SkillTreeNode(
    String id, String branch, int distance, float angleOffset,
    String type, String jutsuId, String effect, float value,
    int spCost, List<String> requires,
    String icon, String displayName, String description,
    String clanRequired,
    String visType, String visKey, int visValue
) {
    public boolean hasVisibilityCondition() { return visType != null && !visType.isEmpty(); }
    public boolean hasClanRestriction() { return clanRequired != null && !clanRequired.isEmpty(); }
}

# ================= src\main\java\com\example\shinobicore\tree\SkillTreeRegistry.java =================
package com.example.shinobicore.tree;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.stat.StatType;
import com.google.gson.*;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.*;
public class SkillTreeRegistry {
    private static final Map<String, SkillTreeNode> NODES = new LinkedHashMap<>();
    private static final Map<String, BranchDef> BRANCHES = new LinkedHashMap<>();

    public record BranchDef(String id, float angle, int color, String label, String clan, boolean hidden) {}

    public static void reload(ResourceManager manager) {
        NODES.clear(); BRANCHES.clear();
        Identifier fileId = new Identifier(ShinobiCore.MOD_ID, "skill_tree/tree.json");
        try {
            Resource resource = manager.getResource(fileId).orElse(null);
            if (resource == null) return;
            try (InputStream stream = resource.getInputStream()) {
                JsonObject root = JsonParser.parseReader(
                    new InputStreamReader(stream, StandardCharsets.UTF_8)).getAsJsonObject();
                if (root.has("branches")) {
                    for (var e : root.getAsJsonObject("branches").entrySet()) {
                        JsonObject b = e.getValue().getAsJsonObject();
                        float angle = b.has("angle") ? b.get("angle").getAsFloat() : 0;
                        int color = parseColor(b.has("color") ? b.get("color").getAsString() : "#FFFFFF");
                        String label = b.has("label") ? b.get("label").getAsString() : e.getKey();
                        String clan = b.has("clan") ? b.get("clan").getAsString() : null;
                        boolean hidden = b.has("hidden") && b.get("hidden").getAsBoolean();
                        BRANCHES.put(e.getKey(), new BranchDef(e.getKey(), angle, color, label, clan, hidden));
                    }
                }
                if (root.has("nodes")) {
                    for (JsonElement el : root.getAsJsonArray("nodes")) {
                        JsonObject n = el.getAsJsonObject();
                        String id = n.get("id").getAsString();
                        String branch = n.has("branch") ? n.get("branch").getAsString() : "general";
                        int dist = n.has("distance") ? n.get("distance").getAsInt() : 1;
                        float aOff = n.has("angleOffset") ? n.get("angleOffset").getAsFloat() : 0;
                        String type = n.has("type") ? n.get("type").getAsString() : "jutsu";
                        String jutsuId = n.has("jutsuId") ? n.get("jutsuId").getAsString() : null;
                        String effect = n.has("effect") ? n.get("effect").getAsString() : null;
                        float value = n.has("value") ? n.get("value").getAsFloat() : 0;
                        int spCost = n.has("spCost") ? n.get("spCost").getAsInt() : 1;
                        List<String> req = new ArrayList<>();
                        if (n.has("requires")) for (var r : n.getAsJsonArray("requires")) req.add(r.getAsString());
                        String icon = n.has("icon") ? n.get("icon").getAsString() : "?";
                        String name = n.has("name") ? n.get("name").getAsString() : id;
                        String desc = n.has("description") ? n.get("description").getAsString() : "";
                        String clanReq = n.has("clanRequired") ? n.get("clanRequired").getAsString() : null;
                        String vType = null, vKey = null; int vVal = 0;
                        if (n.has("visibilityCondition")) {
                            JsonObject vc = n.getAsJsonObject("visibilityCondition");
                            vType = vc.has("type") ? vc.get("type").getAsString() : null;
                            vKey = vc.has("key") ? vc.get("key").getAsString() : null;
                            vVal = vc.has("value") ? vc.get("value").getAsInt() : 0;
                        }
                        NODES.put(id, new SkillTreeNode(id, branch, dist, aOff, type, jutsuId,
                            effect, value, spCost, req, icon, name, desc, clanReq, vType, vKey, vVal));
                    }
                }
            }
        } catch (Exception e) { ShinobiCore.LOGGER.error("Skill tree load error: {}", e.getMessage()); }
        ShinobiCore.LOGGER.info("Loaded {} tree nodes, {} branches", NODES.size(), BRANCHES.size());
    }

    private static int parseColor(String hex) {
        try { return (int) Long.parseLong(hex.replace("#",""), 16) | 0xFF000000; } catch (Exception e) { return 0xFFFFFFFF; }
    }

    public static SkillTreeNode get(String id) { return NODES.get(id); }
    public static Collection<SkillTreeNode> getAll() { return NODES.values(); }
    public static BranchDef getBranch(String id) { return BRANCHES.get(id); }
    public static Collection<BranchDef> getAllBranches() { return BRANCHES.values(); }

    public static boolean isVisibleClient(SkillTreeNode node) {
        BranchDef branch = BRANCHES.get(node.branch());
        if (branch != null && branch.clan() != null) {
            if (!branch.clan().equals(ClientNinjaState.clanId)) return false;
        }
        if (node.hasClanRestriction()) {
            if (!node.clanRequired().equals(ClientNinjaState.clanId)) return false;
        }
        if (branch != null && branch.hidden()) {
            if (!checkVisibilityClient(node)) return false;
        }
        if (node.hasVisibilityCondition()) {
            if (!checkVisibilityClient(node)) return false;
        }
        return true;
    }

    public static boolean isVisibleServer(SkillTreeNode node, NinjaPlayerData data) {
        BranchDef branch = BRANCHES.get(node.branch());
        if (branch != null && branch.clan() != null) {
            if (!branch.clan().equals(data.getClanId())) return false;
        }
        if (node.hasClanRestriction()) {
            if (!node.clanRequired().equals(data.getClanId())) return false;
        }
        if ((branch != null && branch.hidden()) || node.hasVisibilityCondition()) {
            return checkVisibilityServer(node, data);
        }
        return true;
    }

    private static boolean checkVisibilityClient(SkillTreeNode node) {
        if (node.visType() == null) return true;
        return switch (node.visType()) {
            case "stat_level" -> {
                Integer lvl = ClientNinjaState.statLevels.get(node.visKey());
                yield lvl != null && lvl >= node.visValue();
            }
            case "nature_level" -> {
                Integer lvl = ClientNinjaState.natureLevels.get(node.visKey());
                yield lvl != null && lvl >= node.visValue();
            }
            case "nature_unlocked" -> {
                Boolean u = ClientNinjaState.natureUnlocked.get(node.visKey());
                yield u != null && u;
            }
            case "node_unlocked" -> ClientNinjaState.unlockedNodes.contains(node.visKey());
            case "clan" -> node.visKey().equals(ClientNinjaState.clanId);
            case "reserve_level" -> ClientNinjaState.reserveLevel >= node.visValue();
            case "two_natures_50" -> {
                int cnt = 0;
                for (Integer lvl : ClientNinjaState.natureLevels.values()) if (lvl >= node.visValue()) cnt++;
                yield cnt >= 2;
            }
            default -> true;
        };
    }

    private static boolean checkVisibilityServer(SkillTreeNode node, NinjaPlayerData data) {
        if (node.visType() == null) return true;
        return switch (node.visType()) {
            case "stat_level" -> {
                StatType s = statById(node.visKey());
                yield s != null && data.getStatLevel(s) >= node.visValue();
            }
            case "nature_level" -> {
                ElementType e = elementById(node.visKey());
                yield e != null && data.getNatureLevel(e) >= node.visValue();
            }
            case "nature_unlocked" -> {
                ElementType e = elementById(node.visKey());
                yield e != null && data.isNatureUnlocked(e);
            }
            case "node_unlocked" -> data.isNodeUnlocked(node.visKey());
            case "clan" -> node.visKey().equals(data.getClanId());
            case "reserve_level" -> data.getReserveLevel() >= node.visValue();
            case "two_natures_50" -> {
                int cnt = 0;
                for (ElementType e2 : ElementType.values()) if (data.getNatureLevel(e2) >= node.visValue()) cnt++;
                yield cnt >= 2;
            }
            default -> true;
        };
    }

    private static StatType statById(String id) {
        for (StatType s : StatType.values()) if (s.getId().equals(id)) return s;
        return null;
    }
    private static ElementType elementById(String id) {
        for (ElementType e : ElementType.values()) if (e.getId().equals(id)) return e;
        return null;
    }
}

# ================= src\main\java\com\example\shinobicore\tree\TreePassives.java =================
package com.example.shinobicore.tree;

import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.stat.NinjaPlayerData;

public class TreePassives {

    public static class Bonuses {
        public float fatigueReduction = 0f;
        public float affinityXpBonus = 0f;
        public float comboTimeoutBonus = 0f;
        public float autoParryChance = 0f;
        public boolean sensory = false;
        public int sensoryRadius = 0;
        public boolean dangerSense = false;
        public float fireWindSynergy = 0f;
        public float kekkeiFire = 0f;
        public float kekkeiEarth = 0f;
        public float kekkeiLightning = 0f;
        public float kekkeiRegen = 0f;
        public float kekkeiStun = 0f;
    }

    public static Bonuses collectServer(NinjaPlayerData data) {
        Bonuses b = new Bonuses();
        for (String nodeId : data.getUnlockedNodes()) apply(b, nodeId);
        return b;
    }

    public static Bonuses collectClient() {
        Bonuses b = new Bonuses();
        for (String nodeId : ClientNinjaState.unlockedNodes) apply(b, nodeId);
        return b;
    }

    private static void apply(Bonuses b, String node) {
        switch (node) {
            case "gen_iron_will" -> b.fatigueReduction += 0.15f;
            case "gen_leaf_focus" -> b.affinityXpBonus += 0.25f;
            case "tai_combo_plus" -> b.comboTimeoutBonus += 0.5f;
            case "tai_counter" -> b.autoParryChance += 0.15f;
            case "sen_glow" -> { b.sensory = true; b.sensoryRadius = 20; }
            case "sen_danger" -> b.dangerSense = true;
            case "fire_synergy" -> b.fireWindSynergy += 0.15f;
            case "kg_blaze" -> b.kekkeiFire += 0.25f;
            case "kg_crystal" -> b.kekkeiEarth += 0.20f;
            case "kg_wood" -> b.kekkeiRegen += 0.30f;
            case "kg_shadow" -> b.kekkeiStun += 0.5f;
            case "kg_storm" -> b.kekkeiLightning += 0.25f;
            case "kg_lava" -> { b.kekkeiFire += 0.10f; b.kekkeiEarth += 0.10f; }
            default -> {}
        }
    }
}

# ================= src\main\resources\assets\shinobicore\lang\en_us.json =================
{
  "item.shinobicore.shuriken": "Shuriken",
  "item.shinobicore.kunai": "Kunai",
  "item.shinobicore.katana": "Katana",
  "key.shinobicore.skill_tree": "Skill Tree",
  "key.shinobicore.toggle_sensory": "Toggle Sensory",
  "key.shinobicore.switch_stance": "Switch Katana Stance (F)",
  "key.shinobicore.katana_deflect": "Katana Deflect (X)",
  "key.categories.shinobicore": "Shinobi Core",
  "key.categories.shinobicore.combat": "Shinobi Core: Combat"
}

# ================= src\main\resources\assets\shinobicore\models\item\katana.json =================
{ "parent": "item/handheld", "textures": { "layer0": "shinobicore:item/katana" } }

# ================= src\main\resources\assets\shinobicore\models\item\kunai.json =================
{ "parent": "item/generated", "textures": { "layer0": "shinobicore:item/kunai" } }

# ================= src\main\resources\assets\shinobicore\models\item\shuriken.json =================
{ "parent": "item/generated", "textures": { "layer0": "shinobicore:item/shuriken" } }

# ================= src\main\resources\assets\shinobicore\sounds.json =================
{
  "punch_light": {
    "sounds": [
      "minecraft:mob/player/attack/weak1",
      "minecraft:mob/player/attack/weak2",
      "minecraft:mob/player/attack/weak3",
      "minecraft:mob/player/attack/weak4"
    ]
  },
  "punch_heavy": {
    "sounds": [
      "minecraft:mob/player/attack/strong1",
      "minecraft:mob/player/attack/strong2",
      "minecraft:mob/player/attack/strong3",
      "minecraft:mob/player/attack/strong4"
    ]
  },
  "kick": {
    "sounds": [
      "minecraft:mob/player/attack/critical1",
      "minecraft:mob/player/attack/critical2",
      "minecraft:mob/player/attack/critical3"
    ]
  },
  "whoosh": {
    "sounds": [
      "minecraft:mob/player/attack/sweep1",
      "minecraft:mob/player/attack/sweep2",
      "minecraft:mob/player/attack/sweep3",
      "minecraft:mob/player/attack/sweep4",
      "minecraft:mob/player/attack/sweep5",
      "minecraft:mob/player/attack/sweep6",
      "minecraft:mob/player/attack/sweep7"
    ]
  }
}

# ================= src\main\resources\data\shinobicore\clans\hatake.json =================
{
  "id": "hatake",
  "name": "Hatake Clan",
  "affinity": "lightning",
  "extraAffinityCount": 1,
  "statBonuses": {
    "ninjutsu": 5,
    "taijutsu": 3,
    "control": 3
  },
  "natureBonuses": {
    "lightning": 8
  },
  "costMultiplier": {
    "lightning": 0.92
  },
  "fatigueMultiplier": 1.0,
  "reserveBonus": 30,
  "dojutsuHook": null
}

# ================= src\main\resources\data\shinobicore\clans\hyuga.json =================
{
  "id": "hyuga",
  "name": "Hyuga Clan",
  "affinity": "earth",
  "extraAffinityCount": 0,
  "statBonuses": {
    "taijutsu": 5,
    "perception": 5
  },
  "natureBonuses": {
    "earth": 5
  },
  "costMultiplier": {},
  "fatigueMultiplier": 0.95,
  "reserveBonus": 50,
  "dojutsuHook": "byakugan"
}

# ================= src\main\resources\data\shinobicore\clans\nara.json =================
{
  "id": "nara",
  "name": "Nara Clan",
  "affinity": "earth",
  "extraAffinityCount": 0,
  "statBonuses": {
    "control": 8,
    "perception": 5
  },
  "natureBonuses": {
    "earth": 5
  },
  "costMultiplier": {},
  "fatigueMultiplier": 1.1,
  "reserveBonus": 0,
  "dojutsuHook": null
}

# ================= src\main\resources\data\shinobicore\clans\sarutobi.json =================
{
  "id": "sarutobi",
  "name": "Sarutobi Clan",
  "affinity": "fire",
  "extraAffinityCount": 1,
  "statBonuses": {
    "ninjutsu": 5,
    "control": 3,
    "perception": 3
  },
  "natureBonuses": {
    "fire": 8,
    "wind": 5
  },
  "costMultiplier": {
    "fire": 0.95
  },
  "fatigueMultiplier": 1.0,
  "reserveBonus": 50,
  "dojutsuHook": null
}

# ================= src\main\resources\data\shinobicore\clans\uchiha.json =================
{
  "id": "uchiha",
  "name": "Uchiha Clan",
  "affinity": "fire",
  "extraAffinityCount": 0,
  "statBonuses": {
    "genjutsu": 5,
    "perception": 5
  },
  "natureBonuses": {
    "fire": 10
  },
  "costMultiplier": {
    "fire": 0.90
  },
  "fatigueMultiplier": 1.0,
  "reserveBonus": 0,
  "dojutsuHook": "sharingan"
}

# ================= src\main\resources\data\shinobicore\clans\uzumaki.json =================
{
  "id": "uzumaki",
  "name": "Uzumaki Clan",
  "affinity": "water",
  "extraAffinityCount": 0,
  "statBonuses": {
    "control": 5,
    "ninjutsu": 5
  },
  "natureBonuses": {
    "water": 10
  },
  "costMultiplier": {},
  "fatigueMultiplier": 0.85,
  "reserveBonus": 150,
  "dojutsuHook": null
}

# ================= src\main\resources\data\shinobicore\jutsu\earth_release_earth_wall.json =================
{
  "id": "shinobicore:earth_release_earth_wall",
  "name": "Earth Release: Earth Wall",
  "category": "elemental_ninjutsu",
  "nature": "earth",
  "type": "wall",
  "params": {
    "width": 5,
    "height": 3,
    "lifetime": 200,
    "block": "earth"
  },
  "baseCost": 35,
  "baseDamage": 0,
  "strain": 10,
  "requiredUsesForFullProficiency": 60,
  "requirements": {
    "control": 20,
    "nature_earth": 25,
    "ninjutsu": 15
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\earth_release_mud_wave.json =================
{
  "id": "shinobicore:earth_release_mud_wave",
  "name": "Earth Release: Mud Wave",
  "category": "elemental_ninjutsu",
  "nature": "earth",
  "type": "aoe",
  "params": {
    "radius": 5.0,
    "particle": "earth",
    "particleCount": 50,
    "knockback": 0.8,
    "statusEffect": "slowness",
    "statusDuration": 60,
    "statusAmplifier": 2
  },
  "baseCost": 28,
  "baseDamage": 5,
  "strain": 8,
  "requiredUsesForFullProficiency": 45,
  "requirements": {
    "control": 22,
    "nature_earth": 28,
    "ninjutsu": 18
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\fire_release_dragon_flame.json =================
{
  "id": "shinobicore:fire_release_dragon_flame",
  "name": "Fire Release: Dragon Flame Jutsu",
  "category": "elemental_ninjutsu",
  "nature": "fire",
  "type": "projectile",
  "params": {
    "speed": 1.2,
    "radius": 12.0,
    "particle": "flame",
    "lifetime": 90,
    "gravity": false
  },
  "baseCost": 35,
  "baseDamage": 14,
  "strain": 9,
  "requiredUsesForFullProficiency": 55,
  "requirements": {
    "control": 25,
    "nature_fire": 30,
    "ninjutsu": 20
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\fire_release_flame_bullet.json =================
{
  "id": "shinobicore:fire_release_flame_bullet",
  "name": "Fire Release: Flame Bullet",
  "category": "elemental_ninjutsu",
  "nature": "fire",
  "type": "projectile",
  "params": {
    "speed": 3.0,
    "radius": 0.8,
    "particle": "flame",
    "lifetime": 50
  },
  "baseCost": 15,
  "baseDamage": 4,
  "strain": 3,
  "requiredUsesForFullProficiency": 30,
  "requirements": {
    "control": 10,
    "nature_fire": 12,
    "ninjutsu": 5
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\fire_release_great_fireball.json =================
{
  "id": "shinobicore:fire_release_great_fireball",
  "name": "Fire Release: Great Fireball Jutsu",
  "category": "elemental_ninjutsu",
  "nature": "fire",
  "type": "projectile",
  "params": {
    "speed": 1.5,
    "radius": 8.0,
    "particle": "flame",
    "lifetime": 100,
    "gravity": false
  },
  "baseCost": 30,
  "baseDamage": 10,
  "strain": 8,
  "requiredUsesForFullProficiency": 50,
  "requirements": {
    "control": 15,
    "nature_fire": 20,
    "ninjutsu": 10
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\fire_release_phoenix_sage.json =================
{
  "id": "shinobicore:fire_release_phoenix_sage",
  "name": "Fire Release: Phoenix Sage Jutsu",
  "category": "elemental_ninjutsu",
  "nature": "fire",
  "type": "projectile",
  "params": {
    "speed": 2.0,
    "radius": 3.0,
    "particle": "flame",
    "lifetime": 60,
    "count": 5,
    "spread": 12.0
  },
  "baseCost": 25,
  "baseDamage": 5,
  "strain": 6,
  "requiredUsesForFullProficiency": 40,
  "requirements": {
    "control": 20,
    "nature_fire": 25,
    "ninjutsu": 15
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\leaf_whirlwind.json =================
{
  "id": "shinobicore:leaf_whirlwind",
  "name": "Leaf Whirlwind",
  "category": "taijutsu",
  "type": "melee",
  "params": {
    "range": 3.5,
    "fullCircle": true,
    "knockback": 0.8
  },
  "baseCost": 15,
  "baseDamage": 6,
  "strain": 5,
  "requiredUsesForFullProficiency": 35,
  "requirements": {
    "taijutsu": 30,
    "control": 15
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\lightning_release_false_darkness.json =================
{
  "id": "shinobicore:lightning_release_false_darkness",
  "name": "Lightning Release: False Darkness",
  "category": "elemental_ninjutsu",
  "nature": "lightning",
  "type": "aoe",
  "params": {
    "radius": 4.0,
    "particle": "lightning",
    "particleCount": 60,
    "knockback": 0.5,
    "stun": true,
    "stunDuration": 20
  },
  "baseCost": 30,
  "baseDamage": 8,
  "strain": 9,
  "requiredUsesForFullProficiency": 45,
  "requirements": {
    "control": 25,
    "nature_lightning": 30,
    "ninjutsu": 20
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\lightning_release_shock.json =================
{
  "id": "shinobicore:lightning_release_shock",
  "name": "Lightning Release: Shock",
  "category": "elemental_ninjutsu",
  "nature": "lightning",
  "type": "melee",
  "params": {
    "range": 3.0,
    "coneAngle": 120.0,
    "knockback": 0.5,
    "particle": "lightning",
    "particleCount": 30
  },
  "baseCost": 25,
  "baseDamage": 7,
  "strain": 7,
  "requiredUsesForFullProficiency": 45,
  "requirements": {
    "control": 12,
    "nature_lightning": 18,
    "ninjutsu": 10
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\mystical_palm_jutsu.json =================
{
  "id": "shinobicore:mystical_palm_jutsu",
  "name": "Mystical Palm Jutsu",
  "category": "medical",
  "type": "utility",
  "params": {
    "effect": "heal",
    "healAmount": 10.0
  },
  "baseCost": 35,
  "baseDamage": 0,
  "strain": 8,
  "requiredUsesForFullProficiency": 40,
  "requirements": {
    "control": 20,
    "medical": 25
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\poison_extraction.json =================
{
  "id": "shinobicore:poison_extraction",
  "name": "Poison Extraction Jutsu",
  "category": "medical",
  "type": "utility",
  "params": {
    "effect": "clear"
  },
  "baseCost": 20,
  "baseDamage": 0,
  "strain": 5,
  "requiredUsesForFullProficiency": 20,
  "requirements": {
    "control": 15,
    "medical": 20
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\rasengan.json =================
{
  "id": "shinobicore:rasengan",
  "name": "Rasengan",
  "category": "shape_ninjutsu",
  "type": "custom",
  "behaviorClass": "com.example.shinobicore.jutsu.custom.RasenganBehavior",
  "params": {
    "baseChargeTicks": 10,
    "minChargeTicks": 4,
    "dashDistance": 6.0,
    "hitRadius": 2.5,
    "knockback": 3.5,
    "particleCount": 60
  },
  "baseCost": 80,
  "baseDamage": 32,
  "strain": 15,
  "requiredUsesForFullProficiency": 100,
  "requirements": {
    "control": 30,
    "ninjutsu": 30
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\rope_escape_jutsu.json =================
{
  "id": "shinobicore:rope_escape_jutsu",
  "name": "Rope Escape Jutsu",
  "category": "shape_ninjutsu",
  "type": "utility",
  "params": {
    "effect": "clear"
  },
  "baseCost": 10,
  "baseDamage": 0,
  "strain": 2,
  "requiredUsesForFullProficiency": 15,
  "requirements": {
    "control": 8,
    "ninjutsu": 5
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\shunshin_no_jutsu.json =================
{
  "id": "shinobicore:shunshin_no_jutsu",
  "name": "Shunshin no Jutsu",
  "category": "space_time",
  "type": "dash",
  "params": {
    "distance": 10.0,
    "knockback": 0.0,
    "hitRadius": 0.5,
    "particle": "wind",
    "particleCount": 30
  },
  "baseCost": 12,
  "baseDamage": 0,
  "strain": 2,
  "requiredUsesForFullProficiency": 30,
  "requirements": {
    "space_time": 15,
    "control": 15
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\water_release_great_waterfall.json =================
{
  "id": "shinobicore:water_release_great_waterfall",
  "name": "Water Release: Great Waterfall Jutsu",
  "category": "elemental_ninjutsu",
  "nature": "water",
  "type": "dash",
  "params": {
    "distance": 8.0,
    "knockback": 1.5,
    "hitRadius": 3.0,
    "waveWidth": 4.0,
    "particle": "water",
    "particleCount": 80,
    "trailParticle": "water",
    "trailCount": 50,
    "splashOnLand": true,
    "splashRadius": 4.0,
    "splashDamage": 4.0
  },
  "baseCost": 35,
  "baseDamage": 7,
  "strain": 10,
  "requiredUsesForFullProficiency": 55,
  "requirements": {
    "control": 30,
    "nature_water": 35,
    "ninjutsu": 25
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\water_release_raging_waves.json =================
{
  "id": "shinobicore:water_release_raging_waves",
  "name": "Water Release: Raging Waves",
  "category": "elemental_ninjutsu",
  "nature": "water",
  "type": "aoe",
  "params": {
    "radius": 5.0,
    "particle": "water",
    "particleCount": 50,
    "knockback": 1.2
  },
  "baseCost": 20,
  "baseDamage": 0,
  "strain": 5,
  "requiredUsesForFullProficiency": 30,
  "requirements": {
    "control": 18,
    "nature_water": 22,
    "ninjutsu": 12
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\water_release_water_bullet.json =================
{
  "id": "shinobicore:water_release_water_bullet",
  "name": "Water Release: Water Bullet Jutsu",
  "category": "elemental_ninjutsu",
  "nature": "water",
  "type": "projectile",
  "params": {
    "speed": 2.0,
    "radius": 1.5,
    "particle": "water",
    "lifetime": 70,
    "gravity": true
  },
  "baseCost": 25,
  "baseDamage": 5,
  "strain": 6,
  "requiredUsesForFullProficiency": 50,
  "requirements": {
    "control": 15,
    "nature_water": 20,
    "ninjutsu": 10
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\wind_release_gale_palm.json =================
{
  "id": "shinobicore:wind_release_gale_palm",
  "name": "Wind Release: Gale Palm",
  "category": "elemental_ninjutsu",
  "nature": "wind",
  "type": "dash",
  "params": {
    "distance": 6.0,
    "knockback": 0.8,
    "hitRadius": 1.5
  },
  "baseCost": 20,
  "baseDamage": 3,
  "strain": 5,
  "requiredUsesForFullProficiency": 40,
  "requirements": {
    "control": 10,
    "nature_wind": 15,
    "ninjutsu": 8
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\wind_release_great_breakthrough.json =================
{
  "id": "shinobicore:wind_release_great_breakthrough",
  "name": "Wind Release: Great Breakthrough",
  "category": "elemental_ninjutsu",
  "nature": "wind",
  "type": "aoe",
  "params": {
    "radius": 6.0,
    "particle": "wind",
    "particleCount": 40,
    "knockback": 2.0
  },
  "baseCost": 25,
  "baseDamage": 3,
  "strain": 7,
  "requiredUsesForFullProficiency": 40,
  "requirements": {
    "control": 20,
    "nature_wind": 25,
    "ninjutsu": 15
  }
}

# ================= src\main\resources\data\shinobicore\jutsu\wind_release_passing_gale.json =================
{
  "id": "shinobicore:wind_release_passing_gale",
  "name": "Wind Release: Passing Gale",
  "category": "elemental_ninjutsu",
  "nature": "wind",
  "type": "utility",
  "params": {
    "effect": "speed",
    "amplifier": 1,
    "duration": 200,
    "showParticles": false
  },
  "baseCost": 20,
  "baseDamage": 0,
  "strain": 4,
  "requiredUsesForFullProficiency": 25,
  "requirements": {
    "control": 12,
    "nature_wind": 15,
    "ninjutsu": 8
  }
}

# ================= src\main\resources\data\shinobicore\recipes\katana.json =================
{
  "type": "minecraft:crafting_shaped",
  "pattern": ["i", "i", "s"],
  "key": { "i": { "item": "minecraft:iron_ingot" }, "s": { "item": "minecraft:stick" } },
  "result": { "item": "shinobicore:katana", "count": 1 }
}

# ================= src\main\resources\data\shinobicore\recipes\kunai.json =================
{
  "type": "minecraft:crafting_shaped",
  "pattern": ["i", "s"],
  "key": { "i": { "item": "minecraft:iron_ingot" }, "s": { "item": "minecraft:stick" } },
  "result": { "item": "shinobicore:kunai", "count": 2 }
}

# ================= src\main\resources\data\shinobicore\recipes\shuriken.json =================
{
  "type": "minecraft:crafting_shaped",
  "pattern": ["n n", " n ", "n n"],
  "key": { "n": { "item": "minecraft:iron_nugget" } },
  "result": { "item": "shinobicore:shuriken", "count": 4 }
}

# ================= src\main\resources\data\shinobicore\skill_tree\tree.json =================
{
  "branches": {
    "general":   {"angle": 0,   "color": "#AAAAAA", "label": "Ninja Way"},
    "fire":      {"angle": 51,  "color": "#FF6622", "label": "Fire Release"},
    "water":     {"angle": 103, "color": "#4488FF", "label": "Water Release"},
    "wind":      {"angle": 154, "color": "#88DDAA", "label": "Wind Release"},
    "lightning": {"angle": 206, "color": "#FFEE44", "label": "Lightning Release"},
    "earth":     {"angle": 257, "color": "#BB8844", "label": "Earth Release"},
    "taijutsu":  {"angle": 309, "color": "#66FF66", "label": "Taijutsu"},
    "medical":   {"angle": 0,   "color": "#FF88CC", "label": "Medical"},
    "sensory":   {"angle": 0,   "color": "#66DDFF", "label": "Sensory"},
    "space":     {"angle": 0,   "color": "#CC99FF", "label": "Space-Time"},
    "uchiha":    {"angle": 26,  "color": "#FF2222", "label": "Uchiha Secret", "clan": "uchiha"},
    "sarutobi":  {"angle": 77,  "color": "#FFAA44", "label": "Monkey King", "clan": "sarutobi"},
    "uzumaki":   {"angle": 129, "color": "#FF8844", "label": "Uzumaki Seal", "clan": "uzumaki"},
    "hatake":    {"angle": 231, "color": "#EEEEFF", "label": "White Fang", "clan": "hatake"},
    "nara":      {"angle": 283, "color": "#8866AA", "label": "Shadow Arts", "clan": "nara"},
    "hyuga":     {"angle": 334, "color": "#CCCCEE", "label": "Gentle Fist", "clan": "hyuga"},
    "shuriken":  {"angle": 0,   "color": "#BBBBBB", "label": "Shurikenjutsu"},
    "kekkei":    {"angle": 0,   "color": "#FF66CC", "label": "Kekkei Genkai", "hidden": true},
    "forbidden": {"angle": 180, "color": "#AA44FF", "label": "Forbidden Arts", "hidden": true}
  },
  "nodes": [
    {"id":"gen_meditation","branch":"general","distance":1,"type":"passive","effect":"meditation_bonus","value":0.1,"spCost":2,"requires":[],"icon":"*","name":"Inner Peace","description":"+10% meditation regen"},
    {"id":"gen_chakra_eff","branch":"general","distance":2,"type":"passive","effect":"cost_reduction","value":0.05,"spCost":3,"requires":["gen_meditation"],"icon":"*","name":"Chakra Efficiency","description":"-5% jutsu cost"},
    {"id":"gen_iron_will","branch":"general","distance":3,"angleOffset":-12,"type":"passive","effect":"fatigue_reduction","value":0.15,"spCost":4,"requires":["gen_chakra_eff"],"icon":"*","name":"Iron Will","description":"-15% jutsu fatigue"},
    {"id":"gen_leaf_focus","branch":"general","distance":4,"angleOffset":-12,"type":"passive","effect":"affinity_xp","value":0.25,"spCost":5,"requires":["gen_iron_will"],"icon":"*","name":"Leaf Focus","description":"+25% XP for affinity nature"},
    {"id":"gen_body_boost","branch":"general","distance":3,"type":"passive","effect":"hp_bonus","value":4,"spCost":4,"requires":["gen_chakra_eff"],"icon":"*","name":"Body Reinforcement","description":"+4 max HP"},
    {"id":"gen_chakra_surge","branch":"general","distance":4,"type":"passive","effect":"reserve_bonus","value":10,"spCost":5,"requires":["gen_body_boost"],"icon":"*","name":"Chakra Surge","description":"+10 reserve capacity"},
    {"id":"rasengan","branch":"general","distance":5,"type":"jutsu","jutsuId":"shinobicore:rasengan","spCost":15,"requires":["gen_chakra_surge","wind_basic","water_basic"],"icon":"O","name":"Rasengan","description":"Spiraling sphere"},

    {"id":"fire_basic","branch":"fire","distance":1,"type":"jutsu","jutsuId":"shinobicore:fire_release_flame_bullet","spCost":2,"requires":[],"icon":"F","name":"Flame Bullet","description":"Basic fire projectile"},
    {"id":"fire_mid","branch":"fire","distance":2,"type":"jutsu","jutsuId":"shinobicore:fire_release_great_fireball","spCost":4,"requires":["fire_basic"],"icon":"F","name":"Great Fireball","description":"Powerful fire sphere"},
    {"id":"fire_advanced","branch":"fire","distance":3,"type":"jutsu","jutsuId":"shinobicore:fire_release_dragon_flame","spCost":6,"requires":["fire_mid"],"icon":"F","name":"Dragon Flame","description":"Massive fire dragon"},
    {"id":"fire_phoenix","branch":"fire","distance":3,"angleOffset":-12,"type":"jutsu","jutsuId":"shinobicore:fire_release_phoenix_sage","spCost":5,"requires":["fire_mid"],"icon":"F","name":"Phoenix Sage","description":"Scattered fire shots"},
    {"id":"fire_synergy","branch":"fire","distance":4,"type":"passive","effect":"fire_wind_synergy","value":0.15,"spCost":6,"requires":["fire_mid"],"icon":"F","name":"Fire-Wind Synergy","description":"+15% fire damage if Wind unlocked","visibilityCondition":{"type":"nature_unlocked","key":"wind"}},

    {"id":"water_basic","branch":"water","distance":1,"type":"jutsu","jutsuId":"shinobicore:water_release_water_bullet","spCost":2,"requires":[],"icon":"W","name":"Water Bullet","description":"Basic water projectile"},
    {"id":"water_raging","branch":"water","distance":2,"type":"jutsu","jutsuId":"shinobicore:water_release_raging_waves","spCost":4,"requires":["water_basic"],"icon":"W","name":"Raging Waves","description":"AOE water blast"},
    {"id":"water_waterfall","branch":"water","distance":3,"type":"jutsu","jutsuId":"shinobicore:water_release_great_waterfall","spCost":6,"requires":["water_raging"],"icon":"W","name":"Great Waterfall","description":"Water dash attack"},

    {"id":"wind_basic","branch":"wind","distance":1,"type":"jutsu","jutsuId":"shinobicore:wind_release_gale_palm","spCost":2,"requires":[],"icon":"~","name":"Gale Palm","description":"Wind dash"},
    {"id":"wind_breakthrough","branch":"wind","distance":2,"type":"jutsu","jutsuId":"shinobicore:wind_release_great_breakthrough","spCost":4,"requires":["wind_basic"],"icon":"~","name":"Great Breakthrough","description":"AOE wind blast"},
    {"id":"wind_passing","branch":"wind","distance":2,"angleOffset":10,"type":"jutsu","jutsuId":"shinobicore:wind_release_passing_gale","spCost":3,"requires":["wind_basic"],"icon":"~","name":"Passing Gale","description":"Speed buff"},

    {"id":"light_basic","branch":"lightning","distance":1,"type":"jutsu","jutsuId":"shinobicore:lightning_release_shock","spCost":3,"requires":[],"icon":"L","name":"Lightning Shock","description":"Melee lightning"},
    {"id":"light_darkness","branch":"lightning","distance":2,"type":"jutsu","jutsuId":"shinobicore:lightning_release_false_darkness","spCost":5,"requires":["light_basic"],"icon":"L","name":"False Darkness","description":"Lightning beam AOE"},

    {"id":"earth_wall","branch":"earth","distance":1,"type":"jutsu","jutsuId":"shinobicore:earth_release_earth_wall","spCost":3,"requires":[],"icon":"#","name":"Earth Wall","description":"Temporary wall"},
    {"id":"earth_mud","branch":"earth","distance":2,"type":"jutsu","jutsuId":"shinobicore:earth_release_mud_wave","spCost":5,"requires":["earth_wall"],"icon":"#","name":"Mud Wave","description":"AOE slow wave"},

    {"id":"tai_whirlwind","branch":"taijutsu","distance":1,"type":"jutsu","jutsuId":"shinobicore:leaf_whirlwind","spCost":3,"requires":[],"icon":"T","name":"Leaf Whirlwind","description":"360 kick"},
    {"id":"tai_combo_master","branch":"taijutsu","distance":2,"type":"passive","effect":"combo_damage","value":0.15,"spCost":4,"requires":["tai_whirlwind"],"icon":"T","name":"Combo Master","description":"+15% combo damage"},
    {"id":"tai_combo_plus","branch":"taijutsu","distance":3,"type":"passive","effect":"combo_timeout","value":0.5,"spCost":4,"requires":["tai_combo_master"],"icon":"T","name":"Combo Master+","description":"Combo window +50%"},
    {"id":"tai_counter","branch":"taijutsu","distance":4,"type":"passive","effect":"auto_parry","value":0.15,"spCost":6,"requires":["tai_combo_plus"],"icon":"T","name":"Counter Stance","description":"15% chance to auto-parry hits"},

    {"id":"med_palm","branch":"medical","distance":1,"type":"jutsu","jutsuId":"shinobicore:mystical_palm_jutsu","spCost":3,"requires":["gen_meditation"],"icon":"+","name":"Mystical Palm","description":"Heal self"},
    {"id":"med_poison","branch":"medical","distance":2,"type":"jutsu","jutsuId":"shinobicore:poison_extraction","spCost":2,"requires":["med_palm"],"icon":"+","name":"Poison Extraction","description":"Clear debuffs"},

    {"id":"sen_glow","branch":"sensory","distance":1,"type":"passive","effect":"sensory","value":20,"spCost":5,"requires":[],"icon":"?","name":"Sensory Technique","description":"See enemies through walls (20 blocks)","visibilityCondition":{"type":"stat_level","key":"perception","value":20}},
    {"id":"sen_danger","branch":"sensory","distance":2,"type":"passive","effect":"danger_sense","value":1,"spCost":4,"requires":["sen_glow"],"icon":"?","name":"Danger Sense","description":"Warning when an enemy targets you","visibilityCondition":{"type":"stat_level","key":"perception","value":20}},

    {"id":"space_shunshin","branch":"space","distance":1,"type":"jutsu","jutsuId":"shinobicore:shunshin_no_jutsu","spCost":6,"requires":[],"icon":">","name":"Shunshin no Jutsu","description":"High-speed dash technique","visibilityCondition":{"type":"stat_level","key":"space_time","value":15}},

    {"id":"uchi_amaterasu","branch":"uchiha","distance":1,"type":"jutsu","jutsuId":"shinobicore:fire_release_great_fireball","spCost":8,"requires":[],"icon":"@","name":"Amaterasu","description":"Black flames","clanRequired":"uchiha"},
    {"id":"uchi_susano","branch":"uchiha","distance":2,"type":"passive","effect":"damage_reduction","value":0.2,"spCost":10,"requires":["uchi_amaterasu"],"icon":"@","name":"Susano'o","description":"-20% damage taken","clanRequired":"uchiha"},
    {"id":"saru_monkey","branch":"sarutobi","distance":1,"type":"passive","effect":"taijutsu_bonus","value":0.15,"spCost":8,"requires":[],"icon":"M","name":"Monkey King Staff","description":"+15% taijutsu","clanRequired":"sarutobi"},
    {"id":"saru_fire_prof","branch":"sarutobi","distance":2,"type":"passive","effect":"fire_mastery","value":0.2,"spCost":10,"requires":["saru_monkey"],"icon":"M","name":"Fire Professor","description":"+20% fire damage","clanRequired":"sarutobi"},
    {"id":"uzu_chains","branch":"uzumaki","distance":1,"type":"passive","effect":"chakra_regen","value":0.2,"spCost":8,"requires":[],"icon":"S","name":"Adamantine Chains","description":"+20% chakra regen","clanRequired":"uzumaki"},
    {"id":"uzu_seal","branch":"uzumaki","distance":2,"type":"passive","effect":"max_chakra","value":50,"spCost":10,"requires":["uzu_chains"],"icon":"S","name":"Sealing Arts","description":"+50 max chakra","clanRequired":"uzumaki"},
    {"id":"hatake_chidori","branch":"hatake","distance":1,"type":"jutsu","jutsuId":"shinobicore:lightning_release_false_darkness","spCost":8,"requires":[],"icon":">","name":"Chidori","description":"Lightning blade","clanRequired":"hatake"},
    {"id":"hatake_copy","branch":"hatake","distance":2,"type":"passive","effect":"learn_bonus","value":1,"spCost":10,"requires":["hatake_chidori"],"icon":">","name":"Copy Ninja","description":"Learn jutsu faster","clanRequired":"hatake"},
    {"id":"nara_shadow","branch":"nara","distance":1,"type":"passive","effect":"stun_duration","value":0.5,"spCost":8,"requires":[],"icon":"~","name":"Shadow Possession","description":"+50% stun","clanRequired":"nara"},
    {"id":"nara_strangle","branch":"nara","distance":2,"type":"passive","effect":"aoe_range","value":0.3,"spCost":10,"requires":["nara_shadow"],"icon":"~","name":"Shadow Strangle","description":"+30% AOE","clanRequired":"nara"},
    {"id":"hyu_64","branch":"hyuga","distance":1,"type":"passive","effect":"chakra_drain","value":5,"spCost":8,"requires":[],"icon":"O","name":"64 Palms","description":"Drain enemy chakra","clanRequired":"hyuga"},
    {"id":"hyu_128","branch":"hyuga","distance":2,"type":"passive","effect":"chakra_drain","value":10,"spCost":12,"requires":["hyu_64"],"icon":"O","name":"128 Palms","description":"Double drain","clanRequired":"hyuga"},

    {"id":"kg_blaze","branch":"kekkei","distance":1,"type":"passive","effect":"kekkei_fire","value":0.25,"spCost":15,"requires":[],"icon":"@","name":"Blaze Release","description":"+25% fire damage","clanRequired":"uchiha","visibilityCondition":{"type":"two_natures_50","value":50}},
    {"id":"kg_crystal","branch":"kekkei","distance":1,"type":"passive","effect":"kekkei_earth","value":0.2,"spCost":15,"requires":[],"icon":"@","name":"Crystal Release","description":"+20% earth damage","clanRequired":"hyuga","visibilityCondition":{"type":"two_natures_50","value":50}},
    {"id":"kg_wood","branch":"kekkei","distance":1,"type":"passive","effect":"kekkei_regen","value":0.3,"spCost":15,"requires":[],"icon":"@","name":"Wood Release","description":"+30% chakra regen","clanRequired":"uzumaki","visibilityCondition":{"type":"two_natures_50","value":50}},
    {"id":"kg_shadow","branch":"kekkei","distance":1,"type":"passive","effect":"kekkei_stun","value":0.5,"spCost":15,"requires":[],"icon":"@","name":"Shadow Release","description":"+50% stun duration","clanRequired":"nara","visibilityCondition":{"type":"two_natures_50","value":50}},
    {"id":"kg_storm","branch":"kekkei","distance":1,"type":"passive","effect":"kekkei_lightning","value":0.25,"spCost":15,"requires":[],"icon":"@","name":"Storm Release","description":"+25% lightning damage","clanRequired":"hatake","visibilityCondition":{"type":"two_natures_50","value":50}},
    {"id":"kg_lava","branch":"kekkei","distance":1,"type":"passive","effect":"kekkei_lava","value":0.1,"spCost":15,"requires":[],"icon":"@","name":"Lava Release","description":"+10% fire and earth damage","clanRequired":"sarutobi","visibilityCondition":{"type":"two_natures_50","value":50}},

    {"id":"forb_8gates","branch":"forbidden","distance":1,"type":"passive","effect":"8gates_unlock","value":1,"spCost":20,"requires":[],"icon":"!","name":"Eight Gates","description":"Unlock 8 Gates","visibilityCondition":{"type":"stat_level","key":"taijutsu","value":50}},
    {"id":"forb_edo","branch":"forbidden","distance":2,"type":"passive","effect":"edo_tensei","value":1,"spCost":25,"requires":["forb_8gates"],"icon":"!","name":"Edo Tensei","description":"Forbidden resurrection","visibilityCondition":{"type":"stat_level","key":"taijutsu","value":50}},
    {"id":"shuriken_accuracy","branch":"shuriken","distance":1,"type":"passive","effect":"aim_cone","value":5,"spCost":4,"requires":[],"icon":"x","name":"Eagle Eye","description":"+5 deg shuriken aim assist"},
    {"id":"shuriken_mark","branch":"shuriken","distance":2,"type":"passive","effect":"mark_duration","value":5,"spCost":5,"requires":["shuriken_accuracy"],"icon":"x","name":"Cursed Mark","description":"Mark lasts 15s instead of 10s"},
    {"id":"shuriken_double","branch":"shuriken","distance":3,"type":"passive","effect":"double_throw","value":1,"spCost":7,"requires":["shuriken_mark"],"icon":"x","name":"Shadow Shuriken","description":"Throw a second shuriken"}
  ]
}

# ================= src\main\resources\fabric.mod.json =================
{
  "schemaVersion": 1,
  "id": "shinobicore",
  "version": "1.0.0",
  "name": "Shinobi Core",
  "description": "Naruto-themed mod for Minecraft",
  "authors": ["You"],
  "contact": {},
  "license": "MIT",
  "icon": "assets/shinobicore/icon.png",
  "environment": "*",
  "entrypoints": {
    "main": [
      "com.example.shinobicore.ShinobiCore"
    ],
    "client": [
      "com.example.shinobicore.client.ShinobiCoreClient"
    ]
  },
  "mixins": [
    "shinobicore.mixins.json"
  ],
  "depends": {
    "fabricloader": ">=0.14.21",
    "minecraft": "~1.20.1",
    "java": ">=21",
    "fabric-api": "*"
  }
}

# ================= src\main\resources\shinobicore.mixins.json =================
{
  "required": true,
  "package": "com.example.shinobicore.mixin",
  "compatibilityLevel": "JAVA_21",
  "mixins": [
    "ServerPlayerEntityMixin",
    "FallDamageMixin",
    "ChakraWaterTouchMixin",
    "SlideTravelMixin",
    "SlidePoseMixin",
    "RollPoseMixin",
    "ChargedJumpMixin",
    "HideVanillaStatusMixin",
    "PlayerAttackMixin",
    "PlayerRenderAnimationMixin",
    "SlideDimensionsMixin",
    "CameraMixin",
    "KatanaDeflectMixin",
    "PlayerCopyMixin",
    "PlayerParryMixin"
  ],
  "injectors": {
    "defaultRequire": 1
  }
}
