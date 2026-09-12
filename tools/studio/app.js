/* =============================================================================
   ShinobiCore Studio — клиентская часть
   -----------------------------------------------------------------------------
   Всё состояние приходит одним пакетом с /api/state (serve.ps1). Файлы отдаются
   СЫРЫМ текстом, парсит их браузер — поэтому порядок полей и форматирование
   не искажаются сервером. Сохранение — POST /api/save, сервер пишет файл в
   UTF-8 без BOM и валидирует JSON до записи.

   Словарь движка (capabilities) сервер ИЗВЛЕКАЕТ ИЗ ИСХОДНИКОВ при каждом
   запросе: enum'ы, ветки switch'ей, ключи параметров и их дефолты. Поэтому
   редактор никогда не предложит значение, которое движок молча проигнорирует,
   а «ловушки» (объявлено в enum, но нет case) подсвечиваются автоматически.
   ========================================================================== */
'use strict';

/* ============================== УТИЛИТЫ ==================================== */
const $  = (s, r) => (r || document).querySelector(s);
const $$ = (s, r) => Array.prototype.slice.call((r || document).querySelectorAll(s));
function esc(s) {
  return String(s === null || s === undefined ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}
function h(html) { const t = document.createElement('template'); t.innerHTML = html.trim(); return t.content.firstChild; }
function toast(msg, kind) {
  const n = h('<div class="tst ' + (kind || '') + '">' + esc(msg) + '</div>');
  $('#toast').appendChild(n);
  setTimeout(() => { n.style.opacity = '0'; n.style.transition = 'opacity .3s'; setTimeout(() => n.remove(), 320); }, kind === 'err' ? 6000 : 3200);
}
function fmt(n, d) { if (n === null || n === undefined || isNaN(n)) return '—'; return Number(n).toFixed(d === undefined ? 2 : d).replace(/\.?0+$/, ''); }
const TICKS_PER_SEC = 20;
function ticks2s(t) { return fmt((Number(t) || 0) / TICKS_PER_SEC, 2) + ' с'; }

async function api(path, opt) {
  const r = await fetch(path, opt);
  const txt = await r.text();
  let j = null; try { j = JSON.parse(txt); } catch (e) { /* не json */ }
  if (!r.ok) throw new Error((j && j.error) || ('HTTP ' + r.status));
  return j === null ? txt : j;
}

/* ============================== СОСТОЯНИЕ ================================== */
const S = { caps: null, files: {}, projectRoot: '', readOnly: true, ps: '' };
const D = { jutsu: [], clans: [], tree: null, lang: [], sounds: null, recipes: [] };
const dirty = new Map();          // path -> текст, который уйдёт на диск
const pendingDelete = new Set();  // старые файлы после переименования
let section = 'jutsu';
let curJutsu = -1, curClan = -1, curNode = null, jutsuTab = 'general';
let treeShowClan = true;          // учитывать ли правку -FixClanBranches

function parseOr(text, path) {
  try { return JSON.parse(text); }
  catch (e) { toast('Не парсится ' + path + ': ' + e.message, 'err'); return null; }
}
function buildModel() {
  const st = S.files;
  D.jutsu = (st.jutsu || []).map(f => {
    const d = parseOr(textOf(f), f.path) || {};
    return { path: f.path, name: f.name, data: d, id: d.id || ('?' + f.name) };
  }).sort((a, b) => String(a.id).localeCompare(String(b.id)));
  D.clans = (st.clans || []).map(f => {
    const d = parseOr(textOf(f), f.path) || {};
    return { path: f.path, name: f.name, data: d, id: d.id || f.name.replace(/\.json$/, '') };
  });
  D.tree = st.tree ? { path: st.tree.path, data: parseOr(textOf(st.tree), st.tree.path) || { branches: {}, nodes: [] } } : null;
  D.lang = (st.lang || []).map(f => ({ path: f.path, name: f.name, code: f.name.replace(/\.json$/, ''), data: parseOr(textOf(f), f.path) || {} }));
  D.sounds = st.sounds ? { path: st.sounds.path, data: parseOr(textOf(st.sounds), st.sounds.path) || {} } : null;
  D.recipes = (st.recipes || []).map(f => ({ path: f.path, name: f.name, data: parseOr(textOf(f), f.path) || {} }));
}
function textOf(f) {
  if (dirty.has(f.path)) return dirty.get(f.path);
  return f.text;
}

function updateSaveUi() {
  const n = dirty.size;
  $('#btn-save').disabled = (n === 0) || S.readOnly;
  $('#save-cnt').textContent = n ? '(' + n + ')' : '';
  $('#f-status').innerHTML = n
    ? '<b style="color:var(--gold)">Не сохранено файлов: ' + n + '</b>' + (pendingDelete.size ? ' · к удалению: ' + pendingDelete.size : '')
    : 'Все изменения записаны на диск';
}
function markDirty(path, text) {
  if (!path) { updateSaveUi(); return; }
  dirty.set(path, text);
  updateSaveUi();
}
function refreshFileText(path, text) {
  // подменяем текст в исходном пакете, чтобы перечитывание не требовало сервера
  for (const k of ['jutsu', 'clans', 'lang', 'recipes']) {
    for (const f of (S.files[k] || [])) if (f.path === path) { f.text = text; }
  }
  if (S.files.tree && S.files.tree.path === path) S.files.tree.text = text;
  if (S.files.sounds && S.files.sounds.path === path) S.files.sounds.text = text;
}

async function saveAll() {
  if (!dirty.size) return;
  const list = Array.from(dirty.entries());
  let ok = 0, bad = 0;
  for (const [p, txt] of list) {
    try {
      await api('/api/save', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ path: p, content: txt })
      });
      dirty.delete(p); refreshFileText(p, txt); ok++;
    } catch (e) { bad++; toast('Не удалось сохранить ' + p + ': ' + e.message, 'err'); }
  }
  // переименованные файлы: новый уже записан, старый можно удалять
  for (const p of Array.from(pendingDelete)) {
    try {
      await api('/api/delete', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ path: p }) });
      pendingDelete.delete(p); ok++;
    } catch (e) { toast('Старый файл ' + p + ' не удалён: ' + e.message, 'err'); }
  }
  updateSaveUi();
  $('#f-status').innerHTML = 'Сохранено файлов: ' + ok + (bad ? ' · <b style="color:var(--red)">ошибок: ' + bad + '</b>' : '');
  if (ok && !bad) toast('Записано файлов: ' + ok + '. В игре выполните /reload', 'ok');
  buildModel(); renderNav(); renderSection();
}

async function loadState() {
  $('#conn').textContent = 'загрузка…';
  try {
    const st = await api('/api/state');
    S.caps = st.capabilities; S.projectRoot = st.projectRoot; S.readOnly = !!st.readOnly; S.ps = st.psVersion;
    S.files = st;
    dirty.clear();
    $('#root-label').textContent = st.projectRoot;
    $('#root-label').title = 'PowerShell ' + st.psVersion + ' · словарь движка извлечён из исходников ' + st.generated;
    $('#conn').textContent = 'подключено';
    $('#conn').style.color = 'var(--green)';
    $('#btn-save').disabled = true;
    if (S.readOnly) { $('#btn-save').title = 'Сервер запущен с -ReadOnly'; }
    buildModel(); renderNav(); renderSection();
    $('#f-status').textContent = 'Техник: ' + D.jutsu.length + ' · узлов дерева: ' + (D.tree ? D.tree.data.nodes.length : 0) + ' · кланов: ' + D.clans.length;
  } catch (e) {
    $('#conn').textContent = 'нет связи';
    $('#conn').style.color = 'var(--red)';
    $('#view').innerHTML = '<div class="card"><h3>Сервер не отвечает</h3><div class="issue err">' + esc(e.message) +
      '</div><div class="dim" style="margin-top:8px">Проверьте, что <span class="mono">tools\\studio\\serve.ps1</span> запущен и окно не закрыто.</div></div>';
  }
}

/* ============================== НАВИГАЦИЯ ================================== */
const SECTIONS = [
  { id: 'jutsu',     label: '⚔ Техники',      count: () => D.jutsu.length },
  { id: 'tree',      label: '🌳 Дерево',       count: () => (D.tree ? D.tree.data.nodes.length : 0) },
  { id: 'clans',     label: '🏯 Кланы',        count: () => D.clans.length },
  { sep: true },
  { id: 'lang',      label: '🈺 Локализация',  count: () => D.lang.length },
  { id: 'sounds',    label: '🔊 Звуки',        count: () => (D.sounds ? Object.keys(D.sounds.data).length : 0) },
  { id: 'recipes',   label: '⚒ Рецепты',       count: () => D.recipes.length },
  { sep: true },
  { id: 'validate',  label: '✔ Проверка',      count: () => countAllIssues(), bad: true },
  { id: 'dict',      label: '📖 Словарь движка', count: () => '' }
];
function countAllIssues() {
  let n = 0;
  for (const j of D.jutsu) n += validateJutsu(j.data).filter(i => i.lvl === 'err').length;
  if (D.tree) n += validateTree().filter(i => i.lvl === 'err').length;
  for (const c of D.clans) n += validateClan(c.data).filter(i => i.lvl === 'err').length;
  return n;
}
function renderNav() {
  const nav = $('#nav'); nav.innerHTML = '';
  for (const s of SECTIONS) {
    if (s.sep) { nav.appendChild(h('<div class="sep"></div>')); continue; }
    const c = s.count();
    const b = h('<button class="' + (section === s.id ? 'on' : '') + (s.bad && c > 0 ? ' bad' : '') + '">' +
      '<span>' + s.label + '</span>' + (c === '' ? '' : '<span class="cnt">' + esc(c) + '</span>') + '</button>');
    b.onclick = () => { section = s.id; renderNav(); renderSection(); };
    nav.appendChild(b);
  }
}
function renderSection() {
  const v = $('#view');
  v.scrollTop = 0;
  if (section === 'jutsu')    return renderJutsu(v);
  if (section === 'tree')     return renderTree(v);
  if (section === 'clans')    return renderClans(v);
  if (section === 'lang')     return renderLang(v);
  if (section === 'sounds')   return renderSounds(v);
  if (section === 'recipes')  return renderRecipes(v);
  if (section === 'validate') return renderValidate(v);
  if (section === 'dict')     return renderDict(v);
}

/* ============================== СЛОВАРЬ ДВИЖКА ============================= */
const C = () => S.caps || {};
function elColor(id) { const i = (C().elementInfo || {})[id]; return i ? '#' + i.color : '#888888'; }
function elName(id) { const i = (C().elementInfo || {})[id]; return i ? i.name : id; }
const RANK_BALANCE = {          // единая шкала из контент-пака Part 3
  D: { cost: 5,  dmg: 1  }, C: { cost: 10, dmg: 3  }, B: { cost: 18, dmg: 6 },
  A: { cost: 30, dmg: 10 }, S: { cost: 50, dmg: 20 }
};

/* ============================== ВАЛИДАЦИЯ ================================== */
function validateJutsu(j) {
  const out = [], c = C();
  const E = (m, w) => out.push({ lvl: 'err', msg: m, where: w || '' });
  const W = (m, w) => out.push({ lvl: 'warn', msg: m, where: w || '' });
  const I = (m, w) => out.push({ lvl: 'info', msg: m, where: w || '' });
  if (!j || typeof j !== 'object') { E('файл не парсится'); return out; }

  if (!j.id) E('нет поля id');
  else if (!/^shinobicore:/.test(j.id)) E('id должен начинаться с «shinobicore:»', j.id);
  for (const k of ['name', 'category', 'rank', 'form', 'element', 'activation'])
    if (j[k] === undefined || j[k] === null) E('отсутствует обязательное поле «' + k + '»');

  if (j.element && (c.elements || []).indexOf(j.element) < 0) E('element «' + j.element + '» не существует в ElementType');
  if (j.rank && (c.ranks || []).indexOf(j.rank) < 0) E('rank «' + j.rank + '» не существует');

  /* --- форма --- */
  const form = j.form || {};
  if (form.type) {
    if ((c.forms || []).indexOf(form.type) < 0) E('form.type «' + form.type + '» не существует', 'FormType');
    else {
      const spec = (c.formSpecs || {})[form.type] || { params: [] };
      for (const k of Object.keys(form.params || {}))
        if (spec.params.indexOf(k) < 0) W('form.params.' + k + ' не читается формой «' + form.type + '» — движок его проигнорирует',
          'читаются: ' + (spec.params.join(', ') || '—'));
      const fe = c.formEnums || {};
      if (form.type === 'point' && form.params && form.params.targetMode &&
          (fe['point.targetMode'] || []).indexOf(form.params.targetMode) < 0 && form.params.targetMode !== 'look_entity')
        W('point.targetMode «' + form.params.targetMode + '» не сравнивается в executePoint — сработает как «наведение на сущность»',
          'движок знает: ' + (fe['point.targetMode'] || []).join(', '));
      if (form.type === 'construct' && form.params) {
        if (form.params.shape && (fe['construct.shape'] || []).indexOf(form.params.shape) < 0)
          E('construct.shape «' + form.params.shape + '» не реализован', 'есть: ' + (fe['construct.shape'] || []).join(', '));
        if (form.params.blockType && (fe['construct.blockType'] || []).indexOf(form.params.blockType) < 0)
          E('construct.blockType «' + form.params.blockType + '» не реализован', 'есть: ' + (fe['construct.blockType'] || []).join(', '));
      }
      if (form.type === 'summon' && form.params && form.params.behavior &&
          (fe['summon.behavior'] || []).indexOf(form.params.behavior) < 0)
        W('summon.behavior «' + form.params.behavior + '» не встречается в коде ИИ', 'есть: ' + (fe['summon.behavior'] || []).join(', '));
    }
  } else E('нет form.type');

  /* --- активация --- */
  const act = j.activation || {};
  if (act.type) {
    const traps = (c.traps || {}).activation || [];
    if (traps.indexOf(act.type) >= 0)
      E('ЛОВУШКА: activation.type «' + act.type + '» объявлен в enum, но в JutsuCaster.cast() нет такой ветки — техника молча не сработает',
        'нужен case в JutsuCaster, либо другой тип активации');
    else if ((c.activations || []).indexOf(act.type) < 0) E('activation.type «' + act.type + '» не существует');
    else {
      const ap = (c.activationParams || {})[act.type] || { params: [] };
      for (const k of Object.keys(act.params || {}))
        if (ap.params.indexOf(k) < 0) W('activation.params.' + k + ' не читается активацией «' + act.type + '»', 'читаются: ' + (ap.params.join(', ') || '—'));
    }
  }

  /* --- эффекты --- */
  for (const e of (j.effects || [])) {
    const spec = (c.effects || {})[e.type];
    if (!spec) { E('effect.type «' + e.type + '» не существует', 'damage / control / buff / debuff / world'); continue; }
    if (!e.subtype) { E('effect без subtype', e.type); continue; }
    if (spec.handled.indexOf(e.subtype) < 0) {
      if (spec.declared.indexOf(e.subtype) >= 0)
        E('ЛОВУШКА: ' + e.type + ':' + e.subtype + ' объявлен в EffectSubType, но не обрабатывается в ' + spec.method + ' — эффект молча равен нулю',
          'обрабатываются: ' + spec.handled.join(', '));
      else
        E('effect.subtype «' + e.subtype + '» не существует для типа «' + e.type + '»', 'есть: ' + spec.declared.join(', '));
      continue;
    }
    const bs = (spec.bySubtype || {})[e.subtype] || { params: [] };
    for (const k of Object.keys(e.params || {}))
      if (bs.params.indexOf(k) < 0) W(e.type + ':' + e.subtype + ' — параметр «' + k + '» не читается', 'читаются: ' + (bs.params.join(', ') || '—'));
    if (!Object.keys(e.params || {}).length && bs.params.length)
      I(e.type + ':' + e.subtype + ' — параметры не заданы, возьмутся дефолты: ' + bs.params.join(', '));
  }
  // Формы summon / construct / dash / handheld — САМО действие: призванная
  // сущность, стена или рывок полезны и без effects. Ругаемся только на те
  // формы, у которых без эффектов буквально ничего не происходит.
  const SELF_FORMS = ['summon', 'construct', 'dash', 'handheld'];
  if (!(j.effects || []).length && SELF_FORMS.indexOf((j.form || {}).type) < 0)
    W('у техники нет ни одного эффекта — попадание ничего не сделает');

  /* --- свойства --- */
  for (const p of (j.properties || [])) {
    const known = (c.properties || {})[p.id];
    if (known === undefined) {
      E('property «' + p.id + '» не читается движком нигде', 'известные: ' + Object.keys(c.properties || {}).join(', '));
      continue;
    }
    for (const k of Object.keys(p.params || {}))
      if (known.indexOf(k) < 0) W('property «' + p.id + '»: параметр «' + k + '» не читается', 'читаются: ' + (known.join(', ') || '—'));
  }

  /* --- стоимость и требования --- */
  for (const k of Object.keys(j.cost || {}))
    if ((c.resources || []).indexOf(k) < 0) E('cost.' + k + ' не является ResourceType', 'есть: ' + (c.resources || []).join(', '));
  const rq = j.requirements || {};
  if (((c.schema || {}).requirements || []).length)
    for (const k of Object.keys(rq))
      if ((c.schema.requirements || []).indexOf(k) < 0)
        W('requirements.' + k + ' не читается parseRequirements', 'парсер знает: ' + c.schema.requirements.join(', '));
  for (const k of Object.keys(rq.stats || {}))
    if ((c.stats || []).indexOf(k) < 0) E('requirements.stats.' + k + ' не является StatType', 'есть: ' + (c.stats || []).join(', '));
  for (const k of Object.keys(rq.elements || {}))
    if ((c.elements || []).indexOf(k) < 0) E('requirements.elements.' + k + ' не является ElementType');

  /* --- схема файла: что вообще читает JutsuParser --- */
  const sch = c.schema || {};
  if ((sch.top || []).length)
    for (const k of Object.keys(j))
      if (sch.top.indexOf(k) < 0)
        E('ключ верхнего уровня «' + k + '» не читается JutsuParser — будет молча выброшен', 'парсер знает: ' + sch.top.join(', '));

  /* --- визуал / звук --- */
  const vis = j.visual || {};
  if ((sch.visual || []).length)
    for (const k of Object.keys(vis))
      if (sch.visual.indexOf(k) < 0)
        E('visual.' + k + ' не читается parseVisual — будет молча выброшен',
          k === 'trailParticle' ? 'нужен ключ «trail»' : 'парсер знает: ' + sch.visual.join(', '));
  for (const key of ['particle', 'trail']) {
    const v = vis[key];
    if (v && (c.particlesSeen || []).indexOf(v) < 0 && (c.particlesSuggested || []).indexOf(v) < 0)
      W('visual.' + key + ' «' + v + '» не встречается ни в данных, ни в списке известных ванильных частиц');
  }
  if (vis.color && !/^#?[0-9A-Fa-f]{6}$/.test(vis.color)) W('visual.color «' + vis.color + '» не похож на #RRGGBB');
  const snd = j.sound || {};
  const knownSnd = (c.soundsRegistered || []).concat(c.soundsJson || []);
  for (const k of Object.keys(snd)) {
    const v = snd[k];
    if (typeof v === 'string' && v && v.indexOf('.') < 0 && knownSnd.indexOf(v) < 0)
      W('sound.' + k + ' «' + v + '» не зарегистрирован в ModSounds и отсутствует в sounds.json');
  }

  /* --- прокачка: JutsuCaster читает из numericAt только cost и damage --- */
  const lv = j.leveling;
  if (lv && lv.levels) {
    const allowed = (c.levelingNumericKeys || ['cost', 'damage']);
    for (const k of Object.keys(lv.levels)) {
      const row = lv.levels[k] || {};
      for (const rk of Object.keys(row)) {
        if (rk === 'requirements' || rk === 'unlock') continue;
        if (typeof row[rk] !== 'number') { W('leveling.levels.' + k + '.' + rk + ' — не число, numericAt его не возьмёт'); continue; }
        if (allowed.indexOf(rk) < 0)
          W('leveling.levels.' + k + '.' + rk + ' — JutsuCaster читает из numericAt только ' + allowed.join(' и ') + ', остальное молча игнорируется');
      }
      const un = row.unlock || {};
      for (const uk of Object.keys(un))
        if (['properties', 'effects'].indexOf(uk) < 0) W('leveling.levels.' + k + '.unlock.' + uk + ' не читается parseLeveling', 'знает: properties, effects');
      for (const pid of (un.properties || []))
        if ((c.properties || {})[pid] === undefined) E('leveling.levels.' + k + ' открывает свойство «' + pid + '», которого движок не знает');
    }
    if (lv.maxLevel && lv.maxLevel > 1 && !Object.keys(lv.levels).length) W('maxLevel = ' + lv.maxLevel + ', но таблица levels пуста — прокачка ничего не меняет');
  }

  /* --- баланс --- */
  const rb = RANK_BALANCE[j.rank];
  if (rb) {
    const cost = Number((j.cost || {}).chakra || 0);
    if (cost && (cost < rb.cost * 0.5 || cost > rb.cost * 2))
      W('баланс: ранг ' + j.rank + ' ожидает ~' + rb.cost + ' чакры, задано ' + cost);
    let dmg = 0;
    for (const e of (j.effects || [])) if (e.type === 'damage') dmg += Number((e.params || {}).amount || (e.params || {}).percent || 0);
    if (dmg && (dmg < rb.dmg * 0.5 || dmg > rb.dmg * 3))
      W('баланс: ранг ' + j.rank + ' ожидает ~' + rb.dmg + ' урона, суммарно задано ' + fmt(dmg, 1));
  }
  return out;
}

function validateTree() {
  const out = [], c = C();
  if (!D.tree) return out;
  const t = D.tree.data, nodes = t.nodes || [], branches = t.branches || {};
  const E = (m, w) => out.push({ lvl: 'err', msg: m, where: w || '' });
  const W = (m, w) => out.push({ lvl: 'warn', msg: m, where: w || '' });
  const byId = {}, byJutsu = {};
  for (const n of nodes) {
    if (byId[n.id]) E('дубликат id узла «' + n.id + '» — SkillTreeRegistry делает NODES.put(id,…), первый узел молча теряется', byId[n.id].name + ' / ' + n.name);
    byId[n.id] = n;
    if (n.jutsuId) { (byJutsu[n.jutsuId] = byJutsu[n.jutsuId] || []).push(n.id); }
  }
  for (const k of Object.keys(byJutsu))
    if (byJutsu[k].length > 1) E('jutsuId «' + k + '» привязан к нескольким узлам: ' + byJutsu[k].join(', ') + ' — игрок сможет купить технику дважды');
  const ids = {};
  for (const j of D.jutsu) if (j.data.id) ids[j.data.id] = j;
  for (const n of nodes) {
    for (const r of (n.requires || [])) if (!byId[r]) E('узел «' + n.id + '» требует несуществующий «' + r + '» — ветка станет непроходимой');
    if (!branches[n.branch]) W('узел «' + n.id + '» ссылается на ветку «' + n.branch + '», которой нет в branches — цвет/подпись возьмутся по умолчанию');
    if (n.jutsuId && !ids[n.jutsuId]) E('узел «' + n.id + '» ссылается на технику «' + n.jutsuId + '», файла нет — разблокировка будет отклонена');
    if (n.type === 'passive' && (c.passivesImplemented || []).indexOf(n.id) < 0)
      W('инертная пассивка «' + n.id + '»: TreePassives.apply() переключается по ID узла и такого case не знает — игрок тратит ' + (n.spCost || 0) + ' SP впустую',
        (n.requires && n.requires.length) ? 'работает хотя бы как гейт для ' + n.requires.length + ' узл.' : 'тупиковый узел, чистая потеря SP');
    if (n.clanRequired && D.clans.map(x => x.id).indexOf(n.clanRequired) < 0)
      E('узел «' + n.id + '» требует клан «' + n.clanRequired + '», которого нет в data/clans');
  }
  for (const j of D.jutsu) {
    if (!j.data.id) continue;
    const used = Object.keys(byJutsu).indexOf(j.data.id) >= 0;
    if (!used && !/^shinobicore:test/.test(j.data.id)) W('техника «' + j.data.id + '» не привязана ни к одному узлу дерева — доступна только через /shinobicore jutsu');
  }
  for (const b of Object.keys(branches)) {
    const cnt = nodes.filter(n => n.branch === b).length;
    if (!cnt) W('ветка «' + b + '» объявлена, но узлов в ней нет');
    if (branches[b].clan && !treeShowClan) { /* см. подсказку в UI */ }
  }
  return out;
}

function validateClan(cl) {
  const out = [], c = C();
  const E = (m, w) => out.push({ lvl: 'err', msg: m, where: w || '' });
  const W = (m, w) => out.push({ lvl: 'warn', msg: m, where: w || '' });
  if (!cl.id) E('нет id');
  if (cl.affinity && (c.elements || []).indexOf(cl.affinity) < 0) E('affinity «' + cl.affinity + '» не является ElementType');
  for (const k of Object.keys(cl.statBonuses || {})) if ((c.stats || []).indexOf(k) < 0) E('statBonuses.' + k + ' не является StatType');
  for (const k of Object.keys(cl.natureBonuses || {})) if ((c.elements || []).indexOf(k) < 0) E('natureBonuses.' + k + ' не является ElementType');
  for (const k of Object.keys(cl.costMultiplier || {})) if ((c.elements || []).indexOf(k) < 0) E('costMultiplier.' + k + ' не является ElementType');
  const total = Object.values(cl.statBonuses || {}).reduce((a, b) => a + Number(b || 0), 0);
  const ref = D.clans.map(x => Object.values(x.data.statBonuses || {}).reduce((a, b) => a + Number(b || 0), 0));
  const avg = ref.length ? ref.reduce((a, b) => a + b, 0) / ref.length : total;
  if (avg && Math.abs(total - avg) > Math.max(3, avg * 0.35))
    W('бюджет статистик: у «' + (cl.id || '?') + '» сумма ' + total + ', в среднем по кланам ' + fmt(avg, 1) + ' — перекос ломает баланс выбора клана');
  if (cl.dojutsuHook === '' || cl.dojutsuHook === null) W('dojutsuHook пуст — hasDojutsu() вернёт false');
  return out;
}

function issuesHtml(list) {
  if (!list.length) return '<div class="issue info" style="border-color:var(--green);background:#1a2a1e">Ошибок и предупреждений нет</div>';
  return list.map(i => '<div class="issue ' + i.lvl + '">' +
    (i.lvl === 'err' ? '✖ ' : i.lvl === 'warn' ? '⚠ ' : 'ℹ ') + esc(i.msg) +
    (i.where ? '<div class="w">' + esc(i.where) + '</div>' : '') + '</div>').join('');
}

/* ============================== ТЕХНИКИ ==================================== */
let jFilter = { q: '', element: '', form: '', rank: '' };

function renderJutsu(v) {
  v.innerHTML =
    '<h2 class="title">Техники <span class="sub">' + D.jutsu.length + ' файл(ов) в data/shinobicore/jutsu · словарь движка снят с исходников</span></h2>' +
    '<div class="jwrap">' +
      '<div class="jlist"><div class="filters">' +
        '<input id="jq" placeholder="поиск по id / названию…" style="width:100%;margin-bottom:5px">' +
        '<div class="row tight">' +
          '<select id="jf-el" style="flex:1"><option value="">стихия</option>' + (C().elements || []).map(e => '<option value="' + e + '">' + esc(elName(e)) + '</option>').join('') + '</select>' +
          '<select id="jf-fo" style="flex:1"><option value="">форма</option>' + (C().forms || []).map(e => '<option value="' + e + '">' + e + '</option>').join('') + '</select>' +
          '<select id="jf-rk" style="flex:1"><option value="">ранг</option>' + (C().ranks || []).map(e => '<option value="' + e + '">' + e + '</option>').join('') + '</select>' +
        '</div></div><div id="jlist-items"></div></div>' +
      '<div id="jeditor"></div>' +
      '<div class="jside" id="jside"></div>' +
    '</div>';
  $('#jq').value = jFilter.q; $('#jf-el').value = jFilter.element; $('#jf-fo').value = jFilter.form; $('#jf-rk').value = jFilter.rank;
  $('#jq').oninput = e => { jFilter.q = e.target.value; renderJutsuList(); };
  $('#jf-el').onchange = e => { jFilter.element = e.target.value; renderJutsuList(); };
  $('#jf-fo').onchange = e => { jFilter.form = e.target.value; renderJutsuList(); };
  $('#jf-rk').onchange = e => { jFilter.rank = e.target.value; renderJutsuList(); };
  if (curJutsu < 0 || curJutsu >= D.jutsu.length) curJutsu = D.jutsu.length ? 0 : -1;
  renderJutsuList(); renderJutsuEditor();
}

function filteredJutsu() {
  const q = jFilter.q.toLowerCase();
  return D.jutsu.map((j, i) => ({ j, i })).filter(x => {
    const d = x.j.data;
    if (q && (String(d.id || '').toLowerCase().indexOf(q) < 0) && (String(d.name || '').toLowerCase().indexOf(q) < 0) &&
        (String(d.category || '').toLowerCase().indexOf(q) < 0) && x.j.name.toLowerCase().indexOf(q) < 0) return false;
    if (jFilter.element && d.element !== jFilter.element) return false;
    if (jFilter.form && (d.form || {}).type !== jFilter.form) return false;
    if (jFilter.rank && d.rank !== jFilter.rank) return false;
    return true;
  });
}
function renderJutsuList() {
  const box = $('#jlist-items'); if (!box) return;
  const list = filteredJutsu();
  box.innerHTML = list.length ? '' : '<div class="empty">ничего не найдено</div>';
  for (const x of list) {
    const d = x.j.data, iss = validateJutsu(d);
    const errs = iss.filter(i => i.lvl === 'err').length;
    const n = h('<div class="item ' + (x.i === curJutsu ? 'on' : '') + '">' +
      '<span class="dot" style="background:' + elColor(d.element) + '"></span>' +
      '<span class="nm">' + esc(d.name || d.id || x.j.name) + '<br><span class="dim mono" style="font-size:10px">' + esc(String(d.id || '').replace('shinobicore:', '')) + '</span></span>' +
      '<span class="rk" style="color:var(--gold)">' + esc(d.rank || '·') + '</span>' +
      (errs ? '<span class="pill" style="color:var(--red);border-color:#6b2b34">' + errs + '</span>' : '') +
      '</div>');
    n.onclick = () => { curJutsu = x.i; renderJutsuList(); renderJutsuEditor(); };
    box.appendChild(n);
  }
}

const JUTSU_TABS = [
  { id: 'general',  label: 'Общее' },
  { id: 'form',     label: 'Форма' },
  { id: 'effects',  label: 'Эффекты', n: j => ((j.effects || []).length) },
  { id: 'props',    label: 'Свойства', n: j => ((j.properties || []).length) },
  { id: 'cost',     label: 'Цена и требования' },
  { id: 'level',    label: 'Прокачка' },
  { id: 'av',       label: 'Визуал и звук' },
  { id: 'json',     label: 'JSON' }
];

function curJ() { return (curJutsu >= 0 && D.jutsu[curJutsu]) ? D.jutsu[curJutsu] : null; }

/* канонический порядок полей — совпадает с контент-паком Part 3 */
const J_ORDER = ['id', 'name', 'description', 'category', 'rank', 'tags', 'element', 'cooldown',
  'form', 'activation', 'cost', 'requirements', 'effects', 'properties', 'leveling', 'visual', 'sound'];
function canon(o) {
  const r = {};
  for (const k of J_ORDER) if (o[k] !== undefined) r[k] = o[k];
  for (const k of Object.keys(o)) if (r[k] === undefined) r[k] = o[k];
  return r;
}
function commitJ(obj) {
  const j = curJ(); if (!j) return;
  j.data = obj;
  const txt = JSON.stringify(canon(obj), null, 2) + '\n';
  markDirty(j.path, txt);
  refreshFileText(j.path, txt);
}

function renderJutsuEditor() {
  const box = $('#jeditor'), side = $('#jside');
  if (!box) return;
  const j = curJ();
  if (!j) { box.innerHTML = '<div class="card empty">Техник нет. Создайте первую кнопкой ниже.</div>'; side.innerHTML = ''; return; }
  const d = j.data, iss = validateJutsu(d);
  const errs = iss.filter(i => i.lvl === 'err').length;

  box.innerHTML =
    '<div class="card">' +
      '<div class="row" style="align-items:center;margin-bottom:10px">' +
        '<h3 style="margin:0;flex:1">' + esc(d.name || '(без названия)') +
          ' <span class="hint mono">' + esc(d.id || '') + '</span></h3>' +
        '<span class="pill" style="color:var(--gold)">' + esc(d.rank || '—') + '</span>' +
        '<span class="pill" style="color:' + elColor(d.element) + '">' + esc(elName(d.element)) + '</span>' +
        '<span class="pill">' + esc((d.form || {}).type || '—') + '</span>' +
        '<button class="btn sm" id="j-dup">⧉ Дублировать</button>' +
        '<button class="btn sm" id="j-new">＋ Новая</button>' +
      '</div>' +
      '<div class="tabs" id="jtabs"></div>' +
      '<div id="jtab-body"></div>' +
    '</div>' +
    '<div class="card"><h3>Проверка <span class="hint">' + (errs ? errs + ' ошибк(а)' : 'чисто') + '</span></h3>' + issuesHtml(iss) + '</div>';

  const tabs = $('#jtabs');
  for (const t of JUTSU_TABS) {
    const n = t.n ? t.n(d) : null;
    const b = h('<button class="' + (jutsuTab === t.id ? 'on' : '') + '">' + t.label + (n ? '<span class="n">' + n + '</span>' : '') + '</button>');
    b.onclick = () => { jutsuTab = t.id; renderJutsuEditor(); };
    tabs.appendChild(b);
  }
  $('#j-dup').onclick = () => duplicateJutsu(j);
  $('#j-new').onclick = () => newJutsu();
  renderJutsuTab($('#jtab-body'), d);
  renderSide(side, j, d, iss);
}

function field(label, controlHtml, hint) {
  return '<label class="f"><span>' + esc(label) + (hint ? ' <i class="dim" style="font-style:normal" title="' + esc(hint) + '">?</i>' : '') + '</span>' + controlHtml + '</label>';
}
function optList(arr, cur, names) {
  return arr.map(x => '<option value="' + esc(x) + '"' + (x === cur ? ' selected' : '') + '>' + esc(names ? names(x) : x) + '</option>').join('');
}
function bind(id, fn) { const e = $(id); if (e) e.onchange = ev => fn(ev.target.value); }

function renderJutsuTab(box, d) {
  const c = C();
  if (jutsuTab === 'general') {
    box.innerHTML = '<div class="grid g3">' +
      field('id (shinobicore:…)', '<input id="f-id" class="mono" value="' + esc(d.id || '') + '">', 'Меняется вместе с именем файла') +
      field('Название', '<input id="f-name" value="' + esc(d.name || '') + '">') +
      field('Категория', '<input id="f-cat" list="dl-cat" value="' + esc(d.category || '') + '">') +
      field('Ранг', '<select id="f-rank">' + optList(c.ranks || ['D', 'C', 'B', 'A', 'S'], d.rank) + '</select>', 'Определяет ожидаемую цену и урон') +
      field('Стихия', '<select id="f-el">' + optList(c.elements || [], d.element, elName) + '</select>') +
      field('Кулдаун, сек', '<input id="f-cd" type="number" step="0.1" value="' + esc(d.cooldown !== undefined ? d.cooldown : '') + '">') +
      '</div>' +
      '<div style="margin-top:9px">' + field('Описание', '<textarea id="f-desc" rows="3" style="width:100%">' + esc(d.description || '') + '</textarea>') + '</div>' +
      '<div style="margin-top:9px">' + field('Теги (через запятую)', '<input id="f-tags" class="mono" style="width:100%" value="' + esc((d.tags || []).join(', ')) + '">') + '</div>' +
      '<datalist id="dl-cat">' + Array.from(new Set(D.jutsu.map(x => x.data.category).filter(Boolean))).map(x => '<option value="' + esc(x) + '">').join('') + '</datalist>';
    bind('#f-id', v => { const old = d.id; d.id = v; renameJutsu(old, v); commitJ(d); renderJutsuEditor(); });
    bind('#f-name', v => { d.name = v; commitJ(d); renderJutsuList(); });
    bind('#f-cat', v => { d.category = v; commitJ(d); });
    bind('#f-rank', v => { d.rank = v; commitJ(d); renderJutsuEditor(); });
    bind('#f-el', v => { d.element = v; commitJ(d); renderJutsuEditor(); });
    bind('#f-cd', v => { if (v === '') delete d.cooldown; else d.cooldown = Number(v); commitJ(d); renderSide($('#jside'), curJ(), d, validateJutsu(d)); });
    bind('#f-desc', v => { d.description = v; commitJ(d); });
    bind('#f-tags', v => { const a = v.split(',').map(s => s.trim()).filter(Boolean); if (a.length) d.tags = a; else delete d.tags; commitJ(d); });
    return;
  }

  if (jutsuTab === 'form') {
    const f = d.form || (d.form = { type: 'point', params: {} });
    f.params = f.params || {};
    const spec = (c.formSpecs || {})[f.type] || { params: [], defaults: [] };
    box.innerHTML =
      '<div class="dim" style="margin-bottom:8px">Форма определяет, КАК техника доставляется. 8 примитивов — ровно столько веток в FormExecutor.</div>' +
      '<div class="row tight" id="form-btns" style="margin-bottom:10px">' +
        (c.forms || []).map(ft => '<button class="btn sm ' + (ft === f.type ? 'pri' : '') + '" data-ft="' + ft + '">' + ft + '</button>').join('') +
      '</div>' +
      '<div class="grid g3" id="form-params"></div>' +
      '<div id="form-extra" style="margin-top:9px"></div>';
    $$('#form-btns button').forEach(b => b.onclick = () => {
      f.type = b.dataset.ft; f.params = defaultParams((c.formSpecs || {})[f.type]);
      commitJ(d); renderJutsuEditor();
    });
    renderParamGrid($('#form-params'), f.params, spec, () => { commitJ(d); renderSide($('#jside'), curJ(), d, validateJutsu(d)); });
    $('#form-extra').innerHTML = formExtraHint(f.type);
    return;
  }

  if (jutsuTab === 'effects') {
    d.effects = d.effects || [];
    box.innerHTML = '<div class="dim" style="margin-bottom:8px">Каждый эффект — пара «тип : подтип» + параметры. Значения берутся из switch’ей EffectExecutor, ' +
      'поэтому подтип без ветки помечен как ЛОВУШКА и выбрать его нельзя.</div><div id="eff-list"></div>' +
      '<button class="btn sm" id="eff-add">＋ Добавить эффект</button>';
    const list = $('#eff-list');
    d.effects.forEach((e, i) => list.appendChild(effectRow(e, i, d)));
    $('#eff-add').onclick = () => { d.effects.push({ type: 'damage', subtype: 'instant', params: { amount: 8 } }); commitJ(d); renderJutsuEditor(); };
    return;
  }

  if (jutsuTab === 'props') {
    d.properties = d.properties || [];
    const known = c.properties || {};
    box.innerHTML = '<div class="dim" style="margin-bottom:8px">Свойства — модификаторы поведения. Список снят с <span class="mono">hasProp()/prop()/case "…" -&gt;</span> ' +
      'в executor-пакете, параметры — с реальных вызовов <span class="mono">getInt/getDouble</span>.</div>' +
      '<div id="prop-list"></div><button class="btn sm" id="prop-add">＋ Добавить свойство</button>';
    const list = $('#prop-list');
    d.properties.forEach((p, i) => list.appendChild(propRow(p, i, d, known)));
    $('#prop-add').onclick = () => {
      const first = Object.keys(known)[0] || 'piercing';
      d.properties.push({ id: first, params: {} }); commitJ(d); renderJutsuEditor();
    };
    return;
  }

  if (jutsuTab === 'cost') {
    d.cost = d.cost || {}; d.requirements = d.requirements || {};
    const rq = d.requirements;
    box.innerHTML =
      '<div class="grid g3">' + (c.resources || []).map(r =>
        field('cost.' + r, '<input type="number" data-cost="' + r + '" value="' + esc(d.cost[r] !== undefined ? d.cost[r] : '') + '" placeholder="0">')).join('') + '</div>' +
      '<h3 style="margin:14px 0 8px;font-size:12px;color:var(--sakura);text-transform:uppercase;letter-spacing:.8px">Требования для изучения</h3>' +
      '<div class="grid g4">' +
        field('Использований (uses)', '<input type="number" id="rq-uses" value="' + esc(rq.uses !== undefined ? rq.uses : '') + '">') +
        field('Очков навыков (sp)', '<input type="number" id="rq-sp" value="' + esc(rq.sp !== undefined ? rq.sp : '') + '">') +
        field('Додзюцу', '<input id="rq-doj" list="dl-doj" value="' + esc(rq.dojutsu || '') + '" placeholder="sharingan / byakugan…">') +
        '<div></div>' +
      '</div>' +
      '<div style="margin-top:9px"><b class="dim" style="font-size:11px">requirements.stats</b><div class="grid g4" style="margin-top:5px">' +
        (c.stats || []).map(s => field(s, '<input type="number" data-stat="' + s + '" value="' + esc((rq.stats || {})[s] !== undefined ? rq.stats[s] : '') + '" placeholder="0">')).join('') + '</div></div>' +
      '<div style="margin-top:9px"><b class="dim" style="font-size:11px">requirements.elements</b><div class="grid g4" style="margin-top:5px">' +
        (c.elements || []).filter(e => e !== 'none').map(e => field(e, '<input type="number" data-elem="' + e + '" value="' + esc((rq.elements || {})[e] !== undefined ? rq.elements[e] : '') + '" placeholder="0">')).join('') + '</div></div>' +
      '<datalist id="dl-doj"><option value="sharingan"><option value="byakugan"><option value="rinnegan"></datalist>';
    $$('[data-cost]').forEach(i => i.onchange = e => {
      const v = e.target.value; if (v === '') delete d.cost[i.dataset.cost]; else d.cost[i.dataset.cost] = Number(v);
      if (!Object.keys(d.cost).length) delete d.cost;
      commitJ(d); renderSide($('#jside'), curJ(), d, validateJutsu(d));
    });
    $$('[data-stat]').forEach(i => i.onchange = e => {
      rq.stats = rq.stats || {}; const v = e.target.value;
      if (v === '') delete rq.stats[i.dataset.stat]; else rq.stats[i.dataset.stat] = Number(v);
      if (!Object.keys(rq.stats).length) delete rq.stats; commitJ(d);
    });
    $$('[data-elem]').forEach(i => i.onchange = e => {
      rq.elements = rq.elements || {}; const v = e.target.value;
      if (v === '') delete rq.elements[i.dataset.elem]; else rq.elements[i.dataset.elem] = Number(v);
      if (!Object.keys(rq.elements).length) delete rq.elements; commitJ(d);
    });
    bind('#rq-uses', v => { if (v === '') delete rq.uses; else rq.uses = Number(v); commitJ(d); });
    bind('#rq-sp', v => { if (v === '') delete rq.sp; else rq.sp = Number(v); commitJ(d); });
    bind('#rq-doj', v => { if (!v) delete rq.dojutsu; else rq.dojutsu = v; commitJ(d); });
    return;
  }

  if (jutsuTab === 'level') {
    const lv = d.leveling;
    box.innerHTML = '<div class="dim" style="margin-bottom:8px">Прокачка техники: на каждом уровне можно поднять числовые параметры, ' +
      'открыть новые свойства и добавить эффекты. Значение на уровне L = ближайшая заданная строка &lt;= L (LevelingDefinition.numericAt).</div>' +
      (lv ? '<div class="grid g2" style="max-width:280px">' + field('Максимальный уровень', '<input type="number" id="lv-max" value="' + esc(lv.maxLevel || 1) + '">', '') + '</div>' +
            '<div id="lv-rows" style="margin-top:10px"></div><button class="btn sm" id="lv-add">＋ Добавить уровень</button>' +
            '<button class="btn sm" id="lv-off">Убрать прокачку</button>'
          : '<button class="btn" id="lv-on">Включить прокачку</button>');
    if (!lv) { $('#lv-on').onclick = () => { d.leveling = { maxLevel: 3, levels: { 1: {}, 2: {}, 3: {} } }; commitJ(d); renderJutsuEditor(); }; return; }
    lv.levels = lv.levels || {};
    bind('#lv-max', v => { lv.maxLevel = Math.max(1, Number(v) || 1); commitJ(d); });
    const rows = $('#lv-rows');
    Object.keys(lv.levels).sort((a, b) => a - b).forEach(k => rows.appendChild(levelRow(k, lv, d)));
    $('#lv-add').onclick = () => {
      const ks = Object.keys(lv.levels).map(Number);
      const nx = ks.length ? Math.max.apply(null, ks) + 1 : 1;
      lv.levels[nx] = {}; lv.maxLevel = Math.max(lv.maxLevel || 1, nx); commitJ(d); renderJutsuEditor();
    };
    $('#lv-off').onclick = () => { delete d.leveling; commitJ(d); renderJutsuEditor(); };
    return;
  }

  if (jutsuTab === 'av') {
    d.visual = d.visual || {}; d.sound = d.sound || {};
    const vis = d.visual, snd = d.sound, c2 = c;
    box.innerHTML =
      '<div class="grid g3">' +
        field('Частица', '<input id="v-part" list="dl-part" value="' + esc(vis.particle || '') + '">') +
        field('Частица следа (visual.trail)', '<input id="v-trail" list="dl-part" value="' + esc(vis.trail || '') + '">', 'JutsuParser.parseVisual читает ключ «trail», а НЕ «trailParticle»') +
        field('Цвет #RRGGBB', '<div class="row tight"><input id="v-color" class="mono" value="' + esc(vis.color || '') + '" style="flex:1"><input type="color" id="v-colorp" value="' + esc(/^#?[0-9a-fA-F]{6}$/.test(vis.color || '') ? '#' + String(vis.color).replace('#', '') : '#ff9ec4') + '"></div>') +
        field('Масштаб', '<input id="v-scale" type="number" step="0.1" value="' + esc(vis.scale !== undefined ? vis.scale : '') + '">') +
        field('Свечение', '<select id="v-glow"><option value="">—</option><option value="true"' + (vis.glow === true ? ' selected' : '') + '>да</option><option value="false"' + (vis.glow === false ? ' selected' : '') + '>нет</option></select>') +
        field('Воксельная модель', '<input id="v-voxel" value="' + esc(vis.voxelModel || '') + '" placeholder="путь к модели">') +
      '</div>' +
      '<datalist id="dl-part">' + Array.from(new Set((c2.particlesSeen || []).concat(c2.particlesSuggested || []))).map(x => '<option value="' + esc(x) + '">').join('') + '</datalist>' +
      '<h3 style="margin:14px 0 8px;font-size:12px;color:var(--sakura);text-transform:uppercase;letter-spacing:.8px">Звук <span class="hint">SoundDefinition: cast / hit / loop / end</span></h3>' +
      '<div class="grid g4">' + ['cast', 'hit', 'loop', 'end'].map(k =>
        field('sound.' + k, '<input id="s-' + k + '" list="dl-snd" value="' + esc(snd[k] || '') + '">')).join('') + '</div>' +
      '<datalist id="dl-snd">' + Array.from(new Set((c2.soundsRegistered || []).map(x => 'shinobicore:' + x).concat(c2.soundsRegistered || []))).map(x => '<option value="' + esc(x) + '">').join('') + '</datalist>' +
      '<div class="dim" style="margin-top:8px">Зарегистрировано SoundEvent: ' + (c2.soundsRegistered || []).length +
      ' · записей в sounds.json: ' + (c2.soundsJson || []).length + '. Звук по умолчанию берётся из ElementType, если поле пустое.</div>';
    const setV = (k, cast) => v => { if (v === '' || v === null) delete vis[k]; else vis[k] = cast ? cast(v) : v;
      if (!Object.keys(vis).length) delete d.visual; commitJ(d); renderSide($('#jside'), curJ(), d, validateJutsu(d)); };
    bind('#v-part', setV('particle')); bind('#v-trail', setV('trail'));
    if (vis.trailParticle !== undefined) {
      $('#v-trail').className = 'bad';
      $('#v-trail').value = vis.trailParticle;
    }
    bind('#v-color', v => { vis.color = v; commitJ(d); renderSide($('#jside'), curJ(), d, validateJutsu(d)); });
    $('#v-colorp').oninput = e => { $('#v-color').value = e.target.value; vis.color = e.target.value; commitJ(d); renderSide($('#jside'), curJ(), d, validateJutsu(d)); };
    bind('#v-scale', setV('scale', Number)); bind('#v-voxel', setV('voxelModel'));
    bind('#v-glow', v => { if (v === '') delete vis.glow; else vis.glow = (v === 'true'); if (!Object.keys(vis).length) delete d.visual; commitJ(d); });
    ['cast', 'hit', 'loop', 'end'].forEach(k => bind('#s-' + k, v => {
      if (!v) delete snd[k]; else snd[k] = v;
      if (!Object.keys(snd).length) delete d.sound; commitJ(d);
    }));
    return;
  }

  if (jutsuTab === 'json') {
    const iss = validateJutsu(d);
    box.innerHTML = '<div class="dim" style="margin-bottom:7px">Итоговый файл. Сохранение пишет его в <span class="mono">' + esc(curJ().path) + '</span> в UTF-8 без BOM (Gson не любит BOM).</div>' +
      '<pre class="json mono">' + esc(JSON.stringify(canon(d), null, 2)) + '</pre>' +
      '<div class="row" style="margin-top:8px"><button class="btn sm" id="j-copy">⧉ Скопировать</button>' +
      '<button class="btn sm" id="j-revert">↺ Отменить правки файла</button>' +
      '<span class="dim" style="align-self:center">' + (iss.filter(i => i.lvl === 'err').length ? 'есть ошибки — см. блок «Проверка»' : 'ошибок нет') + '</span></div>';
    $('#j-copy').onclick = () => { navigator.clipboard.writeText(JSON.stringify(canon(d), null, 2)).then(() => toast('JSON скопирован', 'ok'), () => toast('Буфер обмена недоступен', 'err')); };
    $('#j-revert').onclick = () => {
      const j2 = curJ(); dirty.delete(j2.path);
      const orig = (S.files.jutsu || []).find(f => f.path === j2.path);
      j2.data = JSON.parse(orig.text);
      markDirty('', ''); renderJutsuEditor(); toast('Правки файла отменены');
    };
    return;
  }
}

function defaultParams(spec) {
  const p = {};
  for (const d of ((spec || {}).defaults || [])) if (d.default !== null) p[d.key] = d.default;
  return p;
}
function formExtraHint(ft) {
  const c = C(), fe = c.formEnums || {};
  const t = {
    point: 'targetMode: <b>self</b> — эффект на себе, <b>raycast_point</b> — точка под прицелом (нужен хотя бы один эффект world), любое другое значение — наведение на ближайшую сущность в пределах range.',
    projectile: 'Интеграция настоящая: каждый тик <span class="mono">pos += vel; vel.y -= gravity</span>. Дальность ≈ speed·lifetime блоков, падение ≈ gravity·lifetime²/2. 20 тиков = 1 секунда.',
    beam: 'Луч живёт duration тиков и бьёт каждые tickRate тиков. Свойство <b>channeled</b> добавляет расход chakraPerTick.',
    zone: 'Зона существует duration тиков, эффекты применяются каждые tickRate тиков внутри radius.',
    dash: 'Рывок на distance блоков; длительность = distance / max(0.5, speed) · 5 тиков. damageOnPath — урон всем на пути.',
    summon: 'behavior: ' + ((fe['summon.behavior'] || []).join(', ') || '—') + '. jutsus — список техник, которыми призванная сущность будет кастовать (через запятую).',
    construct: 'shape: ' + ((fe['construct.shape'] || []).join(', ') || '—') + ' · blockType: ' + ((fe['construct.blockType'] || []).join(', ') || '—') +
      '. Именно одна фигура — для «сэндвича» из двух стен нужен второй вызов construct (см. earth_sandwich в отчёте Part 3).',
    handheld: 'Объект в руке: chargeTime тиков на зарядку, holdDuration тиков удержания. Свойство <b>throwable</b> делает его метательным.'
  };
  return '<div class="issue info">' + (t[ft] || '') + '</div>';
}

/* --- сетка параметров с подсказками дефолтов ------------------------------- */
function renderParamGrid(box, params, spec, onChange) {
  const known = spec.params || [];
  const defs = {}; for (const d of (spec.defaults || [])) if (defs[d.key] === undefined) defs[d.key] = d;
  const keys = known.slice();
  for (const k of Object.keys(params)) if (keys.indexOf(k) < 0) keys.push(k);
  if (!keys.length) { box.innerHTML = '<div class="dim">У этой формы нет читаемых параметров.</div>'; return; }
  box.innerHTML = keys.map(k => {
    const d = defs[k];
    const unknown = known.indexOf(k) < 0;
    const ph = d ? ('дефолт ' + d.default) : '';
    return '<label class="f"><span style="' + (unknown ? 'color:var(--red)' : '') + '">' + esc(k) +
      (unknown ? ' ⚠' : '') + (d ? ' <i class="dim" style="font-style:normal">· ' + esc(d.kind) + '</i>' : '') + '</span>' +
      '<input data-pk="' + esc(k) + '" class="mono ' + (unknown ? 'bad' : '') + '" value="' + esc(params[k] !== undefined ? params[k] : '') + '" placeholder="' + esc(ph) + '"></label>';
  }).join('');
  $$('[data-pk]', box).forEach(inp => inp.onchange = e => {
    const k = inp.dataset.pk, v = e.target.value;
    if (v === '') { delete params[k]; }
    else {
      const d = defs[k];
      const kind = d ? d.kind : (v.match(/^-?\d+$/) ? 'int' : (v.match(/^-?\d*\.\d+$/) ? 'double' : 'string'));
      params[k] = (kind === 'int') ? parseInt(v, 10) : (kind === 'double' || kind === 'float') ? Number(v) : (kind === 'boolean') ? (v === 'true') : v;
      if (isNaN(params[k])) params[k] = v;
    }
    onChange();
    const iss = validateJutsu(curJ().data);
    e.target.className = 'mono ' + (iss.some(i => i.lvl === 'err' && i.msg.indexOf(k) >= 0) ? 'bad' : '');
  });
}

/* --- строка эффекта -------------------------------------------------------- */
function effectRow(e, i, d) {
  const c = C(), spec = (c.effects || {})[e.type] || { handled: [], declared: [], bySubtype: {} };
  const traps = (c.traps || {})[e.type] || [];
  const wrap = h('<div class="rep"></div>');
  wrap.innerHTML =
    '<button class="btn sm danger rm" title="Удалить эффект">✕</button>' +
    '<div class="hd"><b style="color:var(--sakura)">эффект #' + (i + 1) + '</b></div>' +
    '<div class="grid g3">' +
      field('Тип', '<select data-e="type">' + optList(Object.keys(c.effects || {}), e.type) + '</select>') +
      field('Подтип', '<select data-e="subtype">' +
        spec.declared.map(s => {
          const isTrap = spec.handled.indexOf(s) < 0;
          return '<option value="' + esc(s) + '"' + (s === e.subtype ? ' selected' : '') + (isTrap ? ' style="color:#ff6b7a"' : '') + '>' +
            esc(s) + (isTrap ? '  ⚠ ЛОВУШКА (no-op)' : '') + '</option>';
        }).join('') + '</select>', 'Красным — объявлен в enum, но не обрабатывается') +
      '<div></div>' +
    '</div>' +
    (traps.length ? '<div class="issue err" style="margin-top:6px">В типе «' + esc(e.type) + '» есть ловушк' + (traps.length > 1 ? 'и' : 'а') + ': ' + esc(traps.join(', ')) + ' — движок их молча игнорирует.</div>' : '') +
    '<div class="grid g3" style="margin-top:8px" data-params></div>';
  $('.rm', wrap).onclick = () => { d.effects.splice(i, 1); commitJ(d); renderJutsuEditor(); };
  $$('[data-e]', wrap).forEach(sel => sel.onchange = ev => {
    const k = sel.dataset.e;
    e[k] = ev.target.value;
    if (k === 'type') { const ns = (C().effects || {})[e.type]; e.subtype = ns && ns.handled[0]; e.params = {}; }
    commitJ(d); renderJutsuEditor();
  });
  const bs = (spec.bySubtype || {})[e.subtype] || { params: [], defaults: [] };
  e.params = e.params || {};
  renderParamGrid($('[data-params]', wrap), e.params, bs, () => { commitJ(d); renderSide($('#jside'), curJ(), d, validateJutsu(d)); });
  return wrap;
}

/* --- строка свойства ------------------------------------------------------- */
function propRow(p, i, d, known) {
  const wrap = h('<div class="rep"></div>');
  const ids = Object.keys(known);
  wrap.innerHTML =
    '<button class="btn sm danger rm">✕</button>' +
    '<div class="grid g3">' +
      field('Свойство', '<select data-p="id">' + ids.map(x => '<option value="' + esc(x) + '"' + (x === p.id ? ' selected' : '') + '>' + esc(x) + '</option>').join('') + '</select>') +
      '<div></div><div></div>' +
    '</div><div class="grid g3" style="margin-top:8px" data-params></div>';
  $('.rm', wrap).onclick = () => { d.properties.splice(i, 1); commitJ(d); renderJutsuEditor(); };
  $('[data-p]', wrap).onchange = ev => { p.id = ev.target.value; p.params = {}; commitJ(d); renderJutsuEditor(); };
  p.params = p.params || {};
  const keys = known[p.id] || [];
  const spec = { params: keys, defaults: keys.map(k => ({ key: k, kind: 'double', default: null })) };
  renderParamGrid($('[data-params]', wrap), p.params, spec, () => commitJ(d));
  if (!keys.length) $('[data-params]', wrap).innerHTML = '<div class="dim">Флаг: параметров не читает.</div>';
  return wrap;
}

/* --- строка уровня прокачки ------------------------------------------------
   Схема снята с JutsuParser.parseLeveling + JutsuCaster:
     levels."<N>": { <любые числовые ключи>, requirements:{uses,sp,stats,elements},
                     unlock:{properties:[],effects:[]} }
   JutsuCaster читает из numericAt(level) ТОЛЬКО "cost" (переопределяет расход
   чакры) и "damage" (масштабирует ВЕСЬ урон как damage / firstTableDamage).
   Любой другой числовой ключ попадёт в map и будет молча проигнорирован.     */
function levelRow(k, lv, d) {
  const L = lv.levels[k] || (lv.levels[k] = {});
  const allowed = C().levelingNumericKeys || ['cost', 'damage'];
  const numeric = Object.keys(L).filter(x => x !== 'requirements' && x !== 'unlock');
  const rq = L.requirements || {}, un = L.unlock || {};
  const wrap = h('<div class="rep"></div>');
  wrap.innerHTML =
    '<button class="btn sm danger rm">✕</button>' +
    '<div class="hd"><b style="color:var(--gold)">уровень ' + esc(k) + '</b>' +
      '<span class="dim" style="font-size:11px">строка таблицы применяется ко всем уровням &gt;= ' + esc(k) + ' (numericAt берёт ближайшую сверху)</span></div>' +
    '<div class="grid g3" data-nums></div>' +
    '<div class="row tight" style="margin-top:6px"><button class="btn sm" data-addnum>＋ числовой параметр</button>' +
      '<span class="dim" style="align-self:center">движок читает только <b class="mono">' + esc(allowed.join('</b> и <b class="mono">')) + '</b></span></div>' +
    '<div class="grid g2" style="margin-top:9px">' +
      field('requirements (JSON)', '<textarea rows="3" class="mono" data-rq style="width:100%">' + esc(JSON.stringify(rq, null, 1)) + '</textarea>',
        'uses, sp, stats{StatType}, elements{ElementType}') +
      field('unlock.properties (через запятую)', '<input class="mono" data-unp value="' + esc((un.properties || []).join(', ')) + '">' +
        '<span class="dim" style="font-size:10.5px;margin-top:4px">unlock.effects (JSON-массив):</span>' +
        '<textarea rows="3" class="mono" data-une style="width:100%;margin-top:3px">' + esc(JSON.stringify(un.effects || [], null, 1)) + '</textarea>') +
    '</div>';
  $('.rm', wrap).onclick = () => { delete lv.levels[k]; commitJ(d); renderJutsuEditor(); };

  const drawNums = () => {
    const box = $('[data-nums]', wrap);
    const keys = Object.keys(L).filter(x => x !== 'requirements' && x !== 'unlock');
    box.innerHTML = keys.length ? keys.map(kk =>
      '<label class="f"><span style="' + (allowed.indexOf(kk) < 0 ? 'color:var(--red)' : '') + '">' + esc(kk) +
      (allowed.indexOf(kk) < 0 ? ' ⚠ не читается' : '') + '</span>' +
      '<div class="row tight"><input type="number" step="0.01" class="mono" data-nk="' + esc(kk) + '" value="' + esc(L[kk]) + '" style="flex:1">' +
      '<button class="btn sm danger" data-nd="' + esc(kk) + '">✕</button></div></label>').join('') : '<div class="dim">Числовых параметров нет.</div>';
    $$('[data-nk]', box).forEach(i => i.onchange = e => { L[i.dataset.nk] = Number(e.target.value); commitJ(d); renderJutsuEditor(); });
    $$('[data-nd]', box).forEach(b => b.onclick = () => { delete L[b.dataset.nd]; commitJ(d); renderJutsuEditor(); });
  };
  drawNums();
  $('[data-addnum]', wrap).onclick = () => {
    const kk = prompt('Имя числового параметра (движок читает только ' + allowed.join(', ') + '):', allowed[0]);
    if (!kk) return;
    L[kk.trim()] = 0; commitJ(d); renderJutsuEditor();
  };
  $('[data-rq]', wrap).onchange = e => {
    try {
      const o = JSON.parse(e.target.value || '{}');
      if (Object.keys(o).length) L.requirements = o; else delete L.requirements;
      e.target.className = 'mono'; commitJ(d);
    } catch (err) { e.target.className = 'mono bad'; toast('Уровень ' + k + ', requirements: ' + err.message, 'err'); }
  };
  $('[data-unp]', wrap).onchange = e => {
    const a = e.target.value.split(',').map(s => s.trim()).filter(Boolean);
    L.unlock = L.unlock || {};
    if (a.length) L.unlock.properties = a; else delete L.unlock.properties;
    if (!Object.keys(L.unlock).length) delete L.unlock;
    commitJ(d); renderJutsuEditor();
  };
  $('[data-une]', wrap).onchange = e => {
    try {
      const a = JSON.parse(e.target.value || '[]');
      L.unlock = L.unlock || {};
      if (Array.isArray(a) && a.length) L.unlock.effects = a; else delete L.unlock.effects;
      if (!Object.keys(L.unlock).length) delete L.unlock;
      e.target.className = 'mono'; commitJ(d); renderJutsuEditor();
    } catch (err) { e.target.className = 'mono bad'; toast('Уровень ' + k + ', unlock.effects: ' + err.message, 'err'); }
  };
  return wrap;
}

/* --- переименование техники: id + имя файла + ссылки в дереве -------------- */
function renameJutsu(oldId, newId) {
  const j = curJ(); if (!j || !newId || oldId === newId) return;
  const short = String(newId).replace(/^shinobicore:/, '');
  if (!/^[a-z0-9_]+$/.test(short)) { toast('id техники: допустимы только a-z, 0-9 и _ (путь файла)', 'err'); return; }
  const newPath = 'src/main/resources/data/shinobicore/jutsu/' + short + '.json';
  if (newPath !== j.path) {
    const oldPath = j.path;
    dirty.delete(oldPath);
    pendingDelete.add(oldPath);
    j.path = newPath; j.name = short + '.json';
    const f = (S.files.jutsu || []).find(x => x.path === oldPath);
    if (f) { f.path = newPath; f.name = short + '.json'; }
    markDirty(newPath, JSON.stringify(canon(j.data), null, 2) + '\n');
    toast('Файл будет сохранён как ' + short + '.json, старый удалится при сохранении', 'ok');
  }
  // ссылки в дереве
  if (D.tree && oldId) {
    let n = 0;
    for (const node of (D.tree.data.nodes || [])) if (node.jutsuId === oldId) { node.jutsuId = newId; n++; }
    if (n) { markDirty(D.tree.path, JSON.stringify(D.tree.data, null, 2) + '\n'); toast('Обновлено ссылок в tree.json: ' + n); }
  }
}
function newJutsu() {
  const base = {
    id: 'shinobicore:new_jutsu', name: 'New Jutsu', description: '', category: 'ninjutsu', rank: 'D',
    element: 'fire', cooldown: 3,
    form: { type: 'projectile', params: { speed: 1.4, gravity: 0.02, lifetime: 80, size: 0.5 } },
    activation: { type: 'instant', params: {} },
    cost: { chakra: 5 },
    requirements: { uses: 0, sp: 1, stats: { ninjutsu: 5 } },
    effects: [{ type: 'damage', subtype: 'instant', params: { amount: 4 } }],
    properties: [],
    visual: { particle: 'flame', color: '#FF6600' },
    sound: {}
  };
  const path = 'src/main/resources/data/shinobicore/jutsu/new_jutsu.json';
  const txt = JSON.stringify(canon(base), null, 2) + '\n';
  markDirty(path, txt);
  S.files.jutsu = S.files.jutsu || [];
  S.files.jutsu.push({ path: path, name: 'new_jutsu.json', text: txt });
  buildModel();
  curJutsu = D.jutsu.findIndex(x => x.path === path);
  renderNav(); renderJutsuList(); renderJutsuEditor();
  toast('Черновик создан. Сохраните (Ctrl+S), затем /reload в игре.', 'ok');
}
function duplicateJutsu(j) {
  const short = String(j.data.id || 'copy').replace(/^shinobicore:/, '') + '_copy';
  const cp = JSON.parse(JSON.stringify(j.data));
  cp.id = 'shinobicore:' + short; cp.name = (cp.name || 'Jutsu') + ' (copy)';
  const path = 'src/main/resources/data/shinobicore/jutsu/' + short + '.json';
  const txt = JSON.stringify(canon(cp), null, 2) + '\n';
  markDirty(path, txt);
  S.files.jutsu.push({ path: path, name: short + '.json', text: txt });
  buildModel(); curJutsu = D.jutsu.findIndex(x => x.path === path);
  renderNav(); renderJutsuList(); renderJutsuEditor();
  toast('Копия создана: ' + short, 'ok');
}

/* ============================== ВИЗУАЛИЗАЦИЯ =============================== */
const PX = 11;                       // пикселей на блок
function renderSide(box, j, d, iss) {
  if (!box) return;
  box.innerHTML =
    '<div class="viz" id="viz"></div>' +
    '<div class="card" style="margin-top:12px"><h3>Баланс и стоимость</h3><div id="bal"></div></div>' +
    '<div class="card"><h3>Хронометраж</h3><div id="tl"></div></div>' +
    '<div class="card"><h3>Связь с деревом</h3><div id="treelink"></div></div>';
  $('#viz').innerHTML = vizSvg(d) + '<div class="vizcap" id="vizcap"></div>';
  $('#vizcap').innerHTML = vizCaption(d);
  $('#bal').innerHTML = balanceHtml(d);
  $('#tl').innerHTML = timelineHtml(d);
  $('#treelink').innerHTML = treeLinkHtml(d);
}

function vizSvg(d) {
  const f = d.form || {}, p = f.params || {}, c = C();
  const col = elColor(d.element);
  const W = 560, H = 250, gnd = H - 34, x0 = 46;
  const grid = (w, hh) => {
    let s = '';
    for (let x = 0; x <= w; x += PX * 2) s += '<line x1="' + x + '" y1="0" x2="' + x + '" y2="' + hh + '" stroke="#241a2c" stroke-width="1"/>';
    for (let y = 0; y <= hh; y += PX * 2) s += '<line x1="0" y1="' + y + '" x2="' + w + '" y2="' + y + '" stroke="#241a2c" stroke-width="1"/>';
    return s;
  };
  const caster = (x, y) => '<g><circle cx="' + x + '" cy="' + y + '" r="7" fill="#2a1f2e" stroke="' + col + '" stroke-width="2"/>' +
    '<circle cx="' + x + '" cy="' + (y - 11) + '" r="4" fill="' + col + '" opacity=".85"/><text x="' + x + '" y="' + (y + 22) + '" fill="#9a8fa6" font-size="9" text-anchor="middle">кастер</text></g>';
  const ground = '<line x1="0" y1="' + gnd + '" x2="' + W + '" y2="' + gnd + '" stroke="#3a2a3e" stroke-width="1"/>';
  let body = '';

  if (f.type === 'projectile') {
    const speed = Number(p.speed !== undefined ? p.speed : 1.4);
    const grav = Number(p.gravity !== undefined ? p.gravity : 0.02);
    const life = Number(p.lifetime !== undefined ? p.lifetime : 80);
    const size = Number(p.size !== undefined ? p.size : 0.5);
    const cnt = Number(p.count || 1);
    const spread = Number(p.spread || p.spreadAngle || 0);
    // масштаб: подбираем так, чтобы траектория влезла по X
    const maxX = Math.max(1, speed * life);
    const sc = Math.min((W - x0 - 20) / (maxX * PX), 1);
    const pts = [];
    for (let t = 0; t <= life; t++) {
      const X = x0 + speed * t * PX * sc;
      pts.push([X, gnd - 60 + (0.5 * grav * t * t) * PX * sc]);
      if (gnd - 60 + (0.5 * grav * t * t) * PX * sc > gnd) break;
    }
    const path1 = pts.map((q, i) => (i ? 'L' : 'M') + q[0].toFixed(1) + ' ' + q[1].toFixed(1)).join(' ');
    body += grid(W, H) + ground;
    for (let i = 0; i < Math.min(cnt, 7); i++) {
      const ang = cnt > 1 ? (i - (cnt - 1) / 2) * (spread / Math.max(1, cnt - 1)) : 0;
      const dy = Math.tan(ang * Math.PI / 180) * (pts.length ? pts[pts.length - 1][0] - x0 : 100);
      body += '<path d="' + pts.map((q, k) => (k ? 'L' : 'M') + q[0].toFixed(1) + ' ' + (q[1] - dy * (k / Math.max(1, pts.length - 1))).toFixed(1)).join(' ') +
        '" fill="none" stroke="' + col + '" stroke-width="1.6" opacity="' + (i === 0 ? 1 : .45) + '"/>';
    }
    body += '<path d="' + path1 + '" fill="none" stroke="' + col + '" stroke-width="2.4" opacity=".95"/>';
    if (pts.length) {
      const last = pts[pts.length - 1];
      body += '<circle cx="' + last[0].toFixed(1) + '" cy="' + last[1].toFixed(1) + '" r="' + Math.max(3, size * PX * sc).toFixed(1) + '" fill="' + col + '" opacity=".9"/>';
      body += '<circle cx="' + x0 + '" cy="' + (gnd - 60) + '" r="' + Math.max(3, size * PX * sc).toFixed(1) + '" fill="' + col + '"/>';
    }
    body += caster(x0, gnd);
    body += '<text x="' + (W - 8) + '" y="16" fill="#9a8fa6" font-size="10" text-anchor="end">' + fmt(maxX, 0) + ' блоков · ' + life + ' тиков (' + fmt(life / 20, 1) + ' с)</text>';
  } else if (f.type === 'beam') {
    const range = Number(p.maxRange !== undefined ? p.maxRange : 16), wdt = Number(p.width !== undefined ? p.width : 1);
    const dur = Number(p.duration || 60), tr = Number(p.tickRate || 5);
    const sc = Math.min(1, (W - x0 - 20) / (range * PX));
    const hh = Math.max(4, wdt * PX * sc);
    body += grid(W, H) + ground;
    body += '<rect x="' + x0 + '" y="' + (gnd - 40 - hh / 2) + '" width="' + (range * PX * sc) + '" height="' + hh + '" fill="' + col + '" opacity=".28" rx="3"/>';
    body += '<rect x="' + x0 + '" y="' + (gnd - 40 - hh / 6) + '" width="' + (range * PX * sc) + '" height="' + (hh / 3) + '" fill="' + col + '" opacity=".85" rx="2"/>';
    for (let t = tr; t <= dur; t += tr) {
      const x = x0 + (range * PX * sc) * Math.min(1, t / Math.max(1, dur));
      body += '<line x1="' + x + '" y1="' + (gnd - 40 - hh) + '" x2="' + x + '" y2="' + (gnd - 40 + hh) + '" stroke="#ffd75e" stroke-width="1" opacity=".55"/>';
    }
    body += caster(x0, gnd) + '<text x="' + (x0 + range * PX * sc + 6) + '" y="' + (gnd - 36) + '" fill="#9a8fa6" font-size="10">' + fmt(range, 1) + ' бл.</text>';
  } else if (f.type === 'zone') {
    const r = Number(p.radius !== undefined ? p.radius : 4), dur = Number(p.duration || 100), tr = Number(p.tickRate || 20);
    const sc = Math.min(1, (W / 2 - 40) / (r * PX));
    const cx = W / 2, cy = gnd - 10;
    body += grid(W, H) + ground;
    body += '<ellipse cx="' + cx + '" cy="' + cy + '" rx="' + (r * PX * sc) + '" ry="' + (r * PX * sc * 0.42) + '" fill="' + col + '" opacity=".22"/>';
    body += '<ellipse cx="' + cx + '" cy="' + cy + '" rx="' + (r * PX * sc) + '" ry="' + (r * PX * sc * 0.42) + '" fill="none" stroke="' + col + '" stroke-width="2"/>';
    for (let t = tr; t <= dur; t += tr) {
      const k = 1 - (t / dur) * 0.85;
      body += '<ellipse cx="' + cx + '" cy="' + cy + '" rx="' + (r * PX * sc * k) + '" ry="' + (r * PX * sc * 0.42 * k) + '" fill="none" stroke="' + col + '" stroke-width="1" opacity=".3"/>';
    }
    body += '<circle cx="' + cx + '" cy="' + cy + '" r="4" fill="' + col + '"/>';
    body += '<text x="' + cx + '" y="' + (cy - r * PX * sc * 0.42 - 10) + '" fill="#9a8fa6" font-size="10" text-anchor="middle">R = ' + fmt(r, 1) + ' бл · ' + dur + ' тиков (' + fmt(dur / 20, 1) + ' с) · тик каждые ' + tr + '</text>';
  } else if (f.type === 'dash') {
    const dist = Number(p.distance !== undefined ? p.distance : 8), sp = Number(p.speed || 3);
    const sc = Math.min(1, (W - x0 - 60) / (dist * PX));
    const y = gnd - 40, len = dist * PX * sc;
    body += grid(W, H) + ground;
    body += '<defs><marker id="ar" markerWidth="9" markerHeight="9" refX="7" refY="4.5" orient="auto"><path d="M0,0 L9,4.5 L0,9 z" fill="' + col + '"/></marker></defs>';
    body += '<line x1="' + x0 + '" y1="' + y + '" x2="' + (x0 + len) + '" y2="' + y + '" stroke="' + col + '" stroke-width="4" marker-end="url(#ar)" opacity=".9"/>';
    if (p.damageOnPath) body += '<rect x="' + x0 + '" y="' + (y - 12) + '" width="' + len + '" height="24" fill="' + col + '" opacity=".13"/>';
    body += caster(x0, gnd);
    body += '<text x="' + (x0 + len / 2) + '" y="' + (y - 16) + '" fill="#9a8fa6" font-size="10" text-anchor="middle">' + fmt(dist, 1) + ' блоков · ' + fmt(dist / Math.max(0.5, sp) * 5, 0) + ' тиков</text>';
  } else if (f.type === 'construct') {
    const w = Number(p.width || 5), hh = Number(p.height || 3), dp = Number(p.depth || 1), shape = p.shape || 'wall';
    const sc = Math.min(1, (W - 120) / (Math.max(w, dp) * PX), (gnd - 40) / (hh * PX));
    const bw = w * PX * sc, bh = hh * PX * sc, bd = dp * PX * sc;
    const cx = W / 2 - bw / 2, cy = gnd - bh;
    body += grid(W, H) + ground;
    const fill = 'rgba(187,136,68,.30)', stroke = '#bb8844';
    if (shape === 'pillar') {
      body += '<rect x="' + (W / 2 - PX * sc / 2) + '" y="' + cy + '" width="' + (PX * sc) + '" height="' + bh + '" fill="' + fill + '" stroke="' + stroke + '"/>';
    } else if (shape === 'platform') {
      body += '<rect x="' + cx + '" y="' + (gnd - PX * sc) + '" width="' + bw + '" height="' + (PX * sc) + '" fill="' + fill + '" stroke="' + stroke + '"/>';
    } else if (shape === 'dome') {
      body += '<path d="M' + cx + ' ' + gnd + ' A ' + (bw / 2) + ' ' + bh + ' 0 0 1 ' + (cx + bw) + ' ' + gnd + ' Z" fill="' + fill + '" stroke="' + stroke + '"/>';
    } else if (shape === 'cage') {
      body += '<rect x="' + cx + '" y="' + cy + '" width="' + bw + '" height="' + bh + '" fill="none" stroke="' + stroke + '" stroke-width="2"/>';
      for (let i = 1; i < w; i++) body += '<line x1="' + (cx + i * PX * sc) + '" y1="' + cy + '" x2="' + (cx + i * PX * sc) + '" y2="' + (cy + bh) + '" stroke="' + stroke + '" opacity=".5"/>';
      for (let i = 1; i < hh; i++) body += '<line x1="' + cx + '" y1="' + (cy + i * PX * sc) + '" x2="' + (cx + bw) + '" y2="' + (cy + i * PX * sc) + '" stroke="' + stroke + '" opacity=".5"/>';
    } else {
      body += '<rect x="' + cx + '" y="' + cy + '" width="' + bw + '" height="' + bh + '" fill="' + fill + '" stroke="' + stroke + '"/>';
      for (let i = 1; i < w; i++) body += '<line x1="' + (cx + i * PX * sc) + '" y1="' + cy + '" x2="' + (cx + i * PX * sc) + '" y2="' + (cy + bh) + '" stroke="' + stroke + '" opacity=".35"/>';
      for (let i = 1; i < hh; i++) body += '<line x1="' + cx + '" y1="' + (cy + i * PX * sc) + '" x2="' + (cx + bw) + '" y2="' + (cy + i * PX * sc) + '" stroke="' + stroke + '" opacity=".35"/>';
      if (dp > 1) body += '<path d="M' + cx + ' ' + cy + ' l' + (bd * .5) + ' ' + (-bd * .3) + ' h' + bw + ' v' + bh + ' l' + (-bd * .5) + ' ' + (bd * .3) + '" fill="none" stroke="' + stroke + '" opacity=".5"/>';
    }
    body += caster(x0, gnd);
    body += '<text x="' + (W / 2) + '" y="18" fill="#9a8fa6" font-size="10" text-anchor="middle">' + esc(shape) + ' · ' + w + '×' + hh + '×' + dp + ' блоков · ' + esc(p.blockType || 'earth') + ' · ' + (p.duration || 200) + ' тиков</text>';
  } else if (f.type === 'summon') {
    const n = Number(p.count || 1);
    body += grid(W, H) + ground;
    for (let i = 0; i < Math.min(n, 6); i++) {
      const x = W / 2 - ((Math.min(n, 6) - 1) * 34) / 2 + i * 34;
      body += '<g><ellipse cx="' + x + '" cy="' + gnd + '" rx="14" ry="5" fill="' + col + '" opacity=".25"/>' +
        '<rect x="' + (x - 9) + '" y="' + (gnd - 30) + '" width="18" height="26" rx="6" fill="#2a1f2e" stroke="' + col + '" stroke-width="1.6"/>' +
        '<circle cx="' + x + '" cy="' + (gnd - 36) + '" r="7" fill="#2a1f2e" stroke="' + col + '" stroke-width="1.6"/></g>';
    }
    body += caster(x0, gnd);
    body += '<text x="' + (W / 2) + '" y="20" fill="#9a8fa6" font-size="10" text-anchor="middle">' + n + ' × ' + esc(p.entityType || 'minecraft:wolf') + ' · ' + esc(p.behavior || 'fight_for_caster') + ' · ' + (p.lifetime || 600) + ' тиков</text>';
  } else if (f.type === 'handheld') {
    const ct = Number(p.chargeTime || 20), hd = Number(p.holdDuration || 0);
    body += grid(W, H) + ground + caster(x0, gnd);
    body += '<rect x="' + (x0 + 14) + '" y="' + (gnd - 52) + '" width="' + Math.min(160, ct * 3) + '" height="12" rx="6" fill="' + col + '" opacity=".55"/>';
    body += '<text x="' + (x0 + 20 + Math.min(160, ct * 3)) + '" y="' + (gnd - 42) + '" fill="#9a8fa6" font-size="10">зарядка ' + ct + ' тиков (' + fmt(ct / 20, 1) + ' с)</text>';
    if (hd) { body += '<rect x="' + (x0 + 14) + '" y="' + (gnd - 34) + '" width="' + Math.min(200, hd * 2) + '" height="10" rx="5" fill="#ffd75e" opacity=".5"/>' +
      '<text x="' + (x0 + 20 + Math.min(200, hd * 2)) + '" y="' + (gnd - 25) + '" fill="#9a8fa6" font-size="10">удержание ' + hd + ' тиков</text>'; }
    body += '<circle cx="' + (x0 + 4) + '" cy="' + (gnd - 66) + '" r="' + Math.max(5, Number(p.size || 1) * 6) + '" fill="' + col + '" opacity=".8"/>';
  } else { /* point */
    const r = Number(p.range !== undefined ? p.range : 3), tm = p.targetMode || 'look_entity';
    const sc = Math.min(1, (W - x0 - 60) / (r * PX * 2));
    body += grid(W, H) + ground + caster(x0, gnd);
    body += '<circle cx="' + x0 + '" cy="' + (gnd - 10) + '" r="' + (r * PX * sc) + '" fill="' + col + '" opacity=".13"/>';
    body += '<circle cx="' + x0 + '" cy="' + (gnd - 10) + '" r="' + (r * PX * sc) + '" fill="none" stroke="' + col + '" stroke-width="1.6" stroke-dasharray="4 3"/>';
    if (tm === 'self') body += '<circle cx="' + x0 + '" cy="' + (gnd - 10) + '" r="12" fill="' + col + '" opacity=".5"/>';
    else if (tm === 'raycast_point') body += '<g><line x1="' + x0 + '" y1="' + (gnd - 10) + '" x2="' + (x0 + r * PX * sc) + '" y2="' + (gnd - 10) + '" stroke="#ffd75e" stroke-dasharray="3 3"/>' +
      '<circle cx="' + (x0 + r * PX * sc) + '" cy="' + (gnd - 10) + '" r="5" fill="none" stroke="#ffd75e" stroke-width="2"/></g>';
    else body += '<g><rect x="' + (x0 + r * PX * sc * .7 - 7) + '" y="' + (gnd - 34) + '" width="14" height="24" rx="5" fill="#2a1f2e" stroke="#ff6b7a"/>' +
      '<circle cx="' + (x0 + r * PX * sc * .7) + '" cy="' + (gnd - 40) + '" r="6" fill="#2a1f2e" stroke="#ff6b7a"/></g>';
    body += '<text x="' + (W - 8) + '" y="18" fill="#9a8fa6" font-size="10" text-anchor="end">range ' + fmt(r, 1) + ' бл · targetMode: ' + esc(tm) + '</text>';
  }
  return '<svg viewBox="0 0 ' + W + ' ' + H + '" xmlns="http://www.w3.org/2000/svg" style="background:#120d15;border-radius:8px">' + body + '</svg>';
}
function vizCaption(d) {
  const f = d.form || {}, p = f.params || {};
  const bits = [];
  if (f.type === 'projectile') {
    const sp = Number(p.speed !== undefined ? p.speed : 1.4), gr = Number(p.gravity !== undefined ? p.gravity : 0.02), lf = Number(p.lifetime !== undefined ? p.lifetime : 80);
    const fall = 0.5 * gr * lf * lf;
    bits.push('дальность без земли ≈ <b>' + fmt(sp * lf, 0) + ' блоков</b>');
    bits.push('падение за время жизни ≈ <b>' + fmt(fall, 1) + ' блоков</b>' + (fall > 8 ? ' — целиться нужно выше' : ''));
    if (p.count > 1) bits.push('снарядов: <b>' + p.count + '</b>, разброс ' + (p.spread || p.spreadAngle || 0) + '°');
  }
  bits.push('стоимость: ' + Object.keys(d.cost || {}).map(k => k + ' ' + d.cost[k]).join(', '));
  const act = d.activation || {};
  if (act.type === 'charge') bits.push('зарядка ' + ((act.params || {}).minCharge || 20) + '…' + ((act.params || {}).maxCharge || 60) + ' тиков');
  if (act.type === 'handseals') bits.push('печатей: ' + ((act.params || {}).sealCount || 3));
  return bits.join(' · ');
}
function balanceHtml(d) {
  const rb = RANK_BALANCE[d.rank];
  const cost = Number((d.cost || {}).chakra || 0);
  let dmg = 0, ctrl = 0, heal = 0;
  for (const e of (d.effects || [])) {
    const q = Number((e.params || {}).amount || 0);
    if (e.type === 'damage') dmg += q || Number((e.params || {}).percent || 0);
    if (e.type === 'buff' && (e.subtype === 'heal' || e.subtype === 'regen')) heal += q;
    if (e.type === 'control') ctrl++;
  }
  const bar = (v, mx, col) => '<div class="bar"><i style="width:' + Math.min(100, (v / Math.max(0.0001, mx)) * 100) + '%;background:' + col + '"></i></div>';
  if (!rb) return '<div class="dim">Ранг не задан — сравнение недоступно.</div>';
  return '<table class="t"><tr><td class="dim">Ожидание для ранга <b style="color:var(--gold)">' + esc(d.rank) + '</b></td><td>чакры ≈ ' + rb.cost + ' · урона ≈ ' + rb.dmg + '</td></tr>' +
    '<tr><td class="dim">Чакра</td><td><b>' + cost + '</b>' + bar(cost, rb.cost * 2, cost > rb.cost * 2 || cost < rb.cost * .5 ? 'var(--red)' : 'var(--chakra)') + '</td></tr>' +
    '<tr><td class="dim">Урон (сумма)</td><td><b>' + fmt(dmg, 1) + '</b>' + bar(dmg, rb.dmg * 3, dmg > rb.dmg * 3 || dmg < rb.dmg * .5 ? 'var(--red)' : 'var(--sakura)') + '</td></tr>' +
    '<tr><td class="dim">Лечение</td><td>' + fmt(heal, 1) + '</td></tr>' +
    '<tr><td class="dim">Контроль</td><td>' + ctrl + ' эффект(ов)</td></tr>' +
    '<tr><td class="dim">Кулдаун</td><td>' + fmt(d.cooldown || 0, 1) + ' с</td></tr></table>';
}
function timelineHtml(d) {
  const act = d.activation || {}, ap = act.params || {};
  const seg = [];
  if (act.type === 'charge') seg.push({ t: 'зарядка', ms: ((ap.maxCharge || 60) / 20) * 1000, c: 'var(--gold)' });
  if (act.type === 'handseals') seg.push({ t: 'печати', ms: ((ap.sealCount || 3) * 400), c: 'var(--violet)' });
  if (act.type === 'hold') seg.push({ t: 'удержание', ms: 2000, c: 'var(--chakra)' });
  const f = d.form || {}, p = f.params || {};
  if (f.type === 'projectile') seg.push({ t: 'полёт', ms: ((p.lifetime || 80) / 20) * 1000, c: elColor(d.element) });
  if (f.type === 'beam' || f.type === 'zone') seg.push({ t: 'действие', ms: ((p.duration || 60) / 20) * 1000, c: elColor(d.element) });
  if (f.type === 'dash') seg.push({ t: 'рывок', ms: ((p.distance || 8) / Math.max(.5, p.speed || 3) * 5 / 20) * 1000, c: elColor(d.element) });
  let maxDur = 0;
  for (const e of (d.effects || [])) { const dd = Number((e.params || {}).duration || 0); if (dd > maxDur) maxDur = dd; }
  if (maxDur) seg.push({ t: 'эффект ' + maxDur + 'т', ms: (maxDur / 20) * 1000, c: 'var(--sakdim)' });
  if (d.cooldown) seg.push({ t: 'кулдаун', ms: Number(d.cooldown) * 1000, c: '#4a3a50' });
  const total = seg.reduce((a, b) => a + b.ms, 0) || 1;
  return '<div style="display:flex;height:22px;border-radius:5px;overflow:hidden;border:1px solid var(--edge)">' +
    seg.map(s => '<div title="' + esc(s.t) + ': ' + fmt(s.ms / 1000, 2) + ' с" style="width:' + (s.ms / total * 100) + '%;background:' + s.c + '"></div>').join('') +
    '</div><div class="legend">' + seg.map(s => '<span><i style="background:' + s.c + '"></i>' + esc(s.t) + ' ' + fmt(s.ms / 1000, 2) + ' с</span>').join('') +
    '</div><div class="dim" style="margin-top:5px">Полный цикл ≈ ' + fmt(total / 1000, 2) + ' с</div>';
}
function treeLinkHtml(d) {
  if (!D.tree) return '<div class="dim">Дерево не найдено.</div>';
  const ns = (D.tree.data.nodes || []).filter(n => n.jutsuId === d.id);
  if (!ns.length) return '<div class="issue warn">Техника не привязана ни к одному узлу дерева — купить её нельзя, только /shinobicore jutsu.</div>';
  return ns.map(n => {
    const br = (D.tree.data.branches || {})[n.branch] || {};
    return '<div class="issue info">узел <b class="mono">' + esc(n.id) + '</b> · ветка ' + esc(br.label || n.branch) + ' · ' + (n.spCost || 0) + ' SP' +
      (n.clanRequired ? ' · только клан <b>' + esc(n.clanRequired) + '</b>' : '') +
      (n.requires && n.requires.length ? '<div class="w">требует: ' + esc(n.requires.join(', ')) + '</div>' : '') + '</div>';
  }).join('');
}

/* ============================== ДЕРЕВО ===================================== */
const TH = { SCROLL_W: 96, SCROLL_GAP: 44, ROLLER_H: 7, HEADER_H: 34, FOOTER_H: 20, NODE_ROW: 34, NODE_R: 11, BEAM_H: 10, CORD_H: 16 };

function branchOrder() {
  const t = D.tree.data, br = t.branches || {};
  const order = [];
  for (const b of Object.keys(br)) {
    const def = br[b] || {};
    // branchOrder() в SkillTreeScreen пропускает hidden всегда; клановые ветки
    // пропускал ТОЖЕ — это и есть баг, который чинит -FixClanBranches.
    if (def.hidden) continue;
    if (def.clan && !treeShowClan) continue;
    if ((t.nodes || []).some(n => n.branch === b)) order.push(b);
  }
  order.sort((a, b) => a === 'general' ? -1 : (b === 'general' ? 1 : a.localeCompare(b)));
  return order;
}
function nodesOf(branch) {
  return (D.tree.data.nodes || []).filter(n => n.branch === branch).sort((a, b) => {
    const a1 = String(a.id).startsWith('auto_') ? 0 : 1, a2 = String(b.id).startsWith('auto_') ? 0 : 1;
    if (a1 !== a2) return a1 - a2;
    if (a.distance !== b.distance) return a.distance - b.distance;
    return String(a.id).localeCompare(String(b.id));
  });
}
function renderTree(v) {
  if (!D.tree) { v.innerHTML = '<div class="card empty">tree.json не найден</div>'; return; }
  const iss = validateTree();
  const errs = iss.filter(i => i.lvl === 'err').length;
  const nodes = D.tree.data.nodes || [];
  const totalSP = nodes.reduce((a, n) => a + Number(n.spCost || 0), 0);
  const inert = nodes.filter(n => n.type === 'passive' && (C().passivesImplemented || []).indexOf(n.id) < 0);
  const inertSP = inert.reduce((a, n) => a + Number(n.spCost || 0), 0);

  v.innerHTML =
    '<h2 class="title">Дерево навыков <span class="sub">' + nodes.length + ' узлов · ' + Object.keys(D.tree.data.branches || {}).length + ' веток · ' + totalSP + ' SP всего</span></h2>' +
    '<div class="card"><div class="row" style="align-items:center">' +
      '<label style="display:flex;align-items:center;gap:6px"><input type="checkbox" id="t-clan" ' + (treeShowClan ? 'checked' : '') + '> показывать клановые ветки</label>' +
      '<span class="dim">= как будет после <span class="mono">-FixClanBranches</span></span>' +
      '<span class="spacer"></span>' +
      '<span class="pill">ошибок: ' + errs + '</span>' +
      '<span class="pill" style="color:var(--gold)">инертных пассивок: ' + inert.length + ' (' + inertSP + ' SP)</span>' +
      '<button class="btn sm" id="t-new">＋ Новый узел</button>' +
      '<button class="btn sm" id="t-save">💾 Сохранить tree.json</button>' +
    '</div>' +
    '<div class="dim" style="margin-top:7px">Раскладка 1:1 повторяет SkillTreeScreen.buildLayout(): ветки — свитки слева направо, ' +
      'сортировка узлов <span class="mono">auto_* → distance → id</span>, X = центр свитка + angleOffset·0.6, Y = строка · 34 px.</div></div>' +
    '<div class="row" style="align-items:flex-start;gap:12px">' +
      '<div style="flex:1;min-width:0"><div id="treeWrap"></div></div>' +
      '<div style="width:360px;flex:0 0 360px" id="nodePanel"></div>' +
    '</div>' +
    '<div class="card" style="margin-top:12px"><h3>Проверка дерева</h3>' + issuesHtml(iss) + '</div>';

  $('#t-clan').onchange = e => { treeShowClan = e.target.checked; renderTree(v); };
  $('#t-save').onclick = () => { markDirty(D.tree.path, JSON.stringify(D.tree.data, null, 2) + '\n'); toast('tree.json помечен к сохранению — нажмите «Сохранить»'); };
  $('#t-new').onclick = () => {
    const id = 'new_node_' + (nodes.length + 1);
    D.tree.data.nodes.push({ id: id, branch: 'general', distance: 1, angleOffset: 0, type: 'passive', effect: '', value: 0, spCost: 5, requires: [], icon: '?', name: 'New Node', description: '' });
    curNode = id; markDirty(D.tree.path, JSON.stringify(D.tree.data, null, 2) + '\n'); renderTree(v);
  };
  drawTree();
  renderNodePanel();
}

function drawTree() {
  const wrap = $('#treeWrap'); if (!wrap) return;
  const t = D.tree.data, order = branchOrder();
  const pos = {};
  let worldW = 0, worldH = 0;
  const boxes = order.map((b, i) => {
    const ns = nodesOf(b);
    const sb = { branch: b, i: i, x: i * (TH.SCROLL_W + TH.SCROLL_GAP), top: TH.BEAM_H + TH.CORD_H, ns: ns };
    sb.fullH = TH.ROLLER_H * 2 + TH.HEADER_H + TH.FOOTER_H + Math.max(1, ns.length) * TH.NODE_ROW;
    const cy = sb.top + TH.ROLLER_H + TH.HEADER_H;
    ns.forEach((n, row) => { pos[n.id] = [sb.x + TH.SCROLL_W / 2 + Math.round(n.angleOffset * 0.6), cy + row * TH.NODE_ROW + TH.NODE_ROW / 2]; });
    worldW = Math.max(worldW, sb.x + TH.SCROLL_W);
    worldH = Math.max(worldH, sb.fullH + sb.top);
    return sb;
  });
  if (!boxes.length) { wrap.innerHTML = '<div class="empty">Нет видимых веток. Включите «показывать клановые ветки».</div>'; return; }
  const P = 26;
  const W = worldW + P * 2, H = worldH + P * 2;
  let s = '<svg viewBox="0 0 ' + W + ' ' + H + '" width="' + W + '" height="' + H + '" xmlns="http://www.w3.org/2000/svg" style="min-width:' + W + 'px">';
  s += '<rect width="' + W + '" height="' + H + '" fill="#120d15"/>';
  const jids = {}; for (const j of D.jutsu) if (j.data.id) jids[j.data.id] = j;
  const impl = C().passivesImplemented || [];

  // соединения (dottedBezier из SkillTreeScreen)
  for (const n of (t.nodes || [])) {
    for (const r of (n.requires || [])) {
      const a = pos[r], b = pos[n.id];
      if (!a || !b) continue;
      const x1 = a[0] + P, y1 = a[1] + P, x2 = b[0] + P, y2 = b[1] + P;
      const c1 = y1 + (y2 - y1) * 0.45, c2 = y2 - (y2 - y1) * 0.45;
      let dpath = '';
      for (let i = 0; i <= 24; i += 2) {
        const tt = i / 24, u = 1 - tt;
        const x = u * u * u * x1 + 3 * u * u * tt * x1 + 3 * u * tt * tt * x2 + tt * tt * tt * x2;
        const y = u * u * u * y1 + 3 * u * u * tt * c1 + 3 * u * tt * tt * c2 + tt * tt * tt * y2;
        dpath += (i ? 'L' : 'M') + x.toFixed(1) + ' ' + y.toFixed(1) + ' ';
      }
      s += '<path d="' + dpath + '" fill="none" stroke="#8a4a66" stroke-width="1.4" stroke-dasharray="2 3" opacity=".75"/>';
    }
  }
  // свитки
  for (const sb of boxes) {
    const def = (t.branches || {})[sb.branch] || {};
    const col = def.color || '#AAAAAA';
    const x = sb.x + P, y = sb.top + P, w = TH.SCROLL_W, hh = sb.fullH;
    s += '<rect x="' + x + '" y="' + y + '" width="' + w + '" height="' + hh + '" rx="3" fill="#e7d9bc" opacity=".93"/>';
    s += '<rect x="' + x + '" y="' + y + '" width="' + w + '" height="' + TH.ROLLER_H + '" fill="#6b4a33"/>';
    s += '<rect x="' + x + '" y="' + (y + hh - TH.ROLLER_H) + '" width="' + w + '" height="' + TH.ROLLER_H + '" fill="#6b4a33"/>';
    s += '<rect x="' + (x - 4) + '" y="' + (y - 2) + '" width="' + (w + 8) + '" height="' + (TH.ROLLER_H + 4) + '" rx="3" fill="#3e2a1d"/>';
    s += '<rect x="' + (x - 4) + '" y="' + (y + hh - TH.ROLLER_H - 2) + '" width="' + (w + 8) + '" height="' + (TH.ROLLER_H + 4) + '" rx="3" fill="#3e2a1d"/>';
    s += '<text x="' + (x + w / 2) + '" y="' + (y + TH.ROLLER_H + 18) + '" fill="#2a2130" font-size="10" text-anchor="middle" font-weight="600">' + esc(def.label || sb.branch) + '</text>';
    const sp = sb.ns.reduce((a, n) => a + Number(n.spCost || 0), 0);
    s += '<rect x="' + (x + 10) + '" y="' + (y + TH.ROLLER_H + 24) + '" width="' + (w - 20) + '" height="11" rx="5" fill="#d8c8a8"/>';
    s += '<text x="' + (x + w / 2) + '" y="' + (y + TH.ROLLER_H + 33) + '" fill="#2a2130" font-size="8" text-anchor="middle">' + sb.ns.length + ' узл. · ' + sp + ' SP</text>';
    if (def.clan) s += '<rect x="' + x + '" y="' + (y + hh - TH.FOOTER_H) + '" width="' + w + '" height="' + TH.FOOTER_H + '" fill="' + col + '" opacity=".22"/>' +
      '<text x="' + (x + w / 2) + '" y="' + (y + hh - 6) + '" fill="#2a2130" font-size="8" text-anchor="middle">клан: ' + esc(def.clan) + '</text>';
    if (def.hidden) s += '<text x="' + (x + w / 2) + '" y="' + (y + hh - 6) + '" fill="#b3222e" font-size="8" text-anchor="middle">HIDDEN</text>';
  }
  // узлы
  for (const n of (t.nodes || [])) {
    const p = pos[n.id]; if (!p) continue;
    const x = p[0] + P, y = p[1] + P;
    const def = (t.branches || {})[n.branch] || {};
    let col = def.color || '#AAAAAA', warn = '';
    if (n.jutsuId && !jids[n.jutsuId]) { col = '#ff6b7a'; warn = 'нет файла техники'; }
    else if (n.type === 'passive' && impl.indexOf(n.id) < 0) { col = '#ffd75e'; warn = 'инертная пассивка'; }
    if (n.clanRequired) col = '#b48aff';
    s += '<g class="tnode ' + (curNode === n.id ? 'sel' : '') + '" data-id="' + esc(n.id) + '">';
    s += '<circle cx="' + x + '" cy="' + y + '" r="' + TH.NODE_R + '" fill="#1e1624" stroke="' + col + '" stroke-width="2"/>';
    s += '<text x="' + x + '" y="' + (y + 4) + '" fill="' + col + '" font-size="11" text-anchor="middle" font-weight="700">' + esc(n.icon || '?') + '</text>';
    s += '<text x="' + x + '" y="' + (y + TH.NODE_R + 10) + '" fill="#5c4a52" font-size="7.5" text-anchor="middle">' + (n.spCost || 0) + ' SP</text>';
    if (warn) s += '<circle cx="' + (x + 9) + '" cy="' + (y - 9) + '" r="3" fill="' + col + '"><title>' + esc(warn) + '</title></circle>';
    s += '<title>' + esc(n.id + ' — ' + (n.name || '') + '\n' + (warn || '') + (n.jutsuId ? '\n' + n.jutsuId : '')) + '</title></g>';
  }
  s += '</svg>';
  wrap.innerHTML = s;
  $$('.tnode', wrap).forEach(g => g.onclick = () => { curNode = g.dataset.id; drawTree(); renderNodePanel(); });
}

function renderNodePanel() {
  const box = $('#nodePanel'); if (!box) return;
  const n = (D.tree.data.nodes || []).find(x => x.id === curNode);
  if (!n) { box.innerHTML = '<div class="card empty">Кликните узел на схеме</div>'; return; }
  const t = D.tree.data, br = Object.keys(t.branches || {});
  const impl = (C().passivesImplemented || []);
  const jids = {}; for (const j of D.jutsu) if (j.data.id) jids[j.data.id] = j;
  const isPassiveInert = n.type === 'passive' && impl.indexOf(n.id) < 0;
  box.innerHTML =
    '<div class="card"><h3>Узел <span class="hint mono">' + esc(n.id) + '</span></h3>' +
    '<div class="grid g2">' +
      field('id', '<input id="n-id" class="mono" value="' + esc(n.id) + '">') +
      field('Тип', '<select id="n-type">' + ['jutsu', 'passive', 'stat', 'unlock'].map(x => '<option value="' + x + '"' + (n.type === x ? ' selected' : '') + '>' + x + '</option>').join('') + '</select>') +
      field('Ветка', '<select id="n-branch">' + br.map(x => '<option value="' + esc(x) + '"' + (n.branch === x ? ' selected' : '') + '>' + esc(((t.branches || {})[x] || {}).label || x) + '</option>').join('') + '</select>') +
      field('Только для клана', '<input id="n-clan" list="dl-clans" value="' + esc(n.clanRequired || '') + '">') +
      field('distance (порядок строки)', '<input id="n-dist" type="number" value="' + esc(n.distance !== undefined ? n.distance : 1) + '">') +
      field('angleOffset (сдвиг по X, ×0.6)', '<input id="n-ao" type="number" step="1" value="' + esc(n.angleOffset || 0) + '">') +
      field('spCost', '<input id="n-sp" type="number" value="' + esc(n.spCost || 0) + '">') +
      field('icon (1 символ)', '<input id="n-icon" maxlength="2" value="' + esc(n.icon || '?') + '">') +
    '</div>' +
    '<div style="margin-top:8px">' + field('name', '<input id="n-name" style="width:100%" value="' + esc(n.name || '') + '">') + '</div>' +
    '<div style="margin-top:8px">' + field('description', '<textarea id="n-desc" rows="2" style="width:100%">' + esc(n.description || '') + '</textarea>') + '</div>' +
    '<div style="margin-top:8px">' + field('requires (через запятую)', '<input id="n-req" class="mono" style="width:100%" value="' + esc((n.requires || []).join(', ')) + '">') + '</div>' +
    (n.type === 'jutsu'
      ? '<div style="margin-top:8px">' + field('jutsuId', '<input id="n-jid" list="dl-jutsu" class="mono" style="width:100%" value="' + esc(n.jutsuId || '') + '">') +
        (n.jutsuId && !jids[n.jutsuId] ? '<div class="issue err" style="margin-top:6px">Файла техники нет — разблокировка будет отклонена защитой из Part 1.</div>' : '') + '</div>'
      : '<div class="grid g2" style="margin-top:8px">' +
        field('effect', '<input id="n-eff" class="mono" value="' + esc(n.effect || '') + '">') +
        field('value', '<input id="n-val" type="number" step="0.01" value="' + esc(n.value || 0) + '">') + '</div>' +
        (isPassiveInert ? '<div class="issue warn" style="margin-top:6px"><b>Инертная пассивка.</b> TreePassives.apply() переключается по ID узла и case «' + esc(n.id) + '» не знает. ' +
          'Игрок заплатит ' + (n.spCost || 0) + ' SP и не получит ничего. Нужно добавить поле в TreePassives.Bonuses и потребитель в соответствующей системе — это правка Java, не данных.' +
          (impl.length ? '<div class="w">Реализованы: ' + esc(impl.join(', ')) + '</div>' : '') + '</div>' : '')) +
    '<div class="row" style="margin-top:10px"><button class="btn sm danger" id="n-del">Удалить узел</button>' +
    '<span class="spacer"></span><button class="btn sm" id="n-apply">Применить к tree.json</button></div>' +
    '<datalist id="dl-clans">' + D.clans.map(c => '<option value="' + esc(c.id) + '">').join('') + '</datalist>' +
    '<datalist id="dl-jutsu">' + D.jutsu.map(j => '<option value="' + esc(j.data.id || '') + '">' + esc(j.data.name || '') + '</option>').join('') + '</datalist>' +
    '</div>';

  const set = (k, cast) => { const e = $('#' + k); if (!e) return; e.onchange = () => { n[cast.k] = cast.f(e.value); treeTouched(); }; };
  const treeTouched = () => { markDirty(D.tree.path, JSON.stringify(D.tree.data, null, 2) + '\n'); drawTree(); };
  set('n-type', { k: 'type', f: v => v });
  set('n-branch', { k: 'branch', f: v => v });
  set('n-dist', { k: 'distance', f: v => Number(v) || 1 });
  set('n-ao', { k: 'angleOffset', f: v => Number(v) || 0 });
  set('n-sp', { k: 'spCost', f: v => Number(v) || 0 });
  set('n-icon', { k: 'icon', f: v => v || '?' });
  set('n-name', { k: 'name', f: v => v });
  set('n-desc', { k: 'description', f: v => v });
  set('n-eff', { k: 'effect', f: v => v });
  set('n-val', { k: 'value', f: v => Number(v) || 0 });
  const rq = $('#n-req'); if (rq) rq.onchange = () => { n.requires = rq.value.split(',').map(s => s.trim()).filter(Boolean); treeTouched(); };
  const cl = $('#n-clan'); if (cl) cl.onchange = () => { if (cl.value) n.clanRequired = cl.value; else delete n.clanRequired; treeTouched(); };
  const jid = $('#n-jid'); if (jid) jid.onchange = () => { if (jid.value) n.jutsuId = jid.value; else delete n.jutsuId; treeTouched(); renderNodePanel(); };
  const nid = $('#n-id'); if (nid) nid.onchange = () => {
    const old = n.id, nv = nid.value.trim();
    if (!nv || nv === old) return;
    n.id = nv;
    for (const m of (D.tree.data.nodes || [])) m.requires = (m.requires || []).map(r => r === old ? nv : r);
    curNode = nv; treeTouched(); renderNodePanel(); toast('Узел переименован, зависимости обновлены');
  };
  $('#n-del').onclick = () => {
    if (!confirm('Удалить узел «' + n.id + '»? Зависимые узлы останутся с битым requires.')) return;
    D.tree.data.nodes = D.tree.data.nodes.filter(x => x.id !== n.id);
    curNode = null; treeTouched(); renderTree($('#view'));
  };
  $('#n-apply').onclick = () => { treeTouched(); toast('Изменения внесены в tree.json (в памяти). Нажмите «Сохранить».', 'ok'); };
}

/* ============================== КЛАНЫ ====================================== */
function renderClans(v) {
  v.innerHTML = '<h2 class="title">Кланы <span class="sub">' + D.clans.length + ' файл(ов) в data/shinobicore/clans · ClanDefinition — record из 10 полей</span></h2>' +
    '<div class="row" style="align-items:flex-start;gap:12px">' +
      '<div style="width:230px;flex:0 0 230px"><div class="jlist" style="max-height:none">' +
        '<div id="clist"></div>' +
        '<div style="padding:8px"><button class="btn sm" id="c-new">＋ Новый клан</button></div></div></div>' +
      '<div style="flex:1;min-width:0" id="ceditor"></div>' +
      '<div style="width:340px;flex:0 0 340px" id="cradar"></div>' +
    '</div>';
  $('#c-new').onclick = () => {
    const id = 'new_clan';
    const o = { id: id, name: 'New Clan', affinity: 'fire', extraAffinityCount: 0, statBonuses: {}, natureBonuses: {}, costMultiplier: {}, fatigueMultiplier: 1, reserveBonus: 0, dojutsuHook: '' };
    const path = 'src/main/resources/data/shinobicore/clans/' + id + '.json';
    const txt = JSON.stringify(o, null, 2) + '\n';
    markDirty(path, txt); S.files.clans.push({ path: path, name: id + '.json', text: txt });
    buildModel(); curClan = D.clans.findIndex(x => x.id === id); renderClans($('#view'));
  };
  if (curClan < 0 || curClan >= D.clans.length) curClan = D.clans.length ? 0 : -1;
  const list = $('#clist');
  D.clans.forEach((c, i) => {
    const n = h('<div class="item ' + (i === curClan ? 'on' : '') + '"><span class="dot" style="background:' + elColor(c.data.affinity) + '"></span>' +
      '<span class="nm">' + esc(c.data.name || c.id) + '<br><span class="dim mono" style="font-size:10px">' + esc(c.id) + '</span></span>' +
      '<span class="rk" style="color:var(--dim)">' + Object.keys(c.data.statBonuses || {}).length + '</span></div>');
    n.onclick = () => { curClan = i; renderClans($('#view')); };
    list.appendChild(n);
  });
  renderClanEditor(); renderRadar();
}
function renderClanEditor() {
  const box = $('#ceditor'); if (!box) return;
  const c = D.clans[curClan]; if (!c) { box.innerHTML = ''; return; }
  const cl = c.data, cc = C();
  const iss = validateClan(cl);
  const mapRows = (obj, keys, step, title) =>
    '<div style="margin-top:9px"><b class="dim" style="font-size:11px">' + title + '</b><div class="grid g4" style="margin-top:5px">' +
    keys.map(k => '<label class="f"><span>' + esc(elName(k) === k ? k : elName(k)) + '</span>' +
      '<input type="number" step="' + step + '" data-map="' + title + '" data-k="' + esc(k) + '" value="' + esc((obj || {})[k] !== undefined ? obj[k] : '') + '" placeholder="—"></label>').join('') + '</div></div>';
  box.innerHTML = '<div class="card"><h3>' + esc(cl.name || cl.id) + ' <span class="hint mono">' + esc(c.path) + '</span></h3>' +
    '<div class="grid g3">' +
      field('id', '<input id="c-id" class="mono" value="' + esc(cl.id || '') + '">') +
      field('name', '<input id="c-name" value="' + esc(cl.name || '') + '">') +
      field('affinity', '<select id="c-aff">' + optList(cc.elements || [], cl.affinity, elName) + '</select>') +
      field('extraAffinityCount', '<input id="c-eac" type="number" value="' + esc(cl.extraAffinityCount || 0) + '">', 'Сколько дополнительных природ сверх одной') +
      field('fatigueMultiplier', '<input id="c-fm" type="number" step="0.05" value="' + esc(cl.fatigueMultiplier !== undefined ? cl.fatigueMultiplier : 1) + '">', '1.0 = как у всех') +
      field('reserveBonus', '<input id="c-rb" type="number" value="' + esc(cl.reserveBonus || 0) + '">', 'Плоская прибавка к запасу чакры') +
      field('dojutsuHook', '<input id="c-doj" list="dl-doj2" value="' + esc(cl.dojutsuHook || '') + '" placeholder="пусто = нет додзюцу">') +
    '</div>' +
    '<datalist id="dl-doj2"><option value="sharingan"><option value="byakugan"><option value="rinnegan"></datalist>' +
    '<div style="margin-top:9px"><b class="dim" style="font-size:11px">statBonuses (StatType)</b><div class="grid g4" style="margin-top:5px">' +
      (cc.stats || []).map(k => '<label class="f"><span>' + esc(k) + '</span><input type="number" data-stat="' + esc(k) + '" value="' + esc((cl.statBonuses || {})[k] !== undefined ? cl.statBonuses[k] : '') + '" placeholder="0"></label>').join('') + '</div></div>' +
    mapRows(cl.natureBonuses, cc.elements || [], '1', 'natureBonuses') +
    mapRows(cl.costMultiplier, cc.elements || [], '0.05', 'costMultiplier') +
    '<div style="margin-top:11px">' + issuesHtml(iss) + '</div></div>';

  const touch = () => { markDirty(c.path, JSON.stringify(cl, null, 2) + '\n'); refreshFileText(c.path, JSON.stringify(cl, null, 2) + '\n'); renderRadar(); };
  const B = (id, k, f) => { const e = $(id); if (e) e.onchange = () => { cl[k] = f(e.value); touch(); }; };
  B('#c-name', 'name', v => v); B('#c-aff', 'affinity', v => v);
  B('#c-eac', 'extraAffinityCount', v => Number(v) || 0); B('#c-fm', 'fatigueMultiplier', v => Number(v) || 1);
  B('#c-rb', 'reserveBonus', v => Number(v) || 0); B('#c-doj', 'dojutsuHook', v => v);
  $('#c-id').onchange = () => {
    const old = cl.id, nv = $('#c-id').value.trim(); if (!nv || nv === old) return;
    cl.id = nv;
    const np = 'src/main/resources/data/shinobicore/clans/' + nv + '.json';
    dirty.delete(c.path); c.path = np;
    if (D.tree) { let n = 0; for (const b of Object.keys(D.tree.data.branches || {})) if (D.tree.data.branches[b].clan === old) { D.tree.data.branches[b].clan = nv; n++; }
      for (const nd of (D.tree.data.nodes || [])) if (nd.clanRequired === old) { nd.clanRequired = nv; n++; }
      if (n) markDirty(D.tree.path, JSON.stringify(D.tree.data, null, 2) + '\n'); }
    touch(); renderClans($('#view')); toast('Клан переименован; ссылок в дереве обновлено: см. tree.json');
  };
  $$('[data-stat]').forEach(i => i.onchange = e => {
    cl.statBonuses = cl.statBonuses || {}; const v = e.target.value;
    if (v === '') delete cl.statBonuses[i.dataset.stat]; else cl.statBonuses[i.dataset.stat] = Number(v);
    touch();
  });
  $$('[data-map]').forEach(i => i.onchange = e => {
    const grp = i.dataset.map === 'natureBonuses' ? 'natureBonuses' : 'costMultiplier';
    cl[grp] = cl[grp] || {}; const v = e.target.value;
    if (v === '') delete cl[grp][i.dataset.k]; else cl[grp][i.dataset.k] = Number(v);
    touch();
  });
}
function renderRadar() {
  const box = $('#cradar'); if (!box) return;
  const stats = C().stats || [];
  if (!stats.length) { box.innerHTML = ''; return; }
  const W = 320, cx = W / 2, cy = 150, R = 96;
  const maxV = Math.max(1, ...D.clans.map(c => Math.max(0, ...stats.map(s => Number((c.data.statBonuses || {})[s] || 0)))));
  let s = '<svg viewBox="0 0 ' + W + ' 300" width="' + W + '" xmlns="http://www.w3.org/2000/svg">';
  for (let ring = 1; ring <= 3; ring++) {
    const rr = R * ring / 3, pts = stats.map((x, i) => { const a = -Math.PI / 2 + i * 2 * Math.PI / stats.length; return (cx + rr * Math.cos(a)).toFixed(1) + ',' + (cy + rr * Math.sin(a)).toFixed(1); });
    s += '<polygon points="' + pts.join(' ') + '" fill="none" stroke="#3a2a3e" stroke-width="1"/>';
  }
  stats.forEach((x, i) => {
    const a = -Math.PI / 2 + i * 2 * Math.PI / stats.length;
    s += '<line x1="' + cx + '" y1="' + cy + '" x2="' + (cx + R * Math.cos(a)).toFixed(1) + '" y2="' + (cy + R * Math.sin(a)).toFixed(1) + '" stroke="#2a2033"/>';
    s += '<text x="' + (cx + (R + 15) * Math.cos(a)).toFixed(1) + '" y="' + (cy + (R + 15) * Math.sin(a) + 3).toFixed(1) + '" fill="#9a8fa6" font-size="9" text-anchor="middle">' + esc(x) + '</text>';
  });
  const PAL = ['#ff9ec4', '#7ec8ff', '#ffd75e', '#b48aff', '#7ee08a', '#ff9d6b', '#6bd5ff'];
  D.clans.forEach((c, i) => {
    const col = PAL[i % PAL.length], on = (i === curClan);
    const pts = stats.map((x, k) => {
      const a = -Math.PI / 2 + k * 2 * Math.PI / stats.length;
      const v = Number((c.data.statBonuses || {})[x] || 0) / maxV;
      return (cx + R * v * Math.cos(a)).toFixed(1) + ',' + (cy + R * v * Math.sin(a)).toFixed(1);
    });
    s += '<polygon points="' + pts.join(' ') + '" fill="' + col + '" fill-opacity="' + (on ? .28 : .08) + '" stroke="' + col + '" stroke-width="' + (on ? 2.4 : 1) + '"/>';
  });
  s += '</svg><div class="legend">' + D.clans.map((c, i) => '<span><i style="background:' + PAL[i % PAL.length] + '"></i>' + esc(c.data.name || c.id) + '</span>').join('') + '</div>';
  box.innerHTML = '<div class="card"><h3>Сравнение кланов <span class="hint">statBonuses, макс = ' + fmt(maxV, 0) + '</span></h3>' + s + '</div>';
}

/* ============================== ЛОКАЛИЗАЦИЯ ================================ */
function renderLang(v) {
  const en = D.lang.find(l => l.code === 'en_us'), ru = D.lang.find(l => l.code === 'ru_ru');
  const keys = Array.from(new Set(Object.keys((en && en.data) || {}).concat(Object.keys((ru && ru.data) || {})))).sort();
  const missRu = keys.filter(k => !ru || ru.data[k] === undefined);
  const missEn = keys.filter(k => !en || en.data[k] === undefined);
  const MOJI = /[\u00C2\u00C3\u00D0\u00D1\u20AC\u0080-\u009F]|В§|Â§/;
  const raw = keys.filter(k => MOJI.test(String((en && en.data[k]) || '') + String((ru && ru.data[k]) || '')));
  v.innerHTML = '<h2 class="title">Локализация <span class="sub">' + keys.length + ' ключей · en_us и ru_ru</span></h2>' +
    '<div class="card"><div class="row">' +
      '<span class="pill">всего ключей: ' + keys.length + '</span>' +
      '<span class="pill ' + (missRu.length ? 'tag-bad' : 'tag-ok') + '">нет в ru_ru: ' + missRu.length + '</span>' +
      '<span class="pill ' + (missEn.length ? 'tag-bad' : 'tag-ok') + '">нет в en_us: ' + missEn.length + '</span>' +
      '<span class="pill ' + (raw.length ? 'tag-bad' : 'tag-ok') + '">битая кодировка: ' + raw.length + '</span>' +
      '<span class="spacer"></span><input id="lq" placeholder="фильтр по ключу…" style="width:220px">' +
    '</div></div>' +
    '<div class="card" style="padding:0"><div style="max-height:calc(100vh - 260px);overflow:auto">' +
    '<table class="t"><thead><tr><th style="width:34%">ключ</th><th style="width:33%">en_us</th><th style="width:33%">ru_ru</th></tr></thead><tbody id="ltbody"></tbody></table></div></div>';
  const fill = () => {
    const q = ($('#lq').value || '').toLowerCase();
    const tb = $('#ltbody'); tb.innerHTML = '';
    for (const k of keys) {
      if (q && k.toLowerCase().indexOf(q) < 0) continue;
      const a = en ? en.data[k] : undefined, b = ru ? ru.data[k] : undefined;
      const bad = a === undefined || b === undefined || /В§|Â§/.test(String(a) + String(b));
      tb.appendChild(h('<tr' + (bad ? ' style="background:#241a20"' : '') + '><td class="mono" style="font-size:11px">' + esc(k) + '</td>' +
        '<td>' + (a === undefined ? '<span class="tag-bad">— нет —</span>' : esc(a)) + '</td>' +
        '<td>' + (b === undefined ? '<span class="tag-bad">— нет —</span>' : esc(b)) + '</td></tr>'));
    }
  };
  $('#lq').oninput = fill; fill();
}

/* ============================== ЗВУКИ / РЕЦЕПТЫ ============================ */
function renderSounds(v) {
  const c = C(), sj = (D.sounds && D.sounds.data) || {};
  const keys = Object.keys(sj);
  const reg = c.soundsRegistered || [];
  const unused = keys.filter(k => reg.indexOf(k) < 0);
  const unreg = reg.filter(k => keys.indexOf(k) < 0);
  const usedBy = {};
  for (const j of D.jutsu) for (const kk of Object.keys(j.data.sound || {})) { const val = j.data.sound[kk]; usedBy[val] = (usedBy[val] || 0) + 1; }
  v.innerHTML = '<h2 class="title">Звуки <span class="sub">sounds.json · ModSounds.IDS · SoundDefinition техник</span></h2>' +
    '<div class="card"><div class="row">' +
      '<span class="pill">записей в sounds.json: ' + keys.length + '</span>' +
      '<span class="pill">зарегистрировано SoundEvent: ' + reg.length + '</span>' +
      '<span class="pill ' + (unused.length ? 'tag-warn' : 'tag-ok') + '">без регистрации: ' + unused.length + '</span>' +
      '<span class="pill ' + (unreg.length ? 'tag-warn' : 'tag-ok') + '">зарегистрировано без записи: ' + unreg.length + '</span>' +
    '</div><div class="dim" style="margin-top:7px">«Без регистрации» — звук описан, но SoundEvent для него не создан: игра сыграет ванильный fallback или промолчит. ' +
    'Part 3 (WS-4) регистрирует всё из ModSounds.IDS, поэтому расхождение означает, что файл правили вручную.</div></div>' +
    '<div class="card" style="padding:0"><table class="t"><thead><tr><th>ключ</th><th>subtitle</th><th>ванильный звук</th><th>SoundEvent</th><th>используют техники</th></tr></thead><tbody>' +
    keys.map(k => {
      const e = sj[k] || {};
      const snds = (e.sounds || []).map(x => typeof x === 'string' ? x : (x.name || '')).join(', ');
      return '<tr><td class="mono">' + esc(k) + '</td><td class="mono dim">' + esc(e.subtitle || '') + '</td><td class="mono dim">' + esc(snds) + '</td>' +
        '<td>' + (reg.indexOf(k) >= 0 ? '<span class="tag-ok">да</span>' : '<span class="tag-bad">НЕТ</span>') + '</td>' +
        '<td>' + (usedBy['shinobicore:' + k] || usedBy[k] || 0) + '</td></tr>';
    }).join('') + '</tbody></table></div>';
}
function renderRecipes(v) {
  v.innerHTML = '<h2 class="title">Рецепты <span class="sub">' + D.recipes.length + ' файл(ов) в data/shinobicore/recipes</span></h2>' +
    D.recipes.map(r => '<div class="card"><h3>' + esc(r.name) + '</h3><pre class="json mono">' + esc(JSON.stringify(r.data, null, 2)) + '</pre></div>').join('');
}

/* ============================== ПРОВЕРКА =================================== */
function renderValidate(v) {
  const rows = [];
  for (const j of D.jutsu) { const i = validateJutsu(j.data); if (i.length) rows.push({ obj: j.data.name || j.data.id, path: j.path, issues: i, kind: 'Техника' }); }
  if (D.tree) { const i = validateTree(); if (i.length) rows.push({ obj: 'tree.json', path: D.tree.path, issues: i, kind: 'Дерево' }); }
  for (const c of D.clans) { const i = validateClan(c.data); if (i.length) rows.push({ obj: c.data.name || c.id, path: c.path, issues: i, kind: 'Клан' }); }
  const errs = rows.reduce((a, r) => a + r.issues.filter(x => x.lvl === 'err').length, 0);
  const warns = rows.reduce((a, r) => a + r.issues.filter(x => x.lvl === 'warn').length, 0);
  v.innerHTML = '<h2 class="title">Проверка данных <span class="sub">те же правила, что в tools\\check_jutsu.ps1, но словарь взят живьём из исходников</span></h2>' +
    '<div class="card"><div class="row">' +
      '<span class="pill ' + (errs ? 'tag-bad' : 'tag-ok') + '">ошибок: ' + errs + '</span>' +
      '<span class="pill ' + (warns ? 'tag-warn' : 'tag-ok') + '">предупреждений: ' + warns + '</span>' +
      '<span class="pill">объектов с замечаниями: ' + rows.length + '</span>' +
      '<span class="spacer"></span>' +
      '<label style="display:flex;align-items:center;gap:6px"><input type="checkbox" id="v-only-err"> только ошибки</label>' +
    '</div><div class="dim" style="margin-top:7px">Ошибки — техника не сработает или сломает дерево. Предупреждения — параметр будет проигнорирован, ' +
    'баланс выбивается из шкалы ранга, либо пассивка инертна. Ошибки блокируют /reload-загрузку конкретной техники, остальные продолжают работать.</div></div>' +
    '<div id="vrows"></div>';
  const draw = () => {
    const only = $('#v-only-err').checked;
    const box = $('#vrows'); box.innerHTML = '';
    for (const r of rows) {
      const list = only ? r.issues.filter(i => i.lvl === 'err') : r.issues;
      if (!list.length) continue;
      const e = list.filter(i => i.lvl === 'err').length;
      box.appendChild(h('<div class="card"><h3>' + esc(r.kind) + ': ' + esc(r.obj) +
        ' <span class="hint mono">' + esc(r.path) + (e ? ' · ' + e + ' ошибк(а)' : '') + '</span></h3>' + issuesHtml(list) + '</div>'));
    }
    if (!box.children.length) box.innerHTML = '<div class="card empty">' + (only ? 'Ошибок нет 🌸' : 'Замечаний нет вообще 🌸') + '</div>';
  };
  $('#v-only-err').onchange = draw; draw();
}

/* ============================== СЛОВАРЬ ==================================== */
function renderDict(v) {
  const c = C();
  const sec = (title, hint, body) => '<div class="card"><h3>' + title + (hint ? ' <span class="hint">' + hint + '</span>' : '') + '</h3>' + body + '</div>';
  const tbl = (head, rows) => '<table class="t"><thead><tr>' + head.map(x => '<th>' + esc(x) + '</th>').join('') + '</tr></thead><tbody>' +
    rows.map(r => '<tr>' + r.map(x => '<td>' + x + '</td>').join('') + '</tr>').join('') + '</tbody></table>';
  let html = '<h2 class="title">Словарь движка <span class="sub">извлечён из исходников ' + esc(S.files.generated || '') + ' · PowerShell ' + esc(S.ps) + '</span></h2>';
  html += sec('Почему он живой', 'ничего не захардкожено',
    '<div class="dim">Сервер читает <span class="mono">jutsu/enums/*.java</span>, <span class="mono">executor/*.java</span>, <span class="mono">TreePassives.java</span> и ' +
    '<span class="mono">ModSounds.java</span>, достаёт из них enum’ы, метки arrow-switch’ей и вызовы <span class="mono">getInt/getDouble/getString</span>. ' +
    'Добавите ветку в <span class="mono">EffectExecutor</span> — она появится здесь и в редакторе без правки Studio. ' +
    'Ловушки (значение enum без ветки) вычисляются как «объявлено минус обработано».</div>');

  const traps = c.traps || {};
  const trapRows = [];
  for (const k of Object.keys(traps)) for (const t of traps[k]) trapRows.push([esc(k), '<b class="tag-bad">' + esc(t) + '</b>',
    k === 'activation' ? 'нет ветки в JutsuCaster.cast() — техника не сработает' : 'нет ветки в EffectExecutor.apply* — эффект равен нулю']);
  html += sec('ЛОВУШКИ', 'объявлено в enum, но не обрабатывается', trapRows.length
    ? tbl(['где', 'значение', 'последствие'], trapRows)
    : '<div class="issue info" style="border-color:var(--green);background:#1a2a1e">Ловушек нет — каждое значение enum обработано.</div>');

  html += sec('Формы (FormType)', 'FormExecutor.start() → 8 веток',
    tbl(['форма', 'параметры, которые читаются', 'дефолты'], (c.forms || []).map(f => {
      const sp = (c.formSpecs || {})[f] || { params: [], defaults: [] };
      return ['<b>' + esc(f) + '</b>', '<span class="mono">' + esc(sp.params.join(', ') || '—') + '</span>',
        '<span class="mono dim">' + esc(sp.defaults.map(d => d.key + '=' + d.default).join(', ') || '—') + '</span>'];
    })));
  html += sec('Строковые значения форм', 'сравниваются в коде явно',
    tbl(['параметр', 'значения'], Object.keys(c.formEnums || {}).map(k => ['<span class="mono">' + esc(k) + '</span>', '<span class="mono">' + esc((c.formEnums[k] || []).join(', ') || '—') + '</span>'])));

  html += sec('Активации (ActivationType)', 'JutsuCaster.cast()',
    tbl(['тип', 'обрабатывается', 'параметры'], (c.activations || []).map(a => {
      const ok = (c.activationHandled || []).indexOf(a) >= 0;
      const ap = (c.activationParams || {})[a] || { params: [] };
      return ['<b>' + esc(a) + '</b>', ok ? '<span class="tag-ok">да</span>' : '<span class="tag-bad">НЕТ — ловушка</span>',
        '<span class="mono">' + esc(ap.params.join(', ') || '—') + '</span>'];
    })));

  html += sec('Эффекты', 'EffectExecutor / WorldEffectExecutor',
    Object.keys(c.effects || {}).map(t => {
      const e = c.effects[t];
      return '<div style="margin-bottom:9px"><b style="color:var(--sakura)">' + esc(t) + '</b> <span class="dim mono">' + esc(e.method) + '</span>' +
        tbl(['подтип', 'обрабатывается', 'параметры', 'дефолты'], e.declared.map(s => {
          const ok = e.handled.indexOf(s) >= 0;
          const bs = (e.bySubtype || {})[s] || { params: [], defaults: [] };
          return ['<span class="mono">' + esc(s) + '</span>', ok ? '<span class="tag-ok">да</span>' : '<span class="tag-bad">НЕТ</span>',
            '<span class="mono">' + esc(bs.params.join(', ') || '—') + '</span>',
            '<span class="mono dim">' + esc(bs.defaults.map(d => d.key + '=' + d.default).join(', ') || '—') + '</span>'];
        })) + '</div>';
    }).join(''));

  html += sec('Свойства (properties)', 'hasProp() / prop() / case "…" ->',
    tbl(['свойство', 'параметры'], Object.keys(c.properties || {}).sort().map(k =>
      ['<span class="mono"><b>' + esc(k) + '</b></span>', '<span class="mono dim">' + esc((c.properties[k] || []).join(', ') || 'флаг без параметров') + '</span>'])));

  html += sec('Стихии', 'ElementType: id, название, цвет, звук по умолчанию',
    tbl(['id', 'название', 'цвет', 'ванильный звук'], (c.elements || []).map(e => {
      const i = (c.elementInfo || {})[e] || {};
      return ['<span class="mono">' + esc(e) + '</span>', esc(i.name || ''), '<span class="pill" style="background:#' + esc(i.color || '888') + ';color:#000">#' + esc(i.color || '') + '</span>', '<span class="mono dim">' + esc(i.sound || '—') + '</span>'];
    })));
  html += sec('Прочие enum’ы', '', tbl(['набор', 'значения'], [
    ['ResourceType (cost)', '<span class="mono">' + esc((c.resources || []).join(', ')) + '</span>'],
    ['StatType (requirements.stats, statBonuses)', '<span class="mono">' + esc((c.stats || []).join(', ')) + '</span>'],
    ['Ранги (в данных)', '<span class="mono">' + esc((c.ranks || []).join(', ')) + '</span>'],
    ['Шкала баланса Part 3', '<span class="mono">' + esc(Object.keys(RANK_BALANCE).map(k => k + ': ' + RANK_BALANCE[k].cost + ' чакры / ' + RANK_BALANCE[k].dmg + ' урона').join(' · ')) + '</span>']
  ]));
  html += sec('Пассивки дерева, которые действительно применяются', 'TreePassives.apply() → case "id узла"',
    '<div class="dim" style="margin-bottom:6px">Всего реализовано: ' + (c.passivesImplemented || []).length + '. Остальные пассивные узлы — инертны: SP списывается, эффекта нет.</div>' +
    '<div class="row tight">' + (c.passivesImplemented || []).map(x => '<span class="pill mono">' + esc(x) + '</span>').join('') + '</div>');
  html += sec('Звуки', 'ModSounds.IDS + sounds.json',
    '<div class="dim" style="margin-bottom:6px">Зарегистрировано SoundEvent: ' + (c.soundsRegistered || []).length + ' · записей в sounds.json: ' + (c.soundsJson || []).length + '</div>' +
    '<div class="row tight">' + (c.soundsRegistered || []).map(x => '<span class="pill mono">' + esc(x) + '</span>').join('') + '</div>');
  html += sec('Частицы', 'движок передаёт строку в реестр частиц — формально годится любая minecraft:<id>',
    '<div class="dim" style="margin-bottom:6px">Уже используются в данных: ' + (c.particlesSeen || []).map(x => '<span class="pill mono">' + esc(x) + '</span>').join(' ') + '</div>' +
    '<div class="row tight">' + (c.particlesSuggested || []).map(x => '<span class="pill mono">' + esc(x) + '</span>').join('') + '</div>');
  v.innerHTML = html;
}

/* ============================== ЗАПУСК ===================================== */
document.addEventListener('keydown', e => {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') { e.preventDefault(); saveAll(); }
});
$('#btn-save').onclick = saveAll;
$('#btn-reload').onclick = () => { if (dirty.size && !confirm('Есть несохранённые изменения (' + dirty.size + '). Перечитать с диска и потерять их?')) return; loadState(); };
loadState();