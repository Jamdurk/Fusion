# Crater landmark: build log (30 Oct 2026)

References: `design\concepts\hub\B-crater-landmark-chatgpt.png`, `B2-crater-modelling-sheet-chatgpt.png`, `A-master-map-chatgpt.png`.
Build: `assets\blender\scripts\hub_crater.py` -> `roblox-ready\hub-crater.obj` (7.7k tris, 23 pieces) -> 3D Importer ->
`src\tools\hub-crater-place.luau` -> `workspace.Hub.CraterLandmark` in `AlienFusion-map.rbxl` (saved 18:12; backup
`backups\AlienFusion-map.pre-hub-crater-30Oct.rbxl`). The old FusionReactor + glow moved to ServerStorage._HubOld.

| Round | What | ChatGPT |
|---|---|---|
| v1-v3 | petal shell (upright), ring at +46 then raised to +74 x1.45 for the 120-stud test | r1 NO-GO 4/10: "an upright alien portal", rim hides it, ring = thin wires |
| r3 | tried a long ribbed hull: read as a cage | (not sent) |
| r4 | back to B2 petals: plates 1/3/5 dominant, tilted 35 deg, rear buried, x1.3; branching cracks; 8 hull fragments; ring 4 dark 6 x 4 segments, 4-stud gaps; rim NOTCH (24 wide, stepped) on the plot side | r2 **GO WITH CHANGES, proceed to the G2 plot**: match 6.5, spectacle 7, phone 7.5, perf 9 |
| r5 (live in Studio, not in the script yet) | core 11 across SmoothPlastic darker violet + Neon heart; orb SmoothPlastic + Neon heart; ring Metal slate; halo dimmer | its fix 3 + part of fix 1 |

Live Studio edits not yet folded into the scripts: terrain mound under the wreck (+7, FillBall), wreck raised +7, rim notch
(4 stepped FillBlock Air cuts toward (-95, 90)), r5 materials. Fold them in before the next full re-run.
Still to do (landmark polish pass, ChatGPT r2): ring tilted 10-15 deg more toward the plots; 2 big detached hull plates;
the 50-60 stud dark impact scar; animation (ring 0.6 RPM, halo 1.2 RPM, beam + core pulse, rock bob, meteor every
90-120 s, client side); a real phone test. Approved for map progression, not for release.
