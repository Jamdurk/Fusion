# ChatGPT mechanics audit r2 (30 Oct 2026, Thinking high, 32 s) on 21-v3.md

**Verdict: GO WITH CHANGES.** GO: concept + progression, one-place phone slice. NO-GO: locking 5.3 before touch
testing; cross-server multiplayer until T1-T5.
Scores: 0 9 · 1 9 · 2 9 · 3 9 · 4 9 · 5.1 9 · 5.2 UFO 8 (test on phone) · **5.3 controls 7 NO-GO** · 5.4 8 · 5.5 8 (sim
only) · 5.6 9 · 6 8 · 7 9 · **8 Roblox 7 NO-GO** · 9 9 · 10 9.

- §2: the guaranteed Glowing must override the normal roll, never double, never be overwritten.
- 5.3 (beam = right signature move, not the only way): (1) ring 50-70 px above the finger; (2) tap a group + FUSE
  shortcut; (3) honest preview: server validates the SAME unit ids, cancels if they drifted, never fuses another group;
  (4) tutorial teaches MOVE, FUSE, SPLIT only. Rule fix: four F3 within 18 of THEIR centroid, not "inside a circle".
- ReservedServerId: confirmed.
- T1: ReadAsync takes (count, allOrNothing, waitTimeout); invisibility timeout set in GetQueue; use allOrNothing = true.
- T2: one queue pairs whoever comes first: bands (casual power/MMR, ranked rating) + no player in two queues/matches.
- T3: a match id alone doesn't stop two workers taking the same players: atomic per-player assignment/lease.
- T4: the 20 s bot takeover vs 45 s reconnect conflict: one rule (bot holds the army during the window; player takes it
  back without restart; after the deadline, forfeit/bot policy). Failed teleport after the hub released the lock:
  restore the hub state. Rapid server transition lock races are documented.
- T5: battle server verifies UserId, match id, team, live match record (TeleportData isn't authorisation); stale
  snapshot rejection; reliable + unreliable don't share ordering.
"Don't spend another development round expanding the progression document." Next: the UFO beam on a phone with
tap-to-fuse.

Claude: all applied in 21-GAME-MECHANICS.md (v3.1); MemoryStoreQueue signatures re-checked in the live docs:
ReadAsync(count, allOrNothing?, waitTimeout?), RemoveAsync(id), invisibility default 30 s (set via GetQueue).
