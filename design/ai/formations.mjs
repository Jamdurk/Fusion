// Same checks as check.mjs, in a spread-out formation and in a narrow 20-stud lane (audit r1 #9).
// node formations.mjs [runs]
import { edge, COMP, setFormation } from "./sim.mjs";
import { positiveInt } from "./args.mjs";
const N = positiveInt(process.argv[2] ?? 30);
const combos = [["SQUISH","CRUNCH"],["CRUNCH","SQUISH"],["SQUISH","SQUISH"],["CRUNCH","CRUNCH"]];
const f2 = x => x.toFixed(2);
for (const form of ["spread", "lane"]) {
  setFormation(form);
  console.log(`\n== ${form.toUpperCase()}`);
  console.log("mirror " + ["F1","F2","F3","F4"].map(f => f + " " + f2(edge("SQUISH", COMP[f], "CRUNCH", COMP[f], N, new Set()))).join("  "));
  for (const [a, b] of [["F1","F4"],["F4","F3"],["F3","F2"],["F2","F1"],["F1","F3"],["F2","F4"]])
    console.log(`${a}${["F1F3","F2F4"].includes(a + b) ? "v" : ">"}${b}  ` + combos.map(([ra, rb]) => f2(edge(ra, COMP[a], rb, COMP[b], N, new Set()))).join("  "));
}
