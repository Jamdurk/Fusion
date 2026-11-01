// Coarse grid pathfinding round boulders (our code). In Roblox this layer is PathfindingService (or SimplePath, MIT,
// grayzcale) called only when the straight line is blocked, through one global request queue (design §7).
// One grid per clearance: boulders are inflated by the unit's clearance radius PLUS a cell's half-diagonal, so every point
// of a free cell is genuinely clear (code review r3 #3); a Titan sees a wall where a Drip sees a gap.
// path() returns an array of waypoints, or null when there is no safe route (out of the grid, no reachable goal).
const CELL = 1, X0 = -120, Y0 = -90, W = 240, H = 180;   // 240 x 180 studs (the sim's fight area), 1-stud cells
const HALF_DIAG = CELL * Math.SQRT1_2;
const GOAL_CANDIDATES = 3;      // a blocked goal: try the 3 nearest free cells before giving up (review r3 #10)
const GOAL_SEARCH = 12;         // ... within 12 cells of it

export function createNav(obstacles) {
  for (const o of obstacles) if (![o.x, o.y, o.r].every(Number.isFinite) || o.r < 0) throw new RangeError("nav: obstacles need finite x, y and r >= 0");
  const grids = new Map();
  const inBounds = p => p.x >= X0 && p.x < X0 + W * CELL && p.y >= Y0 && p.y < Y0 + H * CELL;
  const cellOf = p => [Math.floor((p.x - X0) / CELL), Math.floor((p.y - Y0) / CELL)];
  const centre = i => ({ x: X0 + (i % W + 0.5) * CELL, y: Y0 + (Math.floor(i / W) + 0.5) * CELL });

  function grid(r) {
    const key = Math.ceil(r * 4) / 4;   // never smaller than the real clearance
    if (grids.has(key)) return grids.get(key);
    const g = new Uint8Array(W * H);
    for (const b of obstacles) {
      const R = b.r + key + HALF_DIAG;
      // loop only over cells inside the grid (review r3b #3: never iterate huge out-of-grid ranges)
      const y0 = Math.max(0, Math.floor((b.y - R - Y0) / CELL)), y1 = Math.min(H - 1, Math.ceil((b.y + R - Y0) / CELL));
      const x0 = Math.max(0, Math.floor((b.x - R - X0) / CELL)), x1 = Math.min(W - 1, Math.ceil((b.x + R - X0) / CELL));
      for (let cy = y0; cy <= y1; cy++)
        for (let cx = x0; cx <= x1; cx++) {
          const c = centre(cy * W + cx);
          if ((c.x - b.x) ** 2 + (c.y - b.y) ** 2 < R * R) g[cy * W + cx] = 1;
        }
    }
    grids.set(key, g);
    return g;
  }

  // segment a→b passes through any boulder inflated by r?
  function blocked(a, b, r) {
    for (const o of obstacles) {
      const R = o.r + r, dx = b.x - a.x, dy = b.y - a.y, L2 = dx * dx + dy * dy || 1e-9;
      const k = Math.max(0, Math.min(1, ((o.x - a.x) * dx + (o.y - a.y) * dy) / L2));
      if ((a.x + dx * k - o.x) ** 2 + (a.y + dy * k - o.y) ** 2 < R * R) return true;
    }
    return false;
  }

  // A* over the grid from cell `start` to cell `goal` (8 neighbours, octile, no corner cutting). Returns the cell chain.
  function astar(g, start, goal) {
    const tx = goal % W, ty = Math.floor(goal / W);
    const startBlocked = g[start] === 1;   // only the cell-margin ring round a boulder (the exit point is truly clear)
    const gS = new Float32Array(W * H).fill(Infinity), came = new Int32Array(W * H).fill(-1), shut = new Uint8Array(W * H);
    const h = i => { const dx = Math.abs(i % W - tx), dy = Math.abs(Math.floor(i / W) - ty); return Math.max(dx, dy) + (Math.SQRT2 - 1) * Math.min(dx, dy); };
    const heap = [];   // binary heap of [f, cell]; ties broken by cell index (deterministic)
    const less = (a, b) => a[0] < b[0] || (a[0] === b[0] && a[1] < b[1]);
    const push = (f, i) => { heap.push([f, i]); let k = heap.length - 1; while (k > 0) { const p = (k - 1) >> 1; if (!less(heap[k], heap[p])) break; [heap[p], heap[k]] = [heap[k], heap[p]]; k = p; } };
    const pop = () => { const top = heap[0], last = heap.pop(); if (heap.length) { heap[0] = last; let k = 0; for (;;) { const l = 2 * k + 1, rr = l + 1; let m = k; if (l < heap.length && less(heap[l], heap[m])) m = l; if (rr < heap.length && less(heap[rr], heap[m])) m = rr; if (m === k) break; [heap[m], heap[k]] = [heap[k], heap[m]]; k = m; } } return top; };
    push(h(start), start); gS[start] = 0;
    while (heap.length) {
      const [, cur] = pop();
      if (shut[cur]) continue; shut[cur] = 1;
      if (cur === goal) break;
      const cx = cur % W, cy = Math.floor(cur / W);
      // a unit pressed into a boulder starts in a blocked cell: it may step OUT through blocked cells for a few studs
      const escaping = startBlocked && gS[cur] < 3;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        if (!dx && !dy) continue;
        const nx = cx + dx, ny = cy + dy; if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
        const n = ny * W + nx;
        if (g[n] && !escaping) continue;
        if (!escaping && dx && dy && (g[cy * W + nx] || g[ny * W + cx])) continue;
        const c = gS[cur] + (dx && dy ? Math.SQRT2 : 1);
        if (c < gS[n]) { gS[n] = c; came[n] = cur; push(c + h(n), n); }
      }
    }
    if (!shut[goal]) return null;
    const chain = [];
    for (let i = goal; i !== -1; i = came[i]) chain.push(i);
    return chain.reverse();
  }

  // the route is safe if every leg clears the boulders at full radius
  function safe(from, pts, r) {
    let a = from;
    for (const p of pts) { if (blocked(a, p, r)) return false; a = p; }
    return true;
  }

  function path(from, to, r) {
    // out of the grid or a non-finite / negative clearance = a real failure (review r3 #9, r3b #3: Infinity used to hang)
    if (!Number.isFinite(r) || r < 0 || ![from.x, from.y, to.x, to.y].every(Number.isFinite) || !inBounds(from) || !inBounds(to)) return null;
    const g = grid(r);
    const [sx, sy] = cellOf(from), [tx, ty] = cellOf(to);
    const goalFree = !g[ty * W + tx];
    // goal candidates: the goal itself, or the nearest free cells to it (ties: nearest the start, then cell index)
    let goals = [ty * W + tx];
    if (!goalFree) {
      const c = [];
      for (let dy = -GOAL_SEARCH; dy <= GOAL_SEARCH; dy++) for (let dx = -GOAL_SEARCH; dx <= GOAL_SEARCH; dx++) {
        const x = tx + dx, y = ty + dy; if (x < 0 || y < 0 || x >= W || y >= H || g[y * W + x]) continue;
        c.push({ i: y * W + x, d: Math.hypot(dx, dy), s: Math.hypot(x - sx, y - sy) });
      }
      c.sort((p, q) => p.d - q.d || p.s - q.s || p.i - q.i);
      goals = c.slice(0, GOAL_CANDIDATES).map(o => o.i);
    }
    // a unit pressed into a boulder first steps straight out of it (radially, deterministic), then routes from there
    let origin = from; const lead = [];
    if (blocked(from, from, r)) {
      origin = exitPoint(from, r);
      if (!origin) return null;
      lead.push(origin);
    }
    const [ox, oy] = cellOf(origin), start = oy * W + ox;
    for (const goal of goals) {
      const chain = astar(g, start, goal);
      if (!chain) continue;
      const pts = chain.slice(1).map(centre);
      if (goalFree) pts.push({ x: to.x, y: to.y });   // never append a blocked destination
      if (!pts.length) {   // already standing on the chosen cell: end at a SAFE point, proved like every other route (r3b #1)
        const endpoint = goalFree ? { x: to.x, y: to.y } : centre(goal);
        if (safe(origin, [endpoint], r) && !blocked(endpoint, endpoint, r)) return [...lead, endpoint];
        continue;
      }
      // string-pull at FULL clearance, then prove the result; fall back to the unsmoothed chain; else no route
      const pulled = []; let a = origin;
      for (let i = 1; i < pts.length; i++) if (blocked(a, pts[i], r)) { pulled.push(pts[i - 1]); a = pts[i - 1]; }
      pulled.push(pts[pts.length - 1]);
      if (safe(origin, pulled, r)) return [...lead, ...pulled];
      if (safe(origin, pts, r)) return [...lead, ...pts];
    }
    return null;
  }
  // push p out of every boulder it overlaps (a few passes: boulders can touch); null if still inside
  function exitPoint(p, r) {
    let q = { x: p.x, y: p.y };
    for (let pass = 0; pass < 4; pass++) {
      let moved = false;
      for (let k = 0; k < obstacles.length; k++) {
        const o = obstacles[k], need = o.r + r + 0.05, dx = q.x - o.x, dy = q.y - o.y, L = Math.hypot(dx, dy);
        if (L >= need) continue;
        const a = L > 1e-6 ? Math.atan2(dy, dx) : k * 2.399963;   // exact centre: a fixed, deterministic direction
        q = { x: o.x + Math.cos(a) * need, y: o.y + Math.sin(a) * need }; moved = true;
      }
      if (!moved) return inBounds(q) ? q : null;
    }
    return blocked(q, q, r) || !inBounds(q) ? null : q;
  }
  return { blocked, path, inBounds };
}
