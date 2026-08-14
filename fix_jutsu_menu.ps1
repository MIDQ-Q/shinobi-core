$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main\java\com\example\shinobicore\client"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============ Новый JutsuAssignmentScreen с вкладками по стихиям ============
Write-File "$base\JutsuAssignmentScreen.java" @'
package com.example.shinobicore.client;

import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.client.gui.widget.ButtonWidget;
import net.minecraft.client.gui.widget.TextFieldWidget;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;

import java.util.*;

public class JutsuAssignmentScreen extends Screen {
    private final int loadoutSet;
    private final int slotIndex;
    private final Screen parent;

    private static final String[] CATEGORIES = {"all","fire","water","wind","lightning","earth","taijutsu","kenjutsu","shuriken","medical","summon","sealing","general"};
    private static final int[] CAT_COLORS = {0xFFFFFFFF,0xFFFF6644,0xFF44AAFF,0xFF88DD88,0xFFFFDD44,0xFFAA8844,0xFFCC88CC,0xFFFF8888,0xFFBBBBBB,0xFF88FF88,0xFFFFCC66,0xFF66CC99,0xFFCCCCCC};

    private String currentCategory = "all";
    private String searchQuery = "";
    private TextFieldWidget searchBox;
    private List<String> filteredJutsus = new ArrayList<>();
    private int scrollOffset = 0;
    private static final int VISIBLE_COUNT = 10;
    private static final int ROW_HEIGHT = 18;

    public JutsuAssignmentScreen(Screen parent, int loadoutSet, int slotIndex) {
        super(Text.literal("Assign Jutsu"));
        this.parent = parent;
        this.loadoutSet = loadoutSet;
        this.slotIndex = slotIndex;
    }

    @Override
    protected void init() {
        searchBox = new TextFieldWidget(textRenderer, width/2 - 100, 20, 200, 18, Text.literal("Search"));
        searchBox.setChangedListener(s -> { searchQuery = s.toLowerCase(); updateFilteredList(); });
        addDrawableChild(searchBox);

        int tabY = 44;
        int tabW = 55, tabH = 18, gap = 2;
        int totalW = CATEGORIES.length * (tabW + gap);
        int startX = width/2 - totalW/2;
        for (int i = 0; i < CATEGORIES.length; i++) {
            final String cat = CATEGORIES[i];
            final int ci = i;
            addDrawableChild(ButtonWidget.builder(
                Text.literal(cat.substring(0,1).toUpperCase() + cat.substring(1)),
                b -> { currentCategory = cat; updateFilteredList(); }
            ).dimensions(startX + i * (tabW + gap), tabY, tabW, tabH).build());
        }

        // Close button
        addDrawableChild(ButtonWidget.builder(Text.literal("Cancel"), b -> close()).dimensions(width/2 - 40, height - 30, 80, 20).build());

        updateFilteredList();
    }

    private void updateFilteredList() {
        filteredJutsus.clear();
        for (String id : ClientNinjaState.learned) {
            String name = ClientNinjaState.name(id).toLowerCase();
            if (!searchQuery.isEmpty() && !name.contains(searchQuery) && !id.toLowerCase().contains(searchQuery)) continue;
            if (!currentCategory.equals("all") && !matchesCategory(id, currentCategory)) continue;
            filteredJutsus.add(id);
        }
        filteredJutsus.sort(String.CASE_INSENSITIVE_ORDER);
        scrollOffset = 0;
    }

    private boolean matchesCategory(String id, String cat) {
        String lower = id.toLowerCase();
        return switch (cat) {
            case "fire" -> lower.contains("fire");
            case "water" -> lower.contains("water");
            case "wind" -> lower.contains("wind");
            case "lightning" -> lower.contains("lightning") || lower.contains("thunder") || lower.contains("chidori") || lower.contains("kirin");
            case "earth" -> lower.contains("earth");
            case "taijutsu" -> lower.contains("taijutsu") || lower.contains("lotus") || lower.contains("peacock") || lower.contains("elephant") || lower.contains("gates") || lower.contains("rotation");
            case "kenjutsu" -> lower.contains("kenjutsu") || lower.contains("katana") || lower.contains("iai") || lower.contains("slash");
            case "shuriken" -> lower.contains("shuriken") || lower.contains("kunai") || lower.contains("senbon") || lower.contains("tracking");
            case "medical" -> lower.contains("medical") || lower.contains("heal") || lower.contains("resus") || lower.contains("hundred");
            case "summon" -> lower.contains("summon") || lower.contains("contract") || lower.contains("edo");
            case "sealing" -> lower.contains("seal") || lower.contains("reaper");
            case "general" -> lower.contains("substitution") || lower.contains("shunshin") || lower.contains("clone") || lower.contains("smoke") || lower.contains("hide") || lower.contains("flicker") || lower.contains("genjutsu");
            default -> true;
        };
    }

    @Override
    public void render(DrawContext ctx, int mouseX, int mouseY, float delta) {
        renderBackground(ctx);
        super.render(ctx, mouseX, mouseY, delta);

        // Title
        String title = "Assign to slot " + (slotIndex + 1) + " (Loadout " + (loadoutSet == 0 ? "A" : "B") + ")";
        ctx.drawText(textRenderer, Text.literal(title), width/2 - textRenderer.getWidth(title)/2, 8, 0xFFFFFF, true);

        // List area
        int listX = width/2 - 150, listY = 68;
        int listW = 300, listH = VISIBLE_COUNT * ROW_HEIGHT + 4;
        ctx.fill(listX - 2, listY - 2, listX + listW + 2, listY + listH + 2, 0xFF333333);
        ctx.fill(listX, listY, listX + listW, listY + listH, 0xAA111111);

        int shown = 0;
        for (int i = scrollOffset; i < filteredJutsus.size() && shown < VISIBLE_COUNT; i++, shown++) {
            String id = filteredJutsus.get(i);
            String name = ClientNinjaState.name(id);
            int rowY = listY + 2 + shown * ROW_HEIGHT;
            boolean hover = mouseX >= listX && mouseX < listX + listW && mouseY >= rowY && mouseY < rowY + ROW_HEIGHT;
            if (hover) ctx.fill(listX, rowY, listX + listW, rowY + ROW_HEIGHT, 0x44FFFFFF);
            ctx.drawText(textRenderer, Text.literal(name), listX + 4, rowY + 4, hover ? 0xFFFFFF : 0xDDDDDD, false);
        }

        // Scroll indicator
        if (filteredJutsus.size() > VISIBLE_COUNT) {
            int maxScroll = filteredJutsus.size() - VISIBLE_COUNT;
            int scrollBarY = listY + (int)((float)scrollOffset / maxScroll * (listH - 20));
            ctx.fill(listX + listW - 4, listY, listX + listW, listY + listH, 0x44444444);
            ctx.fill(listX + listW - 4, scrollBarY, listX + listW, scrollBarY + 20, 0xFF888888);
        }

        // Count
        String count = filteredJutsus.size() + " jutsus";
        ctx.drawText(textRenderer, Text.literal(count), listX + listW - textRenderer.getWidth(count) - 4, listY + listH + 4, 0xAAAAAA, false);

        // Clear slot button
        int clearY = listY + listH + 18;
        boolean clearHover = mouseX >= listX && mouseX < listX + listW && mouseY >= clearY && mouseY < clearY + 14;
        ctx.fill(listX, clearY, listX + listW, clearY + 14, clearHover ? 0xFFCC3322 : 0xAA442211);
        ctx.drawText(textRenderer, Text.literal("[ Clear this slot ]"), listX + listW/2 - textRenderer.getWidth("[ Clear this slot ]")/2, clearY + 3, 0xFFFFFF, false);
    }

    @Override
    public boolean mouseClicked(double mx, double my, int button) {
        int listX = width/2 - 150, listY = 68;
        int listW = 300;
        int listH = VISIBLE_COUNT * ROW_HEIGHT + 4;

        // List click
        if (mx >= listX && mx < listX + listW && my >= listY && my < listY + listH) {
            int idx = scrollOffset + (int)((my - listY) / ROW_HEIGHT);
            if (idx >= 0 && idx < filteredJutsus.size()) {
                sendSetSlot(filteredJutsus.get(idx));
                return true;
            }
        }

        // Clear button
        int clearY = listY + listH + 18;
        if (mx >= listX && mx < listX + listW && my >= clearY && my < clearY + 14) {
            sendSetSlot("");
            return true;
        }

        return super.mouseClicked(mx, my, button);
    }

    @Override
    public boolean mouseScrolled(double mx, double my, double amount) {
        int maxScroll = Math.max(0, filteredJutsus.size() - VISIBLE_COUNT);
        scrollOffset = Math.max(0, Math.min(maxScroll, scrollOffset - (int)amount));
        return true;
    }

    private void sendSetSlot(String id) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeInt(loadoutSet);
        buf.writeInt(slotIndex);
        buf.writeString(id);
        ClientPlayNetworking.send(ModPackets.SET_SLOT_ID, buf);
        close();
    }

    @Override
    public void close() {
        if (client != null) client.setScreen(parent);
    }
}
'@

Write-Host "[OK] JutsuAssignmentScreen created"

# ============ Модифицировать ProgressionScreen чтобы использовать новый экран ============
$ps = "$base\ProgressionScreen.java"
$c = [System.IO.File]::ReadAllText($ps, $utf8)

# Найти место где кликом на слот вызывается выпадающий список, заменить на открытие нового экрана
$c = $c.Replace("assignSlot = i; listOffset = 0; return true;",
    "client.setScreen(new JutsuAssignmentScreen(this, loadoutSet, i)); return true;")

# Удалить старую логику выпадающего списка (assignSlot >= 0 ветки) - делаем их no-op
$c = $c.Replace("sendSetSlot(loadoutSet, assignSlot, learned.get(i));`n                        assignSlot = -1;",
    "// old logic disabled")
$c = $c.Replace("sendSetSlot(loadoutSet, assignSlot, `"`");`n                    assignSlot = -1;",
    "// old logic disabled")
$c = $c.Replace("assignSlot = -1;", "// old logic disabled", [StringSplitOptions]::None)

[System.IO.File]::WriteAllText($ps, $c, $utf8)
Write-Host "[OK] ProgressionScreen: uses JutsuAssignmentScreen on slot click"

Write-Host "=== JUTSU MENU FIX DONE ==="