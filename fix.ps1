# ============================================================
# EDITOR FIX: tags crash on blur (correct PowerShell quoting)
# ============================================================
$ErrorActionPreference = "Stop"
$root = "E:\Games\mod"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$editor = Join-Path $root "tools\editor\shinobi-editor-v3.html"
if (!(Test-Path $editor)) {
    $f = Get-ChildItem -Path $root -Filter "shinobi-editor*.html" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($f) { $editor = $f.FullName } else { Write-Host "[FAIL] editor not found" -ForegroundColor Red; exit 1 }
}
$html = [System.IO.File]::ReadAllText($editor, $utf8)
$changed = $false
$q = [char]39   # одинарная кавычка без адa кавычек PowerShell

# --- PATCH 1: change-handler special-cases tags (string -> array) ---
$old1 = 'if(t.dataset.p==="form.type")state.form={type:v,params:{}};else setByPath(t.dataset.p,v);render()'
$new1 = 'if(t.dataset.p==="tags"){state.tags=String(v).split(",").map(function(s){return s.trim()}).filter(Boolean)}else if(t.dataset.p==="form.type")state.form={type:v,params:{}};else setByPath(t.dataset.p,v);render()'
if ($html.Contains($new1)) { Write-Host "  [SKIP] change-handler already fixed" -ForegroundColor Yellow }
elseif ($html.Contains($old1)) {
    $html = $html.Replace($old1, $new1); $changed = $true
    Write-Host "  [PATCHED] change-handler tags" -ForegroundColor Green
} else { Write-Host "  [FAIL] change-handler pattern not found" -ForegroundColor Red }

# --- PATCH 2: defensive join in meta tab render (quotes via [char]39) ---
$old2 = 'value="' + $q + '+state.tags.join(",")+' + $q + '"'
$new2 = 'value="' + $q + '+(Array.isArray(state.tags)?state.tags:[]).join(",")+' + $q + '"'
if ($html.Contains($new2)) { Write-Host "  [SKIP] meta render already defensive" -ForegroundColor Yellow }
elseif ($html.Contains($old2)) {
    $html = $html.Replace($old2, $new2); $changed = $true
    Write-Host "  [PATCHED] meta render defensive join" -ForegroundColor Green
} else { Write-Host "  [FAIL] meta render pattern not found" -ForegroundColor Red }

# --- PATCH 3: normalize() coerces tags to array (extra safety) ---
$old3 = 'o.tags=Array.isArray(o.tags)?o.tags:[];'
$new3 = 'o.tags=Array.isArray(o.tags)?o.tags:(typeof o.tags==="string"?o.tags.split(",").map(function(s){return s.trim()}).filter(Boolean):[]);'
if ($html.Contains($new3)) { Write-Host "  [SKIP] normalize already safe" -ForegroundColor Yellow }
elseif ($html.Contains($old3)) {
    $html = $html.Replace($old3, $new3); $changed = $true
    Write-Host "  [PATCHED] normalize tags coercion" -ForegroundColor Green
} else { Write-Host "  [WARN] normalize pattern not found (non-critical)" -ForegroundColor Yellow }

if ($changed) {
    [System.IO.File]::WriteAllText($editor, $html, $utf8)
    Write-Host "`n[DONE] Editor patched. Ctrl+F5 in browser." -ForegroundColor Green
} else {
    Write-Host "`n[INFO] No changes needed." -ForegroundColor Yellow
}
Write-Host "Check: Meta -> type tags -> click elsewhere -> no error, tags stay a list." -ForegroundColor White