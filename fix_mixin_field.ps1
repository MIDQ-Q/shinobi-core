$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Укажи точный путь к файлу миксина, который нужно патчить
$file = "E:\Games\mod\src\main\java\com\example\shinobicore\mixin\ServerPlayerEntityMixin.java"

if (Test-Path $file) {
    $c = [System.IO.File]::ReadAllText($file, $utf8NoBom)
    
    if (-not $c.Contains("private NbtCompound shinobicore_attributes")) {
        # --- ТВОЯ ЛОГИКА ПАТЧИНГА ---
        # Пример вставки поля (используй here-строки, если нужно много строк)
        $oldPattern = "public abstract class ServerPlayerEntityMixin"
        $newCode = @'
public abstract class ServerPlayerEntityMixin {
    @Unique
    private NbtCompound shinobicore_attributes;
'@
        # ВНИМАНИЕ: Закрывающий '@ должен быть СТРОГО в начале строки (без пробелов)!
        
        $c = $c.Replace($oldPattern, $newCode)
        [System.IO.File]::WriteAllText($file, $c, $utf8NoBom)
        
        # ТОЛЬКО ASCII (Английский) для консоли!
        Write-Host "[OK] Field injected successfully." -ForegroundColor Green
        Write-Host "Now run: .\gradlew.bat build" -ForegroundColor Cyan
    }
    else {
        Write-Host "[SKIP] Field already exists in the file." -ForegroundColor Yellow
    }
}
else {
    Write-Host "[ERROR] File not found: $file" -ForegroundColor Red
}