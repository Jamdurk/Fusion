// Builds design\power\power-graph.html from kits.mjs + check.json + ablate.json + mixed.json.
// node build-page.mjs
import fs from "node:fs";
import { FORMS, KITS } from "./kits.mjs";
const check = JSON.parse(fs.readFileSync("check.json", "utf8"));
const ablate = JSON.parse(fs.readFileSync("ablate.json", "utf8"));
const mixed = JSON.parse(fs.readFileSync("mixed.json", "utf8"));
const esc = s => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const FS = ["F1", "F2", "F3", "F4"];
const TIER = { F1: "Swarm", F2: "Pack", F3: "Brute", F4: "Titan" };
const JOB = { F1: "kills Titans", F2: "cleans up swarms", F3: "smashes Packs", F4: "crushes Brutes + bases" };
const SLOT = { A: "PASSIVE", B: "AUTO", C: "ORDER" };
const avg = a => a.reduce((s, x) => s + x, 0) / a.length;
const f2 = x => x.toFixed(2);

// numbers worth showing per ability, in plain words
function facts(a) {
  const out = [];
  if (a.every) out.push(`${a.hit} dmg / ${a.every}s`);
  else if (a.hit) out.push(`${a.hit} dmg`);
  if (a.side) out.push(`${a.side} to others`);
  if (a.bonus) out.push(`+${a.bonus} first hit`);
  if (a.cap) out.push(`max ${a.cap} hit`);
  if (a.mult) for (const [f, m] of Object.entries(a.mult)) out.push(`x${m} vs ${TIER[f]}`);
  if (a.surroundMult) out.push(`x${a.surroundMult.F4} Titan / x${a.surroundMult.F3} Brute when 6+ on it`);
  if (a.targets && a.kind === "cleave") out.push(`${a.targets} targets`);
  if (a.slow) out.push(`${a.slow * 100}% slow ${a.dur ?? a.slowDur}s`);
  if (a.stun || a.stunF1 || a.root) out.push(`${a.stun ?? a.stunF1 ?? a.root}s stun`);
  if (a.dr) out.push(`${a.dr * 100}% less dmg`);
  if (a.selfShield) out.push(`shield ${a.selfShield} (+${a.allyShield} friends)`);
  if (a.haste) out.push(`+${a.haste * 100}% attack speed`);
  if (a.burn) out.push(`burns ${a.burn}/s`);
  if (a.base) out.push(`x${a.base} vs bases`);
  if (a.range) out.push(`range ${a.range}`);
  if (a.tele) out.push(`warn ${a.tele}s`);
  if (a.cd) out.push(`every ${a.cd}s`);
  return out;
}

function card(race, f) {
  const k = KITS[race][f], F = FORMS[f], ab = ablate[`${race}.${f}`];
  const rows = k.abilities.map(a => {
    const m = ab?.row.find(r => r.id === a.id);
    const best = m ? Math.max(0, m.bestVal) : 0;
    const w = Math.min(100, best * 100);
    return `<li class="ab">
      <div class="abhead"><span class="slot slot-${a.slot}">${SLOT[a.slot]}</span><b>${esc(a.name)}</b></div>
      <p>${esc(a.text.replace(/^ORDER: (.)/, (m, c) => c.toUpperCase()))}</p>
      <div class="facts">${facts(a).map(x => `<span>${esc(x)}</span>`).join("")}</div>
      ${m ? `<div class="wt" title="Army is ${(best * 100).toFixed(0)}% stronger with it, in its best matchup (vs ${TIER[m.best]})"><div class="bar"><i style="width:${w}%"></i></div><small>+${(best * 100).toFixed(0)}% at its best (vs ${TIER[m.best]})</small></div>` : ""}
    </li>`;
  }).join("");
  return `<article class="card ${race.toLowerCase()}">
    <header><h3>${esc(k.name)}</h3><span class="tier">${f} ${TIER[f]} · ${race}</span></header>
    <div class="stats"><span>${F.hp} HP</span><span>${F.dps} DPS</span><span>speed ${F.speed}</span><span>${F.matter} matter</span></div>
    <ul>${rows}</ul></article>`;
}

// loop ring
const loopAvg = Object.fromEntries(Object.entries(check.loop).map(([k, v]) => [k, avg(v)]));
const diagAvg = Object.fromEntries(Object.entries(check.diag).map(([k, v]) => [k, avg(v)]));
const P = { F1: [90, 60], F4: [330, 60], F3: [330, 250], F2: [90, 250] };
const arrow = (a, b, label) => {
  const [x1, y1] = P[a], [x2, y2] = P[b];
  const dx = x2 - x1, dy = y2 - y1, L = Math.hypot(dx, dy), ux = dx / L, uy = dy / L, pad = 52;
  const sx = x1 + ux * pad, sy = y1 + uy * pad, ex = x2 - ux * pad, ey = y2 - uy * pad;
  const mx = (sx + ex) / 2 - uy * 26, my = (sy + ey) / 2 + ux * 26;
  return `<line x1="${sx}" y1="${sy}" x2="${ex}" y2="${ey}" class="arr" marker-end="url(#ah)"/><text x="${mx}" y="${my + 4}" class="arrlab" text-anchor="middle">${label}</text>`;
};
const node = f => `<g><circle cx="${P[f][0]}" cy="${P[f][1]}" r="40" class="node"/><text x="${P[f][0]}" y="${P[f][1] - 2}" text-anchor="middle" class="nodet">${TIER[f]}</text><text x="${P[f][0]}" y="${P[f][1] + 15}" text-anchor="middle" class="nodes">${f}</text></g>`;
const ring = `<svg viewBox="0 0 420 310" class="ring" role="img" aria-label="Counter loop: Swarm beats Titan, Titan beats Brute, Brute beats Pack, Pack beats Swarm">
  <defs><marker id="ah" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0 L10,5 L0,10 z" class="ahp"/></marker></defs>
  ${arrow("F1", "F4", `${f2(loopAvg["F1>F4"])}x`)}${arrow("F4", "F3", `${f2(loopAvg["F4>F3"])}x`)}${arrow("F3", "F2", `${f2(loopAvg["F3>F2"])}x`)}${arrow("F2", "F1", `${f2(loopAvg["F2>F1"])}x`)}
  <line x1="${P.F1[0] + 30}" y1="${P.F1[1] + 30}" x2="${P.F3[0] - 30}" y2="${P.F3[1] - 30}" class="diag"/><line x1="${P.F2[0] + 30}" y1="${P.F2[1] - 30}" x2="${P.F4[0] - 30}" y2="${P.F4[1] + 30}" class="diag"/>
  <rect x="150" y="134" width="120" height="20" rx="4" class="diagbg"/><text x="210" y="148" text-anchor="middle" class="diaglab">close: ${f2(diagAvg["F1vF3"])} / ${f2(1 / diagAvg["F2vF4"])}</text>
  ${FS.map(node).join("")}</svg>`;

// matchup grid: rows Squish form, cols Crunch form, edge for Squish (needs battle data both ways: use mirror + loop + diag tables)
function edgeOf(rowF, colF, combo) { // combo index 0 = Squish row vs Crunch col
  if (rowF === colF) return check.mirror[rowF];
  const k1 = `${rowF}>${colF}`, k2 = `${colF}>${rowF}`, d1 = `${rowF}v${colF}`, d2 = `${colF}v${rowF}`;
  if (check.loop[k1]) return check.loop[k1][0];
  if (check.loop[k2]) return 1 / check.loop[k2][1];
  if (check.diag[d1]) return check.diag[d1][0];
  if (check.diag[d2]) return 1 / check.diag[d2][1];
}
const cellColor = e => { const t = Math.max(-1, Math.min(1, Math.log(e) / Math.log(2.5))); return t >= 0 ? `color-mix(in oklab, var(--squish) ${Math.round(t * 85)}%, var(--mid))` : `color-mix(in oklab, var(--crunch) ${Math.round(-t * 85)}%, var(--mid))`; };
const grid = `<table class="grid"><thead><tr><th>Squish ↓ vs Crunch →</th>${FS.map(f => `<th>${KITS.CRUNCH[f].name}<small>${f}</small></th>`).join("")}</tr></thead><tbody>
${FS.map(r => `<tr><th>${KITS.SQUISH[r].name}<small>${r}</small></th>${FS.map(c => { const e = edgeOf(r, c); const who = e >= 1 ? KITS.SQUISH[r].name : KITS.CRUNCH[c].name; const x = e >= 1 ? e : 1 / e; return `<td style="background:${cellColor(e)}" title="${who} is ${x.toFixed(2)}x stronger"><b>${x.toFixed(2)}x</b><small>${esc(who)}</small></td>`; }).join("")}</tr>`).join("")}
</tbody></table>`;

const top = mixed.entries.slice(0, 5).map(e => `<li><b>${(e.win * 100).toFixed(0)}%</b> ${e.race === "SQUISH" ? "Squish" : "Crunch"} ${e.comp.F4}T ${e.comp.F3}B ${e.comp.F2}P ${e.comp.F1}S <span class="muted">→ beaten by ${e.counter.race === "SQUISH" ? "Squish" : "Crunch"} ${e.counter.comp.F4}T ${e.counter.comp.F3}B ${e.counter.comp.F2}P ${e.counter.comp.F1}S (${(e.counter.win * 100).toFixed(0)}%)</span></li>`).join("");

const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Alien Fusion Power Graph</title>
<style>
:root{--bg:#fcfcfb;--card:#ffffff;--ink:#0b0b0b;--ink2:#52514e;--muted:#7a7974;--line:#e4e3df;--mid:#f0efec;--squish:#2a78d6;--crunch:#eb6834;--track:#ecebe7}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#1a1a19;--card:#232322;--ink:#f0efec;--ink2:#c3c2b7;--muted:#9a998f;--line:#3a3a37;--mid:#383835;--squish:#3987e5;--crunch:#d95926;--track:#33332f}}
:root[data-theme="dark"]{--bg:#1a1a19;--card:#232322;--ink:#f0efec;--ink2:#c3c2b7;--muted:#9a998f;--line:#3a3a37;--mid:#383835;--squish:#3987e5;--crunch:#d95926;--track:#33332f}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.45 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
main{max-width:1100px;margin:0 auto;padding:24px 16px 60px}h1{font-size:28px;margin:0 0 4px}h2{font-size:19px;margin:36px 0 10px}h3{margin:0;font-size:18px}
.sub{color:var(--ink2);margin:0 0 8px}.muted{color:var(--muted)}
.loop{display:grid;grid-template-columns:minmax(0,420px) 1fr;gap:20px;align-items:center}@media(max-width:760px){.loop{grid-template-columns:1fr}}
.ring{width:100%;height:auto}.node{fill:var(--card);stroke:var(--ink2);stroke-width:2}.nodet{font-weight:700;font-size:15px;fill:var(--ink)}.nodes{font-size:12px;fill:var(--muted)}
.arr{stroke:var(--ink);stroke-width:2.5}.ahp{fill:var(--ink)}.arrlab{font-size:14px;font-weight:700;fill:var(--ink)}.diag{stroke:var(--muted);stroke-width:1.5;stroke-dasharray:4 5}.diaglab{font-size:12px;fill:var(--muted)}.diagbg{fill:var(--bg)}
.tierrow{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:14px}@media(max-width:760px){.tierrow{grid-template-columns:1fr}}
.tierlab{grid-column:1/-1;font-weight:700;margin:10px 0 -4px;color:var(--ink2)}
.card{background:var(--card);border:1px solid var(--line);border-top:4px solid var(--squish);border-radius:10px;padding:14px}.card.crunch{border-top-color:var(--crunch)}
.card header{display:flex;justify-content:space-between;align-items:baseline;gap:8px;flex-wrap:wrap}.tier{color:var(--muted);font-size:13px}
.stats{display:flex;gap:10px;flex-wrap:wrap;color:var(--ink2);font-size:13px;margin:4px 0 6px}
ul{list-style:none;padding:0;margin:0}.ab{border-top:1px solid var(--line);padding:9px 0}.ab p{margin:3px 0 5px;color:var(--ink2)}
.abhead{display:flex;gap:8px;align-items:center}.slot{font-size:11px;font-weight:700;letter-spacing:.04em;padding:2px 6px;border-radius:4px;border:1px solid var(--line);color:var(--ink2)}
.slot-C{background:var(--ink);color:var(--bg);border-color:var(--ink)}
.facts{display:flex;flex-wrap:wrap;gap:4px}.facts span{font-size:12px;background:var(--mid);border-radius:4px;padding:1px 6px;color:var(--ink)}
.wt{display:flex;align-items:center;gap:8px;margin-top:6px}.bar{flex:0 0 120px;height:8px;background:var(--track);border-radius:4px;overflow:hidden}
.bar i{display:block;height:100%;border-radius:0 4px 4px 0}.squish .bar i{background:var(--squish)}.crunch .bar i{background:var(--crunch)}.wt small{color:var(--muted)}
.grid{border-collapse:separate;border-spacing:2px;width:100%;max-width:640px}.grid th,.grid td{padding:8px;text-align:center;border-radius:6px}
.grid th{font-weight:600;font-size:13px}.grid small{display:block;font-weight:400;font-size:11px;color:var(--ink2)}.grid td b{font-size:15px}
.legend{display:flex;gap:16px;font-size:13px;color:var(--ink2);margin:6px 0}.sw{display:inline-block;width:12px;height:12px;border-radius:3px;vertical-align:-1px;margin-right:5px}
.box{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px}ol,.box ul{padding-left:20px}.box ul{list-style:disc}
</style></head><body><main>
<h1>Alien Fusion: Power Graph</h1>
<p class="sub">8 aliens × 3 abilities. Checked in a battle simulator (equal 32-matter armies, thousands of fights), backed by ChatGPT deep research, audited by ChatGPT.</p>
<p class="muted">How to read "2.2x": the winning side is as strong as an army with 2.2x its HP. Close to 1.00x = an even fight.</p>

<h2>The counter loop</h2>
<div class="loop">${ring}
<div class="box"><b>Each alien has three abilities:</b><ul>
<li><b>PASSIVE</b>: how it attacks. It makes its counter job obvious.</li>
<li><b>AUTO</b>: a skill it uses by itself.</li>
<li><b>ORDER</b>: the one button per form. Every unit of that form does it together.</li></ul>
<p class="muted">At most 4 buttons on a phone. Cooldowns belong to the player + form, so splitting and fusing never reset them.</p></div></div>

<h2>The aliens</h2>
${FS.map(f => `<div class="tierrow"><div class="tierlab">${f} ${TIER[f]}: ${JOB[f]}</div>${card("SQUISH", f)}${card("CRUNCH", f)}</div>`).join("")}

<h2>Every form vs every form (Squish vs Crunch)</h2>
<div class="legend"><span><i class="sw" style="background:var(--squish)"></i>Squish side stronger</span><span><i class="sw" style="background:var(--crunch)"></i>Crunch side stronger</span><span><i class="sw" style="background:var(--mid)"></i>even</span></div>
${grid}
<p class="muted">Same form vs same form (the diagonal) is the race check: each is within ${Math.round(100 * Math.max(...Object.values(check.mirror).map(e => Math.abs(e - 1))))}% of even.</p>

<h2>Mixed armies</h2>
<div class="box"><p>${mixed.entries.length} army mixes (22 per race) all fought each other. Overall: <b>Squish ${(mixed.race.SQUISH * 100).toFixed(1)}%</b>, <b>Crunch ${(mixed.race.CRUNCH * 100).toFixed(1)}%</b>. Every mix has a counter that beats it.</p>
<p class="muted">Best mixes and what beats them (T = Titan, B = Brute, P = Pack, S = Swarm):</p><ul>${top}</ul></div>
</main></body></html>`;
fs.writeFileSync("power-graph.html", html);
console.log("wrote power-graph.html", html.length, "bytes");
