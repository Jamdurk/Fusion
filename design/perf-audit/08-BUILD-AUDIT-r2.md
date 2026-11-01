Worked for 1m 25s
ChatGPT said:
Alien Fusion — Performance Build r2 Audit
ROBUST — GO

Yes. This build is now ROBUST for the AI test place. All four outstanding r1 requirements have been addressed. I found no remaining merge-blocking correctness bugs in the supplied diffs.

A. Anything still wrong?

Area

	

Verdict

	

Finding




P5 collision fidelity

	

PASS

	

Original collision shapes restored on all 15 templates




P3a atk.place

	

PASS

	

All seven checked; none depends on its own pre-attack bone pose




P3a foot-state handoff

	

PASS

	

No regression demonstrated; A/B actually favours the new implementation




setGlow

	

PASS

	

Three-level selection and cached inverse remain sound




AI menu

	

PASS

	

Height clamped, larger fold target, single scrolling body




MOVE TEST menu

	

PASS

	

Larger fold control and updated height calculation




FPS readout

	

PASS

	

Counts AI units, moves out from under menu, toggle tested




P9a shared source

	

PASS

	

No new source divergence shown

Two observations, neither requiring a change:

CanQuery remains enabled after Drip attachment. In this test place, that's acceptable given the audited query paths. It does mean P5's query-disabling optimisation is not permanently maintained on every touched target, but no manager or cleanup system is justified.

The FPS readout's 144 FPS / 9 ms example was measured with six aliens, not the approximately 96-unit phone fight. Don't use that particular reading as evidence of 96-unit performance.

B. Is the foot-spike measurement sound?

Yes, as a comparative regression test. Not as an absolute animation-quality metric.

Old double solve

100.5
Mean detected spikes per 30 s

P3a skip enabled

10.75
Mean detected spikes per 30 s

Approximately 89% fewer detected spikes.

Old double solve
P3a skip
0
50
100
150
200
Run 1
Run 2
Run 3
Run 4
Run 1: Old double solve 92, P3a skip 7
Run 2: Old double solve 4, P3a skip 0
Run 3: Old double solve 187, P3a skip 13
Run 4: Old double solve 119, P3a skip 23

Four reported 30-second runs per configuration.

The result supports the hypothesis that the redundant idle solve interfered with the attack solve's persistent leg state.

That makes sense from the code: both calls can mutate foothold state, leg.stand, lastK, and handoff state. For travel attacks, they also use different positional inputs.

There are three limitations:

The 0.5-stud-per-frame threshold depends on frame rate. At 60–140 FPS it detects different physical foot velocities.

Excluding pivot jumps above 1 stud means certain teleport-like discontinuities are not counted.

The old implementation varies substantially between runs (4–187), so the comparison isn't a precise estimate of future spike frequency.

Nevertheless, the magnitude and consistency of the overall improvement are sufficient to approve P3a. The metric doesn't establish perfect foot animation, but it provides strong evidence that the optimisation hasn't introduced a widespread regression.

I would not demand an elaborate new benchmark or artificial 30 FPS scheduler. A real phone visual check is more valuable.

C. Final verdict

Performance Build r2

APPROVED

Required code changes: None.

P1 glow optimisation: Keep.

P3a cached inverses + skipped redundant solve: Keep.

P5 collision/query/shadow cleanup: Keep.

P9a shared source: Keep.

Phone menu fixes: Keep.

James's report that roughly 96 fighting AI units felt smooth on his iPhone 17 is encouraging, although it does not replace sustained frame-time measurements on lower-end devices.

Final verdict: ROBUST for this test place, based on the supplied code and regression evidence.

Freeze this batch. The next useful step is actual on-device performance profiling, not another round of speculative fixes or architectural work.

ChatGPT can make mistakes. Check important info.
Latest response




Thinking effort
High