# ChatGPT mechanics audits r4 + r5 (30 Oct 2026, chat "Roblox Development Depth", Thinking high) on v4 / v4.1

James after v3.1: keep merging + mining; a TYCOON with two mined materials (one builds the base via walk-on pads, the
other gets aliens via an incubator/egg); maybe not the UFO beam; multiple maps / players per map?; gate abilities so
they have one at first?

## r4 on v4: GO WITH CHANGES for the tycoon direction (prefers v4 to v3.1 for young players); NO-GO for locking the economy
Scores: 0 9 · 1 8 · 2 9 · 3 9 · 4 8 · **5 hatching 6 NO-GO** · **6 abilities 6 NO-GO** · 7 9 · 8 8 · 9 8 · 10 9 · 11 7.
- Abilities (answer to James): YES, gate them, but fast: PASSIVE level 1, AUTO level 2 (2-3 min), ORDER level 3
  (5-8 min), PvP at level 3 (~10 min); per species, kits unchanged; 4-20 = mastery, looks, small PvE bonus.
- 8 plots round one crater + one moon: GO (load-test 8 after one full plot). More moons = content later.
- Hatching one at a time: YES, but 16 in 5-8 min, 24 in 12-18, 32 in 20-30 (not 2-3 h). Protect favourites; keep each
  alien's look through merge/split; never duplicate rarity; a poorer roll never silently replaces; DNA/fragments instead.
  Cosmic 0.02 % = 1 in 5,000: rewards between rare finds. Own 32 per species but one species (32) per battle.
- PvP: standardised 32 matter even with 8 owned; PvE uses the owned army.
- Roblox: save pads/upgrades/balances/eggs/cosmetics/mastery in a session-locked profile; idempotent pad purchases;
  offline earnings computed on return from server timestamps, capped 7,200 s; benchmark 8 built plots + 3 hub 8v8 fights;
  alien ids + provenance; DNA never purchasable directly or indirectly (paid-random rules); odds table incl. Normal 89.38 %.
- Camera: overhead tactical, UFO decorative.

## r5 on v4.1: GO WITH THREE MINOR CHANGES
§5 GO 9/10 · §6 GO 9.5/10 · §8 GO after F1 · §11 GO after F2-F3.
F1 hub nests = 8 UNITS a side (not matter), player picks which owned aliens (first Titan can fight there).
F2 delete the "last 20 match ids" line (M3 permanent settlement is the rule).
F3 offline payout: saved rate from the last session, rock + new lastSeen in one profile update, never paid twice.
"The design is now sufficiently stable for implementation ... apply F1-F3, then build the vertical slice. Further
document rounds should be driven by actual gameplay or test failures." -> all applied in v4.2.
