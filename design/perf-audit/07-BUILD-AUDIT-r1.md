Worked for 3m 18s
ChatGPT said:
Alien Fusion — Performance Build r1 Audit
ROBUST WITH CHANGES

The performance improvement is real, and most of the implementation is sound. I found one concrete correctness risk in P5, one P3a dependency that needs checking, and two small menu fixes.

I would keep P1, P9a, and most of P3a. I would not revert the whole P5 change.

Measured outcome

Standing, median

~2.3×
~55 → ~123 FPS

Fight start

~2×
~53 → ~107 FPS

Mid-fight median

+24%
~38 → ~47 FPS

These figures use the reported same-session tests. The mid-fight ranges still overlap considerably, so I would not attribute the entire improvement to P3a or claim a mobile benefit yet.

The glow change is clearly successful. The remaining client bottleneck is still substantial, but there is no reason to tackle P2/P4 before the phone test.

A. Correctness audit
A1. setGlow — PASS

Your three-level selection is logically correct for the intended visuals.

Lua
local lv = (es < st.glow * 0.5) and 0
    or (es >= st.glow + 0.25) and 2
    or 1

The st.glow = 0 case does not cause an error.

At es = 0, it chooses level 1 and writes st.glow, which is zero. Level 0 is unreachable for nonnegative es when the base is zero, but both levels produce the same physical brightness.

No special zero-glow branch is required.

Other checks:

Defeat correctly reaches level 0 when base glow is positive.

Idle breathing no longer changes the material.

Large attack boosts still reach the bright level.

glowLv prevents repeated writes within one level.

DBG_NOGLOW prevents both the write and cached level update.

No required code change.

The hurt dip is effectively removed at 0.88× base. That's a visual tradeoff, not a correctness bug. If James wants it back, use an existing hurt effect rather than restoring per-frame material writes.

A2. P3a — Core optimization PASS, with one dependency to verify

I checked the full runAttack and solveLegs sequence, not just the diff.

For ordinary non-travel attacks, skipping the first idle apply() and solveLegs() when w == 1 is sound:

apply(st, pose) still writes the attack pose.

The final solveLegs() still executes.

st.limbTargets and st.kneel are assigned before that final solve.

held is needed only for blending, so skipping its allocation at full weight is correct.

Foot plants, lastK, and drawnP remain maintained by the final leg solve.

For a Ram travel attack, the final solve still receives the travel pivot, distance, path and standing state.

After resetFeet(st, true):

leg.stand is cleared.

Plants and lastK are cleared.

leg.from captures the previous rendered foot position.

The remaining travel solve can initialize the new plants and handoff.

One subtle change is that leg.from.T is now initialized against the actual travel target instead of the intermediate idle-foot target. That's arguably better, but the handoff trajectory can differ from the original. It deserves a targeted visual comparison.

There is one unresolved dependency: atk.place(ctx, tt, base) is called before the new attack pose is applied.

Previously, it saw the just-applied idle pose. With P3a, at full weight it sees the previous frame's bone transforms. If any atk.place function reads ctx.bonePos, ctx.tip, or another live bone-derived value, the optimisation can introduce a one-frame feedback error.

Exact action: Inspect the atk.place implementations for live bone reads. If none exist, leave P3a alone. If one does, preserve the required baseline pose only for that attack, rather than reinstating the extra solve globally.

This is a conditional risk; the supplied runAttack code alone does not prove that a particular atk.place implementation is broken.

A3. P5 has a real surface-query risk — FIX

This is the most important issue in the build.

The template script changes every visible MeshPart to:

Lua
d.CollisionFidelity = Enum.CollisionFidelity.Box

Yet your Drip's surface rays deliberately turn the target mesh's CanQuery back on and raycast against it.

Roblox's collision documentation establishes that Box uses a bounding box rather than the more detailed shape. That can change the surface returned by the ray, especially on irregular creatures. 
Documentation - Roblox Creator Hub
+1

Potential regression: A Drip clings to a box-shaped collision surface that extends beyond the visible body.

Exact change: Restore the previous CollisionFidelity on meshes used by Drip surface rays. Since any creature can potentially become a target, the simplest safe choice for this build is to restore all 15 meshes' original fidelity.

Keep the other P5 settings:

CanCollide = false

CanTouch = false

CanQuery = false by default, enabling it locally only where the Drip needs it

Hitbox shadows off

F1/F2 mesh shadows off

Then compare Drip contact points before and after, especially on the Titan, Colossus, and irregular smaller forms.

Also check whether the Drip restores CanQuery=false when its surface query is no longer needed. Don't add a manager for it.

A4. Phone menu — PASS WITH TWO SMALL FIXES

The overall layout is sensible. Replacing nested scrolling with one scrolling body was the right choice.

UIScale calculation: Dividing UIListLayout.AbsoluteContentSize.Y by scale.Scale is appropriate for the observed Roblox scaling behaviour. A documented DevForum issue describes exactly this adjustment. 
Roblox

Your reported fit test supports the calculation.

However:

Fix 1 — Clamp the AI menu's available height.

This expression can become negative during unusually small viewport initialization:

Lua
(vs.Y - 80) / scale.Scale - 30

Change the height assignment to:

Lua
local contentH = layout.AbsoluteContentSize.Y / scale.Scale + 16
local availableH = math.max(0, (vs.Y - 80) / scale.Scale - 30)

panel.Size = UDim2.new(
    1, 0, 0,
    math.min(contentH, availableH)
)

It's a trivial defensive correction.

Fix 2 — Increase the fold button's touch target.

At UIScale=0.8, the existing 36×26 button renders around 29×21 pixels. That's unnecessarily small for the control James specifically needs on his phone.

I would use a 44×40 unscaled button with a 40-pixel title bar, and position it 2 pixels from the top and 4 pixels from the right edge. Update the height calculation's -30 to -40.

That's still compact without making the fold control fiddly.

The MOVE TEST touch-only default-fold behaviour is correct. No further layout rewrite is justified.

B. Keep P5 or revert it?

KEEP P5, except restore the collision fidelity settings described above.

Your PC measurements show no convincing FPS gain from P5. That is not surprising: disabling collision/query work and small-unit shadows may matter more on different hardware, and client rendering remains the dominant cost.

There is no reason to undo safe template cleanup. There is also no reason to sacrifice Drip surface accuracy for an unmeasured optimization.

C. Final verdict and required changes

Component

	

Verdict




P9a — Shared source

	

PASS




P1 — Quantized glow

	

PASS




P3a — Cached inverse

	

PASS




P3a — Skip redundant idle solve

	

PASS, conditional on atk.place check




P5 — Collision/touch/shadow settings

	

PASS




P5 — Collision fidelity

	

FIX




AI menu scrolling and scaling

	

PASS WITH SMALL FIXES




MOVE TEST phone fold

	

PASS

Exact remaining work

Restore original collision fidelity on queryable creature meshes; verify Drip contact points.

Inspect atk.place for live bone reads. If present, keep the idle-pose prerequisite for those attacks only.

Clamp the AI menu height to zero and enlarge the fold control.

Run one short regression at 30 FPS covering Ram Charge entering/exiting travel immediately after resetFeet, Drip hop/Cling, and a non-travel attack with limb targets. Check foot continuity and contact positions.

No additional optimization project is required for this round.

Final verdict: ROBUST WITH CHANGES. The performance gain is demonstrated, the code changes are mostly sound, and the remaining corrections are localized.

Once those checks pass, I would consider this performance batch ROBUST for the AI test place. Mobile performance remains a separate release gate.

Do not start P2/P4 until James has tested the current build on his phone.

ChatGPT can make mistakes. Check important info.
Latest response




Thinking effort
High