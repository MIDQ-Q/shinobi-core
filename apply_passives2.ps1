$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"
$res = "E:\Games\mod\src\main\resources"
Write-Host "=== PASSIVES v2 (ASCII-safe) ===" -ForegroundColor Cyan

# === [1] TreePassives.java ===
$file = "$src\tree\TreePassives.java"
$code = @'
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
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[1] TreePassives.java" -ForegroundColor Green

# === [2] ControlTrainingScreen.java ===
$file = "$src\client\ControlTrainingScreen.java"
$code = @'
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
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[2] ControlTrainingScreen.java" -ForegroundColor Green

# === [3] PlayerParryMixin.java ===
$file = "$src\mixin\PlayerParryMixin.java"
$code = @'
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
        if (source.isOutOfWorld()) return;
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        TreePassives.Bonuses b = TreePassives.collectServer(data);
        if (b.autoParryChance <= 0) return;
        if (player.getWorld().getRandom().nextFloat() < b.autoParryChance) {
            if (player.getWorld() instanceof ServerWorld sw) {
                sw.spawnParticles(ParticleTypes.CRIT, player.getX(), player.getY() + 1, player.getZ(),
                        12, 0.3, 0.3, 0.3, 0.05);
            }
            player.sendMessage(Text.literal("§ePARRIED!"), false);
            cir.setReturnValue(false);
        }
    }
}
'@
[System.IO.File]::WriteAllText($file, $code, $utf8)
Write-Host "[3] PlayerParryMixin.java" -ForegroundColor Green

# === [4] mixins.json ===
$file = "$res\shinobicore.mixins.json"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("PlayerParryMixin")) {
    $c = $c.Replace('"PlayerCopyMixin"', '"PlayerCopyMixin",
    "PlayerParryMixin"')
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[4] mixins.json updated" -ForegroundColor Green
}

# === [5] shunshin_no_jutsu.json ===
$file = "$res\data\shinobicore\jutsu\shunshin_no_jutsu.json"
$json = @'
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
'@
[System.IO.File]::WriteAllText($file, $json, $utf8)
Write-Host "[5] shunshin_no_jutsu.json" -ForegroundColor Green

# === [6] tree.json ===
$file = "$res\data\shinobicore\skill_tree\tree.json"
$j = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $j.Contains("gen_iron_will")) {
    $marker = '  "forbidden": {"angle": 180,'
    $idx = $j.IndexOf($marker)
    if ($idx -ge 0) {
        $j = $j.Insert($idx, @'
  "sensory":   {"angle": 0, "color": "#66DDFF", "label": "Sensory"},
  "space":     {"angle": 0, "color": "#CC99FF", "label": "Space-Time"},
  "kekkei":    {"angle": 0, "color": "#FF66CC", "label": "Kekkei Genkai", "hidden": true},
'@ + "`r`n")
    }
    $marker = '    {"id":"forb_edo",'
    $idx2 = $j.IndexOf($marker)
    if ($idx2 -ge 0) {
        $endOfLine = $j.IndexOf("`n", $idx2)
        $newNodes = @'

    {"id":"gen_iron_will","branch":"general","distance":3,"angleOffset":-12,"type":"passive","effect":"fatigue_reduction","value":0.15,"spCost":4,"requires":["gen_chakra_eff"],"icon":"*","name":"Iron Will","description":"-15% jutsu fatigue"},
    {"id":"gen_leaf_focus","branch":"general","distance":4,"angleOffset":-12,"type":"passive","effect":"affinity_xp","value":0.25,"spCost":5,"requires":["gen_iron_will"],"icon":"*","name":"Leaf Focus","description":"+25% XP for affinity nature"},
    {"id":"tai_combo_plus","branch":"taijutsu","distance":3,"type":"passive","effect":"combo_timeout","value":0.5,"spCost":4,"requires":["tai_combo_master"],"icon":"T","name":"Combo Master+","description":"Combo window +50%"},
    {"id":"tai_counter","branch":"taijutsu","distance":4,"type":"passive","effect":"auto_parry","value":0.15,"spCost":6,"requires":["tai_combo_plus"],"icon":"T","name":"Counter Stance","description":"15% chance to auto-parry hits"},
    {"id":"sen_glow","branch":"sensory","distance":1,"type":"passive","effect":"sensory","value":20,"spCost":5,"requires":[],"icon":"?","name":"Sensory Technique","description":"See enemies through walls (20 blocks)","visibilityCondition":{"type":"stat_level","key":"perception","value":20}},
    {"id":"sen_danger","branch":"sensory","distance":2,"type":"passive","effect":"danger_sense","value":1,"spCost":4,"requires":["sen_glow"],"icon":"?","name":"Danger Sense","description":"Warning when an enemy targets you","visibilityCondition":{"type":"stat_level","key":"perception","value":20}},
    {"id":"space_shunshin","branch":"space","distance":1,"type":"jutsu","jutsuId":"shinobicore:shunshin_no_jutsu","spCost":6,"requires":[],"icon":">","name":"Shunshin no Jutsu","description":"High-speed dash technique","visibilityCondition":{"type":"stat_level","key":"space_time","value":15}},
    {"id":"fire_synergy","branch":"fire","distance":4,"type":"passive","effect":"fire_wind_synergy","value":0.15,"spCost":6,"requires":["fire_mid"],"icon":"F","name":"Fire-Wind Synergy","description":"+15% fire damage if Wind unlocked","visibilityCondition":{"type":"nature_unlocked","key":"wind"}},
    {"id":"kg_blaze","branch":"kekkei","distance":1,"type":"passive","effect":"kekkei_fire","value":0.25,"spCost":15,"requires":[],"icon":"@","name":"Blaze Release","description":"+25% fire damage","clanRequired":"uchiha","visibilityCondition":{"type":"two_natures_50","value":50}},
    {"id":"kg_crystal","branch":"kekkei","distance":1,"type":"passive","effect":"kekkei_earth","value":0.2,"spCost":15,"requires":[],"icon":"@","name":"Crystal Release","description":"+20% earth damage","clanRequired":"hyuga","visibilityCondition":{"type":"two_natures_50","value":50}},
    {"id":"kg_wood","branch":"kekkei","distance":1,"type":"passive","effect":"kekkei_regen","value":0.3,"spCost":15,"requires":[],"icon":"@","name":"Wood Release","description":"+30% chakra regen","clanRequired":"uzumaki","visibilityCondition":{"type":"two_natures_50","value":50}},
    {"id":"kg_shadow","branch":"kekkei","distance":1,"type":"passive","effect":"kekkei_stun","value":0.5,"spCost":15,"requires":[],"icon":"@","name":"Shadow Release","description":"+50% stun duration","clanRequired":"nara","visibilityCondition":{"type":"two_natures_50","value":50}},
    {"id":"kg_storm","branch":"kekkei","distance":1,"type":"passive","effect":"kekkei_lightning","value":0.25,"spCost":15,"requires":[],"icon":"@","name":"Storm Release","description":"+25% lightning damage","clanRequired":"hatake","visibilityCondition":{"type":"two_natures_50","value":50}},
    {"id":"kg_lava","branch":"kekkei","distance":1,"type":"passive","effect":"kekkei_lava","value":0.1,"spCost":15,"requires":[],"icon":"@","name":"Lava Release","description":"+10% fire and earth damage","clanRequired":"sarutobi","visibilityCondition":{"type":"two_natures_50","value":50}}
'@
        $j = $j.Insert($endOfLine + 1, $newNodes + "`r`n")
    }
    [System.IO.File]::WriteAllText($file, $j, $utf8)
    Write-Host "[6] tree.json: +3 branches, +14 nodes" -ForegroundColor Green
} else {
    Write-Host "[6] tree.json already updated" -ForegroundColor Gray
}

# === [7] SkillTreeScreen BASE_ORDER ===
$file = "$src\client\SkillTreeScreen.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains('"sensory", "space", "kekkei"')) {
    $marker = '"taijutsu", "earth", "water", "general", "medical", "fire", "wind", "lightning"'
    $c = $c.Replace($marker, '"taijutsu", "earth", "water", "general", "medical", "fire", "wind", "lightning",
        "sensory", "space", "kekkei"')
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[7] SkillTreeScreen BASE_ORDER extended" -ForegroundColor Green
}

# === [8] SkillTreeRegistry two_natures_50 ===
$file = "$src\tree\SkillTreeRegistry.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("two_natures_50")) {
    $marker = 'case "reserve_level" -> ClientNinjaState.reserveLevel >= node.visValue();'
    $c = $c.Replace($marker, @'
case "reserve_level" -> ClientNinjaState.reserveLevel >= node.visValue();
            case "two_natures_50" -> {
                int cnt = 0;
                for (Integer lvl : ClientNinjaState.natureLevels.values()) if (lvl >= node.visValue()) cnt++;
                yield cnt >= 2;
            }
'@)
    $marker = 'case "reserve_level" -> data.getReserveLevel() >= node.visValue();'
    $c = $c.Replace($marker, @'
case "reserve_level" -> data.getReserveLevel() >= node.visValue();
            case "two_natures_50" -> {
                int cnt = 0;
                for (ElementType e2 : ElementType.values()) if (data.getNatureLevel(e2) >= node.visValue()) cnt++;
                yield cnt >= 2;
            }
'@)
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[8] SkillTreeRegistry: two_natures_50" -ForegroundColor Green
}

# === [9] ModPackets ===
$file = "$src\network\ModPackets.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("CONTROL_TRAIN_ID")) {
    $marker = 'public static final Identifier UNLOCK_NODE_ID = new Identifier("shinobicore", "unlock_node");'
    $c = $c.Replace($marker, @'
public static final Identifier UNLOCK_NODE_ID = new Identifier("shinobicore", "unlock_node");
    public static final Identifier CONTROL_TRAIN_ID = new Identifier("shinobicore", "control_train");
    public static final Identifier DANGER_SYNC_ID = new Identifier("shinobicore", "danger_sync");
'@)
    $marker = 'ServerPlayNetworking.registerGlobalReceiver(UNLOCK_NODE_ID,'
    $c = $c.Replace($marker, @'
ServerPlayNetworking.registerGlobalReceiver(CONTROL_TRAIN_ID, (server, player, handler, buf, responseSender) -> {
            boolean success = buf.readBoolean();
            float accuracy = buf.readFloat();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                int xp = success ? Math.round(15 + accuracy * 25) : 3;
                NinjaFormula.grantStatXp(data, StatType.CONTROL, xp);
                ShinobiCore.sendStatsSync(player);
                player.sendMessage(Text.literal(success
                    ? String.format("§aControl training: +%d XP (%.0f%%)", xp, accuracy * 100)
                    : "§7Training: +" + xp + " XP"), false);
            });
        });
        ServerPlayNetworking.registerGlobalReceiver(UNLOCK_NODE_ID,
'@)
    $marker = 'long timeoutMs = TaijutsuCombo.COMBO_TIMEOUT_MS;'
    $c = $c.Replace($marker, 'long timeoutMs = (long)(TaijutsuCombo.COMBO_TIMEOUT_MS * (1 + TreePassives.collectServer(data).comboTimeoutBonus));')
    if (-not $c.Contains("import com.example.shinobicore.tree.TreePassives;")) {
        $c = $c.Replace("import com.example.shinobicore.stat.StatType;",
            "import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.tree.TreePassives;")
    }
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[9] ModPackets: control_train + danger_sync + combo bonus" -ForegroundColor Green
}

# === [10] ClientNinjaState dangerSense ===
$file = "$src\client\ClientNinjaState.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("dangerSense")) {
    $c = $c.Replace("public static boolean chakraMode = false;",
        "public static boolean chakraMode = false;
    public static boolean dangerSense = false;")
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[10] ClientNinjaState: dangerSense" -ForegroundColor Green
}

# === [11] ShinobiCoreClient DANGER receiver ===
$file = "$src\client\ShinobiCoreClient.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("DANGER_SYNC_ID")) {
    $marker = 'HudRenderCallback.EVENT.register(ChakraHudRenderer::render);'
    $c = $c.Replace($marker, @'
ClientPlayNetworking.registerGlobalReceiver(ModPackets.DANGER_SYNC_ID, (client, handler, buf, responseSender) -> {
            boolean danger = buf.readBoolean();
            client.execute(() -> ClientNinjaState.dangerSense = danger);
        });

        HudRenderCallback.EVENT.register(ChakraHudRenderer::render);
'@)
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[11] ShinobiCoreClient: DANGER receiver" -ForegroundColor Green
}

# === [12] ChakraHudRenderer danger indicator ===
$file = "$src\client\ChakraHudRenderer.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("dangerSense")) {
    $marker = @'
        if (exhausted) {
            context.drawTextWithShadow(client.textRenderer, Text.literal("EXHAUSTED"), 10, y, 0xFF3333);
            y += 10;
        }
'@
    $insert = @'
        if (exhausted) {
            context.drawTextWithShadow(client.textRenderer, Text.literal("EXHAUSTED"), 10, y, 0xFF3333);
            y += 10;
        }
        if (ClientNinjaState.dangerSense) {
            int alpha = (int) (150 + 105 * Math.sin(System.currentTimeMillis() / 150.0));
            context.drawTextWithShadow(client.textRenderer, Text.literal("!! DANGER !!"), 10, y,
                    ColorHelper.Argb.getArgb(alpha, 255, 60, 60));
            y += 10;
        }
'@
    $c = $c.Replace($marker, $insert)
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[12] ChakraHudRenderer: danger indicator" -ForegroundColor Green
}

# === [13] JutsuCaster passives ===
$file = "$src\jutsu\JutsuCaster.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("TreePassives")) {
    $c = $c.Replace("NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();",
        "NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        TreePassives.Bonuses pbs = TreePassives.collectServer(data);")
    $c = $c.Replace("float strain = def.strain();",
        "float strain = def.strain() * (1f - pbs.fatigueReduction);")
    $marker = @'
                float xpMult = (data.getAffinity() == def.nature())
                    ? ModConfig.instance.combat.affinityXpMultiplier
                    : 1f;
'@
    $insert = @'
                float xpMult = (data.getAffinity() == def.nature())
                    ? ModConfig.instance.combat.affinityXpMultiplier
                    : 1f;
                xpMult += pbs.affinityXpBonus;
'@
    $c = $c.Replace($marker, $insert)
    $marker = 'float damage = def.baseDamage() * NinjaFormula.damageMultiplier(data, def);'
    $insert = @'
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
'@
    $c = $c.Replace($marker, $insert)
    $c = $c.Replace("import com.example.shinobicore.tree.SkillTreeRegistry;",
        "import com.example.shinobicore.tree.SkillTreeRegistry;
import com.example.shinobicore.tree.TreePassives;
import com.example.shinobicore.stat.ElementType;")
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[13] JutsuCaster: passives applied" -ForegroundColor Green
}

# === [14] NinjaFormula kekkei regen ===
$file = "$src\stat\NinjaFormula.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("TreePassives")) {
    $marker = @'
        if (data.isExhausted())
            regen *= cfg().chakra.regenExhaustedMultiplier();
        return regen;
'@
    $insert = @'
        if (data.isExhausted())
            regen *= cfg().chakra.regenExhaustedMultiplier();
        regen *= 1f + TreePassives.collectServer(data).kekkeiRegen;
        return regen;
'@
    $c = $c.Replace($marker, $insert)
    $c = $c.Replace("import com.example.shinobicore.jutsu.JutsuDefinition;",
        "import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.tree.TreePassives;")
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[14] NinjaFormula: kekkei regen" -ForegroundColor Green
}

# === [15] NinjaTickHandler sensory + danger ===
$file = "$src\event\NinjaTickHandler.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("TreePassives")) {
    $marker = 'ShinobiCore.sendChakraSync(player);'
    $insert = @'
TreePassives.Bonuses pbs = TreePassives.collectServer(data);
            if (pbs.sensory) {
                for (net.minecraft.entity.LivingEntity le : player.getWorld().getEntitiesByClass(
                        net.minecraft.entity.LivingEntity.class,
                        player.getBoundingBox().expand(pbs.sensoryRadius),
                        e -> e != player && e.isAlive())) {
                    le.addStatusEffect(new StatusEffectInstance(StatusEffects.GLOWING, 60, 0, false, false));
                }
            }
            if (pbs.dangerSense) {
                boolean danger = !player.getWorld().getEntitiesByClass(
                        net.minecraft.entity.mob.MobEntity.class,
                        player.getBoundingBox().expand(12),
                        m -> m.getTarget() == player).isEmpty();
                PacketByteBuf dbuf = new PacketByteBuf(Unpooled.buffer());
                dbuf.writeBoolean(danger);
                ServerPlayNetworking.send(player, ModPackets.DANGER_SYNC_ID, dbuf);
            }
            ShinobiCore.sendChakraSync(player);
'@
    $c = $c.Replace($marker, $insert)
    $c = $c.Replace("import com.example.shinobicore.stat.StatType;",
        "import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.tree.TreePassives;
import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;")
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[15] NinjaTickHandler: sensory + danger" -ForegroundColor Green
}

# === [16] TaijutsuClientHandler combo bonus ===
$file = "$src\client\combat\TaijutsuClientHandler.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("TreePassives")) {
    $marker = '        if (comboStep > 0 && now - lastAttackTime > TaijutsuCombo.COMBO_TIMEOUT_MS) {'
    $insert = @'
        long cdTimeout = (long)(TaijutsuCombo.COMBO_TIMEOUT_MS * (1 + TreePassives.collectClient().comboTimeoutBonus));
        if (comboStep > 0 && now - lastAttackTime > cdTimeout) {
'@
    $c = $c.Replace($marker, $insert)
    $marker = '        if (now - lastAttackTime > TaijutsuCombo.COMBO_TIMEOUT_MS) {'
    $insert = @'
        long atkTimeout = (long)(TaijutsuCombo.COMBO_TIMEOUT_MS * (1 + TreePassives.collectClient().comboTimeoutBonus));
        if (now - lastAttackTime > atkTimeout) {
'@
    $c = $c.Replace($marker, $insert)
    $c = $c.Replace("import com.example.shinobicore.combat.TaijutsuCombo;",
        "import com.example.shinobicore.combat.TaijutsuCombo;
import com.example.shinobicore.tree.TreePassives;")
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[16] TaijutsuClientHandler: combo bonus" -ForegroundColor Green
}

# === [17] ProgressionScreen [Train] ===
$file = "$src\client\ProgressionScreen.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("[Train]")) {
    $marker = @'
                if (!row.locked()) {
                    boolean afford = ClientNinjaState.skillPoints >= row.cost();
'@
    $insert = @'
                if (tab == 0 && row.id().equals("control")) {
                    context.drawText(textRenderer, Text.literal("[Train]"),
                            x0 + w - 80, y + 2, 0xFF1F7A1F, false);
                }
                if (!row.locked()) {
                    boolean afford = ClientNinjaState.skillPoints >= row.cost();
'@
    $c = $c.Replace($marker, $insert)
    $marker = '            if (!row.locked() && inRect(mouseX, mouseY, x0 + w - 44, y, 40, 12)) {'
    $insert = @'
            if (tab == 0 && row.id().equals("control") && inRect(mouseX, mouseY, x0 + w - 80, y, 36, 12)) {
                if (this.client != null) this.client.setScreen(new ControlTrainingScreen());
                return true;
            }
            if (!row.locked() && inRect(mouseX, mouseY, x0 + w - 44, y, 40, 12)) {
'@
    $c = $c.Replace($marker, $insert)
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[17] ProgressionScreen: [Train] button" -ForegroundColor Green
}

# === [18] AoeBehavior kekkei stun ===
$file = "$src\jutsu\AoeBehavior.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)
if (-not $c.Contains("TreePassives")) {
    $marker = 'int stunDuration = params.has("stunDuration") ? params.get("stunDuration").getAsInt() : 20;'
    $insert = @'
int stunDuration = params.has("stunDuration") ? params.get("stunDuration").getAsInt() : 20;
        if (stun) {
            stunDuration = (int)(stunDuration * (1 + TreePassives.collectServer(data).kekkeiStun));
        }
'@
    $c = $c.Replace($marker, $insert)
    $c = $c.Replace("import com.example.shinobicore.stat.NinjaPlayerData;",
        "import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.tree.TreePassives;")
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[18] AoeBehavior: kekkei stun" -ForegroundColor Green
}

Write-Host "`n=== PASSIVES v2 COMPLETE ===" -ForegroundColor Cyan
Write-Host "Run: .\gradlew.bat build" -ForegroundColor Yellow