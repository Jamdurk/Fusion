// node edge1.mjs F1 F4 [runs]: the counter EDGE for one pairing, 4 race combos, new AI
import { edge, COMP, setAI } from "./sim.mjs";
setAI(process.argv.includes("--old") ? "old" : "new");
import { positiveInt } from "./args.mjs";
const [a, b, n] = [process.argv[2], process.argv[3], positiveInt(process.argv[4] ?? 30)];
const combos = [["SQUISH","CRUNCH"],["CRUNCH","SQUISH"],["SQUISH","SQUISH"],["CRUNCH","CRUNCH"]];
console.log(`${a} v ${b}`, combos.map(([ra, rb]) => edge(ra, COMP[a], rb, COMP[b], n, new Set()).toFixed(2)).join("  "));
