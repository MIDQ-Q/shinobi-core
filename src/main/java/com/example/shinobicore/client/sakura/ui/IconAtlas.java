package com.example.shinobicore.client.sakura.ui;

import net.minecraft.client.MinecraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.texture.NativeImage;
import net.minecraft.client.texture.NativeImageBackedTexture;
import net.minecraft.util.Identifier;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Pixel-art icon atlas generated at runtime (no asset files).
 * Each icon is a 16x16 char grid; '.' = transparent.
 * Atlas has two strips: normal (top) and dimmed (bottom).
 */
public final class IconAtlas {
    private static final int CELL = 16;
    private static boolean ready = false;
    private static Identifier tex;
    private static int atlasW = 1;
    private static final Map<String, Integer> SLOT = new HashMap<>();
    private static final LinkedHashMap<String, String[]> ICONS = new LinkedHashMap<>();

    static {
        ICONS.put("fire", new String[]{
            "................","......rr........",".....rrrr.......",".....rrrr.......",
            "....rrrrrr......","....rororr......","...rorooorr.....","...rooyooor.....",
            "...rooyooor.....","....roooor......","....roooor......",".....roor.......",
            "......rr........","................","................","................"});
        ICONS.put("water", new String[]{
            "................",".......bb.......","......bbbb......",".....bbbbbb.....",
            "....bbbbbbbb....","...bbbbbbbbbb...","...bbcbbbbbbb...","..bbcbbbbbbbb...",
            "..bcbbbbbbbbb...","..bbbbbbbbbbb...","...bbbbbbbbb....","....bbbbbbb.....",
            ".....bbbbb......","......bbb.......","................","................"});
        ICONS.put("wind", new String[]{
            "................","................","..ggggggggggg...","..g........gg...",
            "................","...ggggggggg....","...g.......gg...","................",
            "....ggggggg.....","....g......gg...","................","................",
            "................","................","................","................"});
        ICONS.put("earth", new String[]{
            "................",".......tt.......","......tttt......",".....ttwwtt.....",
            "....ttwwwwtt....","...tttwwwwttt...","..tttttttttttt..",".tttttttttttttt.",
            "tttttttttttttttt","tttttttttttttttt","................","................",
            "................","................","................","................"});
        ICONS.put("lightning", new String[]{
            "................","......yyyy......",".....yyyy.......","....yyyy........",
            "...yyyyyyy......",".....yyyyy......","......yyy.......",".....yyy........",
            "....yyy.........","...yy...........","................","................",
            "................","................","................","................"});
        ICONS.put("taijutsu", new String[]{
            "................","................","....k.k.k.k.....","...kkkkkkkkk....",
            "..kwwwwwwwwwk...","..kwwwwwwwwwk...","..kwwwwwwwwwk...","..kwwwwwwwwwk...",
            "...kwwwwwwwk....","....kkkkkkk.....","................","................",
            "................","................","................","................"});
        ICONS.put("kenjutsu", new String[]{
            "................",".............ww.","............ww..","...........ww...",
            "..........ww....",".........ww.....","........ww......",".......ww.......",
            "......ww........",".....tt.........","....tt..........","...tt...........",
            "..kk............","................","................","................"});
        ICONS.put("shuriken", new String[]{
            "................",".......ss.......","......ssss......","......ssss......",
            ".......ss.......",".sss..ss..sss...","..sssskkssss....","...ssskksss.....",
            "....ssssss......","......ss........","......ssss......",".......ss.......",
            "................","................","................","................"});
        ICONS.put("genjutsu", new String[]{
            "................","................","....vvvvvvvv....","...vvvvvvvvvv...",
            "..vvvkkkkkvvv...",".vvvkkvvvkkvvv..",".vvvkvvvvvkvvv..",".vvvkvvvvvkvvv..",
            "..vvvkkkkkvvv...","...vvvvvvvvvv...","....vvvvvvvv....","................",
            "................","................","................","................"});
        ICONS.put("sensory", new String[]{
            "...c......c.....","..c..cccc..c....","....c....c......","................",
            "....vvvvvvvv....","...vvvvvvvvvv...","..vvvkkkkkvvv...",".vvvkkvvvkkvvv..",
            "..vvvkkkkkvvv...","...vvvvvvvvvv...","....vvvvvvvv....","................",
            "................","................","................","................"});
        ICONS.put("space", new String[]{
            "................","....vvvvvvvv....","...vv......vv...","..vv..vvvv..vv..",
            "..v..vv..vv..v..","..v..v..vv...v..","..v..v..vv...v..","..v..vvvvv...v..",
            "..vv.......vv...","...vvvvvvvvvv...","....vvvvvvvv....","................",
            "................","................","................","................"});
        ICONS.put("general", new String[]{
            "................",".......gg.......","......gggg......",".....gggggg.....",
            "....gggggggg....","....gggggggg....","...ggggtgggg....","...gggtggggg....",
            "....gtggggg.....",".....tgggg......","......tgg.......",".......t........",
            ".......t........","................","................","................"});
        ICONS.put("medical", new String[]{
            "................","......pp........","......pp........","......pp........",
            "..pppppppppp....","..pppppppppp....","..pppppppppp....","......pp........",
            "......pp........","......pp........","................","................",
            "................","................","................","................"});
        ICONS.put("sealing", new String[]{
            "................","..tttttttttttt..",".t............t.",".t.wwwwwwwwww.t.",
            ".t.wwwwwwwwww.t.",".t.wwkkwwkkww.t.",".t.wwwwwwwwww.t.",".t.wwwwwwwwww.t.",
            ".t.wwwwwwwwww.t.",".t............t.","..tttttttttttt..","................",
            "................","................","................","................"});
        ICONS.put("summon", new String[]{
            "................","....w..w..w.....","...ww.ww.ww.....","...ww.ww.ww.....",
            "................","....wwwwww......","...wwwwwwww.....","...wwwwwwww.....",
            "....wwwwww......",".....wwww.......","................","................",
            "................","................","................","................"});
        ICONS.put("uchiha", new String[]{
            "................","....rrrrrrrr....","...rrrrrrrrrr...","...rrrrrrrrrr...",
            "...rrrrrrrrrr...","...rrrrrrrrrr...","...wwwwwwwwww...","....wwwwwwww....",
            "......tt........","......tt........","......tt........","................",
            "................","................","................","................"});
        ICONS.put("uzumaki", new String[]{
            "................","....rrrrrrrr....","...rr......rr...","..rr..rrrr..rr..",
            "..r..rr..rr..r..","..r..r..rr...r..","..r..r..rr...r..","..r..rrrrr...r..",
            "..rr.......rr...","...rrrrrrrrr....","....rrrrrrr.....","................",
            "................","................","................","................"});
        ICONS.put("hyuga", new String[]{
            "................","....wwwwwwww....","...wwwwwwwwww...","..wwwwkkkkwwww..",
            "..wwwkkkkkkwww..","..wwwkkkkkkwww..","..wwwkkkkkkwww..","..wwwkkkkkkwww..",
            "..wwwwkkkkwwww..","...wwwwwwwwww...","....wwwwwwww....","................",
            "................","................","................","................"});
        ICONS.put("nara", new String[]{
            "................","....kkkkkkkk....","...kkkkkkkkkk...","...kkkkkkkkkk...",
            "...kkkkkkkkkk...","...kkkkkkkkkk...","...kkkkkkkkkk...","...kk.kkk.kk....",
            "....k.kkk.k.....","................","................","................",
            "................","................","................","................"});
        ICONS.put("hatake", new String[]{
            "................","......ww........","......www.......","......wwww......",
            "......wwwww.....","......wwww......","......www.......","......ww........",
            "......ww........",".....tt.........",".....tt.........","....kk..........",
            "................","................","................","................"});
        ICONS.put("sarutobi", new String[]{
            "................",".......rr.......","......rrrr......",".....rrrrrr.....",
            "....rrrrrrrr....","...rrrrrrrrrr...","....rrrrrrrr....",".....rrrrrr.....",
            "......rrrr......",".......rr.......","................","................",
            "................","................","................","................"});
        ICONS.put("kekkei", new String[]{
            "................","....v......b....","...vv.....bb....","...vv....bb.....",
            "....vv..bb......",".....vvbb.......","......vv........",".....vvbb.......",
            "....vv..bb......","...vv....bb.....","...vv.....bb....","....v......b....",
            "................","................","................","................"});
        ICONS.put("forbidden", new String[]{
            "................","..rr........rr..","...rr......rr...","....rr....rr....",
            ".....rr..rr.....","......rrrr......",".......rr.......","......rrrr......",
            ".....rr..rr.....","....rr....rr....","...rr......rr...","..rr........rr..",
            "................","................","................","................"});
        ICONS.put("lock", new String[]{
            "................",".....kkkkkk.....","....kk....kk....","....kk....kk....",
            "....kkkkkkkk....","...kkkkkkkkkk...","...kkkkwwkkkk...","...kkkkwwkkkk...",
            "...kkkkwwkkkk...","...kkkkkkkkkk...","...kkkkkkkkkk...","....kkkkkkkk....",
            "................","................","................","................"});
        ICONS.put("star", new String[]{
            "................",".......ww.......",".......ww.......","......wwww......",
            "..wwwwwwwwwwww..","...wwwwwwwwww...","....wwwwwwww....",".....wwwwww.....",
            "....wwwwwwww....","...wwww..wwww...","...ww......ww...","................",
            "................","................","................","................"});
        ICONS.put("spark", new String[]{
            "................",".......p........","......ppp.......",".......p........",
            "...p...p...p....","....p.ppp.p.....",".....ppppp......","....p.ppp.p.....",
            "...p...p...p....",".......p........","......ppp.......",".......p........",
            "................","................","................","................"});
    }

    private IconAtlas() {}

    public static boolean ready() { return ready; }

    public static void init(MinecraftClient client) {
        if (ready) return;
        try {
            int n = ICONS.size();
            atlasW = n * CELL;
            NativeImage img = new NativeImage(atlasW, CELL * 2, true);
            int slot = 0;
            for (Map.Entry<String, String[]> e : ICONS.entrySet()) {
                SLOT.put(e.getKey(), slot);
                String[] rows = e.getValue();
                for (int y = 0; y < CELL; y++) {
                    String row = (y < rows.length) ? rows[y] : "";
                    for (int x = 0; x < CELL; x++) {
                        char ch = (x < row.length()) ? row.charAt(x) : '.';
                        int c = pal(ch);
                        img.setColor(slot * CELL + x, y, abgr(c));
                        img.setColor(slot * CELL + x, CELL + y, abgr(dim(c)));
                    }
                }
                slot++;
            }
            tex = new Identifier("shinobicore", "dynamic/icon_atlas");
            client.getTextureManager().registerTexture(tex, new NativeImageBackedTexture(img));
            ready = true;
        } catch (Throwable t) {
            ready = false;
        }
    }

    /** Draw icon at size (nearest). dim = locked/dark variant. */
    public static void draw(DrawContext ctx, String key, int x, int y, int size, boolean dim) {
        if (!ready) {
            ctx.fill(x, y, x + size, y + size, 0xFF5A5060);
            return;
        }
        Integer slot = SLOT.get(key);
        if (slot == null) slot = SLOT.getOrDefault("star", 0);
        int v = dim ? CELL : 0;
        ctx.drawTexture(tex, x, y, size, size, slot * CELL, v, CELL, CELL, atlasW, CELL * 2);
    }

    public static void draw(DrawContext ctx, String key, int x, int y, int size) {
        draw(ctx, key, x, y, size, false);
    }

    private static int dim(int c) {
        if ((c >>> 24) == 0) return 0;
        int a = (c >>> 24) & 0xFF, r = (c >> 16) & 0xFF, g = (c >> 8) & 0xFF, b = c & 0xFF;
        r = (r * 35 + 58 * 65) / 100; g = (g * 35 + 49 * 65) / 100; b = (b * 35 + 64 * 65) / 100;
        return (a << 24) | (r << 16) | (g << 8) | b;
    }

    private static int pal(char ch) {
        switch (ch) {
            case 'k': return 0xFF2A2130;
            case 'K': return 0xFF141018;
            case 'w': return 0xFFF2EAF0;
            case 'r': return 0xFFFF5533;
            case 'o': return 0xFFFF9944;
            case 'y': return 0xFFFFEE44;
            case 'g': return 0xFF7ED07E;
            case 'b': return 0xFF4488FF;
            case 'c': return 0xFF66DDFF;
            case 'v': return 0xFFB48AFF;
            case 'p': return 0xFFFF9EC4;
            case 's': return 0xFFB8B8C0;
            case 'd': return 0xFF8A8A94;
            case 't': return 0xFFBB8844;
            case 'e': return 0xFF66CC99;
            default:  return 0;
        }
    }

    private static int abgr(int argb) {
        int a = (argb >>> 24) & 0xFF, r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
        return (a << 24) | (b << 16) | (g << 8) | r;
    }
}