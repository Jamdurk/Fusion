# Goo Marsh uploaded asset ids (30-31 Oct 2026)
## Particle textures (assets\textures\hub\fx, hub_goomarsh_fx.py) -> _G.GM_FX (hub-goomarsh-fx.luau)
- dot    rbxassetid://135727507765454
- ring   rbxassetid://113693594523211
- drop   rbxassetid://134282471999470
- bubble rbxassetid://82824705432358
## Emissive masks, bake r5 (assets\textures\hub\gm<Group>_emit.png) -> _G.GM_EMIT (hub-goomarsh-kit.luau)
- giantCap   rbxassetid://139084273541540
- giantGills rbxassetid://119387035420198
- giantStalk rbxassetid://135662040257763
- mush       rbxassetid://135955726191956
- goo        rbxassetid://136216778011165
- nest       rbxassetid://78733087347586
- tunnel     rbxassetid://134589688096962
- poolA      rbxassetid://125811764768100
- poolB      rbxassetid://113463384752717
- flats      rbxassetid://112648806043589
- rocks      rbxassetid://124197516365128
## Overrides (31 Oct ~01:25): importer uploads that never loaded (rendered flat dark grey)
- mush colour 109481863699367 + mush normal 137819332218041 (and normal v2 113493662565849): dead
  -> caps/gills colour rbxassetid://133248699791960 (gmMushCaps_color.png), stalks colour rbxassetid://122255523052996
     (gmMushStalks_color.png, split with gmMush_stalkmask.png); NO normal map on the small mushrooms
- nest colour 74993926219532: dead -> rbxassetid://81669633638971 (gmNest_color_v2.png)
## Pool fix (Studio audit r2 blocker, 31 Oct ~01:50): *_color_v2 / *_emit_v2 from hub_goomarsh_poolfix.py, strength 1.8
- poolA colour rbxassetid://105815469871936, emit rbxassetid://113614846570270
- poolB colour rbxassetid://70718297096388,  emit rbxassetid://122605761008554
- flats colour rbxassetid://131510013263262, emit rbxassetid://78125153870997
- nest tunnel EmissiveStrength 2.5 -> 1.8
