import { edge, COMP } from "./sim.mjs";
const [a, b, n, off] = process.argv.slice(2); const [ra, fa] = a.split("."), [rb, fb] = b.split(".");
console.log(a, "vs", b, edge(ra, COMP[fa], rb, COMP[fb], Number(n), new Set((off ?? "").split(",").filter(Boolean))).toFixed(2));
