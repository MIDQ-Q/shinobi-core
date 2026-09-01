package com.example.shinobicore.client;

import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.client.gui.widget.ButtonWidget;
import net.minecraft.client.gui.widget.TextFieldWidget;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.text.Text;

import java.util.*;
import com.example.shinobicore.client.ClientNinjaStateHolder;

public class JutsuAssignmentScreen extends Screen {
    private final int loadoutSet;
    private final int slotIndex;
    private final Screen parent;

    private static final String[] CATEGORIES = {"All","Fire","Water","Wind","Light","Earth","Tai","Ken","Shur","Med","Sum","Seal","Gen"};
    private static final String[] CAT_KEYS = {"all","fire","water","wind","lightning","earth","taijutsu","kenjutsu","shuriken","medical","summon","sealing","general"};

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
        searchBox = new TextFieldWidget(textRenderer, width/2 - 100, 16, 200, 16, Text.literal("Search"));
        searchBox.setChangedListener(s -> { searchQuery = s.toLowerCase(); updateFilteredList(); });
        addDrawableChild(searchBox);

        // 2 rows of tabs
        int tabW = 48, tabH = 16, gap = 2;
        int perRow = 7;
        int totalW = perRow * (tabW + gap);
        int startX = width/2 - totalW/2;
        for (int i = 0; i < CATEGORIES.length; i++) {
            int row = i / perRow;
            int col = i % perRow;
            final String cat = CAT_KEYS[i];
            addDrawableChild(ButtonWidget.builder(
                Text.literal(CATEGORIES[i]),
                b -> { currentCategory = cat; updateFilteredList(); }
            ).dimensions(startX + col * (tabW + gap), 38 + row * (tabH + 2), tabW, tabH).build());
        }

        addDrawableChild(ButtonWidget.builder(Text.literal("Cancel"), b -> close()).dimensions(width/2 - 40, height - 28, 80, 20).build());
        updateFilteredList();
    }

    private void updateFilteredList() {
        filteredJutsus.clear();
        for (String id : ClientNinjaStateHolder.get().getLearned()) {
            String name = ClientNinjaStateHolder.get().getName(id).toLowerCase();
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
            case "fire" -> lower.contains("fire") || lower.contains("flame") || lower.contains("ash") || lower.contains("amaterasu") || lower.contains("blaze");
            case "water" -> lower.contains("water") || lower.contains("shark") || lower.contains("maelstrom");
            case "wind" -> lower.contains("wind") || lower.contains("vacuum") || lower.contains("gale") || lower.contains("rasenshuriken") || lower.contains("sickle");
            case "lightning" -> lower.contains("light") || lower.contains("thunder") || lower.contains("chidori") || lower.contains("kirin");
            case "earth" -> lower.contains("earth") || lower.contains("rock") || lower.contains("stone") || lower.contains("golem");
            case "taijutsu" -> lower.contains("taijutsu") || lower.contains("lotus") || lower.contains("peacock") || lower.contains("elephant") || lower.contains("gates") || lower.contains("rotation") || lower.contains("whirlwind") || lower.contains("swallow");
            case "kenjutsu" -> lower.contains("kenjutsu") || lower.contains("katana") || lower.contains("iai") || lower.contains("slash") || lower.contains("counter") || lower.contains("heavenly");
            case "shuriken" -> lower.contains("shuriken") || lower.contains("kunai") || lower.contains("senbon") || lower.contains("tracking") || lower.contains("flash") || lower.contains("smoke");
            case "medical" -> lower.contains("medical") || lower.contains("heal") || lower.contains("resus") || lower.contains("hundred") || lower.contains("palm") || lower.contains("poison_extract");
            case "summon" -> lower.contains("summon") || lower.contains("contract") || lower.contains("edo");
            case "sealing" -> lower.contains("seal") || lower.contains("reaper");
            case "general" -> lower.contains("substitution") || lower.contains("shunshin") || lower.contains("clone") || lower.contains("hide") || lower.contains("flicker") || lower.contains("genjutsu") || lower.contains("rope") || lower.contains("camouflage") || lower.contains("paper");
            default -> true;
        };
    }

    @Override
    public void render(DrawContext ctx, int mouseX, int mouseY, float delta) {
        renderBackground(ctx);
        super.render(ctx, mouseX, mouseY, delta);

        String title = "Slot " + (slotIndex + 1) + " (Loadout " + (loadoutSet == 0 ? "A" : "B") + ")";
        ctx.drawText(textRenderer, Text.literal(title), width/2 - textRenderer.getWidth(title)/2, 6, 0xFFFFFF, true);

        int listX = width/2 - 150, listY = 78;
        int listW = 300, listH = VISIBLE_COUNT * ROW_HEIGHT + 4;
        ctx.fill(listX - 2, listY - 2, listX + listW + 2, listY + listH + 2, 0xFF333333);
        ctx.fill(listX, listY, listX + listW, listY + listH, 0xAA111111);

        int shown = 0;
        for (int i = scrollOffset; i < filteredJutsus.size() && shown < VISIBLE_COUNT; i++, shown++) {
            String id = filteredJutsus.get(i);
            String name = ClientNinjaStateHolder.get().getName(id);
            int rowY = listY + 2 + shown * ROW_HEIGHT;
            boolean hover = mouseX >= listX && mouseX < listX + listW && mouseY >= rowY && mouseY < rowY + ROW_HEIGHT;
            if (hover) ctx.fill(listX, rowY, listX + listW, rowY + ROW_HEIGHT, 0x44FFFFFF);
            ctx.drawText(textRenderer, Text.literal(name), listX + 4, rowY + 4, hover ? 0xFFFFFF : 0xDDDDDD, false);
        }

        if (filteredJutsus.size() > VISIBLE_COUNT) {
            int maxScroll = filteredJutsus.size() - VISIBLE_COUNT;
            int scrollBarY = listY + (int)((float)scrollOffset / maxScroll * (listH - 20));
            ctx.fill(listX + listW - 4, listY, listX + listW, listY + listH, 0x44444444);
            ctx.fill(listX + listW - 4, scrollBarY, listX + listW, scrollBarY + 20, 0xFF888888);
        }

        String count = filteredJutsus.size() + " jutsus";
        ctx.drawText(textRenderer, Text.literal(count), listX + listW - textRenderer.getWidth(count) - 4, listY + listH + 4, 0xAAAAAA, false);

        int clearY = listY + listH + 16;
        boolean clearHover = mouseX >= listX && mouseX < listX + listW && mouseY >= clearY && mouseY < clearY + 14;
        ctx.fill(listX, clearY, listX + listW, clearY + 14, clearHover ? 0xFFCC3322 : 0xAA442211);
        ctx.drawText(textRenderer, Text.literal("[ Clear this slot ]"), listX + listW/2 - textRenderer.getWidth("[ Clear this slot ]")/2, clearY + 3, 0xFFFFFF, false);
    }

    @Override
    public boolean mouseClicked(double mx, double my, int button) {
        int listX = width/2 - 150, listY = 78;
        int listW = 300;
        int listH = VISIBLE_COUNT * ROW_HEIGHT + 4;

        if (mx >= listX && mx < listX + listW && my >= listY && my < listY + listH) {
            int idx = scrollOffset + (int)((my - listY - 2) / ROW_HEIGHT);
            if (idx >= 0 && idx < filteredJutsus.size()) {
                sendSetSlot(filteredJutsus.get(idx));
                return true;
            }
        }

        int clearY = listY + listH + 16;
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