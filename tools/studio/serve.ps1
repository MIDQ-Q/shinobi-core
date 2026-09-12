#Requires -Version 5.1
<#
================================================================================
  ShinobiCore Studio — локальный хост визуального редактора
  ============================================================================
  Поднимает HTTP-сервер на 127.0.0.1 и отдаёт браузеру редактор, который
  читает и пишет НАСТОЯЩИЕ файлы проекта. Ни Minecraft, ни Gradle, ни интернет
  не нужны. Всё остаётся внутри вашей машины: слушатель поднимается только
  на loopback, наружу порт не виден.

      powershell -ExecutionPolicy Bypass -File tools\studio\serve.ps1
      powershell -ExecutionPolicy Bypass -File tools\studio\serve.ps1 -Port 9000
      powershell -ExecutionPolicy Bypass -File tools\studio\serve.ps1 -ReadOnly
      powershell -ExecutionPolicy Bypass -File tools\studio\serve.ps1 -Once   # только дамп состояния

  Останов: Ctrl+C или закрытие окна.

  Почему сервер, а не просто HTML-файл:
    - браузер не умеет писать на диск с file:// без танцев с разрешениями;
    - loopback-сервер читает/пишет файлы сам, поэтому «Сохранить» = одна кнопка;
    - сервер отдаёт словарь движка и список файлов одним пакетом, а вся
      валидация и визуализация живут в браузере и работают мгновенно.

  Безопасность:
    - слушает ТОЛЬКО 127.0.0.1/localhost, наружу не видно;
    - запись разрешена лишь в белый список каталогов данных (см. $ALLOW);
    - любой путь нормализуется, «..» и выход за пределы проекта отклоняются;
    - -ReadOnly отключает запись полностью.

  Если Windows откажет в регистрации префикса (редко, бывает на корпоративных
  машинах с групповыми политиками), выполните один раз от администратора:
      netsh http add urlacl url=http://localhost:8420/ user=%USERNAME%
================================================================================
#>
[CmdletBinding()]
param(
    [string] $ProjectRoot,
    [int]    $Port = 8420,
    [switch] $NoBrowser,
    [switch] $ReadOnly,
    [switch] $Once,
    [string] $OnceOut
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    # tools\studio\serve.ps1  ->  корень проекта на два уровня выше
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$studioDir   = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($studioDir)) { $studioDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

$SEP = [System.IO.Path]::DirectorySeparatorChar

function Norm([string]$p) { return ($p -replace '\\', '/' -replace '/+', '/') }
function Rel([string]$full) { return (Norm $full.Substring($ProjectRoot.Length).TrimStart('/')) }
function Abs([string]$rel) {
    $n = ($rel -replace '/', [string]$SEP)
    return [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $n))
}
function ReadRaw([string]$full) {
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { return $null }
    return [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
}
$UTF8_NO_BOM = New-Object System.Text.UTF8Encoding($false)

# ---- белый список записи ------------------------------------------------------
$ALLOW = @(
    'src/main/resources/data/shinobicore/jutsu/',
    'src/main/resources/assets/shinobicore/voxels/',
    'src/main/resources/assets/shinobicore/weapon_visuals/',
    'src/main/resources/data/shinobicore/_templates/',
    'src/main/resources/data/shinobicore/clans/',
    'src/main/resources/data/shinobicore/skill_tree/',
    'src/main/resources/data/shinobicore/recipes/',
    'src/main/resources/data/shinobicore/trinkets/',
    'src/main/resources/assets/shinobicore/lang/',
    'src/main/resources/assets/shinobicore/sounds.json',
    'src/main/resources/assets/shinobicore/models/item/',
    'docs/'
)

function Test-Allowed([string]$rel) {
    $r = Norm $rel
    if ($r -match '\.\.') { return $false }
    if ($r.StartsWith('/')) { return $false }
    foreach ($a in $ALLOW) {
        if ($a.EndsWith('/')) { if ($r.StartsWith($a)) { return $true } }
        elseif ($r -eq $a)   { return $true }
    }
    return $false
}

# ---- экранирование в JSON-строку (вручную: ConvertTo-Json в PS 5.1 капризен) --
function JsonEsc([string]$s) {
    if ($null -eq $s) { return '' }
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        $code = [int]$ch
        # ВАЖНО: break/continue внутри switch влияют только на сам switch,
        # поэтому вся логика должна жить ВНУТРИ него. Иначе после выхода из
        # switch срабатывает ещё и хвостовой if — и символ экранируется дважды.
        switch ($ch) {
            '"'  { [void]$sb.Append('\"'); break }
            '\'  { [void]$sb.Append('\\'); break }
            "`b" { [void]$sb.Append('\b'); break }
            "`f" { [void]$sb.Append('\f'); break }
            "`n" { [void]$sb.Append('\n'); break }
            "`r" { [void]$sb.Append('\r'); break }
            "`t" { [void]$sb.Append('\t'); break }
            default {
                if ($code -lt 32) { [void]$sb.Append(('\u{0:x4}' -f $code)) }
                else              { [void]$sb.Append($ch) }
            }
        }
    }
    return $sb.ToString()
}
function FileEntry([string]$full) {
    $t = ReadRaw $full
    if ($null -eq $t) { return $null }
    $name = [System.IO.Path]::GetFileName($full)
    return '{"path":"' + (JsonEsc (Rel $full)) + '","name":"' + (JsonEsc $name) + '","text":"' + (JsonEsc $t) + '"}'
}
function DirEntries([string]$relDir, [string]$filter) {
    $full = Abs $relDir
    $out = New-Object System.Collections.ArrayList
    if (Test-Path -LiteralPath $full) {
        foreach ($f in @(Get-ChildItem -LiteralPath $full -Filter $filter -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
            $e = FileEntry $f.FullName
            if ($null -ne $e) { [void]$out.Add($e) }
        }
    }
    return ($out -join ',')
}

# ---- список jutsuId, на которые ссылается дерево, и реализованные пассивки ----
function Get-TreeReferencedIds([string]$treeText) {
    $ids = New-Object System.Collections.ArrayList
    if ($null -eq $treeText) { return ($ids -join ',') }
    foreach ($m in [regex]::Matches($treeText, '"jutsuId"\s*:\s*"([^"]+)"')) {
        [void]$ids.Add('"' + (JsonEsc $m.Groups[1].Value) + '"')
    }
    return ($ids -join ',')
}

function JsonArrDefaults($items) {
    $out = New-Object System.Collections.ArrayList
    foreach ($i in @($items)) {
        if ($null -eq $i) { continue }
        $kind = [string]$i['kind']; $key = [string]$i['key']; $d = ([string]$i['def']).Trim()
        $val = 'null'
        if ($kind -eq 'string') {
            $val = '"' + (JsonEsc ($d.Trim('"'))) + '"'
        } elseif ($kind -eq 'boolean') {
            $val = $(if ($d -eq 'true') { 'true' } else { 'false' })
        } elseif ($d -match '^-?\d+(\.\d+)?[fFdDlL]?$') {
            $val = ($d -replace '[fFdDlL]$', '')
        }
        [void]$out.Add('{"key":"' + (JsonEsc $key) + '","kind":"' + $kind + '","default":' + $val + '}')
    }
    return ('[' + ($out -join ',') + ']')
}

# ---- словарь движка: снимается ЖИВЬЁМ из исходников, а не хардкодом -----------
# Studio не может соврать про возможности движка: словарь строится из тех же
# switch'ей, которые исполняют технику в рантайме. Добавите case в
# EffectExecutor — при следующем обновлении страницы он появится в редакторе,
# а «ловушка» (значение enum без case) исчезнет из списка ловушек сама.
$J = 'src/main/java/com/example/shinobicore/jutsu/'

function Read-Java([string]$rel) { return ReadRaw (Abs $rel) }

# Только те файлы, которые действительно работают со свойствами техники.
# Иначе в список свойств попадают посторонние string-switch'и
# (например blockType у ConstructSystem: "earth"/"stone"/"ice"/"wood").
function Read-PropJava([string]$relDir) {
    $full = Abs $relDir
    $sb = New-Object System.Text.StringBuilder
    if (Test-Path -LiteralPath $full) {
        foreach ($f in @(Get-ChildItem -LiteralPath $full -Recurse -Filter '*.java' -File -ErrorAction SilentlyContinue | Sort-Object FullName)) {
            $t = ReadRaw $f.FullName
            if ($null -eq $t) { continue }
            if ($t -notmatch 'PropertyDefinition' -and $t -notmatch 'prop\.getId\(\)' -and $t -notmatch 'hasProp\(') { continue }
            [void]$sb.Append("`n// ==== "); [void]$sb.Append($f.Name); [void]$sb.Append("`n"); [void]$sb.Append($t)
        }
    }
    return $sb.ToString()
}

function Read-DirJava([string]$relDir) {
    $full = Abs $relDir
    $sb = New-Object System.Text.StringBuilder
    if (Test-Path -LiteralPath $full) {
        foreach ($f in @(Get-ChildItem -LiteralPath $full -Recurse -Filter '*.java' -File -ErrorAction SilentlyContinue | Sort-Object FullName)) {
            $t = ReadRaw $f.FullName
            if ($null -ne $t) { [void]$sb.Append("`n"); [void]$sb.Append($t) }
        }
    }
    return $sb.ToString()
}

function Get-EnumMap([string]$Text) {
    $map = @{}
    if ([string]::IsNullOrEmpty($Text)) { return $map }
    foreach ($m in [regex]::Matches($Text, '(?m)^\s*([A-Z][A-Z0-9_]*)\s*\(\s*"([^"]+)"')) {
        if (-not $map.ContainsKey($m.Groups[1].Value)) { $map[$m.Groups[1].Value] = $m.Groups[2].Value }
    }
    return $map
}
function Get-EnumIds([string]$Text) {
    $out = New-Object System.Collections.ArrayList
    if ([string]::IsNullOrEmpty($Text)) { return $out }
    foreach ($m in [regex]::Matches($Text, '(?m)^\s*([A-Z][A-Z0-9_]*)\s*\(\s*"([^"]+)"')) {
        $v = $m.Groups[2].Value
        if (-not ($out -contains $v)) { [void]$out.Add($v) }
    }
    return $out
}

function Get-MethodBody([string]$Text, [string]$Name) {
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    $m = [regex]::Match($Text, '[\w<>\[\],\.\s]+\s' + [regex]::Escape($Name) + '\s*\([^;\{]*\)\s*\{')
    if (-not $m.Success) { return '' }
    $i = $m.Index + $m.Length - 1
    $depth = 0
    for ($k = $i; $k -lt $Text.Length; $k++) {
        $c = $Text[$k]
        if ($c -eq '{') { $depth++ }
        elseif ($c -eq '}') { $depth--; if ($depth -eq 0) { return $Text.Substring($i, $k - $i + 1) } }
    }
    return $Text.Substring($i)
}

# Блоки arrow-switch: каждая ветка отдельно, чтобы знать параметры КАЖДОГО
# подтипа, а не свалку параметров всего метода.
function Get-CaseBlocks([string]$Body, [switch]$UpperLabels) {
    $out = New-Object System.Collections.ArrayList
    if ([string]::IsNullOrEmpty($Body)) { return $out }
    $pat = 'case\s+([A-Z][A-Z0-9_]*(?:\s*,\s*[A-Z][A-Z0-9_]*)*)\s*->'
    if (-not $UpperLabels) { $pat = 'case\s+("([^"]+)"|[A-Z][A-Z0-9_]*)\s*->' }
    $ms = [regex]::Matches($Body, $pat)
    for ($i = 0; $i -lt $ms.Count; $i++) {
        $s = $ms[$i].Index + $ms[$i].Length
        $e = $Body.Length
        if ($i + 1 -lt $ms.Count) { $e = $ms[$i + 1].Index }
        $dm = [regex]::Match($Body.Substring($s, $e - $s), '(?m)^\s*default\s*->')
        if ($dm.Success) { $e = $s + $dm.Index }
        $label = $ms[$i].Groups[1].Value.Trim()
        if ($UpperLabels) {
            foreach ($p in $label.Split(',')) {
                [void]$out.Add(@{ label = $p.Trim(); body = $Body.Substring($s, [Math]::Max(0, $e - $s)) })
            }
        } else {
            [void]$out.Add(@{ label = $label; body = $Body.Substring($s, [Math]::Max(0, $e - $s)) })
        }
    }
    return $out
}

function Get-ParamKeys([string]$Body) {
    $out = New-Object System.Collections.ArrayList
    if ([string]::IsNullOrEmpty($Body)) { return $out }
    foreach ($m in [regex]::Matches($Body, '\.get(?:Double|Int|Boolean|String|Float)\(\s*"([^"]+)"')) {
        $v = $m.Groups[1].Value
        if (-not ($out -contains $v)) { [void]$out.Add($v) }
    }
    return $out
}
function Get-ParamDefaults([string]$Body) {
    $out = New-Object System.Collections.ArrayList
    if ([string]::IsNullOrEmpty($Body)) { return $out }
    foreach ($m in [regex]::Matches($Body, '\.get(Double|Int|Boolean|String|Float)\(\s*"([^"]+)"\s*,\s*([^()]*?)\s*\)')) {
        $o = @{}
        $o['kind'] = $m.Groups[1].Value.ToLowerInvariant()
        $o['key']  = $m.Groups[2].Value
        $o['def']  = $m.Groups[3].Value.Trim()
        [void]$out.Add($o)
    }
    return $out
}
function Get-RegexLits([string]$Body, [string]$Pattern) {
    $out = New-Object System.Collections.ArrayList
    if ([string]::IsNullOrEmpty($Body)) { return $out }
    foreach ($m in [regex]::Matches($Body, $Pattern)) {
        $v = $m.Groups[1].Value
        if ($v -ne '' -and -not ($out -contains $v)) { [void]$out.Add($v) }
    }
    return $out
}

function JsonArr($items) {
    $out = New-Object System.Collections.ArrayList
    foreach ($i in @($items)) { if ($null -eq $i) { continue }; [void]$out.Add('"' + (JsonEsc ([string]$i)) + '"') }
    return ('[' + ($out -join ',') + ']')
}
function JsonObjPairs($pairs) {
    $out = New-Object System.Collections.ArrayList
    foreach ($p in @($pairs)) { if ($null -eq $p) { continue }; [void]$out.Add('"' + (JsonEsc ([string]$p[0])) + '":' + $p[1]) }
    return ('{' + ($out -join ',') + '}')
}
function JsonArrDefaults($items) {
    $out = New-Object System.Collections.ArrayList
    foreach ($i in $items) {
        $kind = [string]$i['kind']; $key = [string]$i['key']; $d = ([string]$i['def']).Trim()
        $val = 'null'
        if ($kind -eq 'string')        { $val = '"' + (JsonEsc ($d.Trim('"'))) + '"' }
        elseif ($kind -eq 'boolean')   { $val = $(if ($d -eq 'true') { 'true' } else { 'false' }) }
        elseif ($d -match '^-?\d+(\.\d+)?[fFdDlL]?$') { $val = ($d -replace '[fFdDlL]$', '') }
        [void]$out.Add('{"key":"' + (JsonEsc $key) + '","kind":"' + $kind + '","default":' + $val + '}')
    }
    return ('[' + ($out -join ',') + ']')
}
# параметры по веткам switch: { "<label>": {"params":[...],"defaults":[...]} }
function Get-SwitchHead([string]$Body) {
    if ([string]::IsNullOrEmpty($Body)) { return '' }
    $i = $Body.IndexOf('switch')
    if ($i -lt 0) { return $Body }
    return $Body.Substring(0, $i)
}
# $headKeys/$headDefs — параметры, которые метод читает ДО switch: они общие для
# всех веток. Пример: applyControl/applyBuff/applyDebuff читают "duration" один
# раз в начале, поэтому duration доступен КАЖДОМУ подтипу, а не только тем,
# у которых он встретился внутри case.
function JsonCaseParams($blocks, $map, $headKeys, $headDefs) {
    $pairs = New-Object System.Collections.ArrayList
    foreach ($b in $blocks) {
        $label = [string]$b['label']
        $id = $label
        if ($null -ne $map -and $map.ContainsKey($label)) { $id = $map[$label] }
        $id = $id.Trim('"')
        if ($id -eq '' -or $id -eq 'default') { continue }
        $body = [string]$b['body']
        $seen = $false
        foreach ($p in $pairs) { if ($p[0] -eq $id) { $seen = $true } }
        if ($seen) { continue }
        $keys = New-Object System.Collections.ArrayList
        foreach ($k in @(Get-ParamKeys $body)) { if ($null -ne $k) { [void]$keys.Add($k) } }
        foreach ($k in @($headKeys)) { if ($null -ne $k -and -not ($keys -contains $k)) { [void]$keys.Add($k) } }
        $defs = New-Object System.Collections.ArrayList
        foreach ($dd in @(Get-ParamDefaults $body)) { if ($null -ne $dd) { [void]$defs.Add($dd) } }
        foreach ($dd in @($headDefs)) {
            if ($null -eq $dd) { continue }
            $dup = $false
            foreach ($x in $defs) { if ([string]$x['key'] -eq [string]$dd['key']) { $dup = $true } }
            if (-not $dup) { [void]$defs.Add($dd) }
        }
        [void]$pairs.Add(@($id, ('{"params":' + (JsonArr $keys) +
            ',"defaults":' + (JsonArrDefaults $defs) + '}')))
    }
    return (JsonObjPairs $pairs)
}

function Get-Capabilities {
    $formT   = Read-Java ($J + 'enums/FormType.java')
    $actT    = Read-Java ($J + 'enums/ActivationType.java')
    $elemT   = Read-Java ($J + 'enums/ElementType.java')
    $resT    = Read-Java ($J + 'enums/ResourceType.java')
    $subT    = Read-Java ($J + 'enums/EffectSubType.java')
    $statT   = Read-Java 'src/main/java/com/example/shinobicore/stat/StatType.java'
    $effEx   = Read-Java ($J + 'executor/EffectExecutor.java')
    $wEx     = Read-Java ($J + 'executor/WorldEffectExecutor.java')
    $caster  = Read-Java ($J + 'executor/JutsuCaster.java')
    $formEx  = Read-Java ($J + 'executor/FormExecutor.java')
    $consSys = Read-Java ($J + 'executor/ConstructSystem.java')
    $sumSys  = Read-Java 'src/main/java/com/example/shinobicore/ai/SummonSystem.java'
    $propAll = Read-PropJava ($J + 'executor')
    $pass    = Read-Java 'src/main/java/com/example/shinobicore/tree/TreePassives.java'
    $modsnd  = Read-Java 'src/main/java/com/example/shinobicore/sound/ModSounds.java'
    $sndJson = ReadRaw (Abs 'src/main/resources/assets/shinobicore/sounds.json')
    $parser  = Read-Java 'src/main/java/com/example/shinobicore/jutsu/loader/JutsuParser.java'

    $subMap = Get-EnumMap $subT
    $actMap = Get-EnumMap $actT

    # --- стихии ----------------------------------------------------------------
    $elemPairs = New-Object System.Collections.ArrayList
    foreach ($m in [regex]::Matches([string]$elemT, '([A-Z][A-Z0-9_]*)\s*\(\s*"([^"]+)"\s*,\s*"([^"]*)"\s*,\s*0x([0-9A-Fa-f]{6})\s*,\s*(null|"([^"]*)")')) {
        $snd = $m.Groups[6].Value
        $sndLit = 'null'
        if (-not [string]::IsNullOrEmpty($snd)) { $sndLit = '"' + (JsonEsc $snd) + '"' }
        [void]$elemPairs.Add(@($m.Groups[2].Value,
            ('{"name":"' + (JsonEsc $m.Groups[3].Value) + '","color":"' + $m.Groups[4].Value + '","sound":' + $sndLit + '}')))
    }

    # --- эффекты: объявлено vs обрабатывается, параметры КАЖДОГО подтипа -------
    $declared = @{}
    foreach ($t in @('damage', 'control', 'buff', 'debuff', 'world')) { $declared[$t] = New-Object System.Collections.ArrayList }
    foreach ($m in [regex]::Matches([string]$subT, '([A-Z][A-Z0-9_]*)\s*\(\s*"([^"]+)"\s*,\s*EffectType\.([A-Z]+)')) {
        $t = $m.Groups[3].Value.ToLowerInvariant()
        if ($declared.ContainsKey($t)) { [void]$declared[$t].Add($m.Groups[2].Value) }
    }
    $effMethods = @{}
    $effMethods['damage'] = 'applyDamage'; $effMethods['control'] = 'applyControl'
    $effMethods['buff'] = 'applyBuff';     $effMethods['debuff'] = 'applyDebuff'
    $effPairs = New-Object System.Collections.ArrayList
    $trapPairs = New-Object System.Collections.ArrayList
    foreach ($t in @('damage', 'control', 'buff', 'debuff')) {
        $body = Get-MethodBody $effEx $effMethods[$t]
        $blocks = Get-CaseBlocks $body -UpperLabels
        $head = Get-SwitchHead $body
        $headKeys = Get-ParamKeys $head
        $headDefs = Get-ParamDefaults $head
        $handled = New-Object System.Collections.ArrayList
        foreach ($b in $blocks) { $l = [string]$b['label']; if ($subMap.ContainsKey($l) -and -not ($handled -contains $subMap[$l])) { [void]$handled.Add($subMap[$l]) } }
        $miss = New-Object System.Collections.ArrayList
        foreach ($d in $declared[$t]) { if (-not ($handled -contains $d)) { [void]$miss.Add($d) } }
        [void]$effPairs.Add(@($t, ('{"method":"EffectExecutor.' + $effMethods[$t] + '","handled":' + (JsonArr $handled) +
            ',"declared":' + (JsonArr $declared[$t]) + ',"params":' + (JsonArr (Get-ParamKeys $body)) +
            ',"bySubtype":' + (JsonCaseParams $blocks $subMap $headKeys $headDefs) + '}')))
        if ($miss.Count -gt 0) { [void]$trapPairs.Add(@($t, (JsonArr $miss))) }
    }
    $wBody = Get-MethodBody $wEx 'applyWorld'
    $wBlocks = Get-CaseBlocks $wBody -UpperLabels
    $wHead = Get-SwitchHead $wBody
    $wHeadKeys = Get-ParamKeys $wHead
    $wHeadDefs = Get-ParamDefaults $wHead
    $wHandled = New-Object System.Collections.ArrayList
    foreach ($b in $wBlocks) { $l = [string]$b['label']; if ($subMap.ContainsKey($l) -and -not ($wHandled -contains $subMap[$l])) { [void]$wHandled.Add($subMap[$l]) } }
    $wMiss = New-Object System.Collections.ArrayList
    foreach ($d in $declared['world']) { if (-not ($wHandled -contains $d)) { [void]$wMiss.Add($d) } }
    [void]$effPairs.Add(@('world', ('{"method":"WorldEffectExecutor.applyWorld","handled":' + (JsonArr $wHandled) +
        ',"declared":' + (JsonArr $declared['world']) + ',"params":' + (JsonArr (Get-ParamKeys $wBody)) +
        ',"bySubtype":' + (JsonCaseParams $wBlocks $subMap $wHeadKeys $wHeadDefs) + '}')))
    if ($wMiss.Count -gt 0) { [void]$trapPairs.Add(@('world', (JsonArr $wMiss))) }

    # --- активации -------------------------------------------------------------
    $castBody = Get-MethodBody $caster 'cast'
    $actBlocks = Get-CaseBlocks $castBody -UpperLabels
    $actHead = Get-SwitchHead $castBody
    $actHeadKeys = Get-ParamKeys $actHead
    $actHeadDefs = Get-ParamDefaults $actHead
    $actHandled = New-Object System.Collections.ArrayList
    foreach ($b in $actBlocks) { $l = [string]$b['label']; if ($actMap.ContainsKey($l) -and -not ($actHandled -contains $actMap[$l])) { [void]$actHandled.Add($actMap[$l]) } }
    $actDecl = Get-EnumIds $actT
    $actMiss = New-Object System.Collections.ArrayList
    foreach ($d in $actDecl) { if (-not ($actHandled -contains $d)) { [void]$actMiss.Add($d) } }
    if ($actMiss.Count -gt 0) { [void]$trapPairs.Add(@('activation', (JsonArr $actMiss))) }

    # --- формы -----------------------------------------------------------------
    $pointBody = Get-MethodBody $formEx 'executePoint'
    $projBody  = (Get-MethodBody $formEx 'executeProjectile') + "`n" + [string](Read-Java ($J + 'executor/ProjectileSystem.java'))
    $sumBody   = (Get-MethodBody $formEx 'executeSummon') + "`n" + [string]$sumSys + "`n" + [string](Read-DirJava 'src/main/java/com/example/shinobicore/ai')
    $formSrc = @{}
    $formSrc['point']      = @($pointBody)
    $formSrc['projectile'] = @($projBody)
    $formSrc['beam']       = @((Read-Java ($J + 'executor/BeamSystem.java')))
    $formSrc['zone']       = @((Read-Java ($J + 'executor/ZoneSystem.java')))
    $formSrc['dash']       = @((Read-Java ($J + 'executor/DashSystem.java')))
    $formSrc['summon']     = @($sumBody)
    $formSrc['construct']  = @($consSys)
    $formSrc['handheld']   = @((Read-Java ($J + 'executor/HandheldSystem.java')))
    $formPairs = New-Object System.Collections.ArrayList
    foreach ($fk in (Get-EnumIds $formT)) {
        $keys = New-Object System.Collections.ArrayList
        $defs = New-Object System.Collections.ArrayList
        if ($formSrc.ContainsKey($fk)) {
            foreach ($src in $formSrc[$fk]) {
                if ([string]::IsNullOrEmpty($src)) { continue }
                foreach ($k in (Get-ParamKeys $src)) { if (-not ($keys -contains $k)) { [void]$keys.Add($k) } }
                foreach ($d in (Get-ParamDefaults $src)) { [void]$defs.Add($d) }
            }
        }
        [void]$formPairs.Add(@($fk, ('{"params":' + (JsonArr $keys) + ',"defaults":' + (JsonArrDefaults $defs) + '}')))
    }

    # --- значения строковых параметров, которые движок сравнивает явно ---------
    # Get-RegexLits возвращает ArrayList, но PowerShell разворачивает коллекцию
    # из одного элемента в скаляр - поэтому результат обязательно оборачиваем.
    $tmModes = New-Object System.Collections.ArrayList
    foreach ($v in @(Get-RegexLits $pointBody 'getString\(\s*"targetMode"\s*,\s*"([^"]+)"')) { [void]$tmModes.Add($v) }
    foreach ($v in @(Get-RegexLits $pointBody 'equals(?:IgnoreCase)?\(\s*"([a-z_]+)"')) { if (-not ($tmModes -contains $v)) { [void]$tmModes.Add($v) } }
    $shapes = New-Object System.Collections.ArrayList
    foreach ($v in @(Get-RegexLits $consSys 'shape\.equals(?:IgnoreCase)?\(\s*"([^"]+)"')) { [void]$shapes.Add($v) }
    $blocks = New-Object System.Collections.ArrayList
    foreach ($v in @(Get-RegexLits $consSys 'case\s+"([a-z_]+)"\s*->\s*Blocks\.')) { [void]$blocks.Add($v) }
    $behavs = New-Object System.Collections.ArrayList
    foreach ($v in @(Get-RegexLits $sumBody 'getString\(\s*"behavior"\s*,\s*"([^"]+)"')) { [void]$behavs.Add($v) }
    foreach ($v in @(Get-RegexLits $sumBody 'behaviou?r\.equals(?:IgnoreCase)?\(\s*"([^"]+)"')) { if (-not ($behavs -contains $v)) { [void]$behavs.Add($v) } }
    foreach ($v in @(Get-RegexLits $sumBody '"([a-z_]+)"\.equals(?:IgnoreCase)?\(\s*\w*[Bb]ehaviou?r')) { if (-not ($behavs -contains $v)) { [void]$behavs.Add($v) } }
    foreach ($v in @(Get-RegexLits $sumBody 'case\s+"([a-z_]+)"\s*->')) { if (-not ($behavs -contains $v)) { [void]$behavs.Add($v) } }
    $enumPairs = New-Object System.Collections.ArrayList
    [void]$enumPairs.Add(@('point.targetMode',      (JsonArr $tmModes)))
    [void]$enumPairs.Add(@('construct.shape',       (JsonArr $shapes)))
    [void]$enumPairs.Add(@('construct.blockType',   (JsonArr $blocks)))
    [void]$enumPairs.Add(@('summon.behavior',       (JsonArr $behavs)))

    # --- свойства --------------------------------------------------------------
    $propMap = @{}
    $cm = [regex]::Matches($propAll, 'case\s+"([a-z0-9_]+)"\s*->')
    for ($ci = 0; $ci -lt $cm.Count; $ci++) {
        $id = $cm[$ci].Groups[1].Value
        $s0 = $cm[$ci].Index + $cm[$ci].Length
        $e0 = [Math]::Min($propAll.Length, $s0 + 1200)
        if ($ci + 1 -lt $cm.Count) { $e0 = [Math]::Min($e0, $cm[$ci + 1].Index) }
        $nx = [regex]::Match($propAll.Substring($s0, [Math]::Max(0, $e0 - $s0)), '(?m)^\s*(case\s|default\s*->)')
        if ($nx.Success) { $e0 = [Math]::Min($e0, $s0 + $nx.Index) }
        $mk = $propAll.IndexOf('// =====', $s0)
        if ($mk -ge 0) { $e0 = [Math]::Min($e0, $mk) }
        $body = $propAll.Substring($s0, [Math]::Max(0, $e0 - $s0))
        if (-not $propMap.ContainsKey($id)) { $propMap[$id] = New-Object System.Collections.ArrayList }
        foreach ($k in (Get-ParamKeys $body)) { if (-not ($propMap[$id] -contains $k)) { [void]$propMap[$id].Add($k) } }
    }
    foreach ($m in [regex]::Matches($propAll, 'hasProp\(\s*"([a-z0-9_]+)"')) {
        $id = $m.Groups[1].Value
        if (-not $propMap.ContainsKey($id)) { $propMap[$id] = New-Object System.Collections.ArrayList }
    }
    foreach ($m in [regex]::Matches($propAll, 'prop\(\s*"([a-z0-9_]+)"\s*\)\s*\.get(?:Double|Int|Boolean|String|Float)\(\s*"([^"]+)"')) {
        $id = $m.Groups[1].Value; $k = $m.Groups[2].Value
        if (-not $propMap.ContainsKey($id)) { $propMap[$id] = New-Object System.Collections.ArrayList }
        if (-not ($propMap[$id] -contains $k)) { [void]$propMap[$id].Add($k) }
    }
    foreach ($m in [regex]::Matches($propAll, 'getId\(\)\.equals\(\s*"([a-z0-9_]+)"')) {
        $id = $m.Groups[1].Value
        if (-not $propMap.ContainsKey($id)) { $propMap[$id] = New-Object System.Collections.ArrayList }
    }
    # PropertyDefinition pi = ctx.prop("piercing");  ...  pi.getInt("count", 3)
    # Параметр живёт не в самой строке prop(), а в переменной - идём по ней.
    foreach ($m in [regex]::Matches($propAll, '\bprop\(\s*"([a-z0-9_]+)"')) {
        $id = $m.Groups[1].Value
        if (-not $propMap.ContainsKey($id)) { $propMap[$id] = New-Object System.Collections.ArrayList }
    }
    foreach ($m in [regex]::Matches($propAll, 'PropertyDefinition\s+(\w+)\s*=\s*(?:ctx\.)?prop\(\s*"([a-z0-9_]+)"')) {
        $var = $m.Groups[1].Value; $id = $m.Groups[2].Value
        $s0 = $m.Index
        $e0 = [Math]::Min($propAll.Length, $s0 + 1500)
        $mk = $propAll.IndexOf('// =====', $s0)
        if ($mk -ge 0) { $e0 = [Math]::Min($e0, $mk) }
        $body = $propAll.Substring($s0, [Math]::Max(0, $e0 - $s0))
        if (-not $propMap.ContainsKey($id)) { $propMap[$id] = New-Object System.Collections.ArrayList }
        foreach ($k in (Get-RegexLits $body ('\b' + [regex]::Escape($var) + '\.get(?:Double|Int|Boolean|String|Float)\(\s*"([^"]+)"'))) {
            if (-not ($propMap[$id] -contains $k)) { [void]$propMap[$id].Add($k) }
        }
    }
    $propPairs = New-Object System.Collections.ArrayList
    foreach ($k in ($propMap.Keys | Sort-Object)) {
        # "earth"/"stone"/"ice"/"wood" - это blockType конструкта, а не свойства
        if ($blocks -contains $k -or $shapes -contains $k) { continue }
        [void]$propPairs.Add(@($k, (JsonArr $propMap[$k])))
    }

    # --- пассивки дерева -------------------------------------------------------
    $passIds = New-Object System.Collections.ArrayList
    foreach ($m in [regex]::Matches([string]$pass, 'case\s+"([a-z0-9_]+)"\s*->')) {
        $v = $m.Groups[1].Value
        if (-not ($passIds -contains $v)) { [void]$passIds.Add($v) }
    }

    # --- звуки -----------------------------------------------------------------
    $sndReg = New-Object System.Collections.ArrayList
    $blk = [regex]::Match([string]$modsnd, 'IDS\s*=\s*\{[^}]*\}')
    if ($blk.Success) { foreach ($m in [regex]::Matches($blk.Value, '"([^"]+)"')) { [void]$sndReg.Add($m.Groups[1].Value) } }
    $sndJsonKeys = New-Object System.Collections.ArrayList
    foreach ($m in [regex]::Matches([string]$sndJson, '(?m)^\s*"([a-z0-9_]+)"\s*:\s*\{')) { [void]$sndJsonKeys.Add($m.Groups[1].Value) }

    # --- частицы и ранги из реальных данных ------------------------------------
    $parts = New-Object System.Collections.ArrayList
    $ranksSeen = New-Object System.Collections.ArrayList
    $jdir = Abs 'src/main/resources/data/shinobicore/jutsu'
    if (Test-Path -LiteralPath $jdir) {
        foreach ($f in @(Get-ChildItem -LiteralPath $jdir -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
            $t = ReadRaw $f.FullName
            if ($null -eq $t) { continue }
            foreach ($m in [regex]::Matches($t, '"(?:particle|trail)"\s*:\s*"([^"]+)"')) {
                $v = $m.Groups[1].Value
                if (-not ($parts -contains $v)) { [void]$parts.Add($v) }
            }
            $mr = [regex]::Match($t, '"rank"\s*:\s*"([^"]+)"')
            if ($mr.Success) { $v = $mr.Groups[1].Value; if (-not ($ranksSeen -contains $v)) { [void]$ranksSeen.Add($v) } }
        }
    }
    $ranks = New-Object System.Collections.ArrayList
    foreach ($r in @('D', 'C', 'B', 'A', 'S')) { if ($ranksSeen -contains $r) { [void]$ranks.Add($r) } }
    foreach ($r in $ranksSeen) { if (-not ($ranks -contains $r)) { [void]$ranks.Add($r) } }

    # Ванильные частицы, которые имеют смысл для техник. Это ПОДСКАЗКА, а не
    # whitelist: движок передаёт строку в реестр частиц, поэтому формально
    # годится любой minecraft:<particle>. Список помечен как suggested.
    $partsSuggested = @('flame', 'small_flame', 'soul_fire_flame', 'large_smoke', 'campfire_cosy_smoke',
        'campfire_signal_smoke', 'smoke', 'poof', 'cloud', 'explosion', 'explosion_emitter',
        'splash', 'falling_water', 'rain', 'bubble', 'bubble_pop', 'dripping_water', 'dripping_lava',
        'lava', 'ash', 'white_ash', 'crimson_spore', 'warped_spore', 'electric_spark', 'flash',
        'glow', 'glow_squid_ink', 'enchant', 'enchanted_hit', 'witch', 'portal', 'reverse_portal',
        'end_rod', 'firework', 'dragon_breath', 'angry_villager', 'happy_villager', 'heart',
        'note', 'crit', 'sweep_attack', 'spit', 'snowflake', 'item_slime', 'totem_of_undying',
        'sonic_boom', 'sculk_soul', 'glow_squid_ink', 'cherry_leaves', 'snowflake')

    # --- схема JSON-файла техники: какие ключи ДЕЙСТВИТЕЛЬНО читает JutsuParser --
    # Ключевой момент: VisualDefinition читает "trail", а не "trailParticle".
    # Без этой проверки редактор мог бы предложить поле, которое loader молча
    # выбросит. Всё, что не входит в схему, валидатор помечает как «не читается».
    $topKeys = Get-RegexLits $parser 'root\.(?:has|get|getAsJsonObject|getAsJsonArray)\(\s*"([^"]+)"'
    $visKeys = Get-RegexLits (Get-MethodBody $parser 'parseVisual') 'o\.has\(\s*"([^"]+)"'
    $sndKeys = Get-RegexLits (Get-MethodBody $parser 'parseSound') 'o\.has\(\s*"([^"]+)"'
    $reqKeys = Get-RegexLits (Get-MethodBody $parser 'parseRequirements') '(?:o|rq|r)\.has\(\s*"([^"]+)"'
    $lvKeys  = Get-RegexLits (Get-MethodBody $parser 'parseLeveling') '(?:root|o|row|rq|un)\.has\(\s*"([^"]+)"'
    $schemaPairs = New-Object System.Collections.ArrayList
    [void]$schemaPairs.Add(@('top',        (JsonArr $topKeys)))
    [void]$schemaPairs.Add(@('visual',     (JsonArr $visKeys)))
    [void]$schemaPairs.Add(@('sound',      (JsonArr $sndKeys)))
    [void]$schemaPairs.Add(@('requirements', (JsonArr $reqKeys)))
    [void]$schemaPairs.Add(@('leveling',   (JsonArr $lvKeys)))

    # --- какие числовые ключи прокачки ДЕЙСТВИТЕЛЬНО потребляются --------------
    # LevelingDefinition.numericAt(level) возвращает Map<String,Double>, но
    # читает из неё JutsuCaster только "cost" и "damage". Любой другой ключ
    # в строке уровня молча игнорируется - это такая же ловушка, как и
    # buff:resistance, поэтому вычисляем её из кода, а не на глаз.
    $lvNumKeys = New-Object System.Collections.ArrayList
    $mv = [regex]::Match([string]$caster, '(\w+)\s*=\s*[\w\.()]*getLeveling\(\)\.numericAt\(')
    if ($mv.Success) {
        $vn = [regex]::Escape($mv.Groups[1].Value)
        foreach ($m in [regex]::Matches([string]$caster, $vn + '\.(?:containsKey|get)\(\s*"([^"]+)"')) {
            $v = $m.Groups[1].Value
            if (-not ($lvNumKeys -contains $v)) { [void]$lvNumKeys.Add($v) }
        }
    }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('{"generatedFromSource":true,')
    [void]$sb.Append('"levelingNumericKeys":' + (JsonArr $lvNumKeys) + ',')
    [void]$sb.Append('"schema":'            + (JsonObjPairs $schemaPairs) + ',')
    [void]$sb.Append('"forms":'              + (JsonArr (Get-EnumIds $formT)) + ',')
    [void]$sb.Append('"activations":'        + (JsonArr $actDecl) + ',')
    [void]$sb.Append('"activationHandled":'  + (JsonArr $actHandled) + ',')
    [void]$sb.Append('"activationParams":'   + (JsonCaseParams $actBlocks $actMap $actHeadKeys $actHeadDefs) + ',')
    [void]$sb.Append('"elements":'           + (JsonArr (Get-EnumIds $elemT)) + ',')
    [void]$sb.Append('"elementInfo":'        + (JsonObjPairs $elemPairs) + ',')
    [void]$sb.Append('"resources":'          + (JsonArr (Get-EnumIds $resT)) + ',')
    [void]$sb.Append('"stats":'              + (JsonArr (Get-EnumIds $statT)) + ',')
    [void]$sb.Append('"ranks":'              + (JsonArr $ranks) + ',')
    [void]$sb.Append('"effects":'            + (JsonObjPairs $effPairs) + ',')
    [void]$sb.Append('"traps":'              + (JsonObjPairs $trapPairs) + ',')
    [void]$sb.Append('"formSpecs":'          + (JsonObjPairs $formPairs) + ',')
    [void]$sb.Append('"formEnums":'          + (JsonObjPairs $enumPairs) + ',')
    [void]$sb.Append('"properties":'         + (JsonObjPairs $propPairs) + ',')
    [void]$sb.Append('"passivesImplemented":' + (JsonArr $passIds) + ',')
    [void]$sb.Append('"soundsRegistered":'     + (JsonArr $sndReg) + ',')
    [void]$sb.Append('"soundsJson":'           + (JsonArr $sndJsonKeys) + ',')
    [void]$sb.Append('"particlesSeen":'        + (JsonArr $parts) + ',')
    [void]$sb.Append('"particlesSuggested":'   + (JsonArr $partsSuggested))
    [void]$sb.Append('}')
    return $sb.ToString()
}

# ---- состояние проекта одним пакетом -----------------------------------------
function Get-StateJson {
    $treePath = Abs 'src/main/resources/data/shinobicore/skill_tree/tree.json'
    $treeText = ReadRaw $treePath
    $treeEntry = FileEntry $treePath
    if ($null -eq $treeEntry) { $treeEntry = 'null' }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('{')
    [void]$sb.Append('"generated":"' + (JsonEsc (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) + '",')
    [void]$sb.Append('"projectRoot":"' + (JsonEsc $ProjectRoot) + '",')
    [void]$sb.Append('"readOnly":' + $(if ($ReadOnly) { 'true' } else { 'false' }) + ',')
    [void]$sb.Append('"psVersion":"' + (JsonEsc $PSVersionTable.PSVersion.ToString()) + '",')
    [void]$sb.Append('"capabilities":' + (Get-Capabilities) + ',')
    [void]$sb.Append('"tree":' + $treeEntry + ',')
    [void]$sb.Append('"treeRefs":[' + (Get-TreeReferencedIds $treeText) + '],')
    [void]$sb.Append('"jutsu":['  + (DirEntries 'src/main/resources/data/shinobicore/jutsu' '*.json') + '],')
    [void]$sb.Append('"clans":['  + (DirEntries 'src/main/resources/data/shinobicore/clans' '*.json') + '],')
    [void]$sb.Append('"recipes":[' + (DirEntries 'src/main/resources/data/shinobicore/recipes' '*.json') + '],')
    [void]$sb.Append('"lang":[')
    $langs = New-Object System.Collections.ArrayList
    $langDir = Abs 'src/main/resources/assets/shinobicore/lang'
    if (Test-Path -LiteralPath $langDir) {
        foreach ($f in @(Get-ChildItem -LiteralPath $langDir -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
            $e = FileEntry $f.FullName
            if ($null -ne $e) { [void]$langs.Add($e) }
        }
    }
    [void]$sb.Append(($langs -join ','))
    [void]$sb.Append('],')
    $sndEntry = FileEntry (Abs 'src/main/resources/assets/shinobicore/sounds.json')
    if ($null -eq $sndEntry) { $sndEntry = 'null' }
    [void]$sb.Append('"voxels":['    + (DirEntries 'src/main/resources/assets/shinobicore/voxels' '*.json') + '],')
    [void]$sb.Append('"templates":[' + (DirEntries 'src/main/resources/data/shinobicore/_templates' '*.json') + '],')
    [void]$sb.Append('"formats":['   + (DirEntries 'docs/formats' '*.md') + '],')
    [void]$sb.Append('"sounds":' + $sndEntry)
    [void]$sb.Append('}')
    return $sb.ToString()
}

# ==============================================================================
#  РЕЖИМ -Once : просто выгрузить состояние (для отладки и для офлайн-режима)
# ==============================================================================
if ($Once) {
    $json = Get-StateJson
    $dest = $OnceOut
    if ([string]::IsNullOrWhiteSpace($dest)) { $dest = Join-Path $studioDir 'state.json' }
    [System.IO.File]::WriteAllText($dest, $json, $UTF8_NO_BOM)
    Write-Host ''
    Write-Host "  Состояние выгружено: $dest" -ForegroundColor Green
    Write-Host "  Байт: $($json.Length)" -ForegroundColor Gray
    Write-Host ''
    exit 0
}

# ==============================================================================
#  HTTP
# ==============================================================================
if (-not (Test-Path -LiteralPath (Join-Path $studioDir 'index.html'))) {
    Write-Host "  [FAIL] Не найден $(Join-Path $studioDir 'index.html')" -ForegroundColor Red
    exit 1
}

$prefixList = @("http://localhost:$Port/", "http://127.0.0.1:$Port/")
$listener = $null
# Сначала пробуем занять оба префикса; если HTTP.SYS отказывает — откатываемся
# на один localhost. Так браузер может ходить и по localhost, и по 127.0.0.1.
for ($take = $prefixList.Count; $take -ge 1; $take--) {
    $cand = New-Object System.Net.HttpListener
    try {
        for ($k = 0; $k -lt $take; $k++) { $cand.Prefixes.Add($prefixList[$k]) }
        $cand.Start()
        $listener = $cand
        break
    } catch {
        Write-Host "  [WARN] Не удалось занять $(($prefixList[0..($take-1)]) -join ', ') : $($_.Exception.Message)" -ForegroundColor Yellow
        try { $cand.Close() } catch { }
    }
}
if ($null -eq $listener -or -not $listener.IsListening) {
    Write-Host ''
    Write-Host '  [FAIL] HTTP-слушатель не запустился.' -ForegroundColor Red
    Write-Host '         Скорее всего порт занят или нужна регистрация префикса.' -ForegroundColor Yellow
    Write-Host "         Попробуйте другой порт:  -Port $($Port + 1)" -ForegroundColor Yellow
    Write-Host '         Либо один раз от администратора:' -ForegroundColor Yellow
    Write-Host "             netsh http add urlacl url=http://localhost:$Port/ user=%USERNAME%" -ForegroundColor Gray
    Write-Host ''
    exit 1
}

function Send-Bytes($Ctx, [int]$Status, [string]$ContentType, [byte[]]$Body) {
    try {
        $r = $Ctx.Response
        $r.StatusCode = $Status
        $r.ContentType = $ContentType
        $r.ContentEncoding = [System.Text.Encoding]::UTF8
        $r.Headers.Add('Cache-Control', 'no-store')
        $r.Headers.Add('Access-Control-Allow-Origin', '*')
        $r.Headers.Add('Access-Control-Allow-Headers', 'Content-Type')
        $r.Headers.Add('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS')
        $r.ContentLength64 = $Body.Length
        $r.OutputStream.Write($Body, 0, $Body.Length)
        $r.OutputStream.Close()
    } catch { }
}
function Send-Text($Ctx, [int]$Status, [string]$ContentType, [string]$Text) {
    Send-Bytes $Ctx $Status $ContentType ([System.Text.Encoding]::UTF8.GetBytes($Text))
}
function Send-Json($Ctx, [int]$Status, [string]$Json) {
    Send-Text $Ctx $Status 'application/json; charset=utf-8' $Json
}

$url = "http://localhost:$Port/"
Write-Host ''
Write-Host ('=' * 78) -ForegroundColor DarkCyan
Write-Host '  ShinobiCore Studio' -ForegroundColor Cyan
Write-Host ('=' * 78) -ForegroundColor DarkCyan
Write-Host "  Проект   : $ProjectRoot"
Write-Host "  Адрес    : $url"
Write-Host "  Оболочка : PowerShell $($PSVersionTable.PSVersion)"
Write-Host "  Запись   : $(if ($ReadOnly) { 'ЗАПРЕЩЕНА (-ReadOnly)' } else { 'разрешена в каталоги данных' })"
Write-Host ''
Write-Host '  Ctrl+C — остановить.' -ForegroundColor DarkGray
Write-Host ''

if (-not $NoBrowser) {
    try { Start-Process $url } catch { Write-Host "  [WARN] Не удалось открыть браузер: $($_.Exception.Message)" -ForegroundColor Yellow }
}

$requests = 0
while ($listener.IsListening) {
    $ctx = $null
    try { $ctx = $listener.GetContext() } catch { break }
    if ($null -eq $ctx) { continue }
    $requests++
    $req = $ctx.Request
    $rawUrl = [string]$req.Url.AbsolutePath
    $method = [string]$req.HttpMethod
    $stamp = Get-Date -Format 'HH:mm:ss'

    try {
        if ($method -eq 'OPTIONS') { Send-Text $ctx 204 'text/plain' ''; continue }

        # ---- статика -------------------------------------------------------
        if ($rawUrl -eq '/' -or $rawUrl -eq '/index.html') {
            $html = ReadRaw (Join-Path $studioDir 'index.html')
            if ($null -eq $html) { Send-Text $ctx 500 'text/plain' 'index.html missing'; continue }
            Write-Host "  [$stamp] GET  /  (index.html, $($html.Length) байт)" -ForegroundColor DarkGray
            Send-Text $ctx 200 'text/html; charset=utf-8' $html
            continue
        }
        if ($rawUrl -eq '/favicon.ico') { Send-Text $ctx 204 'text/plain' ''; continue }

        # ---- прочая статика студии (app.js, theme.css, *.svg) -----------------
        # Имя файла жёстко ограничено regexp'ом: ни слэшей, ни '..' — выйти за
        # пределы каталога студии нельзя.
        if ($rawUrl -match '^/([A-Za-z0-9_\-\.]+\.(js|css|svg|png|ico))$') {
            $nm = $Matches[1]
            $fp = Join-Path $studioDir $nm
            if (Test-Path -LiteralPath $fp -PathType Leaf) {
                $ct = 'text/plain; charset=utf-8'
                $ext = [System.IO.Path]::GetExtension($nm).ToLowerInvariant()
                if ($ext -eq '.js')  { $ct = 'application/javascript; charset=utf-8' }
                if ($ext -eq '.css') { $ct = 'text/css; charset=utf-8' }
                if ($ext -eq '.svg') { $ct = 'image/svg+xml' }
                if ($ext -eq '.png') { $ct = 'image/png' }
                $bytes = [System.IO.File]::ReadAllBytes($fp)
                Write-Host "  [$stamp] GET  /$nm  ($($bytes.Length) байт)" -ForegroundColor DarkGray
                Send-Bytes $ctx 200 $ct $bytes
                continue
            }
            Send-Text $ctx 404 'text/plain' 'not found'
            continue
        }

        # ---- состояние ------------------------------------------------------
        if ($rawUrl -eq '/api/state') {
            $json = Get-StateJson
            Write-Host "  [$stamp] GET  /api/state  ($($json.Length) байт)" -ForegroundColor DarkGray
            Send-Json $ctx 200 $json
            continue
        }

        # ---- перезапись состояния в браузере --------------------------------
        if ($rawUrl -eq '/api/capabilities') {
            Send-Json $ctx 200 (Get-Capabilities)
            continue
        }

        # ---- чтение одного файла -------------------------------------------
        if ($rawUrl -like '/api/file*') {
            # System.Web.HttpUtility в Windows PowerShell 5.1 не загружен, а в
            # PowerShell 7 его нет вовсе — разбираем query вручную.
            $p = $null
            foreach ($kv in ([string]$req.Url.Query).TrimStart('?').Split('&')) {
                if ($kv -eq '') { continue }
                $ix = $kv.IndexOf('=')
                if ($ix -lt 1) { continue }
                if ($kv.Substring(0, $ix) -eq 'path') {
                    $p = [System.Uri]::UnescapeDataString($kv.Substring($ix + 1))
                }
            }
            if ([string]::IsNullOrWhiteSpace($p)) { Send-Json $ctx 400 '{"ok":false,"error":"path required"}'; continue }
            $full = Abs $p
            if (-not $full.StartsWith($ProjectRoot)) { Send-Json $ctx 403 '{"ok":false,"error":"outside project"}'; continue }
            $t = ReadRaw $full
            if ($null -eq $t) { Send-Json $ctx 404 ('{"ok":false,"error":"not found"}'); continue }
            Send-Json $ctx 200 ('{"ok":true,"path":"' + (JsonEsc (Rel $full)) + '","text":"' + (JsonEsc $t) + '"}')
            continue
        }

        # ---- запись ---------------------------------------------------------
        if ($rawUrl -eq '/api/save' -and ($method -eq 'POST' -or $method -eq 'PUT')) {
            if ($ReadOnly) { Send-Json $ctx 403 '{"ok":false,"error":"server is read-only"}'; continue }
            $sr = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
            $bodyText = $sr.ReadToEnd(); $sr.Close()
            $o = $null
            try { $o = $bodyText | ConvertFrom-Json } catch { Send-Json $ctx 400 '{"ok":false,"error":"bad json body"}'; continue }
            $p = [string]$o.path
            $c = [string]$o.content
            if ([string]::IsNullOrWhiteSpace($p)) { Send-Json $ctx 400 '{"ok":false,"error":"path required"}'; continue }
            if (-not (Test-Allowed $p)) {
                Write-Host "  [$stamp] POST /api/save  ОТКАЗАНО: $p" -ForegroundColor Red
                Send-Json $ctx 403 ('{"ok":false,"error":"path not in whitelist: ' + (JsonEsc $p) + '"}')
                continue
            }
            $full = Abs $p
            if (-not $full.StartsWith($ProjectRoot)) { Send-Json $ctx 403 '{"ok":false,"error":"outside project"}'; continue }
            # страховка от битого JSON: данные игры должны парситься
            if ($full.ToLowerInvariant().EndsWith('.json')) {
                try { $null = $c | ConvertFrom-Json }
                catch {
                    Send-Json $ctx 400 ('{"ok":false,"error":"content is not valid JSON: ' + (JsonEsc $_.Exception.Message) + '"}')
                    continue
                }
            }
            $dir = [System.IO.Path]::GetDirectoryName($full)
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            [System.IO.File]::WriteAllText($full, $c, $UTF8_NO_BOM)
            Write-Host "  [$stamp] POST /api/save  $p  ($($c.Length) байт)" -ForegroundColor Green
            Send-Json $ctx 200 ('{"ok":true,"path":"' + (JsonEsc (Rel $full)) + '","bytes":' + $c.Length + '}')
            continue
        }

        # ---- удаление -------------------------------------------------------
        if ($rawUrl -eq '/api/delete' -and $method -eq 'POST') {
            if ($ReadOnly) { Send-Json $ctx 403 '{"ok":false,"error":"server is read-only"}'; continue }
            $sr = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
            $bodyText = $sr.ReadToEnd(); $sr.Close()
            $o = $bodyText | ConvertFrom-Json
            $p = [string]$o.path
            if (-not (Test-Allowed $p)) { Send-Json $ctx 403 '{"ok":false,"error":"path not in whitelist"}'; continue }
            $full = Abs $p
            if (-not $full.StartsWith($ProjectRoot)) { Send-Json $ctx 403 '{"ok":false,"error":"outside project"}'; continue }
            if (Test-Path -LiteralPath $full -PathType Leaf) {
                Remove-Item -LiteralPath $full -Force
                Write-Host "  [$stamp] POST /api/delete  $p" -ForegroundColor Yellow
                Send-Json $ctx 200 '{"ok":true}'
            } else { Send-Json $ctx 404 '{"ok":false,"error":"not found"}' }
            continue
        }

        Send-Json $ctx 404 '{"ok":false,"error":"unknown route"}'
    } catch {
        Write-Host "  [$stamp] ОШИБКА на $method $rawUrl : $($_.Exception.Message)" -ForegroundColor Red
        try { Send-Json $ctx 500 ('{"ok":false,"error":"' + (JsonEsc $_.Exception.Message) + '"}') } catch { }
    }
}

Write-Host ''
Write-Host "  Остановлено. Обработано запросов: $requests" -ForegroundColor DarkGray