// ORCA local avoidance (agents only), ported to JS from RVO2 (snape/RVO2, src/Agent.cc, commit 6b4eb00, 24 Oct 2026).
// Copyright 2008 University of North Carolina at Chapel Hill. Licensed under the Apache License, Version 2.0
// (http://www.apache.org/licenses/LICENSE-2.0). Changes from the original: plain {x, y} objects; static circles (boulders)
// are agents with zero velocity; each pair splits the avoidance by `share` (RVO2 always splits 0.5 / 0.5) so small units
// step around big ones and a Titan barely flinches for a Drip. Our own code calls computeVelocity() once per unit per tick.
const EPS = 1e-5;
const det = (a, b) => a.x * b.y - a.y * b.x;
const dot = (a, b) => a.x * b.x + a.y * b.y;
const absSq = a => a.x * a.x + a.y * a.y;
const add = (a, b) => ({ x: a.x + b.x, y: a.y + b.y });
const sub = (a, b) => ({ x: a.x - b.x, y: a.y - b.y });
const mul = (a, k) => ({ x: a.x * k, y: a.y * k });
const norm = a => { const L = Math.sqrt(absSq(a)) || 1; return { x: a.x / L, y: a.y / L }; };

function lp1(lines, no, radius, opt, dirOpt, res) {
  const L = lines[no];
  const dp = dot(L.point, L.direction);
  const disc = dp * dp + radius * radius - absSq(L.point);
  if (disc < 0) return false;
  const sd = Math.sqrt(disc);
  let tL = -dp - sd, tR = -dp + sd;
  for (let i = 0; i < no; i++) {
    const den = det(L.direction, lines[i].direction);
    const num = det(lines[i].direction, sub(L.point, lines[i].point));
    if (Math.abs(den) <= EPS) { if (num < 0) return false; continue; }
    const t = num / den;
    if (den >= 0) tR = Math.min(tR, t); else tL = Math.max(tL, t);
    if (tL > tR) return false;
  }
  let p;
  if (dirOpt) p = dot(opt, L.direction) > 0 ? add(L.point, mul(L.direction, tR)) : add(L.point, mul(L.direction, tL));
  else { const t = dot(L.direction, sub(opt, L.point)); p = add(L.point, mul(L.direction, t < tL ? tL : t > tR ? tR : t)); }
  res.x = p.x; res.y = p.y;
  return true;
}

function lp2(lines, radius, opt, dirOpt, res) {
  if (dirOpt) { res.x = opt.x * radius; res.y = opt.y * radius; }
  else if (absSq(opt) > radius * radius) { const n = norm(opt); res.x = n.x * radius; res.y = n.y * radius; }
  else { res.x = opt.x; res.y = opt.y; }
  for (let i = 0; i < lines.length; i++) {
    if (det(lines[i].direction, sub(lines[i].point, res)) > 0) {
      const tmp = { x: res.x, y: res.y };
      if (!lp1(lines, i, radius, opt, dirOpt, res)) { res.x = tmp.x; res.y = tmp.y; return i; }
    }
  }
  return lines.length;
}

function lp3(lines, begin, radius, res) {
  let distance = 0;
  for (let i = begin; i < lines.length; i++) {
    if (det(lines[i].direction, sub(lines[i].point, res)) > distance) {
      const proj = [];
      for (let j = 0; j < i; j++) {
        const d = det(lines[i].direction, lines[j].direction);
        let point;
        if (Math.abs(d) <= EPS) {
          if (dot(lines[i].direction, lines[j].direction) > 0) continue;
          point = mul(add(lines[i].point, lines[j].point), 0.5);
        } else point = add(lines[i].point, mul(lines[i].direction, det(lines[j].direction, sub(lines[i].point, lines[j].point)) / d));
        proj.push({ point, direction: norm(sub(lines[j].direction, lines[i].direction)) });
      }
      const tmp = { x: res.x, y: res.y };
      if (lp2(proj, radius, { x: -lines[i].direction.y, y: lines[i].direction.x }, true, res) < proj.length) { res.x = tmp.x; res.y = tmp.y; }
      distance = det(lines[i].direction, sub(lines[i].point, res));
    }
  }
}

// me = { x, y, vx, vy, r }; prefV = {x, y}; maxSpeed; neighbours = [{ x, y, vx, vy, r, share }] (share = my part of the
// avoidance, 0..1; 0.5 = RVO2's reciprocal split, 1 = I do all of it, e.g. a boulder); horizon (s); dt = tick (s).
export function computeVelocity(me, prefV, maxSpeed, neighbours, horizon, dt) {
  const lines = [];
  const inv = 1 / horizon;
  const vel = { x: me.vx, y: me.vy };
  for (const o of neighbours) {
    const relP = { x: o.x - me.x, y: o.y - me.y };
    const relV = { x: me.vx - o.vx, y: me.vy - o.vy };
    const distSq = absSq(relP), R = me.r + o.r, RSq = R * R;
    let direction, u;
    if (distSq > RSq) {
      const w = sub(relV, mul(relP, inv));
      const wLenSq = absSq(w), dp = dot(w, relP);
      if (dp < 0 && dp * dp > RSq * wLenSq) {
        const wLen = Math.sqrt(wLenSq), unitW = mul(w, 1 / wLen);
        direction = { x: unitW.y, y: -unitW.x };
        u = mul(unitW, R * inv - wLen);
      } else {
        const leg = Math.sqrt(distSq - RSq);
        if (det(relP, w) > 0) direction = mul({ x: relP.x * leg - relP.y * R, y: relP.x * R + relP.y * leg }, 1 / distSq);
        else direction = mul({ x: relP.x * leg + relP.y * R, y: -relP.x * R + relP.y * leg }, -1 / distSq);
        u = sub(mul(direction, dot(relV, direction)), relV);
      }
    } else {
      const invT = 1 / dt;
      const w = sub(relV, mul(relP, invT));
      const wLen = Math.sqrt(absSq(w)) || EPS, unitW = mul(w, 1 / wLen);
      direction = { x: unitW.y, y: -unitW.x };
      u = mul(unitW, R * invT - wLen);
    }
    lines.push({ point: add(vel, mul(u, o.share ?? 0.5)), direction });
  }
  const res = { x: 0, y: 0 };
  const fail = lp2(lines, maxSpeed, prefV, false, res);
  if (fail < lines.length) lp3(lines, fail, maxSpeed, res);
  return res;
}
