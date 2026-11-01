# ChatGPT mechanics audit r1 (30 Oct 2026, chat "Roblox Development Depth", Thinking high, 1m 10s) on 21-v2.md

**Verdict: NO-GO for full production. GO for the 10-minute vertical slice, with changes.**
"The idea is worth building. The v2 production scope isn't."

Scores: 0 premise 9 GO · 1 loop 7 NO-GO · 2 collecting 7 NO-GO · 3 levelling 6 NO-GO · 4 minigames 6 NO-GO ·
5 battles 6 NO-GO (biggest) · 6 return goals 8 GO · 7 money 5 NO-GO · 8 Roblox 6 NO-GO · 9 build order 9 GO · 10 decisions 8 GO.

Fixes it required:
- §1: 5 min hub + 2 x 3 min battles = 11 min, not 10. First battle <= 60 s, first discovery <= 3 min, one full
  collect-battle-collect cycle in 10 min; no fixed time split.
- §2: two races aren't a big species collection; launch 2 races + cosmetic variants; first unusual find GUARANTEED;
  no +2 % mutation stats.
- §3: 4 forms x 30 levels per species = too much; ONE species mastery level 1-20; cosmetic unlocks per form; an Order
  variant that changes the hit shape is not equal power (cosmetic variants must keep the hit geometry); no combat bonus
  in ranked.
- §4: mining only at launch; the UFO minigame after testing, never a daily chore.
- §5: form chips select ALL of a form; players need to pick WHICH group to fuse/split: tap-selected local group or a
  spatial beam target with a clear preview (keep locked distances + times). Vent 2.5 s lock conflicts with the locked
  5 s. Test 12 s respawn (one Titan of 16 vs 16 swarmers dying). Core shield rule ambiguous: one explicit rule. Unit-count
  capture must be simulated with respawns, cooldowns, pylons, core damage. Don't lock 360 x 240 yet. Deploy must allow
  every legal mix, not only presets.
- §7: no +2 % stats, no paid equip slots, no x2 luck at launch (paid-random-items policy: odds + regional rules);
  cosmetics only; ranked fully normalised.
- §8 (Roblox): one place for the slice; MemoryStore UpdateAsync on one key doesn't atomically claim two players: atomic
  pair claim + idempotent match ids; use TeleportOptions.ReservedServerId = GUID (ReserveServer / access codes are
  deprecated: VERIFIED by Claude in the live docs 30 Oct); handle TeleportInitFailed, retries, one-sided arrivals;
  hand off / release profile session locks between places, unique match ids against double rewards; benchmark a real
  two-client live-server match (client FPS proves nothing about the server); measure the snapshot size (640 B is an
  estimate), buffers, chunking, sequence numbers, periodic full-state; replay protection, impossible-target checks.
- Rules lock: 03 still says F3 650/48 vs power graph 560/44: settle it in the locked file first.

B (young mobile audience): potential high, retention confidence low. Borrow: Grow a Garden (mutations, visible growth),
Steal a Brainrot (status, showing off), Fish It! (fast repeatable finds), 99 Nights (escalating goals), RIVALS
(skill + instant rematch). Missing: visible ownership (show your favourite mutation in hub + battle), a spectacular
first fusion, a guaranteed early find, ONE obvious next goal after every reward, instant Rematch. "The differentiator
is not mining ... it's transforming your army during combat to reverse a losing fight."

C (cap): +10/+10 OK as a PvE ceiling; NOT proof for PvP (1.98 is extra-HP-to-tie in specific fights, not a universal
multiplier). First PvP test: casual AND ranked normalised; later compare bonuses on/off incl. level 30 vs 1.

E (its answers): both sides rewarding, no fixed split · no PvP stat bonuses at first · UFO (test on a phone) · smaller
arena prototype, keep the original map to compare · species + cosmetic mutations, no 32 copies · F3 560/44
provisionally, F3 speed stays 16, one Order per form.

Next three tasks it gives Claude: (1) a full bot match where select / fuse / split / Orders are effortless on a phone;
(2) test the objective + respawn rules in the sim before making arena changes permanent; (3) wrap it in a tiny loop:
guaranteed starter, meteorite, discovery, instant rematch. Not yet: ranked seasons, 2nd minigame, deep levelling, money.
