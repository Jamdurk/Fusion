// Kit uplift per form: how much stronger B + C make it (edge with / edge without, averaged over the other race's 4 forms).
import { edge, COMP } from "./sim.mjs";
import { KITS } from "./kits.mjs";
const N = Number(process.argv[2] ?? 24), FS = ["F1","F2","F3","F4"];
for (const race of ["SQUISH","CRUNCH"]) { const other = race === "SQUISH" ? "CRUNCH" : "SQUISH";
  for (const f of FS) { const off = new Set(KITS[race][f].abilities.filter(a => a.slot !== "A").map(a => a.id));
    const per = FS.map(g => edge(race, COMP[f], other, COMP[g], N, new Set()) / edge(race, COMP[f], other, COMP[g], N, off) - 1);
    console.log(race.padEnd(6), f, KITS[race][f].name.padEnd(9), "B+C uplift avg", (100 * per.reduce((s, x) => s + x, 0) / 4).toFixed(0) + "%", " per enemy form", per.map(x => (100 * x).toFixed(0) + "%").join(" ")); } }
