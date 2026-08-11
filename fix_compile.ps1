$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"
Write-Host "=== FIX COMPILE ERRORS ===" -ForegroundColor Cyan

# === [1] JutsuCaster: добавить импорты TreePassives + ElementType ===
$file = "$src\jutsu\JutsuCaster.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

# Считаем импорты
$hasTreePassives = $c.Contains("import com.example.shinobicore.tree.TreePassives;")
$hasElementType = $c.Contains("import com.example.shinobicore.stat.ElementType;")

if (-not $hasTreePassives -or -not $hasElementType) {
    # Вставим импорты сразу после первого package или import
    $marker = 'import net.minecraft.server.network.ServerPlayerEntity;'
    if ($c.Contains($marker)) {
        $insert = @'
import net.minecraft.server.network.ServerPlayerEntity;
import com.example.shinobicore.tree.TreePassives;
import com.example.shinobicore.stat.ElementType;
'@
        $c = $c.Replace($marker, $insert)
        Write-Host "[1] JutsuCaster: added TreePassives + ElementType imports" -ForegroundColor Green
    } else {
        # Альтернативный маркер
        $marker2 = 'import net.minecraft.text.Text;'
        $insert2 = @'
import net.minecraft.text.Text;
import com.example.shinobicore.tree.TreePassives;
import com.example.shinobicore.stat.ElementType;
'@
        $c = $c.Replace($marker2, $insert2)
        Write-Host "[1] JutsuCaster: added imports via alt marker" -ForegroundColor Green
    }
    [System.IO.File]::WriteAllText($file, $c, $utf8)
} else {
    Write-Host "[1] JutsuCaster: imports already present" -ForegroundColor Gray
}

# === [2] PlayerParryMixin: убрать isOutOfWorld() (его нет в 1.20.1) ===
$file = "$src\mixin\PlayerParryMixin.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

# Заменяем на безопасную проверку (source != null и damage > 0)
$marker = 'if (source.isOutOfWorld()) return;'
$insert = 'if (amount <= 0) return;'
if ($c.Contains($marker)) {
    $c = $c.Replace($marker, $insert)
    Write-Host "[2] PlayerParryMixin: isOutOfWorld() -> amount check" -ForegroundColor Green
    [System.IO.File]::WriteAllText($file, $c, $utf8)
} else {
    Write-Host "[2] PlayerParryMixin: already patched" -ForegroundColor Gray
}

Write-Host "`n=== DONE ===" -ForegroundColor Cyan
Write-Host "Run: .\gradlew.bat build; .\gradlew.bat runClient" -ForegroundColor Yellow