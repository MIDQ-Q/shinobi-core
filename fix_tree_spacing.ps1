$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"
$res = "E:\Games\mod\src\main\resources"

Write-Host "=== FIX TREE SPACING ===" -ForegroundColor Cyan

# === [1] SkillTreeScreen.java ===
$file = "$src\client\SkillTreeScreen.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

# 1a. Плечо ветки 85 -> 160
$c = $c.Replace("private static final int BRANCH_LENGTH = 85;",
                "private static final int BRANCH_LENGTH = 160;")

# 1b. Поле zoom после hoveredNode
$c = $c.Replace("private SkillTreeNode hoveredNode = null;",
                "private SkillTreeNode hoveredNode = null;`n    private float zoom = 1.0f;")

# 1c. getNodePos учитывает zoom
$c = $c.Replace("int dist = (int)(BRANCH_LENGTH * node.distance());",
                "int dist = (int)(BRANCH_LENGTH * node.distance() * zoom);")

# 1d. Линии веток учитывают zoom
$c = $c.Replace("int endX = cx + (int)(Math.sin(rad) * BRANCH_LENGTH * (maxDist + 0.8));",
                "int endX = cx + (int)(Math.sin(rad) * BRANCH_LENGTH * (maxDist + 0.8) * zoom);")
$c = $c.Replace("int endY = cy - (int)(Math.cos(rad) * BRANCH_LENGTH * (maxDist + 0.8));",
                "int endY = cy - (int)(Math.cos(rad) * BRANCH_LENGTH * (maxDist + 0.8) * zoom);")

# 1e. Подписи веток учитывают zoom
$c = $c.Replace("int labelX = cx + (int)(Math.sin(rad) * BRANCH_LENGTH * (maxDist + 1.5));",
                "int labelX = cx + (int)(Math.sin(rad) * BRANCH_LENGTH * (maxDist + 1.5) * zoom);")
$c = $c.Replace("int labelY = cy - (int)(Math.cos(rad) * BRANCH_LENGTH * (maxDist + 1.5));",
                "int labelY = cy - (int)(Math.cos(rad) * BRANCH_LENGTH * (maxDist + 1.5) * zoom);")

# 1f. Зум колесом + обновлённая подсказка
$c = $c.Replace('drawCentered(ctx, "LMB: unlock  |  RMB drag: pan",',
                'drawCentered(ctx, "LMB: unlock  |  RMB drag: pan  |  Scroll: zoom " + (int)(zoom * 100) + "%",')

$zoomMethod = @'
    @Override public boolean mouseScrolled(double mx, double my, double amount) {
        zoom = (float)Math.max(0.6, Math.min(1.5, zoom + amount * 0.1));
        return true;
    }

    private void drawCircle(DrawContext ctx, int cx, int cy, int r, int color) {
'@
$c = $c.Replace("    private void drawCircle(DrawContext ctx, int cx, int cy, int r, int color) {", $zoomMethod)

[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[1] SkillTreeScreen: BRANCH_LENGTH=160, zoom added" -ForegroundColor Green

# === [2] tree.json — развести углы кланов в свободные зоны ===
$file = "$res\data\shinobicore\skill_tree\tree.json"
$j = [System.IO.File]::ReadAllText($file, $utf8)

# Кланы -> середины между базовыми ветками (базовые: 0/51/103/154/206/257/309)
$j = $j.Replace('"uchiha":    {"angle": 40,',  '"uchiha":    {"angle": 26,')
$j = $j.Replace('"sarutobi":  {"angle": 55,',  '"sarutobi":  {"angle": 77,')
$j = $j.Replace('"uzumaki":   {"angle": 115,', '"uzumaki":   {"angle": 129,')
$j = $j.Replace('"hatake":    {"angle": 215,', '"hatake":    {"angle": 231,')
$j = $j.Replace('"nara":      {"angle": 265,', '"nara":      {"angle": 283,')
$j = $j.Replace('"hyuga":     {"angle": 320,', '"hyuga":     {"angle": 334,')

# Мед-узлы ближе к general, чтобы не цепляли uchiha
$j = $j.Replace('"angleOffset":20', '"angleOffset":12')

[System.IO.File]::WriteAllText($file, $j, $utf8)
Write-Host "[2] tree.json: clan angles spread to free zones" -ForegroundColor Green

Write-Host "`n=== DONE ===" -ForegroundColor Cyan
Write-Host "Run: .\gradlew.bat build; .\gradlew.bat runClient" -ForegroundColor Yellow