=== ROUND 1 PART 1 ===
ChatGPT said:
GO WITH CHANGES — do not port v1 verbatim

Architecture: approved. Implementation: not yet. This is a better foundation than the old nearest-enemy AI, but I found one major logic bug that disables an entire behaviour system, several navigation and collision edge cases, and a significant gap between the eight advertised personalities and what the shared brain actually implements.

I compared the ORCA code with RVO2's original Agent.cc, inspected the uploaded brain, profiles, pathfinder and simulator, and checked the Roblox implementation claims against official documentation.

The encouraging result is that I would not rewrite the AI architecture. I would fix it, preserve the power graph, and rerun the behavioural tests before James builds the Luau version.

1. Required changes, in priority order
1. Fix EVADE — currently effectively disabled (critical)

In ai-brain.js, line 73:

JavaScript
const saviour = pred && friends.find(
  f => PREDATOR[pred.form] !== f.form
    && PREY[f.form][pred.form] >= 3
    && dist(f, u) < 60
);

The !== excludes the exact form that hunts the predator.

For example, a Drip fears F2; F3 is the unit that counters F2. But PREDATOR.F2 === "F3", so the Brute is excluded.

This happens throughout the counter cycle. Your EVADE-to-bodyguard behaviour never gets its intended rescuer.

Replace it with:

JavaScript
const saviour = pred && friends
  .filter(f =>
    f.alive &&
    f.form === PREDATOR[pred.form] &&
    dist(f, u) < 60
  )
  .sort((a, b) => dist(a, u) - dist(b, u))[0];

Keep the existing holdMax values: Squish 2.5–3s, Crunch 1.5s, and the 3s forced-engage window.

This fix will change combat results. The current hunter-exposure reduction cannot be credited to the fear/evade system. It is likely coming from spacing, target selection or other movement logic.

2. Fix melee slot ownership and unnecessary repositioning (high)

goalFor() stores occupied slots in the target's Map, keyed by integer index. The problem is that slot counts differ by attacker size.

A Drip and a Brute can both use slot 2 while having completely different ring geometry. The reservation system treats their indices as equivalent. Releasing or refreshing a slot can also delete a reservation without verifying ownership.

Required:

Key reservations using a shared angular grid, for example 24 sectors around each target, rather than an index derived independently for every attacking unit.

Release only when slots.get(key) === u.

Do not reassign a valid slot every 0.6–1.0s. Retain it until blocked, the target changes, or meaningful positional improvement is possible.

Set a minimum reassignment interval of 1.5s and require a new position to reduce travel distance by at least 2 studs before switching.

The current slot-refresh behaviour could make aliens orbit their targets rather than fight them.

3. Fix ORCA exact-overlap and update-order problems (high)

I checked lp1, lp2, lp3, the velocity-obstacle construction and the RVO2 source.

Linear-program port

PASS

The important determinant signs, cut-off circle calculations, leg projections and LP failure recovery match RVO2's structure. Your lp3 omits the obstacle-line prefix because your system uses only agent-style ORCA constraints; that is consistent with this simplified implementation. 
GitHub

The per-pair share change is mathematically sound:

𝑠
𝐴
→
𝐵
=
𝑚
𝐵
𝑚
𝐴
+
𝑚
𝐵
s
A→B
	​

=
m
A
	​

+m
B
	​

m
B
	​

	​


The reverse contribution is 
𝑚
𝐴
/
(
𝑚
𝐴
+
𝑚
𝐵
)
m
A
	​

/(m
A
	​

+m
B
	​

), and the two sum to 1. A Drip should indeed move much more than a Colossus.

But two problems remain.

First, two units with identical positions and zero velocity produce no separating direction. I reproduced this using computeVelocity(): the resulting velocity was (0, 0). Your hard-separation pass also has a zero-distance direction problem.

Use a deterministic unit-ID-based separation normal when distance is below 0.001 studs. Do this before the ORCA solve and in hard separation; do not rely on random movement to resolve it.

Second, the simulator processes movement sequentially. Later units can observe positions and velocities already updated for earlier units in the same tick. That violates the simultaneous-state assumption behind reciprocal avoidance.

Required: snapshot all agents' positions and velocities, calculate every desired velocity from that snapshot, then integrate movement for every agent. Keep damage and timed ability resolution deterministic.

One final limitation: your 0.8-radius scaling and post-ORCA acceleration clamp mean even a correct LP solution does not guarantee actual collision avoidance. Treat hard separation as a safety net and measure its frequency. 
GitHub

4. Repair A* path failures and the repath limiter (high)

ai-nav.js has three concerning edge cases.

The first is the nearStart = gS[cur] < 3 exception. It allows blocked cells during the first few steps even when the starting cell was valid. That can produce paths that cut through terrain.

The second is the blocked-goal fallback. The search may terminate near an obstructed goal but then append the original blocked destination to the path.

The third is in brain.steer(): when nav.path() returns null, !A.path remains true, so the system can retry every movement tick instead of respecting the intended one-second limit.

Required:

Permit traversal of a blocked start cell only when the start cell itself is blocked, and only while exiting that region.

Reject blocked goals; select the nearest reachable free cell instead.

Set nextPathAttempt = now + 1.0s whether the path succeeded or failed.

After three consecutive failed attempts, switch to a reachable fallback goal, and record a navigation failure.

Also note that the prototype grid is only 240 × 180 studs. The actual larger Roblox map needs appropriately scoped navigation data, not a literal port of those fixed bounds.

5. Repair the stuck detector, then measure actual stalls

I do not accept the explanation that 4–12% stuck time is simply the cost of intelligent positioning.

Some of it may be legitimate. But it may also include deadlock, arrival braking, avoidance-induced waiting and failed routing.

The reported metric checks displacement over a tick; that is not equivalent to failure to make progress toward a reachable goal.

Use separate states:

State

	

Definition




Fighting

	

Within valid attack reach or intentionally completing an attack




Positioning

	

Moving towards a reachable slot




Yielding

	

ORCA slows movement to prevent collision




Blocked

	

Goal is reachable but progress remains below 25% of expected movement for 1.5s




Path failed

	

No valid route can be found

For the next run, require true blocked time below 3%, with no unit trapped for over 3 consecutive seconds unless it genuinely has no accessible route.

The observed 45–60% engagement time versus the old AI's 55–75% also needs separation by form. A Drip spending time flanking a Titan is different from a Ram failing to reach a Pack. The current comparison cannot establish whether the loss is healthy positioning.

6. Make the promised personalities actually influence behaviour

Several source creatures appear in profiles.js descriptions without their signature logic being implemented in the shared brain.

Most notably:

Pincer: Nutcracker-inspired sentry positioning is currently mostly a guard-target score, not a true hold-position state.

Ram: no Thumper-style straight-line acceleration ramp or overshoot behaviour is implemented yet.

Brute: no Eyeless Dog-style suspicion/commitment meter; mostly a target preference and a friendly-spacing bias.

Titan: Forest Keeper-style stop-and-look and escalation are not part of the simulation.

Colossus: its courage: 1 currently has no effect because evade is null. Its principal movement distinction is a slightly lower acceleration.

I would implement two identity-critical movement differences before the first visual review:

Ram: during an unobstructed pursuit lasting at least 0.6s, ramp from 70% to 100% of normal speed, with turn responsiveness reduced by 20% at full speed. Reset the ramp after a sharp turn or obstruction. Keep its Order charge timing separate.

Pincer: when guarding a friendly F3/F4, hold its assigned defensive position for at least 2.0s, unless a prey unit enters direct attack reach or the guarded unit moves more than 6 studs.

These are candidate values, not simulator-validated balance numbers. The remaining personality animation and state hooks can be completed during the Roblox implementation, but they need explicit acceptance tests rather than descriptive comments.

7. Correct overkill prediction and opportunistic targeting

The shared brain declares a dps(u,e) hook in its interface, but ai-sim.js estimates incoming damage using base form DPS × 1.5 seconds.

That ignores important counter multipliers and F4's massive anti-Brute slam.

For example, an F4's nominal DPS is 100, but its 1,000-damage slam every 4 seconds corresponds to 250 DPS against Brutes before misses, wind-ups and overkill. The incoming-damage estimate can be substantially wrong.

Use effective target-specific damage over the next 1.5 seconds, including the relevant passive and attack readiness. It need not predict every ability perfectly.

Also remove the current attack-of-opportunity selection based simply on the first enemy in the unit array. Prefer enemies with valid prey priority and never interrupt deliberate pursuit merely because a predator happened to be listed first.

8. Rerun balance after the critical fixes

Do not tune any of the power-graph damage numbers yet.

Run the existing counter suite after fixing EVADE, slots, navigation and update ordering. Add these behavioural checks: all four predator/rescuer interactions, exact-overlap recovery, unreachable destinations, two-way bottlenecks, and attack uptime per form.

The check-new-ai.txt file confirms the reported basic counters, but not the complete movement metrics or the final mixed-army run. Those remain preliminary.

2. Lethal Company source fidelity and alien fit

Your mapping is generally sensible as inspiration, but I would not call every alien a faithful implementation of its Lethal Company source.

The uploaded decompilation notes describe plausible, detailed behaviours. However, I have not independently inspected the claimed April 2026 game binary, so I cannot authenticate every exact timing or state transition from those notes alone. They are substantially more useful than the uncited Deep Research report.

Alien

	

Fit

	

Audit




Drip

	

9/10

	

Baboon Hawk pack behaviour and Snare Flea attachment are excellent fits. Fix the disabled EVADE logic.




Pebble

	

8/10

	

Hawk courage fits; Thumper's momentum is more relevant to ROLL OUT than the current ordinary movement




Twin

	

9/10

	

Hoarding Bug territorial annoyance maps naturally to protecting larger allies




Pincer

	

7/10

	

Nutcracker sentinel is a good choice, but actual stationary guard behaviour is underimplemented




Brute

	

7/10

	

Eyeless Dog commitment and Kidnapper Fox grab suit the creature; too much of that identity exists only in the kit




Ram

	

7/10

	

Thumper is the correct source, but acceleration, overshoot and charge positioning need implementation




Titan

	

8/10

	

Forest Keeper is a strong reference for large, deliberate movement; current AI lacks several of its presentation beats




Colossus

	

7/10

	

Keeper + Old Bird is coherent, but its AI is almost the same as Titan's

I would not replace these with other Lethal Company creatures. The source choices are reasonable; the incomplete translation into gameplay is the problem.

The previous Deep Research report should not be trusted for exact Lethal Company implementation facts. Its claim that Old Birds release swarms of smaller birds, for example, conflicts with your decompilation notes. Likewise, treat its Roblox performance estimates as unverified until measured.

On licensing: RVO2's original repository identifies the code as Apache-2.0. Preserve its copyright and licence notices and document your changes. James's reported conversation with Zeekers is relevant, but the decompilation notes are not independent evidence of the permission's terms. Keep any written permission or correspondence alongside the project documentation. 
GitHub

3. Squish swarm versus Crunch swarm

Accept the current asymmetry provisionally. Do not force both to 2.3.

The F1-versus-F4 values run from roughly 1.90 to 2.69 across pairings. That is a meaningful difference, but both races remain Titan predators and same-form race mirrors are close.

Different movement identities should legitimately change matchup performance.

However, the disabled EVADE system means these are not the results of the complete intended AI. Recheck after that repair. I would become concerned if an equivalent race pairing systematically gives one swarm a counter edge more than 30% stronger without a compensating advantage elsewhere, or if real-player race win rates depart substantially from parity.

4. Should non-swarm units automatically dodge Titan slams?

Agree with the intention; disagree with an absolute movement prohibition.

Units should not gain omniscient, telegraph-reactive dodges. That would make a 1-second Titan warning almost useless against competent AI.

But ordinary movement must continue. A Brute already circling a Titan should be allowed to leave the danger wedge naturally, even during the wind-up. Freezing it in place would look contrived.

Recommended rule: 0% additional dodge steering triggered by the Titan's warning for F2/F3, while preserving their pre-existing navigation, acceleration and targeting. F1's kit-specific BOING remains reactive. The F4 counters should be maintained by ability geometry and stats, not by artificially immobilising prey.

5. Bot opponent

I would not lock Normal to the third-best static counter mix.

Your simulator demonstrates that every sampled composition has a strong counter among the sampled static compositions. It does not demonstrate that a bot can reach that composition in time, especially with one fusion/split per decision and a five-second transformation lock.

Keep the difficulty reaction settings, but score the bot's choices using reachable transitions rather than an instantaneous perfect composition.

Difficulty

	

Decision interval

	

Reaction delay

	

Recommendation




Easy

	

20s

	

3s

	

Keep




Normal

	

12s

	

1.5s

	

Choose a good reachable response, with occasional suboptimal decisions




Hard

	

6s

	

0.6s

	

Choose the strongest reachable response, not a theoretically perfect static mix

For Normal, choosing randomly from the top three reachable actions is more believable than choosing the third-best complete army. Use a 3-second regroup limit when retreating, otherwise repeated retreat decisions may produce passive matches.

The bot should also obey the same visibility, cooldown, transformation and matter rules as a player.

6. Roblox implementation plan — verified against current documentation

Server-side shared ArmyAI

Approve

One central state simulation, staggered decisions and a spatial index are appropriate for 64 units. Roblox's Parallel Luau documentation supports parallelising complex NPC workloads when sequential work becomes expensive, but it does not prescribe a particular NPC count or guarantee a performance budget. 
Documentation - Roblox Creator Hub

There is also a calculation error in the design: 64 units thinking five times per second means 320 decisions per second, averaging 5.3 decisions per 60 Hz frame, not 13. Steer at 20 Hz means 1,280 unit steering updates per second.

PathfindingService only when blocked

Approve

The queue/cache strategy is sensible. Roblox documents pathfinding failures caused by node budgets and incompatible agent parameters. It does not establish a universal “150 active paths” performance threshold. ComputeAsync() yields and should be scheduled conservatively; measure requests and latency on the actual map. 
Documentation - Roblox Creator Hub
+2

The shared flow field works for rally navigation; it does not replace local target slots or individual obstacle avoidance.

UnreliableRemoteEvent positions

Approve with constraints

Roblox explicitly recommends UnreliableRemoteEvent for continuously changing, short-lived data. Its payload limit is 1,000 bytes, and messages may be dropped or arrive out of order. 
Documentation - Roblox Creator Hub
+1

Use sequence numbers, packed position buffers, client interpolation and occasional complete correction snapshots. A starting target is 10 Hz position updates, then measure whether 15–20 Hz materially improves appearance on phones. Keep authoritative damage, target decisions, fusion, Orders and unit creation/deletion on reliable server state and reliable event paths as appropriate.

A sensible initial packet format is an ID, quantised X/Z, quantised facing and a compact state flag per updated unit. Verify the actual encoded size rather than assuming buffer compression always keeps it below 1,000 bytes.

Avoid server-owned physical rigs as the automatic fallback merely because custom interpolation is difficult. Roblox warns that forcing server network ownership can increase jitter and physics cost. Profile that choice rather than assuming it is cheaper. 
Documentation - Roblox Creator Hub
+1

One more important issue: your simulator steers at 10 Hz, while the proposed Roblox implementation steers at 20 Hz. ORCA's immediate collision branch depends on dt, so this is not a performance-only change. Rerun the movement tests at dt = 0.05s before declaring the port equivalent.

7. What James will still notice as “iffy”

Even with the bugs repaired, a creature can be logically correct but visually unconvincing. The biggest remaining risks are units repeatedly circling a moving target without attacking, Titans rotating awkwardly before moving, Pincers failing to hold a recognisable defensive line, and Rams sliding around corners instead of committing to a heavy charge.

I would deliberately watch four scenes in Studio: 16 Drips surrounding one Titan; a Brute trying to reach a Twin behind two boulders; a Ram charging through a crowded lane; and a Titan surrounded by swarmers with friendly Packs nearby.

Those scenes should show the behaviours the profiles promise, not merely produce favourable win percentages.

Final verdict

GO WITH CHANGES. The overall system is the right direction, and the counter graph's headline results justify continuing with this design.

But fix the broken rescuer predicate, shared slot reservations, simultaneous ORCA updates, and navigation failure handling before a line-by-line Luau port. Then verify the 20 Hz implementation and reassess the movement metrics.

The most important finding is that the current simulation reports better positioning without its intended EVADE-to-bodyguard system functioning. That is a genuine opportunity to improve the AI, but it also means the current balance numbers do not describe the finished behaviour.

And, since James apparently insists on immaculate wording: “the ALIEN AI” is perfectly understandable, but “the aliens’ AI” is the cleaner possessive construction. Even a rock crab deserves correct punctuation.

You said:
Claude here. Thanks, strong audit: I had found the same EVADE bug myself while you were thinking, and all 8 required changes are now applied (details next round with the full re-run). Your reply stopped partway through section 5 (bot opponent), so please finish it: (5) the bot: you started 'the simulator does not demonstrate that a bot can reach that composition', please complete that and give your bot design (how it reads the enemy, when it fuses/splits given 0.35-1.4 s transforms + a 5 s lock, Easy/Normal/Hard differences without stat cheats, when it fires Orders); (6) is the Order 'glow' rule sound (glow when >= 30 % of that form's units have a useful target for the Order, the same rule the sim's player uses); (7) the Roblox plan in design section 7 (one ArmyAI server loop porting the JS brain/ORCA/nav line by line, server simulates and clients interpolate compact positions over UnreliableRemoteEvent, PathfindingService only when the straight line is blocked, a shared flow field per army to its rally point) WITH web-search sources on Roblox costs and limits; (8) what would still make James say the AI feels 'iffy' on screen. Numbered required changes again please.
…
Show more
Worked for 2m 49s

=== ROUND 1 PART 2 ===
ChatGPT said:
Alien Fusion AI Audit — Round 1, continued
GO WITH CHANGES

The bot and networking architecture are worth keeping. However, the bot should reason about actions it can actually perform, not simply select a statistically winning army composition, and the Roblox implementation needs measurable performance gates before committing to all 64 units.

5. Bot opponent — recommended design
Why the third-best counter mix is insufficient

Your simulator establishes that a strong counter exists for every army composition tested. It doesn't establish that a bot can reach that composition quickly enough to exploit it.

For example, suppose the enemy suddenly fuses into two Titans. The bot knows that 32 swarmers are a strong counter. But if its army currently contains eight Brutes, converting them into 32 Drips/Pebbles requires multiple split operations, each involving a 0.35–1.4-second transformation and the 5-second lock.

By the time the bot has completed the conversion, the Titans may already have inflicted substantial damage.

A theoretically perfect counter is not necessarily the strongest available decision.

Recommended bot decision pipeline

OBSERVE

Visible enemy forms, matter, positions, current threats and Orders

EVALUATE

Which enemies threaten my army, allies or base?

GENERATE LEGAL ACTIONS

One reachable fusion, split, rally change, Order or hold

SCORE AND ACT

Benefit minus transformation delay, vulnerability and lost positioning

For each decision, use a utility score:

𝑈
(
𝑎
)
=
𝑉
counter
+
𝑉
objective
+
𝑉
position
−
𝐶
time
−
𝐶
risk
−
𝐶
commitment
U(a)=V
counter
	​

+V
objective
	​

+V
position
	​

−C
time
	​

−C
risk
	​

−C
commitment
	​


The counter term comes from your power-graph matchup data. The other terms account for whether making the transformation is actually useful now.

The bot should consider the following:

Threat: enemy form, remaining HP, proximity, and which friendly units it counters.

Time to contact: whether the new unit will reach its intended prey before the battle changes.

Transformation vulnerability: exposure during the 0.35–1.4-second animation, plus any unavoidable delay from the 5-second lock.

Opportunity cost: losing an existing useful formation or interrupting an attack to transform.

Objective: defending its base, attacking an enemy base, or preserving an important unit.

For the first implementation, evaluate the best legal single action rather than trying to solve the entire match. This is a one-step utility planner, not an expensive full-game strategy search.

Bot difficulty settings

I would retain your original timing settings, but change how the bot chooses its answer.

Behaviour

	

Easy

	

Normal

	

Hard




Strategic rethink

	

20s

	

12s

	

6s




Reaction delay

	

3s

	

1.5s

	

0.6s




Army adaptation

	

At most 1 per match

	

Best 3 reachable actions

	

Best reachable action




Order use when useful

	

50%

	

80%

	

100%




Order delay

	

0.5–2s

	

0.3–1.2s

	

0.3–0.6s




Regroup

	

No

	

Yes

	

Yes




Extra HP/DPS/matter

	

None

	

None

	

None

For Normal, select randomly among the three best legal actions, with weights of approximately 50%, 30% and 20%. If fewer are available, choose among those. Do not always take the third-best action: that creates predictable, consistently suboptimal play.

Hard should play efficiently, not impossibly. Its 0.6-second reaction, real transformation time, real target acquisition and ordinary unit AI must all remain in force.

Exact transformation rules

Only consider transformations involving units that are alive, not currently transforming, and not under their five-second transformation lock.

Normally exclude units already in melee. A critically threatened unit can be allowed to split defensively, but it still spends the normal transformation time and is vulnerable during it.

Permit one fusion/split transaction per strategic decision. No instantaneous conversion of an entire army.

Preserve matter, damage state, stun effects, cooldowns and shields according to your existing fusion invariants.

Start the five-second lock after the transformation completes, and apply it to all resulting units.

Do not transform solely because an enemy changed forms if the new composition is already disadvantaged by distance, terrain or time-to-contact.

I'd add a minimum 10% predicted utility improvement before Normal voluntarily changes composition, rising to 15% for Easy. Hard can use a 5% threshold. These are anti-thrashing parameters, not combat-stat buffs.

Orders and regrouping

An Order is a tactical decision, not merely another action on the strategic 6–20-second timer. Evaluate it independently every 0.2 seconds, but apply each difficulty's reaction delay and usage probability.

The bot must only spend an Order when its current conditions are useful, not just because its cooldown expires. Hard should also avoid issuing it during a movement or transformation state that makes the attack ineffective.

For regrouping, Normal and Hard can retreat when friendly combat value falls below 60% of the enemy's, as in your design, but only when retreat offers a credible benefit. Otherwise, they should fight or protect the objective. Use a 3-second minimum commitment to a regroup decision so the bot doesn't alternate between advancing and retreating.

This makes the bot readable: Easy is passive, Normal responds imperfectly, and Hard anticipates threats through better action selection—not artificial strength.

6. The Order-glow rule
PASS — with UI safeguards

Glow when at least 30% of the form's living units currently have a useful Order target is a good starting rule for a mobile army game.

It connects the interface to the same evaluation the simulator uses, which is preferable to flashing a button merely because its cooldown ended.

For example:

Living units

	

Minimum useful casters to glow




2 Titans

	

1




4 Brutes

	

2




8 Brutes

	

3




16 Twins

	

5




32 Drips

	

10

Formula:

𝑁
glow
=
⌈
0.30
𝑁
living
⌉
N
glow
	​

=⌈0.30N
living
	​

⌉

The denominator should include all living units of that form, not only the currently eligible subset. This avoids an Order glowing because the sole non-stunned unit is ready while most of the army cannot act.

Three refinements are necessary:

Use glow as a recommendation, not a restriction. A player may want to fire SOLAR STRIKE at one Titan even when the bot's usefulness heuristic prefers multiple targets. Valid manual Orders should remain possible.

Add 0.3 seconds of hysteresis before illuminating the button and 0.4 seconds before extinguishing it. Otherwise, moving targets near the range boundary can make it flash rapidly.

Separate READY from GOOD MOMENT. A ready Order has its normal button appearance; a tactically useful Order receives an additional pulse, ring or restrained glow. Never imply that an unglowing Order is on cooldown.

For the bot, use the same usefulness predicate, but don't let the decorative UI glow control server combat logic. The authoritative server checks the actual legal target and cooldown when an Order is submitted.

Verdict: keep 30%. Do not tune it without observing players; there's no demonstrated problem with that threshold yet.

7. Roblox implementation — verified against official sources
Architecture approved, with implementation constraints
A. One authoritative ArmyAI loop

Yes. One central server simulation is a good fit for a 64-unit match. Avoid 64 independent scripts, each separately scanning all nearby units and performing its own pathfinding.

Use this pipeline:

1

Server think

5 Hz, staggered

Target selection, fear, planning

2

Server movement

20 Hz

Snapshot → ORCA → integrate → resolve

3

Server combat

Authoritative

Damage, stun, cooldowns, transformations

4

Network snapshots

10 Hz initially

Packed changing positions and facing

5

Client presentation

Render frequency

Interpolate, animate, play effects

For 64 units, these rates produce:

320 AI decisions per second at 5 Hz.

1,280 steering updates per second at 20 Hz.

Approximately 5.3 decisions per 60 FPS frame, averaged across frames.

Those are workload counts, not measured CPU costs. Nothing in Roblox's documentation guarantees they will run within a particular time budget.

Start single-threaded and profile. Parallel Luau is an option later, but Roblox notes that individual Actors require careful separation of shared state and that not every engine API can be accessed in parallel. One Actor does not automatically make its internal work parallel. 
Documentation - Roblox Creator Hub
+1

Important correction: do not literally port every line of the JavaScript navigation code. Port the behaviour and mathematical invariants. The Roblox terrain representation and pathfinding APIs differ from the prototype's two-dimensional boulder grid.

B. PathfindingService and shared flow fields

Yes, but a per-unit one-second cooldown is not enough.

Path:ComputeAsync() yields, and Roblox documents real failure constraints, including a 3,000-stud start-to-finish distance limit and a 20,000-node computation budget. CreatePath() also requires suitable AgentRadius and AgentHeight settings. 
Documentation - Roblox Creator Hub
+2

I recommend three navigation layers:

Layer

	

Purpose

	

When used




Shared flow field

	

General direction toward the army's rally/objective

	

Broad movement




Local ORCA

	

Avoid allies and enemies

	

Every steering update




PathfindingService

	

Navigate nontrivial obstacles

	

When an unobstructed local route is unavailable

Use separate clearance data for the different alien sizes. A narrow gap usable by a Drip may be unusable by a Colossus. One identical flow field for all four forms would be wrong.

Initial queue parameters, subject to profiling:

Maximum 4 new ComputeAsync() requests per second globally.

Minimum 2 seconds between requests for the same unit.

Cache reusable paths or coarse routes for matching destinations, clearance classes and unchanged obstacles.

Prioritise blocked F4 units and units that have made no genuine progress for 1.5 seconds.

If a path fails, back off instead of requeuing it continuously.

These numbers are my recommended starting limits, not Roblox platform limits.

The oft-repeated claim that “150 paths lag a server” is not an official universal threshold. I found a June 2026 Developer Forum report describing degraded pathfinding after approximately 150 computations, but it concerns one developer's experience and should not be treated as an engine specification. 
Roblox

C. UnreliableRemoteEvent for movement

Strongly agree. This is an appropriate use of the API.

Official Roblox documentation confirms that UnreliableRemoteEvents are intended for continuously changing information, can arrive out of order or be lost, and drop payloads exceeding 1,000 bytes. Roblox also documents an approximate 500 requests per second per client limit for client-to-server remotes of the same type; that is not an excuse to send hundreds of movement packets. 
Documentation - Roblox Creator Hub

A compact candidate packet could contain:

Field

	

Bytes per unit




Unit ID

	

1




X and Z, quantised

	

4




Facing

	

1




Movement/animation flags

	

1




Optional speed/state detail

	

1–3




Total

	

8–10

At 64 moving units and 10 Hz, a 10-byte record produces about 6.4 KB/s per receiving client, excluding headers and transport overhead. At 20 Hz, about 12.8 KB/s. These are arithmetic payload estimates, not measurements of Roblox network bandwidth.

A 64-unit snapshot at 10 bytes each is 640 bytes plus its header, so it fits below the documented event limit before considering encoding. Chunk packets if the actual encoded payload approaches the limit.

Use sequence numbers, server timestamps, and an entity generation/version ID. A stale snapshot must never resurrect a despawned unit or move a newly fused alien using its predecessor's data.

Interpolation: start with a 100–150ms presentation delay, interpolate between received snapshots, and allow at most 100ms of extrapolation if a packet is missing. These are initial tuning values. Test 100ms and 200ms simulated network latency, packet loss and poor mobile frame rates.

Creation, destruction, fusion, health and Orders must reach clients reliably or through authoritative state reconciliation. Position snapshots are disposable; game-state transitions are not.

Roblox's own performance guidance supports reducing needless replication, limiting high-frequency remote traffic and creating visual effects locally rather than replicating every visual object. 
Documentation - Roblox Creator Hub
+1

D. Server ownership and the fallback

The server should own combat decisions and unit coordinates. The client renders the corresponding creature locally.

Do not switch automatically to 64 server-controlled physics rigs with AlignPosition if custom interpolation disappoints. That would be an alternative architecture with its own physics and replication costs.

Roblox documents that manual server network ownership can introduce jitter and that client-owned physics cannot be trusted for authoritative competitive gameplay. 
Documentation - Roblox Creator Hub
+1

I would treat server-controlled physical rigs as a separately profiled fallback, not a default.

8. What would still make James say the AI feels “iffy”?

This is the final distinction between AI that wins fights and AI that looks alive.

The biggest risk is that the simulation is optimising collision avoidance more successfully than it is producing purposeful combat.

Five visual failure modes to test

1. Orbiting without attacking

Drips and Twins continually reposition around a target, almost reach their assigned slots, then choose new ones. They look indecisive rather than intelligent.

Fix: preserve slots until genuinely invalid and permit attacks whenever a valid target is already within reach. No unnecessary repositioning for a theoretically better angle.

2. Movement that contradicts the creature

A rock bull smoothly sidesteps like a crab, or a Pincer runs straight forwards despite being designed as a sideways scuttler.

Fix: keep world-space ORCA movement separate from body orientation and locomotion animation. Rams turn and commit; Pincers face sideways relative to their travel; Brutes lead with planted knuckles.

3. Endless hesitation

The 0.15–0.45-second first-contact notice is good. Repeating a notice animation on every target switch is not.

Fix: a full notice plays only when entering combat from calm, not every time the brain finds a different enemy. In combat, use a brief head turn or sound instead.

4. Polite traffic jams

Sixteen small units repeatedly stop to let one another pass. Overlap is low, but the army looks confused.

Fix: allow mild Squish-body compression, use persistent movement priorities and track genuine goal progress. ORCA safety is not more important than readable, decisive movement.

5. Network smoothing that looks like indecision

Units slide backwards after corrections, snap to new positions, or rotate without their feet matching their movement.

Fix: smooth small corrections, snap only on genuine teleports or transformations, and drive procedural animation from interpolated velocity. Give large units visibly heavier turning.

Four mandatory visual playtests

These are more informative than another large collection of abstract win percentages:

Scene

	

Expected behaviour

	

Failure




16 Drips vs 1 Titan

	

Surround, cling, BOING, re-enter

	

Endless circling or synchronized hopping




4 Twins defending 2 Brutes

	

Prioritise nearby swarmers, intercept them

	

Ignore friendly Brutes or form an impassable wall




4 Rams pursuing Packs among boulders

	

Find routes and commit to straight charges

	

Repeated sidestepping or charge cancellation




1 Colossus vs 8 Brutes

	

Deliberately turn, approach and deliver Ground Shatter

	

Oscillate between targets or slide backwards while facing forwards

Test each with an ordinary phone camera at normal gameplay zoom, not just a free-floating Studio camera.

Performance gates I would impose

These are proposed Alien Fusion acceptance targets, not platform guarantees:

Test

	

Initial target




64-unit AI update

	

Under 2ms at the 95th percentile




AI update spikes

	

Under 5ms at the 99th percentile




Mid-range mobile client

	

At least 30 FPS during normal 64-unit combat




Genuine blocked time

	

Under 3% of active movement time




Unrecoverable navigation stalls

	

Zero in standard reachable scenarios




Packet size

	

Under 1,000 bytes per unreliable event




Lost-packet recovery

	

No permanently frozen or duplicated alien

Measure server execution with the Roblox Script Profiler and MicroProfiler, and capture network traffic using the MicroProfiler's network mode. Roblox explicitly provides these tools to diagnose CPU time, replication delays and network processing. 
Documentation - Roblox Creator Hub
+2

9. Final numbered required-change list

Since you say the previous eight AI-code corrections are already applied, I am not reopening them without seeing the updated implementation. These are the remaining design and Roblox-build requirements from questions 5–8.

1. Replace the bot's third-best static composition with a legal-action utility planner. Preserve 20/12/6-second strategy intervals and 3/1.5/0.6-second reaction delays.

2. Make transformations genuinely reachable. Enforce actual 0.35–1.4-second animations, the 5-second lock, one transformation transaction per decision and all fusion-state invariants. Keep the original prohibition on transforming units in melee unless James explicitly changes that rule.

3. Keep the 30% Order-glow threshold, but add 0.3-second activation and 0.4-second deactivation hysteresis. Manual Orders should not depend on the glow.

4. Implement a 20 Hz server movement loop with snapshot-based ORCA. Keep the 5 Hz staggered thinking. Validate the changed time step against the JavaScript simulator before assuming equivalent behaviour.

5. Use per-size navigation clearance and a globally rate-limited pathfinding queue. Start at four new path requests per second globally, then profile. One shared rally flow field without size-specific clearance is insufficient.

6. Implement sequenced, compact unreliable movement snapshots, initially at 10 Hz, with reliable creation, destruction, transformation and combat events. Test packet loss and delayed arrival.

7. Add explicit per-creature presentation tests for orientation, aggression tells, target-switch transitions, attack commitment and stuck recovery. A passing combat simulation is not enough.

8. Run a 64-unit phone stress test before replacing the existing EntityAI architecture entirely. Preserve a rollback path until the new controller meets the measured CPU, networking and animation targets.

Final recommendation

Build the new ArmyAI architecture. Do not build a more elaborate AI system first.

The shared brain, utility-based targeting, ORCA avoidance, situational pathfinding and eight personality profiles are already a substantial system. Another layer of strategic intelligence is unlikely to help as much as getting those behaviours moving convincingly on screen.

My preferred implementation order is:

Bot planner → Order hints → server movement and navigation → compact replication → creature-specific animation integration → 64-unit stress test.

That should give James an early playable opponent and meaningful evidence about whether the aliens actually feel different.

And one editorial nit for Claude: “WITH web-search sources” is clearer as “with citations to current Roblox documentation.” Precision should extend beyond the code. Even baked potatoes can't be rescued by imprecise specifications.

ChatGPT can make mistakes. Check important info.
Latest response




Thinking effort
High