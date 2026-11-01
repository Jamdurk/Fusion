// Alien Fusion: bake the GOO effect shapes into one OBJ for Studio's 3D Importer (batch 3, 28 Oct).
// Same shapes as src/ReplicatedStorage.AlienFusion.GooMesh.module.luau (EditableMesh at runtime ran out of the client's
// memory budget after ~3 shapes once attacks cloned them, so the shapes are baked into real meshes instead).
// Each shape is a separate OBJ object named like the module's baked lookup: crown7, crown11, puddle1, puddle2, ring1,
// drop1, lump1, lump2, shell1. Unit size (about 2 studs across); the game sizes them with MeshPart.Size.
// UVs map onto a patch of the Twin's goo texture (u 0.89-0.985, v 0.39-0.485): give each MeshPart the GooSkin.
//   node goo-obj.mjs  -> ..\..\roblox-ready\goo-fx.obj
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const { sin, cos, PI: pi, sqrt, max } = Math;
const TAU = 2 * pi;
const PATCH = [0.89, 0.985, 0.39, 0.485];
const mod1 = (x) => x - Math.floor(x);
const uvAt = (a, b) => [PATCH[0] + (PATCH[1] - PATCH[0]) * mod1(a), PATCH[2] + (PATCH[3] - PATCH[2]) * mod1(b)];
const V = (x, y, z) => ({ x, y, z });
const add = (a, b) => V(a.x + b.x, a.y + b.y, a.z + b.z);
const sub = (a, b) => V(a.x - b.x, a.y - b.y, a.z - b.z);
const mul = (a, s) => V(a.x * s, a.y * s, a.z * s);
const cross = (a, b) => V(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);
const len = (a) => sqrt(a.x * a.x + a.y * a.y + a.z * a.z);
const unit = (a) => { const l = len(a); return l > 1e-9 ? mul(a, 1 / l) : V(0, 1, 0); };

function builder() {
  const B = { pos: [], uv: [], tris: [], double: false };
  B.v = (p, uv) => { B.pos.push(p); B.uv.push(uv); return B.pos.length - 1; };
  B.t = (a, b, c) => B.tris.push([a, c, b]);            // (the Luau module's winding, measured in Studio)
  B.q = (a, b, c, d) => { B.t(a, b, c); B.t(a, c, d); };
  B.loft = (rows, closed) => {
    for (let k = 0; k < rows.length - 1; k++) {
      const r0 = rows[k], r1 = rows[k + 1], n = r0.length;
      for (let i = 0; i < (closed ? n : n - 1); i++) { const j = (i + 1) % n; B.q(r0[i], r0[j], r1[j], r1[i]); }
    }
  };
  return B;
}
function lathe(B, prof, n, rOf) {
  const rows = [];
  prof.forEach((pr, k) => {
    const row = [];
    for (let i = 0; i < n; i++) {
      const a = i / n * TAU;
      const s = rOf ? rOf(a, (k + 1) / prof.length) : 1;
      row.push(B.v(V(cos(a) * pr[0] * s, pr[1], sin(a) * pr[0] * s), uvAt(i / n, (k + 1) / prof.length)));
    }
    rows.push(row);
  });
  B.loft(rows, true);
  return rows;
}
function cap(B, row, p, flip) {
  const c = B.v(p, uvAt(0.5, 0.5));
  for (let i = 0; i < row.length; i++) { const j = (i + 1) % row.length; if (flip) B.t(c, row[i], row[j]); else B.t(c, row[j], row[i]); }
}
function bulb(B, tip, br) {
  const rows = [];
  for (let k = 0; k < 4; k++) {
    const ph = k / 3 * pi, row = [];
    for (let j = 0; j < 5; j++) { const t = j / 5 * TAU; row.push(B.v(add(tip, mul(V(cos(t) * sin(ph), cos(ph), sin(t) * sin(ph)), br)), uvAt(j / 5, k / 4))); }
    rows.push(row);
  }
  B.loft(rows, true);
}
function torusRim(B, N, S, rad, y0, wav, seed) {
  const rows = [];
  for (let i = 0; i < N; i++) {
    const a = i / N * TAU, row = [];
    for (let j = 0; j < S; j++) {
      const t = j / S * TAU;
      const rr = rad(a, t);
      const R = 1 + wav * sin(6 * a + seed);
      row.push(B.v(V(cos(a) * (R + cos(t) * rr), max(0, y0 + sin(t) * rr), sin(a) * (R + cos(t) * rr)), uvAt(i / N, j / S)));
    }
    rows.push(row);
  }
  for (let i = 0; i < N; i++) { const r0 = rows[i], r1 = rows[(i + 1) % N]; for (let j = 0; j < S; j++) { const k = (j + 1) % S; B.q(r0[j], r1[j], r1[k], r0[k]); } }
}

const SHAPES = {
  // PUDDLE: a glossy flat pool, a raised rounded rim, a wavy outline (profile from the lip inward: faces up)
  puddle(seed) {
    const B = builder();
    const wavy = (a) => 1 + 0.07 * sin(5 * a + seed) + 0.05 * sin(9 * a + 2 * seed) + 0.025 * sin(14 * a + 3 * seed);
    const prof = [[0.99, 0], [1.0, 0.07], [0.98, 0.14], [0.92, 0.18], [0.84, 0.16], [0.74, 0.10], [0.55, 0.08], [0.3, 0.09], [0.05, 0.10]];
    const rows = lathe(B, prof, 36, (a) => wavy(a));
    cap(B, rows[rows.length - 1], V(0, 0.10, 0), false);
    return B;
  },
  // CROWN: one sheet of goo rising from a thick base into uneven points, flaring out; a droplet bulb on each peak
  crown(seed, nSpikes) {
    const B = builder(); B.double = true;
    const peaks = [];
    for (let i = 1; i <= nSpikes; i++) peaks.push({ a: (i - 1 + 0.35 * sin(i * 3.1 + seed)) / nSpikes * TAU, h: 0.55 + 0.45 * (0.5 + 0.5 * sin(i * 2.3 + seed)) });
    const W = TAU / nSpikes * 0.33;
    const height = (a) => { let h = 0.22; for (const p of peaks) { const d = Math.abs(((a - p.a + pi) % TAU + TAU) % TAU - pi); if (d < W) h = max(h, 0.22 + (p.h - 0.22) * (1 - d / W) ** 1.7); } return h; };
    const N = 60, K = 6, rows = [];
    for (let k = 0; k <= K; k++) {
      const f = k / K, row = [];
      for (let i = 0; i < N; i++) {
        const a = i / N * TAU, h = height(a);
        let r = 0.62 + 0.12 * f + 0.25 * (f * f) * (h - 0.22) / 0.78;
        r *= 1 + 0.05 * sin(7 * a + seed);
        row.push(B.v(V(cos(a) * r, f * h, sin(a) * r), uvAt(i / N, f)));
      }
      rows.push(row);
    }
    B.loft(rows, true);
    peaks.forEach((p, i) => {
      const r = (0.62 + 0.12 + 0.25 * (p.h - 0.22) / 0.78) * (1 + 0.05 * sin(7 * p.a + seed));
      bulb(B, V(cos(p.a) * r, p.h + 0.04, sin(p.a) * r), 0.06 + 0.035 * (0.5 + 0.5 * sin((i + 1) * 4.1 + seed)));
    });
    return B;
  },
  // DROP: a teardrop, round end down, tail up (+Y)
  drop() {
    const B = builder(), prof = [];
    for (let k = 0; k <= 10; k++) {
      const t = k / 10, y = -0.5 + 1.3 * t;
      let r = t < 0.45 ? 0.5 * sin(pi * (0.5 * t / 0.45)) : 0.5 * (1 - (t - 0.45) / 0.55) ** 1.6 * 0.98;
      if (k === 0) r = 0.02;
      prof.push([max(r, 0.015), y]);
    }
    const rows = lathe(B, prof, 12);
    cap(B, rows[0], V(0, -0.5, 0), true);
    cap(B, rows[rows.length - 1], V(0, 0.8, 0), false);
    return B;
  },
  // RING: a low rolling goo torus, thicker on its outer side, a wavy outline
  ring(seed) {
    const B = builder(); B.double = true;
    torusRim(B, 32, 6, (a, t) => 0.12 * (1 + 0.25 * cos(t)) * (1 + 0.15 * sin(9 * a + seed)), 0.05, 0.04, seed);
    return B;
  },
  // SHELL: a jelly dome, a wobbly surface, a thick rounded rim where it meets the ground
  shell(seed) {
    const B = builder();
    const prof = [];
    for (let k = 0; k <= 7; k++) { const ph = k / 7 * (pi / 2); prof.push([cos(ph), sin(ph)]); }
    const outer = lathe(B, prof, 28, (a, f) => 1 + 0.035 * sin(5 * a + seed + f * 3) * (1 - f) + 0.02 * sin(11 * a + seed));
    cap(B, outer[outer.length - 1], V(0, 1.0, 0), false);
    torusRim(B, 28, 6, (a) => 0.09 * (1 + 0.3 * sin(7 * a + seed)), 0.06, 0, seed);
    return B;
  },
  // LUMP: a lumpy glossy blob dome
  lump(seed) {
    const B = builder(), prof = [];
    for (let k = 0; k <= 7; k++) { const ph = k / 7 * (pi / 2); prof.push([0.02 + cos(ph), sin(ph) * 0.8]); }
    const rows = lathe(B, prof, 24, (a, f) => 1 + 0.12 * sin(4 * a + seed) * sin(f * pi) + 0.08 * sin(7 * a + 2 * seed + f * 4) + 0.05 * sin(13 * a + f * 7));
    cap(B, rows[rows.length - 1], V(0, 0.8, 0), false);
    return B;
  },

  // ---- batch 3 audit r1 (ChatGPT): authored shapes for the Twin + Brute effect sheets ----
  // POOL (Twin STICKY FLOOR, cell 2): 11 rounded lobes, a continuous raised rim, a wide bevel down to the ground. Real
  // proportions (studs / 5): radius 5, rim 0.34 high, centre 0.13
  pool(seed) {
    const B = builder();
    const lobes = (a) => 1 + 0.07 * Math.cos(11 * a + seed) + 0.035 * sin(5 * a + 2 * seed) + 0.02 * sin(17 * a);
    const prof = [[4.97, 0], [5.0, 0.10], [4.93, 0.24], [4.78, 0.34], [4.55, 0.32], [4.3, 0.21], [3.8, 0.14], [2.5, 0.13], [1.0, 0.14], [0.2, 0.13]].map(([r, y]) => [r / 5, y / 5]);
    const rows = lathe(B, prof, 66, (a) => lobes(a));
    cap(B, rows[rows.length - 1], V(0, 0.13 / 5, 0), false);
    return B;
  },
  // SHIELD (Brute CHEST THUMP, cell 4): a rounded jelly dome (not tapered), five broad undulations, a thick base rim
  shield(seed) {
    const B = builder(); B.double = true;
    const prof = [];
    for (let k = 0; k <= 9; k++) { const ph = k / 9 * (pi / 2); prof.push([cos(ph), sin(ph) ** 0.75]); }   // (superellipse: a full, round top)
    const outer = lathe(B, prof, 36, (a, f) => 1 + 0.032 * sin(5 * a + seed + f * 2) + 0.012 * sin(13 * a + seed));
    cap(B, outer[outer.length - 1], V(0, 1.0, 0), false);
    torusRim(B, 36, 6, (a) => 0.05 * (1 + 0.35 * sin(6 * a + seed)), 0.05, 0.015, seed);
    return B;
  },
  // ROPE (Brute STRETCH GRAB, cell 2): a glossy tapered tube along +Y, wide at the shoulder (y 0), thin in the middle
  // (0.38 of the base), thickening into the wrist (y 1)
  rope() {
    const B = builder(), rows = [];
    const N = 12, K = 24;
    for (let k = 0; k <= K; k++) {
      const t = k / K;
      const r = 0.5 * (0.38 + 0.62 * (1 - t) ** 3 + 0.25 * t ** 4);
      const row = [];
      for (let i = 0; i < N; i++) { const a = i / N * TAU; row.push(B.v(V(cos(a) * r, t, sin(a) * r), uvAt(i / N, t))); }
      rows.push(row);
    }
    B.loft(rows, true);
    cap(B, rows[0], V(0, 0, 0), true); cap(B, rows[K], V(0, 1, 0), false);
    return B;
  },
  // ROPE S (the recoil): the same tube on an S-curve (one full wave sideways in X)
  ropeS() {
    const B = builder(), rows = [];
    const N = 10, K = 30;
    for (let k = 0; k <= K; k++) {
      const t = k / K;
      const r = 0.22 * (0.45 + 0.55 * (1 - t) ** 2 + 0.3 * t ** 4);
      const cx = 0.35 * sin(t * TAU) * (1 - t * 0.4), cy = t * 1.6;
      const tx = 0.35 * TAU * cos(t * TAU), ty = 1.6;                   // (tangent: the ring faces along the curve)
      const tl = sqrt(tx * tx + ty * ty), nx = ty / tl, ny = -tx / tl;  // (in-plane normal)
      const row = [];
      for (let i = 0; i < N; i++) { const a = i / N * TAU; row.push(B.v(V(cx + nx * cos(a) * r, cy + ny * cos(a) * r, sin(a) * r), uvAt(i / N, t))); }
      rows.push(row);
    }
    B.loft(rows, true);
    return B;
  },
  // PALM (the open sticky goo hand): a flat palm with 4 spread fingers (+Y) and a thumb, thin along Z (it faces -Z)
  palm() {
    const B = builder();
    const ell = (c, rx, ry, rz, n, m) => {
      const rows = [];
      for (let k = 0; k <= m; k++) {
        const ph = k / m * pi, row = [];
        for (let i = 0; i < n; i++) { const a = i / n * TAU; row.push(B.v(V(c.x + cos(a) * sin(ph) * rx, c.y + cos(ph) * ry, c.z + sin(a) * sin(ph) * rz), uvAt(i / n, k / m))); }
        rows.push(row);
      }
      B.loft(rows, true);
    };
    ell(V(0, 0, 0), 0.5, 0.42, 0.22, 16, 10);                              // (the palm)
    const fingers = [[-0.33, 0.55, -0.22], [-0.11, 0.66, -0.07], [0.12, 0.66, 0.07], [0.34, 0.56, 0.22]];
    for (const [x, y, lean] of fingers) ell(V(x + lean * 0.3, y, 0.02), 0.1, 0.32, 0.1, 10, 8);
    ell(V(0.55, 0.05, 0.02), 0.28, 0.1, 0.1, 10, 8);                      // (the thumb, out sideways)
    return B;
  },
  // RIPPLE (Brute chest, cell 5): a curved patch of three rings (a cap of a sphere, the chest's curve), thin
  ripple() {
    const B = builder(); B.double = true;
    const prof = [];
    for (let k = 0; k <= 18; k++) { const r = 0.02 + k / 18 * 0.98; prof.push([r, -0.25 * r * r + 0.06 * sin(r * 3 * pi) * (1 - r * 0.5)]); }
    lathe(B, prof, 32);
    return B;
  },
  // MOUND (Brute melt, DEFEAT frame 3): a low lumpy mound with THREE drooping fin remnants along its back (+Z)
  mound(seed) {
    const B = builder();
    const prof = [];
    for (let k = 0; k <= 7; k++) { const ph = k / 7 * (pi / 2); prof.push([0.02 + cos(ph), sin(ph) * 0.55]); }
    const rows = lathe(B, prof, 28, (a, f) => 1 + 0.1 * sin(5 * a + seed) * sin(f * pi) + 0.06 * sin(9 * a + seed));
    cap(B, rows[rows.length - 1], V(0, 0.55, 0), false);
    // fins: tapered tubes leaning back and over (35-50 deg droop), on the mound's back ridge
    [[-0.35, 0.18, 0.55, 40], [0.0, 0.32, 0.62, 48], [0.35, 0.16, 0.5, 36]].forEach(([x, z, h, droop], j) => {
      const base = V(x * 0.8, 0.42, z), K = 8, N = 8, fr = [];
      for (let k = 0; k <= K; k++) {
        const t = k / K, ang = (droop * t * t) * pi / 180;
        const c = add(base, V(0, sin(pi / 2 - ang) * h * t, cos(pi / 2 - ang) * h * t + 0.1 * t));
        const r = 0.16 * (1 - t * 0.85) + 0.02, row = [];
        for (let i = 0; i < N; i++) { const a = i / N * TAU; row.push(B.v(add(c, V(cos(a) * r * 0.55, 0, sin(a) * r)), uvAt(i / N, t))); }
        fr.push(row);
      }
      B.loft(fr, true);
    });
    return B;
  },
  // PIN (Brute grab, cell 3): a lumpy glossy blob with SIX sticky strands down to the ground
  pin(seed) {
    const B = builder();
    const prof = [];
    for (let k = 0; k <= 7; k++) { const ph = k / 7 * (pi / 2); prof.push([0.02 + cos(ph) * 0.62, 0.18 + sin(ph) * 0.6]); }
    const rows = lathe(B, prof, 24, (a, f) => 1 + 0.12 * sin(4 * a + seed) * sin(f * pi) + 0.07 * sin(7 * a + 2 * seed));
    cap(B, rows[rows.length - 1], V(0, 0.78, 0), false);
    for (let j = 0; j < 6; j++) {
      const a = j / 6 * TAU + 0.3, K = 8, N = 6, sr = [];
      for (let k = 0; k <= K; k++) {
        const t = k / K;
        const c = V(cos(a) * (0.5 + 0.45 * t), 0.35 * (1 - t) ** 1.4, sin(a) * (0.5 + 0.45 * t));
        const r = 0.05 + 0.04 * (1 - sin(t * pi)) , row = [];
        for (let i = 0; i < N; i++) { const b = i / N * TAU; row.push(B.v(add(c, V(cos(b) * r, sin(b) * r, 0)), uvAt(i / N, t))); }
        sr.push(row);
      }
      B.loft(sr, true);
    }
    return B;
  },
};

// (batch 4, the Drip) SPLAT: the BOING BOMBS impact splat for a giant's sloped back. Local Y = the surface normal,
// -Z = down the slope. 8 uneven rounded lobes, a raised wet centre (0.12 of the 1.0 radius), a low rim; three drips
// running down the slope (0.45 / 0.70 / 0.90 long) with a bead on each tip; two thin strands over the upper edge.
// curv bends the whole sheet away from the normal (0 = flat ground or a broad back, 0.22 = a rounded rock body).
SHAPES.splat = (seed, curv) => {
  const B = builder(); B.double = true;
  const R = (a) => 0.82 + 0.12 * sin(8 * a + seed) + 0.06 * sin(3 * a + 2 * seed) + 0.03 * sin(13 * a + seed);
  const bend = (x, z) => -curv * (x * x + z * z);
  const K = 7, N = 64, rows = [];
  for (let k = 0; k <= K; k++) {
    const f = k / K, row = [];
    for (let i = 0; i < N; i++) {
      const a = i / N * TAU, r = f * R(a);
      const x = cos(a) * r, z = sin(a) * r;
      const h = 0.12 * (1 - f * f) ** 1.5 + 0.035 * Math.exp(-((f - 0.86) ** 2) / 0.006) + 0.012;
      row.push(B.v(V(x, h + bend(x, z), z), uvAt(i / N, f)));
    }
    rows.push(row);
  }
  for (let k = 0; k < K; k++) {                          // (the centre ring collapses to a point: a fan there)
    const r0 = rows[k], r1 = rows[k + 1];
    for (let i = 0; i < N; i++) { const j = (i + 1) % N; if (k === 0) B.t(r0[i], r1[j], r1[i]); else B.q(r0[i], r0[j], r1[j], r1[i]); }
  }
  const tube = (pts, r0, r1) => {                        // (a tube along pts, radius r0 -> r1, a bead on its end)
    const M = 6, sr = [];
    pts.forEach((c, k) => {
      const t = k / (pts.length - 1), r = r0 + (r1 - r0) * t, row = [];
      for (let i = 0; i < M; i++) { const b = i / M * TAU; row.push(B.v(add(c, V(cos(b) * r, sin(b) * r * 0.7 + r * 0.5, 0)), uvAt(i / M, t))); }
      sr.push(row);
    });
    B.loft(sr, true);
    bulb(B, add(pts[pts.length - 1], V(0, r1 * 0.6, -r1 * 0.6)), r1 * 1.7);
  };
  [[-1.75, 0.45], [-1.52, 0.90], [-1.30, 0.70]].forEach(([a, L]) => {   // (three drips, angles round -Z)
    const pts = [];
    for (let k = 0; k <= 8; k++) {
      const z = -(R(a) * 0.85 + L * k / 8);
      const x = cos(a) * R(a) * 0.9 + 0.04 * sin(k + seed);
      pts.push(V(x, 0.015 + bend(x, z), z));
    }
    tube(pts, 0.075, 0.045);
  });
  [[1.25, 0.32], [1.95, 0.26]].forEach(([a, L]) => {     // (two thin strands over the upper edge, +Z)
    const pts = [];
    for (let k = 0; k <= 6; k++) {
      const s = R(a) * 0.9 + L * k / 6, x = cos(a) * s, z = sin(a) * s;
      pts.push(V(x, 0.02 + 0.06 * sin(k / 6 * pi) + bend(x, z), z));
    }
    tube(pts, 0.03, 0.02);
  });
  return B;
};
// (batch 4) SPIRAL: the dazed-eye overlay, a flat ribbon spiral (2.5 turns, radius 0.06 -> 0.5) in the XZ plane,
// facing +Y; sits on the Drip's iris during DEFEAT and spins (the spec's "UV rotation" done as a spin of the overlay)
SHAPES.spiral = () => {
  const B = builder(); B.double = true;
  const N = 90, inner = [], outer = [];
  for (let i = 0; i <= N; i++) {
    const t = i / N, a = t * 2.5 * TAU, r = 0.06 + 0.44 * t, w = 0.035 + 0.03 * t;
    inner.push(B.v(V(cos(a) * (r - w), 0, sin(a) * (r - w)), uvAt(t, 0)));
    outer.push(B.v(V(cos(a) * (r + w), 0, sin(a) * (r + w)), uvAt(t, 1)));
  }
  for (let i = 0; i < N; i++) B.q(inner[i], inner[i + 1], outer[i + 1], outer[i]);
  return B;
};

// the baked set (names = the module's lookup names; seeds = the module's variant numbers)
// (node goo-obj.mjs drip -> only the batch-4 Drip shapes, into roblox-ready/drip-fx.obj)
const DRIP = process.argv[2] === "drip";
const SET = DRIP ? [["splat1", () => SHAPES.splat(1, 0)], ["splat2", () => SHAPES.splat(2, 0.22)], ["spiral1", () => SHAPES.spiral()]] : [
  ["crown7", () => SHAPES.crown(1, 7)], ["crown11", () => SHAPES.crown(1, 11)], ["crown6", () => SHAPES.crown(3, 6)],
  ["puddle1", () => SHAPES.puddle(1)], ["puddle2", () => SHAPES.puddle(2)],
  ["ring1", () => SHAPES.ring(1)], ["drop1", () => SHAPES.drop()],
  ["lump1", () => SHAPES.lump(1)], ["lump2", () => SHAPES.lump(2)], ["shell1", () => SHAPES.shell(1)],
  ["pool1", () => SHAPES.pool(1)], ["shield1", () => SHAPES.shield(2)], ["rope1", () => SHAPES.rope()], ["ropeS1", () => SHAPES.ropeS()],
  ["palm1", () => SHAPES.palm()], ["ripple1", () => SHAPES.ripple()], ["mound1", () => SHAPES.mound(1)], ["pin1", () => SHAPES.pin(2)],
];

let out = "# Alien Fusion goo effect meshes (design/fx/goo-obj.mjs)\n", vBase = 0, nOff = 0, stats = [];
for (const [name, make] of SET) {
  const B = make();
  // smooth normals from the faces as stored
  const nrm = B.pos.map(() => V(0, 0, 0));
  for (const t of B.tris) { const [a, b, c] = t.map((i) => B.pos[i]); const n = cross(sub(b, a), sub(c, a)); for (const i of t) nrm[i] = add(nrm[i], n); }
  out += `o ${name}\ng ${name}\nusemtl ${name}\n`;   // (Studio's importer merged plain "o" objects into one mesh)
  for (const p of B.pos) out += `v ${p.x.toFixed(5)} ${p.y.toFixed(5)} ${p.z.toFixed(5)}\n`;
  // (OBJ's v runs bottom-up, Roblox's top-down: the importer flips it, so write 1 - v to land on the goo patch)
  for (const u of B.uv) out += `vt ${u[0].toFixed(5)} ${(1 - u[1]).toFixed(5)}\n`;
  for (const n of nrm) { const k = unit(n); out += `vn ${k.x.toFixed(5)} ${k.y.toFixed(5)} ${k.z.toFixed(5)}\n`; }
  const nVerts = B.pos.length;
  if (B.double) for (const n of nrm) { const k = unit(n); out += `vn ${(-k.x).toFixed(5)} ${(-k.y).toFixed(5)} ${(-k.z).toFixed(5)}\n`; }
  const f = (i) => `${vBase + i + 1}/${vBase + i + 1}`;
  let tris = 0;
  for (const t of B.tris) { out += `f ${t.map((i) => `${f(i)}/${nOff + i + 1}`).join(" ")}\n`; tris++; }
  if (B.double) for (const t of B.tris) { out += `f ${[t[0], t[2], t[1]].map((i) => `${f(i)}/${nOff + nVerts + i + 1}`).join(" ")}\n`; tris++; }
  stats.push(`${name} ${nVerts}v ${tris}t`);
  vBase += nVerts; nOff += nVerts * (B.double ? 2 : 1);
}
const here = path.dirname(fileURLToPath(import.meta.url));
const dest = path.resolve(here, "..", "..", "roblox-ready", DRIP ? "drip-fx.obj" : "goo-fx.obj");
fs.writeFileSync(dest, out);
console.log(dest, "\n" + stats.join("\n"));
