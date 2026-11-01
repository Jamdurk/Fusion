// Static guard rails (no fights): warning times, CC caps, shields, area caps, Order payload per matter.
// node guard.mjs   (exit code 1 if a rule is broken)
import { FORMS, KITS, RULES } from "./kits.mjs";
let bad = 0;
const row = (ok, txt) => { if (!ok) bad++; console.log(ok ? "  ok " : "  !! ", txt); };
for (const race of ["SQUISH", "CRUNCH"]) for (const f of ["F1", "F2", "F3", "F4"]) {
  const k = KITS[race][f], F = FORMS[f];
  console.log(`${race} ${f} ${k.name}`);
  for (const a of k.abilities) {
    const tag = `${a.slot} ${a.name}`;
    if (a.tele != null) {
      const need = f === "F4" ? RULES.minTele.titan : a.slot === "C" ? RULES.minTele.order : RULES.minTele.auto;
      row(a.tele >= need || (a.slot === "B" && f === "F4" && a.tele >= RULES.minTele.auto), `${tag}: warning ${a.tele}s (min ${need})`);
    }
    if (a.stun ?? a.stunF1 ?? a.root) row((a.stun ?? a.stunF1 ?? a.root) <= RULES.stunMax, `${tag}: stun ${a.stun ?? a.stunF1 ?? a.root}s (max ${RULES.stunMax})`);
    if (a.slow) row(a.slow <= RULES.slowCap && (a.dur ?? a.slowDur) <= 2.5, `${tag}: slow ${a.slow * 100}% for ${a.dur ?? a.slowDur}s (max ${RULES.slowCap * 100}%, 2.5 s)`);
    if (a.selfShield) row(a.selfShield <= F.hp * 0.2, `${tag}: shield ${a.selfShield} = ${(100 * a.selfShield / F.hp).toFixed(0)}% of HP (max 20%)`);
    if (a.dr && a.vsOnly) row(a.dr <= 0.85 && a.cd >= 8, `${tag}: one-hit dodge, ${a.dr * 100}% off a single ${a.vsOnly.join("/")} hit, every ${a.cd}s`);
    else if (a.dr && a.slot !== "A") row(a.dr <= 0.5 && (a.dur ?? 0) <= 3, `${tag}: damage cut ${a.dr * 100}% for ${a.dur}s (short only)`);
    if (a.cap) row(a.cap <= (f === "F2" ? 4 : f === "F4" ? 4 : 3) || a.kind === "leapSlam", `${tag}: hits at most ${a.cap}`);
    if (a.slot === "C") {
      row(a.cd >= 22 && a.cd <= 30, `${tag}: Order cooldown ${a.cd}s (22-30)`);
      const payload = (a.hit ?? a.bonus ?? 0) + (a.side ?? 0) * Math.max(0, (a.cap ?? 1) - 1) + (a.kind === "leapSlam" || a.kind === "dashLine" ? (a.hit ?? 0) * ((a.cap ?? 1) - 1) : 0);
      const perMatter = payload / F.matter;
      console.log(`       ${tag}: max direct payload ${payload} per unit = ${perMatter.toFixed(0)} per matter (guide ~${RULES.orderBudgetPerMatter}; CC/defence Orders count lower)`);
    }
    if (a.slot === "B" && a.cd) row(a.cd >= 6 && a.cd <= 12, `${tag}: auto cooldown ${a.cd}s (6-12)`);
  }
}
console.log(bad ? `${bad} RULE(S) BROKEN` : "ALL GUARD RAILS MET");
process.exitCode = bad ? 1 : 0;
