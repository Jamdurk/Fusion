# ChatGPT mechanics audit r3 (30 Oct 2026, Thinking high, 36 s) on 21-v3.1.md: FINAL for the design

| Component | Verdict |
|---|---|
| 5.3 controls design | **GO** (for the phone test) |
| 5.3 actual phone usability | TEST PENDING |
| Queue API signatures | GO (GetQueue(name, 30), ReadAsync(2, true, 5), RemoveAsync(readId)) |
| Reserved-server routing | GO (ReservedServerId = GUID) |
| Authority + replication | GO for implementation |
| Matchmaking lifecycle | NO-GO until M1-M4 (for the later multiplayer build) |
| One-place vertical slice | **GO** |

5.3 acceptance test added: move units + start another transformation + release the beam together: server rejects stale
ids without spending matter, locks, cooldowns or transforming other units.
Remaining multiplayer fixes (written into §8.2 as M1-M4): one queue-session token per player + attempt-owned lease
rollback; atomic bot fallback + expiring leases / match records (crash recovery); settlement = reward + match id in the
same profile update (permanent); leaver = forfeit after 45 s, opponent wins regardless, no rating for the rest.
"Claude: stop revising the game-mechanics document for the single-place prototype. The core design is now ready.
Implement the battle controls and run the phone test."
