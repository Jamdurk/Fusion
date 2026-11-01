Ability-system research and balance framework for a 32-matter Roblox PvP army game
Design conclusion
The strongest design for this game is not “three buttons per unit”. With up to 32 simultaneous bodies, a phone-first audience, reversible fusion/splitting, and a roughly 210-second match, that would create exactly the sort of micro burden that large-army RTS and auto-battlers systematically try to remove. Warcraft III explicitly uses autocast to remove repetitive spell micro; StarCraft II has repeatedly converted abilities to autocast where appropriate; They Are Billions explicitly says its large-army design is about strategy rather than memorising dozens of commands; and Clash Royale went even further in August 2026, making almost all Hero/Champion abilities single-use because Supercell concluded recurring cooldown abilities did not add enough meaningful gameplay to justify their complexity. 

My recommendation is exactly three ability slots on every form, but only one of them should require player input:

Slot	Function	Player input	Approx. share of ability budget
Identity passive	Defines the form and reinforces its prey relationship	None	25%
Automatic tactic	Periodic situational behaviour with an internal cooldown	None	35%
Form Order	Signature tactical decision for all currently selected/owned units of that form	One contextual button	40%

That gives you all 24 requested abilities — 8 passives, 8 autocasts, 8 player-triggered Orders — while the player only ever needs to think about at most one context-sensitive combat button for the form they are commanding.

There is a second, more important conclusion from the numbers you supplied: abilities should not be asked to repair an arbitrarily weak base counter topology. Your base stats already contain substantial per-matter differences:

Form	Units at 32 matter	HP / matter	DPS / matter	Total army HP	Total army DPS	HP ÷ DPS
F1	32	100.0	12.00	3,200	384	8.33 s
F2	16	117.5	10.00	3,760	320	11.75 s
F3	8	162.5	12.00	5,200	384	13.54 s
F4	2	150.0	6.25	4,800	200	24.00 s

A crude cost-normalised duel proxy, (\sqrt{HP\times DPS}/matter), is about 34.6, 34.3, 44.2 and 30.6 for F1–F4 respectively. It is only a heuristic, because range, attack cadence, collision, focus fire and overkill matter enormously, but it immediately says F3 has an unusually rich raw chassis and F4 a relatively low offensive chassis.

That is not necessarily a problem. In fact, the cleanest way to produce F1 → F4 → F3 is likely to be attack cadence and overkill, not hidden percentage modifiers: make the Titan attack infrequently with huge single-target hits. A 300–400-damage Titan blow is efficient into a 650-HP F3 and catastrophically inefficient into a 100-HP F1 because most of the damage disappears into overkill. That creates a naturally comprehensible counter: a giant fist is excellent at crushing a big alien, but stupidly inefficient at swatting thirty-two tiny ones. It is far more readable for children than a tooltip saying “+27% damage against Fusion Level 3”.

The overall philosophy should therefore be:

Base attack patterns establish the counter loop; passives make the counter unmistakable; autocasts create texture; Orders create the player's moment of agency.

That closely matches how successful strategy games protect unit roles. Relic, for example, has explicitly added passives to Company of Heroes 3 units to reinforce their intended counter role, while also removing or replacing abilities that blurred a unit's purpose; Supercell similarly balances away “generic” power and toward distinctive abilities and counterplay. 

What comparable games actually teach about ability kits
There is no meaningful universal industry rule such as “tier-one units have 0.7 abilities and tier-four units have 2.4”. I found no credible published roster-wide census that would justify pretending such a number exists. The useful evidence is instead the distribution of player attention: the more bodies the player commands, the more combat functionality migrates from manual actives into passives, autocasts and autonomous targeting.

RTS and auto-battler patterns
Game / genre	Typical combat-facing pattern	Lesson for your game
StarCraft II	Ordinary combat units can be mechanically simple; specialist casters carry several abilities. Blizzard has converted abilities such as Jump Jet Assault and Rocket Barrage to autocast, and even conditioned autocast on finding enough targets. Raven redesigns have also explicitly targeted the problem of a specialist becoming oppressive when massed. 
Complex functionality belongs on specialists or AI; an ability that is healthy on one unit can become broken when multiplied across a swarm.
Warcraft III	Caster kits explicitly mix manual and autocast abilities. The Priest is a particularly relevant example: Heal and Inner Fire can autocast while Dispel Magic is manual; Warcraft's own guide describes autocast as the mechanism for automatically using a spell when appropriate. 
Your three slots map extremely well to passive + autocast + deliberate Order.
Clash Royale	Normal troops resolve combat autonomously. Special abilities are sparse. In August 2026 Supercell converted nearly all Hero/Champion ability cooldowns to single-use because repeated activations added complexity without enough meaningful gameplay. 
On mobile, a rare consequential action beats lots of small cooldown taps.
Mechabellum	The strategic layer is composition, placement and technology; battlefield execution is substantially automated. Official balance updates routinely change unit durability specifically so designated counters work better, rather than expecting combat micro to rescue the matchup. 
Counter relationships should survive autonomous battle resolution.
Company of Heroes 3	Squad/vehicle abilities mix passives, toggles, timed skills and active munitions abilities. Relic frequently ties bonuses to conditions such as remaining stationary, accepting a movement penalty, setting up, or specialising against a target class. 
Interesting abilities often exchange one axis of power for another rather than simply adding stats.
They Are Billions	The developer explicitly describes a game with armies and up to 20,000 infected where the emphasis is strategic decisions rather than memorising many commands; individual infected run AI. 
Unit count and control complexity must move in opposite directions.
TABS	The essential model is pre-battle army choice followed by highly autonomous combat, with unit peculiarities expressed through AI behaviours and special effects. 
Spectacle and unit personality can come from automatic behaviour rather than buttons.
Current Roblox tower-defence examples	The genre is not standardised, but contemporary examples commonly stack passives/automatic effects and reserve active abilities for advanced units or final upgrades, sometimes with very long cooldowns. One 2026 Universal Tower Defense X roster shows exactly this pattern. 
Roblox players can understand rich kits, but that does not mean every effect should be directly controlled.
League / Dota-style MOBAs	A single directly controlled hero can justify a passive plus multiple active abilities because all player attention is concentrated into one body. Riot treats clarity and the ability to react as fundamental design requirements. 
Copy the semantic structure of a MOBA kit — identity, tactical verb, signature moment — not its button density.

Warcraft III is particularly instructive for your architecture. Its Priest effectively demonstrates that three abilities do not have to mean three decisions every few seconds. Repetitive healing and buff upkeep can be delegated to autocast, leaving the human to make the unusual decision. Warcraft even caps some area restoration effects at six targets and prevents same-type effects from stacking, two principles directly relevant to your swarm problem. 

Company of Heroes offers another useful pattern: power coupled to a visible sacrifice. Entrenchment takes five seconds, leaves the unit stationary, disables weapons during setup, and then gives damage reduction plus faster fire; another anti-infantry toggle gains blast effectiveness while sacrificing direct damage and range. 
 Those abilities are interesting because the opponent can understand both the advantage and the weakness. For a children's PvP game, that is much healthier than invisible conditional arithmetic.

StarCraft II provides the warning at the other end. Blizzard's Raven redesign explicitly cited the problem that a caster useful in small numbers could become oppressive when mass-produced. 
 Your F1 form is exactly where this multiplication problem will appear: a harmless-looking on-hit effect becomes thirty-two simultaneous procs. Any ability that exists once per body must be budgeted per matter, not per unit.

What “tier” should mean
I would resist the conventional RPG instinct that the Titan needs “better” abilities because it is a higher tier. F4 is not a level-4 unit; it is sixteen matter packaged into one body. It should receive more spectacular effects per activation because sixteen matter are concentrated into it, but a 32-matter F4 army should not possess more total ability budget than a 32-matter F1 army.

That distinction is foundational:

[ \text{ability budget of one unit} \propto \text{matter contained} ]

but

[ \text{ability budget of a full 32-matter army} \approx \text{constant}. ]

So an F4 Order may deliver roughly sixteen times the single-target payload of one F1's contribution, but there are only two F4s versus thirty-two F1s. The spectacle grows with fusion; the underlying economy does not.

This is also how you prevent the psychologically tempting but strategically disastrous outcome where fusion is simply an upgrade. Fusion needs to be redistribution of matter into a different combat geometry, not vertical progression.

Quantitative balance model for thirty-two matter
Start with time-to-kill, but do not stop there
The basic equations should be in your simulator even if they never appear to players:

[ TTK_{A\rightarrow B} \approx \frac{HP_B}{N_A\cdot DPS_A} ]

for the deliberately simplified case where all attackers remain alive, all DPS lands and there is no overkill.

For damage reduction (r):

[ EHP=\frac{HP}{1-r}. ]

This shows why Titan damage reduction becomes dangerous extraordinarily quickly:

Damage reduction	EHP multiplier
10%	1.111×
20%	1.250×
25%	1.333×
30%	1.429×
40%	1.667×
50%	2.000×

A “mere” 30% damage reduction does not make a unit 30% tankier; it makes its effective health about 43% larger. That is precisely why I would use only modest persistent DR on F4 and put most Titan survivability into finite shields or matchup-specific mitigation.

A useful first-pass combat proxy is

[ P=EHP\times DPS. ]

For cost comparison, take its square root:

[ C=\sqrt{EHP\times DPS}. ]

The reason for the square root is mathematical rather than mystical: if both HP and DPS double, (HP\times DPS) quadruples even though the overall chassis broadly doubled; the square root returns the measure to approximately linear scale. Do not use this as the final balance score. Mobility, range, overkill, splash and target acquisition can all invalidate it. Its value is as a regression sanity check: when one form is 25–30% away from the others before any tactical variables are modelled, you know where to investigate.

Attack interval is a first-class balance stat
Your prototype specifies DPS but not damage per attack / attack interval. That omission matters enormously to the counter loop.

Two units can both deal 100 DPS:

Unit A: 20 damage every 0.2 s.
Unit B: 400 damage every 4 s.
Against a 2,400-HP Titan, their nominal throughput is similar. Against 100-HP F1s, Unit B may waste 300 damage every time it kills one.

That gives you a beautiful, non-arbitrary counter mechanism:

F1 → F4: Titan's huge slow attacks overkill tiny bodies.

F4 → F3: the same huge attacks efficiently remove large chunks of 650-HP targets.

F3 → F2: substantial single-target attacks efficiently delete 235-HP mediums.

F2 → F1: fast attacks with small capped multi-target coverage process many 100-HP bodies efficiently.

This is better than putting all four relationships in explicit DamageMultiplierAgainstFormX tables. You may still need modest form-specific modifiers, but the physical combat model should do most of the work.

Lanchester is useful here, provided you do not worship it
Lanchester's models distinguish situations where fighting power scales roughly linearly with participant count from situations where numerical strength produces a disproportionate advantage. In the classical square-law conception, force effectiveness can scale with the square of combatant count; linear-law conditions arise when combat is more effectively pairwise. Empirical research also finds real group combat can fall between those idealised extremes rather than obeying either exactly. 

That maps unusually well to your game.

If all 32 F1s can simultaneously shoot one Titan from range, the swarm gets something approaching concentrated-fire numerical scaling. If collision means only six can physically touch it and the rest queue behind them, the swarm behaves much more linearly. Likewise, if thirty-two F1s can surround a Titan but its AoE hits all thirty-two, the Titan receives its own superlinear scaling.

Therefore put these in the simulator as explicit variables:

[ N_{\text{effective attackers}}= \min(N_{\text{alive}},N_{\text{contact slots}},N_{\text{LOS}}) ]

and

[ N_{\text{AoE hit}}= \min(N_{\text{inside area}},K_{\text{target cap}}). ]

Target cap (K) is one of your most powerful balance knobs.

Uncapped splash has effective value roughly proportional to how many bodies happen to occupy its radius. That means its power rises specifically against the form that already has the greatest unit count. Capping affected bodies changes that from something like (O(n)) to (O(\min(n,K))).

Relic literally uses model-damage limits as a balancing mechanism for area weapons in Company of Heroes 3, adjusting how many infantry models a shot can damage; Supercell has likewise nerfed chain/AoE effects when they could effectively erase huge pushes. 

For your game I would use:

Source	Recommended damaging target cap
F1 incidental AoE	1
F2 anti-swarm auto	3–4 F1s
F3 attack/ability	1–2
F4 ordinary area impact	2, sometimes 3 at greatly reduced secondary damage
F4 signature against F3	1 primary, or 2 maximum

The crucial counterintuitive rule is: the Titan should look enormous without actually possessing enormous uncapped AoE. Give it a gigantic dust ring, screen shake and crater, but let the lethal core hit one or two bodies. Spectacle does not have to equal hitbox size.

Cooldowns should be normalised by uptime
For a buff of duration (D) with cooldown (C):

[ u=\min\left(1,\frac{D}{C}\right) ]

is its theoretical maximum uptime.

A +30% DPS buff lasting 3 seconds every 12 seconds is not a 30% sustained DPS increase:

[ 0.30\times\frac{3}{12}=7.5%. ]

Similarly +40% for 4 seconds on a 24-second cooldown has a theoretical average uplift of:

[ 0.40\times\frac{4}{24}\approx6.7%. ]

That is how cooldowns should be compared across apparently different skills. Company of Heroes balance notes routinely adjust duration, reload and recharge independently, while Supercell frequently changes first-hit delay, duration or deployment time rather than raw output because timing itself is part of an ability's power. 

For a 210-second match, a continuously available 24-second Order can be fired at most around nine meaningful times if ready at the start; a 30-second one around seven or eight. That is already plenty. A child on a phone does not need a button begging to be tapped every five seconds.

A practical per-matter ability budget
For your prototype, I would establish a reference “matter combat package” using roughly the middle of your per-matter chassis values:

[ H_r=130,\qquad DPS_r=11. ]

Use a 12-second reference engagement, approximately the middle of your current self-TTK values:

[ R = H_r +(12\times DPS_r)=130+132=262 ]

combat-equivalent units per matter.

This is deliberately a rough accounting currency, not a physical law. It simply lets a designer compare extra damage, absorbed damage and other effects over a common window.

I would initially allocate 20% of that reference package to abilities:

[ 0.20\times262\approx52 ]

combat-equivalent value per matter per 12-second reference window.

Split it as:

Slot	Budget / matter	32-matter army equivalent
Passive	~13 CE	~416 CE
Autocast	~18 CE	~576 CE
Order	~21 CE	~672 CE
Total	~52 CE	~1,664 CE

Do not blindly add “21 damage” and declare an Order balanced. For an actual battle log, calculate:

[ V_{\text{ability}}= \Delta damage\ dealt+ damage\ prevented+ shield\ actually\ absorbed+ \Delta combat\ value\ caused\ by\ CC/mobility. ]

For movement, slow and knockback, the best measurement is counterfactual simulation: run the exact same random seed with the ability enabled and disabled, then measure the difference. That automatically values a slow at zero when nothing needed to move and highly when it prevented a target from reaching combat.

This is much better than assigning arbitrary point values such as “one second of slow = 30 damage”.

Preserving the counter loop while making the factions feel different
The most important rule is that an ability should have one of three relationships with the counter topology:

reinforce the intended prey relationship, express the unit's normal job, or create manoeuvring options without reversing a predator relationship.

It should almost never say, in effect, “F1 normally loses to F2, except F1's ability completely destroys F2.”

Riot has described its preferred counter design in similar terms: reactive/counter choices should provide meaningful advantage without completely negating the opponent. Supercell's balance history repeatedly removes mechanics that make an otherwise counterable interaction absolute — permanent knockback, overly broad area utility, or effects with no practical reaction window. 

Give every form a prey and a predator
Your matrix should remain:

Attacker	Intended prey	Why the ability package should help
F1 Swarm	F4 Titan	Numerous tiny attacks exploit overkill, surround, cling/fracture
F2	F1 Swarm	Fast, target-capped multi-hit processing
F3	F2	Efficient heavy single-target pressure
F4 Titan	F3	Huge single-target alpha with little benefit against F1

And equally important:

Form	Predator it must not solve
F1	F2
F2	F3
F3	F4
F4	F1

When testing an ability, therefore run two balance questions, not one:

Does it improve performance against its intended prey?
Does it accidentally improve performance just as much against its intended predator?
If the second answer is yes, the ability is generic power and should probably be redesigned.

Supercell's 2024 Evolution balance pass is almost a textbook warning: the team said Evolutions had become “too generically powerful” and were deciding battles themselves, so power was moved out of raw stats into distinctive mechanics. 
 Its 2026 changes continue the same philosophy, removing one utility effect when an ability already had slow and freeze, and nerfing area damage that let a cheap unit blow up almost any push. 

Mirrored budget, not mirrored mechanics
SQUISH and CRUNCH should have the same outcome envelope, not necessarily the same spell with different particles.

I would define their vocabulary as:

SQUISH	CRUNCH
deform	brace
bounce	recoil
stretch	launch
stick / slow	fracture / stagger
absorb briefly	chip / armour
circular, elastic motion	angular, directional motion
softer continuous feedback	hard discrete impacts

Then pair abilities by measurable result.

For example:

SQUISH gets 20% slow for 1.2 s.
CRUNCH gets a small knockback that, in the benchmark scenario, causes approximately the same average lost contact time.
Those are not cosmetically identical, but their simulator-measured marginal value can be equal.

This is a better form of faction asymmetry than “CRUNCH has 10% more HP and SQUISH has 10% more speed”, because you explicitly want identical base numbers. You can keep the spreadsheet mirrored while the moment-to-moment physical verbs are visibly different.

Fusion and splitting need anti-exploit state rules
Reversible fusion creates a major balance exploit unless ability state belongs to matter/player state, not newly created unit instances.

Do not allow:

F4 casts shield → splits into F1 → immediately fuses into fresh F4 → shield is ready again.

Likewise, splitting must not cleanse stun, reset autocast timers or multiply charges.

I would store at minimum:

PlayerID + Form + AbilitySlot → cooldown_remaining

rather than storing the important cooldown solely on a unit object.

For temporary status effects, either transfer remaining duration proportionally to descendant matter or deliberately define transformations as unable to occur under hard CC. What matters is that fusion is not a free dispel.

StarCraft II's editor even supports swapping an ability while retaining charges, cooldown and level state — an instructive precedent for treating the ability's state as persistent rather than “new body, new spell”. 

Readability and interaction for children on phones
Roblox's own documentation stresses that phones and tablets have the least screen space and recommends explicitly testing interfaces using phone emulation. Its current Input Action System also supports action/context bindings across touch, keyboard/mouse and controller rather than forcing identical controls onto every device. 
 Apple similarly recommends touch targets around 44×44 points for primary controls and notes that smaller targets become noticeably harder to hit. 

For this game, that argues strongly against a four-form × three-ability permanent button grid. On a phone it would sacrifice enormous screen area to buttons while combat itself involves up to 64 bodies.

I would use:

form selector → one large contextual Order button.

The passive and autocast appear as tiny informational icons if the player inspects a form, but not as combat controls. The Order icon changes with the selected form. Cooldown is communicated through one radial fill and a short sound cue.

Telegraphing should be deliberately slower than desktop RTS
Riot discovered this directly while building Teamfight Tactics: with eighteen champions casting, the original League-speed animations produced a cloud of effects that made fights hard to understand, so the team reduced VFX and deliberately slowed animation timings. 
 Riot's broader clarity rule is that visuals and audio should let the player identify and react to spells and attacks. 

Supercell's live balancing provides useful real-world reaction-window examples. It increased Void's first-hit delay because players could not react quickly enough; in March 2026 Vines deployment went from 0.4 to 0.9 seconds specifically to give defenders more time; in April an ability gained a 1.5-second post-spawn delay because its instantaneous lock-on left no time to adjust. 

I would begin playtests with these telegraph ranges:

Event	Initial telegraph target
Minor automatic proc	0.35–0.50 s
Important single-target auto	0.50–0.70 s
Player Order / small AoE	0.65–0.90 s
Significant CC	0.75–1.00 s
F4 Titan signature	0.9–1.2 s

Those are recommended starting points, not industry laws. Your test is whether a child on a phone can answer “what is about to happen?” before it happens.

An important distinction is that telegraph time is not input latency. Once my Order button is pressed, it should acknowledge immediately — squish animation begins, crystal cracks glow, sound plays — but the damaging part lands later. That preserves responsiveness while still giving the opponent counterplay.

Show danger geometry before spectacle
Every consequential area skill should follow:

anticipation → committed hit area → impact → fast cleanup.

For example, Titan slam:

Titan visibly raises body/arm.
Ground receives a clean projected lethal zone.
Projection fills or pulses toward impact.
Damage occurs.
Dust/crystal/goo can explode outside that shape for spectacle.
The giant explosion is allowed to look larger than the actual damaging area, but the pre-hit shape must be authoritative.

Do not make colour carry all semantic information. Cyan versus amber can establish race identity, but use geometry as well:

SQUISH hazards: circles, ripples, expanding blobs.
CRUNCH hazards: wedges, cracks, angular lines.
“Stun” always gets one consistent icon.
“Shield” always gets another.
Predator/prey relationship should be readable through silhouette and size before the tooltip is opened.
Crowd control should interrupt, not remove the player's army
Clash Royale has repeatedly shortened or removed CC when it removes reasonable interaction: Tesla Evolution's stun was halved; Royal Giant was changed because repeated knockback could permanently hold melee units away; Mega Knight's knockback against heavy units was reduced because it could make breakthrough effectively impossible. 
 Dota has explicitly used status resistance to shorten effects such as stuns, roots, silences and fears, while Wild Rift increased tenacity after noting that stuns felt especially long in its mobile context. 

For your faster, child-oriented game I would be substantially harsher on CC than a desktop MOBA:

Mechanic	Recommended v0 guard rail
Hard stun, ordinary ability	0.35–0.60 s
Hard stun, big Titan signature	≤0.8 s
Slow	15–30%
Slow duration	1.0–2.5 s
Heavy knockback	Translate to roughly ≤0.5 s lost combat time in normal conditions
Repeat hard CC	50% duration on second application within 2 s
Third hard CC inside same window	Immunity / no hard control
Movement displacement	Never move a victim so far that re-engagement becomes multiple seconds of helpless walking

The philosophy is simple: an opponent should mutter “damn, good ability”, not put the phone down while watching their army fail to move.

Proposed twenty-four-ability kit
These are v0 simulator inputs, not final production numbers. Their purpose is to instantiate the architecture above with enough numerical specificity that you can build the prototype rather than merely discuss it.

The paired SQUISH/CRUNCH abilities use similar budgets but intentionally different physical verbs.

F1 Swarm — predator of F4 Titan
The F1 package should reward numbers versus one giant body and remain unimpressive against the F2 that is supposed to eat it.

Race	Slot	Ability	v0 behaviour
SQUISH	Passive	Dogpile	When multiple SQUISH F1s attack the same F4, each additional nearby attacker adds +2% F1 damage to that Titan, capped at +22%. Bonus falls off after 1 s without contact. No bonus against F1–F3.
SQUISH	Auto	Boing!	Once every 7 s, when struck by an F4 basic attack, the F1 squashes flat, reduces that hit by 35%, then elastically hops a short distance sideways. Does not trigger against F2/F3.
SQUISH	Order	Slingshot Rush	24 s shared form cooldown, 0.55 s tell. F1s gain +30% move speed for 2.5 s; each can add +20 damage to its next F4 hit. Maximum 12 bonus-hit procs on one Titan per cast, preventing 32-body alpha from instantly deleting one target.
CRUNCH	Passive	Stress Fracture	Distinct CRUNCH F1 attackers place tiny fracture stacks on an F4; each stack causes that Titan to take +2% damage from F1 only, cap +22%. Stacks decay after 1 s without F1 contact.
CRUNCH	Auto	Chip Armour	Once every 7 s when hit by F4, the shard sheds an outer crystal plate, reducing the hit by 35%. Unlike SQUISH it stays planted rather than bouncing.
CRUNCH	Order	Needle Rush	24 s shared cooldown, 0.55 s tell. +30% move for 2.5 s; next hit on an F4 adds 20 damage, with the same 12-proc-per-Titan cap. The visual is an angular shard thrust rather than a stretch.

The two passives intentionally converge on the same maximum numerical result through different fiction: goo piles on, crystal creates stress fractures.

Notice that neither gives F1 splash, healing or broad damage reduction. Those would help against F2 and risk destroying the counter loop.

F2 — predator of F1 Swarm
This tier's defining mechanic should be bounded throughput against many tiny bodies. Do not give it uncapped explosions.

Race	Slot	Ability	v0 behaviour
SQUISH	Passive	Wide Slap	When the primary target is F1, each basic attack splashes 15% of attack damage to each of up to 2 nearby F1s. Maximum three victims including the primary.
SQUISH	Auto	Bubble Pop	Every 7 s, if at least 3 F1s are nearby, 0.55 s bubble swell then pop: 28 damage to at most 4 F1s, plus 20% slow for 1.2 s.
SQUISH	Order	Mop-Up Roll	22 s cooldown, 0.70 s tell. For 3.5 s, +25% attack rate while the primary target is F1 and Wide Slap's two secondary hits rise from 15% to 25%.
CRUNCH	Passive	Shard Fork	Against F1, each attack sends two fragments at the nearest additional F1s for 15% attack damage each. Same three-target maximum as Wide Slap.
CRUNCH	Auto	Gravel Burst	Every 7 s when ≥3 F1s are close, 0.55 s angular cone: 28 damage, maximum 4 F1s, with a small shove tuned to cause about the same average lost contact time as Bubble Pop's slow.
CRUNCH	Order	Sawtooth March	22 s cooldown, 0.70 s tell. For 3.5 s, +25% attack rate into F1 and Shard Fork fragments rise to 25% each.

Why capped splash rather than “40 damage in a 5-stud radius”? Because the latter is secretly an ability whose power budget is determined by enemy density. The former has a hard ceiling you can test.

There is strong precedent for explicitly limiting multi-target value: Warcraft III uses target limits on area restoration, Company of Heroes uses model damage limits, and Supercell has nerfed area/chain effects when they wipe an entire push rather than merely perform their intended specialist role. 

F3 — predator of F2
F3 should be the efficient medium-unit breaker. It wants accurate, concentrated value, not Titan-scale area control.

Race	Slot	Ability	v0 behaviour
SQUISH	Passive	Engulf	+15% basic damage against F2. Visually, the blow wraps around the smaller target. No bonus against F1/F3/F4.
SQUISH	Auto	Gulp & Tug	Every 8 s against an F2: 0.60 s wind-up, +55 bonus damage to one target and 15% slow for 1 s.
SQUISH	Order	Belly Lunge	26 s cooldown, 0.80 s tell. Short elastic surge; first F2 contacted takes +80 damage per F3, one victim maximum per unit. A miss remains a miss.
CRUNCH	Passive	Wedge Strike	+15% basic damage against F2. The bonus is represented as a precise crystal edge rather than wrapping.
CRUNCH	Auto	Crack Shot	Every 8 s against F2: 0.60 s tell, +55 bonus damage, one target, followed by a small recoil shove instead of a slow.
CRUNCH	Order	Faultline Lunge	26 s cooldown, 0.85 s tell. Short committed charge; first F2 hit takes +80 bonus damage, one target per F3.

Because there are eight F3s at 32 matter, the theoretical Order payload is (8\times80=640) bonus damage before misses and overkill.

That “640” becomes useful in the next tier.

F4 Titan — predator of F3
This is where I would make the design deliberately single-target and theatrical. The Titan should look as though it could wipe a swarm while mechanically being bad at doing so.

Race	Slot	Ability	v0 behaviour
SQUISH	Passive	Mass Pressure	Against F3 attacks only, 10% damage reduction; F4 basic attacks deal +12% damage to F3. No mitigation against F1.
SQUISH	Auto	Pancake Drop	Every 9 s, 0.95 s squash-up telegraph, slams one F3 primary for +120 damage; a second F3 very close to it may take 40% of the bonus. No broad light-unit splash.
SQUISH	Order	Giga-Squash	28 s cooldown, 1.10 s telegraph. Each Titan flattens one target for +320 damage, automatically preferring F3. A 100-HP F1 still consumes the entire hit, so most of the 320 is wasted — intentionally.
CRUNCH	Passive	Dense Core	Same 10% F3-only mitigation and +12% F3 basic damage; expressed through bracing and a glowing crystal core.
CRUNCH	Auto	Seismic Hammer	Every 9 s, 1.0 s raised-arm tell. One F3 takes +120 damage; a nearby second F3 may receive 40%, with a small hard-looking recoil instead of SQUISH's flattening effect.
CRUNCH	Order	Monolith Strike	28 s cooldown, 1.10 s telegraph. One target per Titan receives +320 damage, preferring F3. Massive crack VFX, deliberately tiny lethal target cap.

There are two Titans at 32 matter:

[ 2\times320=640. ]

So the maximum direct Order bonus across a full army is also 640, matching the F3 example despite drastically different presentation.

That is the key scaling discipline I recommend:

[ \boxed{\text{signature burst per unit}\approx20\times matter} ]

as a starting rule, before counter-specific simulation.

Thus:

F1: 20 each × 32 = 640
F2: 40 each × 16 = 640
F3: 80 each × 8 = 640
F4: 320 each × 2 = 640
For F2, you can divide its 40-point payload over multiple F1s rather than concentrating it. The player sees progressively bigger abilities as matter fuses, while the underlying full-army budget remains mathematically stable.

Failure modes and the tests that expose them
The “does everything” ability
This is one of the oldest balance smells. Supercell once described the Executioner as a troop whose power was too high because it essentially “does it all”, and reduced damage, range and the amount its attack could hit. More recently, it has repeatedly removed extraneous utility from otherwise healthy abilities. 

For your game, an ability that simultaneously deals burst, stuns, shields its caster and increases movement speed is suspicious before you run a single simulation.

Ablation test: disable one ability while leaving the other two intact.

If one slot changes a neutral matchup by more than roughly 10 percentage points, or an intended counter by more than 12–15 points, inspect it. A healthy three-slot package should normally derive meaningful value from all three.

Swarm deletion by AoE
This will be the easiest mistake to make because Titan explosions are fun.

Supercell's Electro Dragon Evolution was reduced after its chain attack could effectively destroy huge pushes by itself; Wall Breakers' troop AoE was later reduced because it provided too much defensive bailout utility. 
 Company of Heroes similarly uses maximum-model-damage limits to prevent explosive weapons from translating radius directly into unlimited casualties. 

Your regression test should place all 32 F1s at several packing densities:

tight ball,
normal navigation spacing,
deliberately spread,
chokepoint.
A single F4 proc should never erase a dramatic fraction of the swarm merely because pathfinding caused them to overlap. Use target caps as the hard backstop.

Titan pseudo-invulnerability
The bad combination is:

high HP × percentage DR × regenerating shield × CC resistance × healing.

Because percentage DR multiplies EHP, stacking several defensive layers can quietly create a Titan that has no practical failure state.

Initial guard rails:

persistent F4 DR: ≤10–12%;
temporary F4 DR: ≤20%, short duration;
shield per application: ≤12–15% F4 max HP;
shields refresh or replace — never stack additively without a hard cap;
no simultaneous significant heal + shield + DR package;
F1's intended anti-F4 pressure must never be fully blocked by defence.
Supercell's Evolution balance work illustrates the broader principle: it has repeatedly removed bonus HP where an ability already generates substantial effective health. 

Stun-lock and displacement-lock
The pathological test is not “how long is one stun?” It is:

[ \text{maximum continuous time without meaningful control} ]

after multiple units chain their autocasts.

Run every CC ability at synchronised worst-case timings. If an army can be unable to act for more than roughly 1.0–1.2 seconds continuously, your anti-chain rule should trigger.

This is not theoretical nit-picking: Clash Royale has explicitly changed Royal Giant because knockback could permanently hold melee units away and reduced Mega Knight knockback because some units had effectively no chance to break through. 

Ability multiplication through fusion
Test these sequences automatically:

cast → split → fuse

auto proc → split → fuse

shield → split → take damage → fuse

stunned → split

Order cooldown → split into other form → reform original

None should create extra charges, remove a cooldown, duplicate a shield, erase a downside or cleanse CC unless cleansing is an explicit priced mechanic.

Snowballing
A combat advantage naturally produces fewer enemy guns firing, which produces a larger advantage — the Lanchester-style feedback loop. 
 On top of that, permanent kill-trigger buffs, repeated healing-on-kill or ability cooldown resets can turn one early kill into an irreversible avalanche.

P.E.K.K.A Evolution is an unusually relevant precedent: Supercell changed its healing from a fixed value to a victim-health-dependent value specifically because the fixed version could farm health too efficiently from small swarm units. 

I would consequently ban uncapped heal-on-kill from your first production ability set. It is particularly dangerous when one race can harvest 32 F1 deaths but only two F4 deaths.

Balance metrics should be segmented, not averaged away
Riot's published Wild Rift balance framework uses win rate as a primary indicator but then segments performance by skill/MMR and role; its stated emergency criterion at that time included champions exceeding 56% across the board. 
 Supercell likewise says it uses both playtesting and card use/win rates. 

For this game, an overall 50% faction win rate is nearly meaningless if one matchup is 90:10 and another compensates at 10:90.

Your primary dashboard should therefore be the equal-matter battle matrix, not global win rate.

My initial targets would be:

Test	Target
Same form, SQUISH vs CRUNCH	48–52%
Neutral form matchup	47–53%
Intended counter, equal skill	60–65% intended winner
Reverse counter	35–40%
Mirror	statistically indistinguishable from 50%
Overall race win rate after varied compositions	49–51%
No single active's share of total army damage in ordinary battle	preferably <20%
Removing one non-counter-anchor ability	usually <8 percentage-point win-rate swing
Removing full three-ability package	clearly measurable, but should not turn every battle into nonsense

A deliberate 60–65% matchup-specific counter is not inconsistent with a 50% overall faction target. You are creating a rock-paper-scissors system; counters are supposed to matter. What you do not want is 90–10, because then a composition decision determines the result before anyone plays.

Final recommended framework and simulator test plan
The production rules I would lock before adding more abilities
Ability structure

Every race/form receives:

one Identity passive;
one conditional autocast;
one context-sensitive Form Order.
No individual-unit buttons. The Order applies to every eligible body of that form, with its total effect intrinsically scaling by matter.

Input

Show at most one large combat ability button after the player selects a form/group. Use Roblox's cross-platform action system to bind the same semantic Order to touch, mouse and gamepad appropriately rather than forcing identical physical UI everywhere. 

Per-matter budget

Use approximately:

[ \boxed{52\ combat\ equivalents / matter / 12s} ]

as the first-pass maximum ability package, corresponding to about 20% of the 262-point reference matter package.

Allocate approximately:

[ \boxed{25% \ passive,\ 35% \ auto,\ 40% \ Order} ]

and calibrate the numbers through counterfactual simulations rather than raw tooltip arithmetic.

Signature burst

Begin with:

[ \boxed{20\ bonus\ damage\times matter\ per\ unit} ]

for a direct-damage Order, meaning a theoretical 640 bonus damage at 32 matter regardless of form. Reduce it when the ability also contains meaningful CC, mobility or defence.

Cooldowns

Ability	Guard rail
Minor internal proc	6–10 s
Strong automatic proc	8–12 s
Player Order	22–30 s
Temporary combat buff	2.5–4 s
Sustained average stat uplift from a periodic buff	generally ≤8–10%

Given Supercell's 2026 conclusion that repeated cooldown abilities can add complexity without enough meaningful play, I would also A/B test a radically simpler alternative in child playtests: two Order charges per form per match rather than continuously refreshing cooldowns. 
 If children hoard, forget or spam cooldown abilities, limited charges may actually produce clearer decision-making.

Damage and area rules

[ \boxed{\text{Never use uncapped combat AoE in the core unit kits}} ]

F2 anti-swarm effects: 3–4 targets maximum.

F3: normally 1–2.

F4: normally 1 lethal primary plus perhaps one reduced secondary.

Let F4 look devastating over a broad area without mechanically damaging everything in that visual footprint.

Defence

Persistent DR ≤10–12%.

Short-duration DR ≤20%.

Ordinary shield ≤15–20% max HP; F4 preferably ≤12–15%.

Shield refreshes should replace the old shield rather than stacking.

Never let transform reset defensive charges.

Crowd control

Hard CC ordinary:

[ \boxed{0.35–0.60s} ]

Titan signature maximum:

[ \boxed{\sim0.8s} ]

Slow:

[ \boxed{15–30%,\ 1–2.5s} ]

After one hard CC, a second inside approximately two seconds receives 50% duration; further hard CC inside the window is ignored or converted to a soft slow. This borrows the philosophy behind status-resistance systems without burdening children with a visible “tenacity” statistic. Dota's explicit status-resistance mechanic and Wild Rift's mobile CC tuning demonstrate the underlying problem. 

Telegraphs

Use roughly:

[ \boxed{0.5–0.7s\ for\ meaningful\ autos} ]

[ \boxed{0.7–0.9s\ for\ Orders} ]

[ \boxed{0.9–1.2s\ for\ Titan\ signatures} ]

with immediate animation/audio acknowledgement on button press. Riot's TFT experience and Supercell's live reaction-window changes both support erring toward greater clarity when many simultaneous actors are on screen. 

Build the simulator around events rather than frames
A simple simulator does not need Roblox physics initially. Make it discrete-event based.

For each unit store approximately:

text
Copy
form
race
matter
hp
position
speed
attackDamage
attackInterval
attackRange
targetId
nextAttackTime

passiveState
autoCooldown
orderCooldown

shield
damageReduction
slowMultiplier
ccRemaining
ccResistanceWindow

matterLineageId
The matterLineageId or equivalent shared-state identifier is important for fusion/split regression tests.

Events are:

text
Copy
AcquireTarget
MoveIntoRange
BasicAttack
AutoCast
OrderCast
Damage
ApplyCC
Death
Fuse
Split
This will let you model the things the current HP/DPS spreadsheet cannot: overkill, lost attack time, contact limits, target distribution and ability timing.

Run the pure-form battle matrix first
For each race pairing:

SQUISH vs SQUISH,
CRUNCH vs CRUNCH,
SQUISH vs CRUNCH,
CRUNCH vs SQUISH,
run every form against every form at exactly 32 matter.

That produces sixteen form cells per race pairing. Randomise:

spawn jitter,
target selection tie-breaks,
formation,
initial ability phase,
pathing/contact assignment,
small attack timing jitter.
Use 5,000 seeds per important cell. Around a 50% true win rate, 5,000 Bernoulli trials gives a rough 95% sampling uncertainty of about ±1.4 percentage points, which is enough to distinguish a 50% neutral matchup from a 60% counter without absurd simulation volume.

Record, per run:

Metric	Why it matters
Winner	obvious outcome
Remaining HP and remaining matter	measures margin, not only win/loss
Battle duration	detects degenerate stalls / instant wipes
Damage by basics/passive/auto/Order	finds dominant ability
Damage prevented	catches hidden defence dominance
Shield used vs wasted	nominal shield is not realised value
Targets hit per AoE	detects density scaling
Overkill damage	critical to F1↔F4 relationship
Hard-CC seconds suffered	detects stun chains
Time unable to attack due to displacement	values knockback
Ability casts	verifies cooldown model
Missed/wasted casts	measures practical rather than theoretical power
Distance travelled	helps quantify mobility abilities

Use paired-seed ablation rather than eyeballing
For every seed, run:

A: complete kit.

B: passive disabled.

C: auto disabled.

D: Order disabled.

E: all abilities disabled.

Because the random seed is identical, differences are much less noisy.

Calculate:

[ \Delta WR_i = WR_\text{full} - WR_{\text{without ability }i} ]

and

[ \Delta CE_i = CE_\text{full}-CE_{\text{without ability }i}. ]

This is the measurement that should decide whether SQUISH's slow and CRUNCH's knockback are truly budget-equivalent.

Enumerate fusion compositions after pure forms work
Your matter denominations are 1, 2, 4 and 16. Under

[ n_1+2n_2+4n_3+16n_4=32,\qquad n_4\le2, ]

there are only 107 legal count compositions.

That is small enough to enumerate.

Do not immediately run every possible composition versus every other composition at 5,000 seeds; that is 11,449 army-pair combinations before race permutations. First run a coarse screening tournament, perhaps 100–250 seeds per army pair. Rank compositions by win rate and identify outliers. Then give the suspicious/top compositions 5,000-seed validation runs.

This exposes a failure a 4×4 pure matrix cannot: an ability may be fair on F2 alone and F4 alone but degenerate when, say, four F2s exploit Titan displacement while one F4 delivers uncontested alpha.

Add transformation tests next
Feed the simulator scripted transformations at several times:

immediately before contact;
immediately after an autocast;
immediately after an Order;
while shielded;
while slowed;
immediately after taking lethal-looking burst;
while cooldowns are halfway finished.
Your invariant should be:

[ \boxed{\text{Fusion changes geometry and role; it does not create resources.}} ]

No extra effective HP, shield, proc, cast, cleanse or cooldown should be generated merely by rearranging the same matter.

Finally stress the counter matrix, not just mean win rate
For each intended edge — F1→F4, F4→F3, F3→F2, F2→F1 — test under:

tightly packed formation;
spread formation;
flank;
chokepoint;
delayed Order;
optimal Order;
no Order;
±10% attack timing jitter;
poor versus good target selection.
The intended winner should remain favoured across ordinary conditions, but not invincible. I would target approximately:

[ \boxed{60–65%\ counter\ win\ rate} ]

at equal matter and competent automatic play.

The neutral pairings — F1/F3 and F2/F4 — should live near:

[ \boxed{47–53%} ]

unless you deliberately introduce another relationship.

Same-form SQUISH versus CRUNCH should sit around:

[ \boxed{48–52%} ]

even though the combat log looks completely different.

That last result is the real test of successful faction design: cyan goo should win by bending, sticking and bouncing; amber crystal should win by bracing, cracking and knocking — yet neither colour should be the better spreadsheet choice.

The central design equation I would keep on the wall is therefore not HP × DPS. It is:

[ \boxed{ \text{same matter budget} + \text{different delivery} + \text{bounded multi-target scaling} + \text{one human decision per form}
\text{readable asymmetric army combat} } ]

That architecture gives you considerable room to make SQUISH hilarious and elastic and CRUNCH brutally satisfying without sacrificing the counter loop, mobile readability or the mathematical advantage of having a conserved 32-matter economy.
