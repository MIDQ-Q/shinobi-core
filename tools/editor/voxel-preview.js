/* Shinobi Editor MVP: 3D voxel preview (dependency-free, guarded) */
(function () {
"use strict";
var VP = window.VoxelPreview = {
  offset: [0, 0, 0], scale: 1, glow: false,
  viewYaw: 35, viewPitch: -18, zoom: 1,
  model: null, modelName: null, imgs: {}, facesCache: null, bbox: null
};
function el(id) { return document.getElementById(id); }
function getState() { return (typeof state !== "undefined") ? state : null; }
function deg(d) { return d * Math.PI / 180; }
function rotY(v, a) { var c = Math.cos(a), s = Math.sin(a); return [v[0]*c + v[2]*s, v[1], -v[0]*s + v[2]*c]; }
function rotX(v, a) { var c = Math.cos(a), s = Math.sin(a); return [v[0], v[1]*c - v[2]*s, v[1]*s + v[2]*c]; }
function rotZ(v, a) { var c = Math.cos(a), s = Math.sin(a); return [v[0]*c - v[1]*s, v[0]*s + v[1]*c, v[2]]; }
function hexColor(c) { if (typeof c === "string" && c.charAt(0) === "#") { var n = parseInt(c.slice(1), 16); if (!isNaN(n)) return n; } return 0xff6600; }
function rgbArr(n) { return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; }
function sub(a, b) { return [a[0]-b[0], a[1]-b[1], a[2]-b[2]]; }
function cross(a, b) { return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]; }
function norm(a) { var l = Math.sqrt(a[0]*a[0]+a[1]*a[1]+a[2]*a[2]) || 1; return [a[0]/l, a[1]/l, a[2]/l]; }
function dot(a, b) { return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]; }

function computeBbox(elements) {
  var mn = [1e9,1e9,1e9], mx = [-1e9,-1e9,-1e9];
  function eat(v) { if (!v) return; for (var i = 0; i < 3; i++) { if (v[i] < mn[i]) mn[i] = v[i]; if (v[i] > mx[i]) mx[i] = v[i]; } }
  (elements || []).forEach(function (e) {
    if (!e) return;
    if (e.type === "mesh") (e.vertices || []).forEach(eat);
    else if (e.from && e.to) { eat(e.from); eat(e.to); }
  });
  if (mn[0] > mx[0]) { mn = [0,0,0]; mx = [0,0,0]; }
  return { center: [(mn[0]+mx[0])/2, (mn[1]+mx[1])/2, (mn[2]+mx[2])/2],
           half: Math.max(mx[0]-mn[0], mx[1]-mn[1], mx[2]-mn[2]) / 2 || 0.5,
           minY: mn[1] };
}

function buildFaces(model) {
  var faces = [];
  (model.elements || []).forEach(function (e) {
    if (!e) return;
    if (e.type === "mesh") {
      var vs = e.vertices || [];
      (e.faces || []).forEach(function (f) {
        if (!f) return;
        var idx = f.indices || [], uv = f.uv || [];
        for (var t = 1; t < idx.length - 1; t++) {
          if (idx[0] == null || idx[t] == null || idx[t+1] == null) continue;
          if (!vs[idx[0]] || !vs[idx[t]] || !vs[idx[t+1]]) continue;
          faces.push({ pts: [vs[idx[0]], vs[idx[t]], vs[idx[t+1]]],
                       uvs: [uv[0], uv[t], uv[t+1]], tex: f.texture || 0, color: 0xff6600 });
        }
      });
    } else if (e.from && e.to) {
      var x1=e.from[0], y1=e.from[1], z1=e.from[2], x2=e.to[0], y2=e.to[1], z2=e.to[2];
      var col = hexColor(e.color); var fu = e.faces || {};
      function quad(pts, fn) {
        var f = fu[fn];
        faces.push({ pts: pts, color: col, tex: f ? (f.texture || 0) : 0,
                     uvs: (f && f.uv) ? [[f.uv[0],f.uv[1]],[f.uv[2],f.uv[1]],[f.uv[2],f.uv[3]],[f.uv[0],f.uv[3]]] : null });
      }
      quad([[x2,y1,z1],[x1,y1,z1],[x1,y2,z1],[x2,y2,z1]], "north");
      quad([[x1,y1,z2],[x2,y1,z2],[x2,y2,z2],[x1,y2,z2]], "south");
      quad([[x2,y1,z2],[x2,y1,z1],[x2,y2,z1],[x2,y2,z2]], "east");
      quad([[x1,y1,z1],[x1,y1,z2],[x1,y2,z2],[x1,y2,z1]], "west");
      quad([[x1,y2,z1],[x2,y2,z1],[x2,y2,z2],[x1,y2,z2]], "up");
      quad([[x1,y1,z1],[x2,y1,z1],[x2,y1,z2],[x1,y1,z2]], "down");
    }
  });
  return faces;
}

function loadImages() {
  VP.imgs = {};
  var ts = (VP.model && VP.model.textures) || [];
  ts.forEach(function (t, i) {
    if (t && t.source && t.source.indexOf("data:image") === 0) {
      var img = new Image();
      img.onload = function () { VP.imgs[i] = img; draw(); };
      img.src = t.source;
    }
  });
}
function setModel(name, elements, textures) {
  VP.modelName = name;
  VP.model = { elements: elements || [], textures: textures || [] };
  VP.bbox = computeBbox(VP.model.elements);
  VP.facesCache = buildFaces(VP.model);
  loadImages(); draw();
}
function ensureModel() {
  var st = getState();
  var name = (st && st.visual && st.visual.voxelModel) || "";
  if (!name) { VP.model = null; VP.modelName = null; VP.facesCache = null; return; }
  if (window.__lastImport && window.__lastImport.name === name) {
    if (VP.modelName !== name) setModel(name, window.__lastImport.elements, window.__lastImport.textures);
    return;
  }
  if (VP.modelName === name && VP.model) return;
  VP.modelName = name; VP.model = null; VP.facesCache = null;
  if (typeof assetsDir !== "undefined" && assetsDir) {
    assetsDir.getDirectoryHandle("voxels").then(function (d) { return d.getFileHandle(name + ".json"); })
      .then(function (fh) { return fh.getFile(); })
      .then(function (f) { return f.text(); })
      .then(function (txt) { var j = JSON.parse(txt); setModel(name, j.elements || j.voxels || [], j.textures || []); })
      .catch(function () { draw(); });
  }
}

function texTri(ctx, img, s0, s1, s2, u0, u1, u2) {
  if (!u0 || !u1 || !u2) return;
  ctx.save();
  ctx.beginPath(); ctx.moveTo(s0[0], s0[1]); ctx.lineTo(s1[0], s1[1]); ctx.lineTo(s2[0], s2[1]); ctx.closePath();
  ctx.clip();
  var den = u0[0]*(u1[1]-u2[1]) + u1[0]*(u2[1]-u0[1]) + u2[0]*(u0[1]-u1[1]);
  if (Math.abs(den) < 1e-6) { ctx.restore(); return; }
  var a  = (s0[0]*(u1[1]-u2[1]) + s1[0]*(u2[1]-u0[1]) + s2[0]*(u0[1]-u1[1])) / den;
  var b  = (s0[0]*(u2[0]-u1[0]) + s1[0]*(u0[0]-u2[0]) + s2[0]*(u1[0]-u0[0])) / den;
  var e  = s0[0] - a*u0[0] - b*u0[1];
  var d2 = (s0[1]*(u1[1]-u2[1]) + s1[1]*(u2[1]-u0[1]) + s2[1]*(u0[1]-u1[1])) / den;
  var f2 = (s0[1]*(u2[0]-u1[0]) + s1[1]*(u0[0]-u2[0]) + s2[1]*(u1[0]-u0[0])) / den;
  var g2 = s0[1] - d2*u0[0] - f2*u0[1];
  ctx.transform(a, d2, b, f2, e, g2);
  ctx.drawImage(img, 0, 0);
  ctx.restore();
}

function draw() {
  var cv = el("vpCanvas"); if (!cv) return;
  var ctx = cv.getContext("2d");
  ctx.clearRect(0, 0, cv.width, cv.height);
  ctx.fillStyle = "#10121c"; ctx.fillRect(0, 0, cv.width, cv.height);
  if (!VP.model || !VP.facesCache || !VP.facesCache.length) {
    ctx.fillStyle = "#9a9db0"; ctx.font = "13px Segoe UI, sans-serif"; ctx.textAlign = "center";
    ctx.fillText("Модель не найдена или не содержит граней:", cv.width/2, cv.height/2);
    ctx.fillText("импортируйте .bbmodel заново (выбрав папку ассетов)", cv.width/2, cv.height/2 + 18);
    ctx.textAlign = "left"; return;
  }
  var c = VP.bbox.center, half = VP.bbox.half;
  var oy = deg(VP.offset[0]), op = deg(VP.offset[1]), orr = deg(VP.offset[2]);
  var vy = deg(VP.viewYaw), vp = deg(VP.viewPitch);
  var DIST = 6 + half * 3;
  function T(v) {
    var p = [(v[0]-c[0])*VP.scale, (v[1]-c[1])*VP.scale, (v[2]-c[2])*VP.scale];
    p = rotY(p, oy); p = rotX(p, op); p = rotZ(p, orr);
    p = rotY(p, vy); p = rotX(p, vp); return p;
  }
  function P(p) { var z = p[2] + DIST; var s = (cv.height * 1.2 * VP.zoom) / z; return [cv.width/2 + p[0]*s, cv.height/2 - p[1]*s, z]; }
  function TV(v) { var p = rotY(v, vy); p = rotX(p, vp); return p; }
  function PG(p) { var z = p[2] + DIST; var s = (cv.height * 1.2 * VP.zoom) / z; return [cv.width/2 + p[0]*s, cv.height/2 - p[1]*s]; }
  var R = Math.ceil(half * 2) + 1, gy = (VP.bbox.minY - c[1]) - 0.15;
  ctx.strokeStyle = "rgba(255,255,255,0.08)"; ctx.lineWidth = 1;
  for (var gi = -R; gi <= R; gi++) {
    var a1 = PG(TV([gi, gy, -R])), a2 = PG(TV([gi, gy, R]));
    ctx.beginPath(); ctx.moveTo(a1[0], a1[1]); ctx.lineTo(a2[0], a2[1]); ctx.stroke();
    var b1 = PG(TV([-R, gy, gi])), b2 = PG(TV([R, gy, gi]));
    ctx.beginPath(); ctx.moveTo(b1[0], b1[1]); ctx.lineTo(b2[0], b2[1]); ctx.stroke();
  }
  var items = [];
  VP.facesCache.forEach(function (f) {
    var p3 = f.pts.map(T), p2 = p3.map(P);
    var zsum = 0; for (var i = 0; i < p3.length; i++) zsum += p3[i][2];
    items.push({ f: f, p2: p2, p3: p3, z: zsum / p3.length });
  });
  items.sort(function (a, b) { return b.z - a.z; });
  var L = norm([-0.42, 0.75, -0.51]);
  items.forEach(function (it) {
    var n = norm(cross(sub(it.p3[1], it.p3[0]), sub(it.p3[2], it.p3[0])));
    var shade = 0.45 + 0.55 * Math.abs(dot(n, L));
    ctx.shadowBlur = VP.glow ? 16 : 0; ctx.shadowColor = "#ff8c40";
    var okUv = it.f.uvs && it.f.uvs.length === it.f.pts.length && it.f.uvs.every(function (u) { return !!u; });
    var img = okUv ? VP.imgs[it.f.tex] : null;
    if (img) {
      var tris = it.p2.length === 4 ? [[0,1,2],[0,2,3]] : [[0,1,2]];
      tris.forEach(function (tr) {
        texTri(ctx, img, it.p2[tr[0]], it.p2[tr[1]], it.p2[tr[2]], it.f.uvs[tr[0]], it.f.uvs[tr[1]], it.f.uvs[tr[2]]);
        ctx.fillStyle = "rgba(0,0,0," + ((1 - shade) * 0.5).toFixed(3) + ")";
        ctx.beginPath(); ctx.moveTo(it.p2[tr[0]][0], it.p2[tr[0]][1]);
        ctx.lineTo(it.p2[tr[1]][0], it.p2[tr[1]][1]); ctx.lineTo(it.p2[tr[2]][0], it.p2[tr[2]][1]);
        ctx.closePath(); ctx.fill();
      });
    } else {
      var col = rgbArr(it.f.color || 0xff6600);
      ctx.fillStyle = "rgb(" + Math.round(col[0]*shade) + "," + Math.round(col[1]*shade) + "," + Math.round(col[2]*shade) + ")";
      ctx.beginPath(); ctx.moveTo(it.p2[0][0], it.p2[0][1]);
      for (var k = 1; k < it.p2.length; k++) ctx.lineTo(it.p2[k][0], it.p2[k][1]);
      ctx.closePath(); ctx.fill();
      ctx.strokeStyle = "rgba(0,0,0,0.3)"; ctx.stroke();
    }
    ctx.shadowBlur = 0;
  });
}

function snippet() {
  var j = el("vpJson"); if (!j) return;
  var st = getState();
  var o = { voxelModel: (st && st.visual && st.visual.voxelModel) || "", rotationOffset: VP.offset, scale: VP.scale, glow: VP.glow };
  j.textContent = JSON.stringify(o, null, 2);
}
function labels() {
  var s;
  s = el("vpYawV"); if (s) s.textContent = VP.offset[0] + "\u00B0";
  s = el("vpPitchV"); if (s) s.textContent = VP.offset[1] + "\u00B0";
  s = el("vpRollV"); if (s) s.textContent = VP.offset[2] + "\u00B0";
  s = el("vpScaleV"); if (s) s.textContent = VP.scale.toFixed(2);
}
function syncFromState() {
  var st = getState(); var vis = (st && st.visual) || {};
  var ro = Array.isArray(vis.rotationOffset) ? vis.rotationOffset : [0,0,0];
  VP.offset = [Math.round(ro[0]||0), Math.round(ro[1]||0), Math.round(ro[2]||0)];
  VP.scale = (typeof vis.scale === "number" && vis.scale > 0) ? vis.scale : 1;
  VP.glow = !!vis.glow;
  var y = el("vpYaw"); if (y) y.value = VP.offset[0];
  var p = el("vpPitch"); if (p) p.value = VP.offset[1];
  var r = el("vpRoll"); if (r) r.value = VP.offset[2];
  var sc = el("vpScale"); if (sc) sc.value = VP.scale;
  var g = el("vpGlow"); if (g) g.checked = VP.glow;
  labels(); snippet();
}
function pushToState() {
  if (typeof setByPath === "function") {
    setByPath("visual.rotationOffset", [VP.offset[0], VP.offset[1], VP.offset[2]]);
    setByPath("visual.scale", VP.scale);
    setByPath("visual.glow", VP.glow);
    if (typeof update === "function") update();
  }
  labels(); snippet();
}
function bindControls() {
  ["vpYaw","vpPitch","vpRoll"].forEach(function (id, i) {
    var s = el(id); if (!s) return;
    s.addEventListener("input", function () { VP.offset[i] = parseInt(s.value, 10) || 0; pushToState(); draw(); });
  });
  var sc = el("vpScale"); if (sc) sc.addEventListener("input", function () { VP.scale = parseFloat(sc.value) || 1; pushToState(); draw(); });
  var gl = el("vpGlow"); if (gl) gl.addEventListener("change", function () { VP.glow = gl.checked; pushToState(); draw(); });
}
function bindMouse() {
  var cv = el("vpCanvas"); if (!cv) return;
  var drag = null;
  cv.addEventListener("mousedown", function (e) { drag = { x: e.clientX, y: e.clientY }; e.preventDefault(); });
  window.addEventListener("mousemove", function (e) {
    if (!drag) return;
    VP.viewYaw += (e.clientX - drag.x) * 0.4;
    VP.viewPitch = Math.max(-89, Math.min(89, VP.viewPitch + (e.clientY - drag.y) * 0.4));
    drag = { x: e.clientX, y: e.clientY }; draw();
  });
  window.addEventListener("mouseup", function () { drag = null; });
  cv.addEventListener("wheel", function (e) {
    e.preventDefault();
    VP.zoom = Math.max(0.3, Math.min(4, VP.zoom * (e.deltaY > 0 ? 0.9 : 1.1))); draw();
  }, { passive: false });
}

VP.mount = function () {
  var panel = el("panel"); if (!panel) return;
  if (!el("vpCard")) {
    var card = document.createElement("div");
    card.id = "vpCard"; card.className = "card";
    card.innerHTML = '<h3>3D превью модели</h3>'
      + '<canvas id="vpCanvas" width="640" height="380" style="width:100%;background:#10121c;border:1px solid #33364a;border-radius:6px;cursor:grab"></canvas>'
      + '<div class="row" style="margin-top:8px"><label>Yaw</label><input type="range" id="vpYaw" min="-180" max="180" step="1" style="flex:1"><span id="vpYawV" class="small"></span></div>'
      + '<div class="row"><label>Pitch</label><input type="range" id="vpPitch" min="-180" max="180" step="1" style="flex:1"><span id="vpPitchV" class="small"></span></div>'
      + '<div class="row"><label>Roll</label><input type="range" id="vpRoll" min="-180" max="180" step="1" style="flex:1"><span id="vpRollV" class="small"></span></div>'
      + '<div class="row"><label>Масштаб</label><input type="range" id="vpScale" min="0.1" max="3" step="0.05" style="flex:1"><span id="vpScaleV" class="small"></span></div>'
      + '<div class="row"><label>Свечение</label><input type="checkbox" id="vpGlow"></div>'
      + '<div class="small">ЛКМ по превью - орбита, колесо - зум. Слайдеры пишут visual.rotationOffset / scale / glow в JSON техники (в игре применяется после /reload).</div>'
      + '<pre id="vpJson" class="small" style="margin-top:6px;white-space:pre-wrap"></pre>';
    panel.insertBefore(card, panel.firstChild);
    bindControls(); bindMouse();
  }
  syncFromState(); ensureModel(); draw();
};
})();