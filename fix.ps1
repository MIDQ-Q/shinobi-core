# ============================================================
# FIX 4: JUTSU tab via LoadoutPanel + correct scroll signature
# ============================================================
$ErrorActionPreference = "Stop"
$root = "E:\Games\mod"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $fullPath = Join-Path $root $Path
    $dir = Split-Path $fullPath -Parent
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($fullPath, $Content, $utf8NoBom)
    Write-Host "[OK] $Path" -ForegroundColor Green
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FIX 4: JUTSU tab (LoadoutPanel) + scroll signature fix" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# ============================================================
# 1. LoadoutPanel.java (JUTSU tab content: sets A/B + 5 slots)
# ============================================================
Write-Utf8NoBom "src\main\java\com\example\shinobicore\client\sakura\ui\LoadoutPanel.java" @'
package com.example.shinobicore.client.sakura.ui;

import com.example.shinobicore.client.ClientNinjaStateHolder;
import com.example.shinobicore.client.JutsuAssignmentScreen;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.text.Text;

/** JUTSU tab: loadout sets A/B, click a slot to assign a jutsu. */
public final class LoadoutPanel {
    private static int set = 0;

    private LoadoutPanel() {}

    private static int[] setBtnRect(int idx, int x0, int y0) {
        return new int[]{ x0 + 20 + idx * 46, y0 + 34, 40, 14 };
    }
    private static int[] slotRect(int idx, int x0, int y0) {
        return new int[]{ x0 + 20, y0 + 58 + idx * 22, 240, 20 };
    }

    public static void render(DrawContext ctx, int x0, int y0, int w, int h, int mx, int my) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client == null) return;
        ctx.drawTextWithShadow(client.textRenderer, Text.literal("JUTSU LOADOUT"),
            x0 + 20, y0 + 16, 0xFFFF9EC4);

        for (int i = 0; i < 2; i++) {
            int[] r = setBtnRect(i, x0, y0);
            boolean active = set == i;
            boolean hov = mx >= r[0] && mx <= r[0] + r[2] && my >= r[1] && my <= r[1] + r[3];
            ctx.fill(r[0], r[1], r[0] + r[2], r[1] + r[3], active ? 0xFF8A4A66 : 0xFF2A1F2E);
            ctx.fill(r[0], r[1], r[0] + r[2], r[1] + 1, active ? 0xFFFF9EC4 : 0xFF4A3A50);
            if (hov && !active) ctx.fill(r[0], r[1], r[0] + r[2], r[1] + r[3], 0x22FF9EC4);
            ctx.drawTextWithShadow(client.textRenderer, Text.literal(i == 0 ? "A" : "B"),
                r[0] + r[2] / 2 - 3, r[1] + 3, active ? 0xFFF2EAF0 : 0xFF9A8FA6);
        }

        String[] loadout = ClientNinjaStateHolder.get().getLoadout(set);
        int active = ClientNinjaStateHolder.get().getActive(set);
        for (int i = 0; i < 5; i++) {
            int[] r = slotRect(i, x0, y0);
            boolean hov = mx >= r[0] && mx <= r[0] + r[2] && my >= r[1] && my <= r[1] + r[3];
            ctx.fill(r[0], r[1], r[0] + r[2], r[1] + r[3], hov ? 0xFF3A2A3E : 0xFF241B2A);
            ctx.fill(r[0], r[1], r[0] + 1, r[1] + r[3], i == active ? 0xFFFF9EC4 : 0xFF4A3A50);
            if (hov) ctx.fill(r[0], r[1], r[0] + r[2], r[1] + 1, 0x55FF9EC4);

            ctx.drawTextWithShadow(client.textRenderer, Text.literal((i + 1) + "."),
                r[0] + 6, r[1] + 6, 0xFF9A8FA6);
            String id = loadout[i];
            String name = id == null ? "- empty -" : ClientNinjaStateHolder.get().getName(id);
            ctx.drawTextWithShadow(client.textRenderer, Text.literal(name),
                r[0] + 22, r[1] + 6, id == null ? 0xFF6E6478 : 0xFFF2EAF0);
            if (i == active) {
                ctx.drawTextWithShadow(client.textRenderer, Text.literal("ACT"),
                    r[0] + r[2] - 26, r[1] + 6, 0xFFFF9EC4);
            }
        }
        ctx.drawTextWithShadow(client.textRenderer,
            Text.literal("Click a slot to assign a jutsu"),
            x0 + 20, y0 + 58 + 5 * 22 + 8, 0xFF9A8FA6);
    }

    public static boolean handleClick(double mx, double my, int x0, int y0, int w, int h) {
        for (int i = 0; i < 2; i++) {
            int[] r = setBtnRect(i, x0, y0);
            if (mx >= r[0] && mx <= r[0] + r[2] && my >= r[1] && my <= r[1] + r[3]) {
                set = i;
                UiSounds.tab();
                return true;
            }
        }
        for (int i = 0; i < 5; i++) {
            int[] r = slotRect(i, x0, y0);
            if (mx >= r[0] && mx <= r[0] + r[2] && my >= r[1] && my <= r[1] + r[3]) {
                MinecraftClient client = MinecraftClient.getInstance();
                if (client != null) {
                    UiSounds.click();
                    client.setScreen(new JutsuAssignmentScreen(client.currentScreen, set, i));
                }
                return true;
            }
        }
        return false;
    }
}
'@

# ============================================================
# 2. SakuraHubScreen.java (4 tabs, no ProgressionScreen refs, correct scroll call)
# ============================================================
Write-Utf8NoBom "src\main\java\com\example\shinobicore\client\sakura\SakuraHubScreen.java" @'
package com.example.shinobicore.client.sakura;

import com.example.shinobicore.client.SkillTreeScreen;
import com.example.shinobicore.client.sakura.ui.CharacterPanel;
import com.example.shinobicore.client.sakura.ui.LoadoutPanel;
import com.example.shinobicore.client.sakura.ui.SakuraAtmosphere;
import com.example.shinobicore.client.sakura.ui.SakuraTextures;
import com.example.shinobicore.client.sakura.ui.SakuraTheme;
import com.example.shinobicore.client.sakura.ui.UiAnim;
import com.example.shinobicore.client.sakura.ui.UiSounds;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.client.gui.screen.ingame.HandledScreen;
import net.minecraft.client.gui.screen.ingame.InventoryScreen;
import net.minecraft.entity.player.PlayerInventory;
import net.minecraft.screen.slot.Slot;
import net.minecraft.text.Text;

public class SakuraHubScreen extends HandledScreen<SakuraHandler> {
    private static final String[] TABS = {"CHARACTER", "SKILL TREE", "JUTSU", "INVENTORY"};
    private static final int TAB_INVENTORY = 3;
    private static final String[] SLOT_LABELS = {
        "gui.shinobicore.slot.head", "gui.shinobicore.slot.chest",
        "gui.shinobicore.slot.legs", "gui.shinobicore.slot.feet",
        "gui.shinobicore.slot.off"
    };
    private int tab;
    private Screen child;
    private long openMs;
    private long tabSwitchMs;
    private long lastFrameMs;
    private int hoveredTab = -1;
    private final UiAnim.Smooth indX = new UiAnim.Smooth(-1, 16);
    private final UiAnim.Smooth indW = new UiAnim.Smooth(0, 16);
    private final int[] tabXs = new int[TABS.length];
    private final int[] tabWs = new int[TABS.length];

    public SakuraHubScreen(SakuraHandler handler, PlayerInventory inv, int tab) {
        super(handler, inv, Text.literal("Shinobi"));
        this.tab = tab;
        this.backgroundWidth = SakuraHandler.BG_W;
        this.backgroundHeight = SakuraHandler.BG_H;
        this.titleX = -10000;
        this.titleY = -10000;
        this.playerInventoryTitleY = 10000;
    }

    @Override
    protected void init() {
        super.init();
        long now = System.currentTimeMillis();
        openMs = now;
        tabSwitchMs = now;
        lastFrameMs = now;
        SakuraTextures.init(client);
        buildChild();
    }

    private void buildChild() {
        if (tab == 1) child = new SkillTreeScreen(true);
        else child = null;
        if (child != null) child.init(client, width, height - SakuraTheme.BAR_H);
    }

    @Override
    public void renderBackground(DrawContext context) {}

    @Override
    public void render(DrawContext ctx, int mx, int my, float delta) {
        long now = System.currentTimeMillis();
        long prev = lastFrameMs;
        lastFrameMs = now;
        SakuraAtmosphere.render(ctx, width, height, now);
        int ht = tabAt(mx, my);
        if (ht != hoveredTab) {
            hoveredTab = ht;
            if (ht >= 0) UiSounds.hover();
        }
        float open = UiAnim.openEase(openMs, now, SakuraTheme.OPEN_MS);
        if (tab == TAB_INVENTORY) {
            ctx.getMatrices().push();
            applyOpenTransform(ctx, open);
            super.render(ctx, mx, my, delta);
            ctx.getMatrices().pop();
        } else if (tab == 0) {
            CharacterPanel.render(ctx, 0, SakuraTheme.BAR_H, width, height - SakuraTheme.BAR_H, mx, my);
        } else if (tab == 2) {
            LoadoutPanel.render(ctx, 0, SakuraTheme.BAR_H, width, height - SakuraTheme.BAR_H, mx, my);
        } else if (child != null) {
            ctx.getMatrices().push();
            ctx.getMatrices().translate(0, SakuraTheme.BAR_H, 0);
            child.render(ctx, mx, my - SakuraTheme.BAR_H, delta);
            ctx.getMatrices().pop();
        }
        drawBar(ctx, mx, now, prev, open);
    }

    private void applyOpenTransform(DrawContext ctx, float open) {
        if (open >= 1f) return;
        float s = 0.94f + 0.06f * open;
        ctx.getMatrices().translate(width / 2f, height / 2f, 0);
        ctx.getMatrices().scale(s, s, 1);
        ctx.getMatrices().translate(-width / 2f, -height / 2f + (1 - open) * 10, 0);
    }

    @Override
    protected void drawBackground(DrawContext ctx, float delta, int mx, int my) {
        if (tab != TAB_INVENTORY) return;
        int gx = this.x, gy = this.y;
        SakuraTextures.drawPanel(ctx, gx - 3, gy - 3, backgroundWidth + 6, backgroundHeight + 6);
        ctx.fill(gx, gy, gx + 3, gy + 3, SakuraTheme.SAKURA);
        ctx.fill(gx + backgroundWidth - 3, gy, gx + backgroundWidth, gy + 3, SakuraTheme.SAKURA);
        ctx.fill(gx, gy + backgroundHeight - 3, gx + 3, gy + backgroundHeight, SakuraTheme.SAKURA);
        ctx.fill(gx + backgroundWidth - 3, gy + backgroundHeight - 3, gx + backgroundWidth, gy + backgroundHeight, SakuraTheme.SAKURA);
        drawInventory(ctx, gx, gy, mx, my, System.currentTimeMillis());
    }

    private void drawInventory(DrawContext ctx, int gx, int gy, int mx, int my, long now) {
        int lx = gx + 6, ly = gy + 6, lw = 104, lh = backgroundHeight - 12;
        SakuraTextures.drawPanel(ctx, lx, ly, lw, lh);
        ctx.drawTextWithShadow(textRenderer, Text.translatable("gui.shinobicore.equipment"), lx + 6, ly + 4, SakuraTheme.SAKURA);
        for (int i = 0; i < 5; i++) {
            Slot s = handler.slots.get(i);
            float a = UiAnim.openEase(tabSwitchMs + i * SakuraTheme.STAGGER_MS, now, 180);
            slotBox(ctx, gx + s.x, gy + s.y, mx, my, a);
            if (s.getStack().isEmpty()) {
                ctx.drawTextWithShadow(textRenderer, Text.translatable(SLOT_LABELS[i]),
                    gx + s.x + 20, gy + s.y + 4, withAlpha(0x88FF9EC4, a));
            }
        }
        int modelX = lx + 80, modelY = ly + lh - 12;
        InventoryScreen.drawEntity(ctx, modelX, modelY, 32, (float)(modelX - mx), (float)(modelY - 50 - my), client.player);

        int rx = gx + 116, ry = gy + 6, rw = backgroundWidth - 122, rh = backgroundHeight - 12;
        SakuraTextures.drawPanel(ctx, rx, ry, rw, rh);
        ctx.drawTextWithShadow(textRenderer, Text.translatable("gui.shinobicore.stash"), rx + 6, ry + 4, SakuraTheme.SAKURA);
        for (int i = 5; i <= 31; i++) {
            Slot s = handler.slots.get(i);
            float a = UiAnim.openEase(tabSwitchMs + i * SakuraTheme.STAGGER_MS, now, 180);
            slotBox(ctx, gx + s.x, gy + s.y, mx, my, a);
        }
        int sepY = gy + SakuraHandler.SEP_Y;
        ctx.fill(rx + 4, sepY, rx + rw - 4, sepY + 1, SakuraTheme.EDGE);
        ctx.drawTextWithShadow(textRenderer, Text.translatable("gui.shinobicore.hotbar"), rx + 6, sepY + 4, SakuraTheme.INK_DIM);
        for (int i = 32; i <= 40; i++) {
            Slot s = handler.slots.get(i);
            float a = UiAnim.openEase(tabSwitchMs + i * SakuraTheme.STAGGER_MS, now, 180);
            slotBox(ctx, gx + s.x, gy + s.y, mx, my, a);
        }
        ctx.drawTextWithShadow(textRenderer, Text.translatable("gui.shinobicore.hint.inv"), rx + 6, ry + rh - 12, SakuraTheme.INK_DIM);
    }

    private void slotBox(DrawContext ctx, int ax, int ay, int mx, int my, float a) {
        if (a <= 0.01f) return;
        boolean hov = mx >= ax && mx < ax + 16 && my >= ay && my < ay + 16;
        ctx.fill(ax, ay, ax + 16, ay + 16, withAlpha(SakuraTheme.SLOT_BG, a));
        int e = withAlpha(SakuraTheme.SLOT_EDGE, a);
        ctx.fill(ax, ay, ax + 16, ay + 1, e);
        ctx.fill(ax, ay + 15, ax + 16, ay + 16, e);
        ctx.fill(ax, ay, ax + 1, ay + 16, e);
        ctx.fill(ax + 15, ay, ax + 16, ay + 16, e);
        if (hov) ctx.fill(ax, ay, ax + 16, ay + 16, withAlpha(SakuraTheme.SLOT_HOVER, a));
    }

    private static int withAlpha(int argb, float a) {
        int al = (argb >>> 24) & 0xFF;
        int na = (int)(al * Math.max(0, Math.min(1, a)));
        return (argb & 0x00FFFFFF) | (na << 24);
    }

    private void drawBar(DrawContext ctx, int mx, long now, long prev, float open) {
        int barH = SakuraTheme.BAR_H;
        ctx.getMatrices().push();
        if (open < 1f) ctx.getMatrices().translate(0, (1 - open) * -8, 0);
        ctx.fill(0, 0, width, barH, 0xE8171119);
        ctx.fill(0, barH - 1, width, barH, SakuraTheme.SAK_DIM);
        int bx = 8;
        for (int i = 0; i < TABS.length; i++) {
            tabWs[i] = textRenderer.getWidth(TABS[i]) + 16;
            tabXs[i] = bx;
            bx += tabWs[i] + 6;
        }
        if (indX.get() < 0) { indX.set(tabXs[tab]); indW.set(tabWs[tab]); }
        indX.update(tabXs[tab], now, prev);
        indW.update(tabWs[tab], now, prev);
        int ix = (int) indX.get(), iw = (int) indW.get();
        ctx.fill(ix, 4, ix + iw, barH - 3, 0x33FF9EC4);
        ctx.fill(ix, barH - 3, ix + iw, barH - 1, SakuraTheme.SAKURA);
        for (int i = 0; i < TABS.length; i++) {
            boolean hov = mx >= tabXs[i] && mx <= tabXs[i] + tabWs[i];
            if (hov && i != tab) ctx.fill(tabXs[i], 4, tabXs[i] + tabWs[i], barH - 3, 0x22FF9EC4);
            ctx.drawTextWithShadow(textRenderer, Text.literal(TABS[i]), tabXs[i] + 8, 8,
                i == tab ? SakuraTheme.SAKURA : (hov ? SakuraTheme.INK : SakuraTheme.INK_DIM));
        }
        ctx.drawTextWithShadow(textRenderer, Text.literal("ESC - close"), width - 80, 8, SakuraTheme.INK_DIM);
        ctx.getMatrices().pop();
    }

    private int tabAt(int mx, int my) {
        if (my >= SakuraTheme.BAR_H) return -1;
        int bx = 8;
        for (int i = 0; i < TABS.length; i++) {
            int w = textRenderer.getWidth(TABS[i]) + 16;
            if (mx >= bx && mx <= bx + w) return i;
            bx += w + 6;
        }
        return -1;
    }

    @Override
    public boolean mouseClicked(double mx, double my, int button) {
        int t = tabAt((int) mx, (int) my);
        if (t >= 0) {
            if (t != tab) {
                tab = t;
                tabSwitchMs = System.currentTimeMillis();
                UiSounds.tab();
                buildChild();
            } else {
                UiSounds.click();
            }
            return true;
        }
        if (tab == TAB_INVENTORY) return super.mouseClicked(mx, my, button);
        if (tab == 0) return CharacterPanel.handleClick(mx, my, 0, SakuraTheme.BAR_H, button);
        if (tab == 2) return LoadoutPanel.handleClick(mx, my, 0, SakuraTheme.BAR_H, width, height - SakuraTheme.BAR_H);
        return child != null && child.mouseClicked(mx, my - SakuraTheme.BAR_H, button);
    }

    @Override
    public boolean mouseReleased(double mx, double my, int button) {
        if (tab == TAB_INVENTORY) return super.mouseReleased(mx, my, button);
        return child != null && child.mouseReleased(mx, my - SakuraTheme.BAR_H, button);
    }

    @Override
    public boolean mouseDragged(double mx, double my, int b, double dx, double dy) {
        if (tab == TAB_INVENTORY) return super.mouseDragged(mx, my, b, dx, dy);
        return child != null && child.mouseDragged(mx, my - SakuraTheme.BAR_H, b, dx, dy);
    }

    @Override
    public boolean mouseScrolled(double mx, double my, double amount) {
        if (tab == TAB_INVENTORY) return super.mouseScrolled(mx, my, amount);
        if (tab == 0) return CharacterPanel.mouseScrolled(mx, my, amount);
        return child != null && child.mouseScrolled(mx, my - SakuraTheme.BAR_H, amount);
    }

    @Override
    public boolean keyPressed(int keyCode, int scanCode, int modifiers) {
        if (keyCode == 256) { close(); return true; }
        if (tab == TAB_INVENTORY) return super.keyPressed(keyCode, scanCode, modifiers);
        return child != null && child.keyPressed(keyCode, scanCode, modifiers);
    }

    @Override
    public boolean charTyped(char chr, int modifiers) {
        if (tab == TAB_INVENTORY) return super.charTyped(chr, modifiers);
        return child != null && child.charTyped(chr, modifiers);
    }

    @Override
    public boolean shouldPause() { return false; }
}
'@

# ============================================================
# BUILD
# ============================================================
Write-Host ""
Write-Host "Building..." -ForegroundColor Yellow
Push-Location $root
try {
    $buildOut = & cmd /c "gradlew.bat build 2>&1" | Out-String
    if ($buildOut -match "BUILD SUCCESSFUL") {
        Write-Host "[PASS] BUILD SUCCESSFUL!" -ForegroundColor Green
        Write-Host ""
        Write-Host "FIXED:" -ForegroundColor Yellow
        Write-Host "  JUTSU tab -> LoadoutPanel (sets A/B + 5 assign slots)" -ForegroundColor Gray
        Write-Host "  No ProgressionScreen ctor dependency in hub" -ForegroundColor Gray
        Write-Host "  CharacterPanel.mouseScrolled(mx, my, amount) - correct arity" -ForegroundColor Gray
        Write-Host ""
        Write-Host "HUB TABS: CHARACTER / SKILL TREE / JUTSU / INVENTORY" -ForegroundColor Cyan
    } else {
        Write-Host "[FAIL] Build errors:" -ForegroundColor Red
        ($buildOut -split "`n") | Where-Object { $_ -match "error:" } | Select-Object -First 25 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally { Pop-Location }