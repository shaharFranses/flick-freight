# Flick Freight — Expansion Plan 2: Moving Obstacles, New Vehicles, 100 Levels

> For execution in Claude Code inside the `flick-freight` repo (Godot 4.3).
> Builds on `EXPANSION_PLAN.md` (levels 1–40, mechanics M1–M15), which is complete.
> Goal: grow from **40 → 100 levels** by adding **moving obstacles**, **new vehicles** (including the **helicopter**), and making the **height limit physical** instead of a red line.

> **Status: done.** All phases A–E are built: 100 levels in 9 worlds (Downtown, Construction and
> Sky Port behind 90 / 120 / 150 stars). Notes from building it:
> - M24 icicles were cut, as planned. Both stretch vehicles (V9 balloon, V10 food truck) are in.
> - Helicopter and balloon levels score like the motorcycle: load N, stars for few throws. The net
>   swings at its cable's natural period, so loaded cargo rides calmly.
> - Mail van and food truck have roller floors: what gets through the slot / window slides to the
>   far end, so the skill is the opening, not the packing.
> - Hardest for the human-aim bot (0 stars at error 0.5, 2 at perfect aim): Downtown 8 and the
>   Downtown boss (food truck window precision). Worth a look in play-testing.
> - Star gates and difficulty are provisional; tune after play-testing.

---

## 0. Decisions already made (read first)

| # | Decision | Status |
|---|---|---|
| D1 | New content is **added, not changed**. Existing levels 1–40 keep their gameplay exactly. | Locked (carried over from Plan 1) |
| D2 | The red height-limit line is replaced by a **real low bridge / tunnel arch** the vehicle drives under on departure. Over-height cargo is visibly knocked off. This is the **only** permitted change to frozen levels, and it must not change any level's outcome. | Confirmed (real bridge) |
| D3 | The **helicopter** is in scope as a headline vehicle with its own world. | Locked |
| D4 | Target: **100 levels** = 40 existing + 60 new. | Locked |
| D5 | All motion (obstacles, moving vehicles) is **deterministic**: driven by a level clock, no randomness, identical on every restart. | Locked (needed for the bot and for fairness) |

---

## 1. Invariants (the regression contract)

These must hold after **every** phase. A phase is not done until they pass.

1. **Levels 1–40 unchanged in play.** Level files, IDs, cargo, star thresholds, and physics parameters are not edited, except the visual swap in D2.
2. **Bot parity.** The QA bot's results on levels 1–40 (solvable, best star count, and solution throw parameters within tolerance) match a baseline snapshot taken **before Phase A starts**. Save this snapshot as `tools/baseline_1_40.json`.
3. **Save compatibility.** Existing saves (stars per level, unlocks) load correctly. Saves are keyed by **level ID**, never by list position. If they're keyed by position today, migrate them in Phase A with a one-time mapping and a test.
4. **Existing mechanics M1–M15 behave identically.** New systems wrap or extend them. They don't alter their code paths. If a shared script has to change, add a branch for the new behaviour and leave the old path byte-for-byte equivalent.
5. **Performance.** No level drops below 60 fps on the CrazyGames minimum spec in the web export. Moving obstacles use `AnimatableBody2D` (with `sync_to_physics`), not per-frame RigidBody forces.
6. **Readability at 907×510.** Every new obstacle and vehicle stays readable at CrazyGames' smallest iframe size.

---

## 2. Height limit: physical instead of a red line (D2)

**Problem:** the red line is an abstract rule painted on the scene, while every other mechanic is a physical object.

**Change:**
- Remove the red line's rendering in every level that uses the height limit.
- Place a **low bridge / tunnel arch** prop on the departure path. It's sized so its underside is at exactly the old limit height, and its art matches each world (stone arch in Town, wooden bridge in Woods, rock overhang in Desert, steel overpass in Freight Yard, and so on).
- **Rule check stays the same.** The pass/fail logic for height (whatever it currently checks) is not changed. Only the presentation changes.
- **Departure feedback:**
  - Success: the vehicle drives under, with a small camera follow.
  - Failure: the vehicle drives forward, the bridge collides with over-height cargo, and the cargo tumbles off. Then the existing fail flow runs.
  - Use a scripted animation, not live physics, so the outcome always matches the rule check.
- **Pre-throw hint:** show a faint dashed silhouette under the bridge, at the bridge's height, so the limit is still readable before the first throw. It's subtle, not a red line.

**Acceptance:** bot parity on 1–40 is unchanged, and a manual check confirms each affected level shows its bridge at the right height.

---

## 3. New systems

### 3.1 Level clock (foundation for all motion)

- One `LevelClock` per level, counting **physics frames** since the level started or restarted. Restart resets it to 0.
- Every moving element reads its position from `f(clock_frame, params)`: a sine, a path-follow, or a keyframed loop. Nothing integrates its own state.
- Per-level parameters include `phase_offset_frames`, so the same obstacle can start in a different place in different levels.
- Optional "time-scrub" debug key for designers, to preview obstacle positions.

### 3.2 Moving obstacles (M16–M24)

Each new mechanic must appear **combined with at least one older mechanic (M1–M15)** in at least one level, as in Plan 1.

| ID | Obstacle | Category | Behaviour | Home world |
|---|---|---|---|---|
| **M16** | **Harbor gantry crane** | Blocker | A container hangs from a cable and swings as a pendulum across the throw path; the trolley may also slide along the gantry. | Harbor |
| **M17** | **Garage door** | Timed gate | A roller door between player and vehicle opens, holds, and closes on a loop. | Town |
| **M18** | **Passing train / bus** | Timed full blocker | A long body crosses the whole lane at intervals, with a short warning (lights or horn) before it arrives. | Freight Yard, Town |
| **M19** | **Ski-lift chairs** | Moving platforms | Chairs travel along a cable. Cargo can land on a chair and ride it, or bank off it. | Snow |
| **M20** | **Swinging log** | Pusher | A log on ropes swings and knocks cargo off course. | Woods |
| **M21** | **Windmill blades** | Rotating blocker | Blades rotate at a constant speed, and you thread throws through the gaps. | Desert |
| **M22** | **Forklift patrol** | Moving pusher | Drives back and forth along the floor and shoves cargo that's on the ground or low on its arc. | Harbor, Construction |
| **M23** | **Conveyor belt** | Carrier platform | Cargo landing on it is carried toward or away from the vehicle at a fixed speed. | Freight Yard, Construction |
| **M24** | **Falling icicles** | Hazard to loaded cargo | Icicles drop on a fixed schedule and can knock cargo that's already on the vehicle. | Snow (**cut candidate**) |

**Implementation notes:**
- Moving obstacles that cargo can touch are `AnimatableBody2D`. Pure-visual elements (warning lights) are plain nodes.
- Every blocker needs a **visible tell**, so timing is learnable. Examples: the crane cable creaks at the top of the swing, the garage door flashes before closing, the train has signal lights.
- Pushers must not trap cargo in unwinnable states. If cargo rests in an unreachable spot for more than 3 seconds, it counts as lost, using the existing lost-cargo flow if there is one.

### 3.3 Vehicle system (V0–V10)

**Approach — do not refactor the existing truck.**
- Define a small common interface, `CargoVehicle`, that the level and win logic talk to. For example: `get_load_zone() -> Area2D`, `is_cargo_secured(body) -> bool`, `depart()`, plus optional `get_motion_params()`.
- The **existing truck is V0**. Wrap it with a thin adapter that implements the interface, without changing its scene or physics.
- Each new vehicle is its own scene implementing `CargoVehicle`.
- **First step in Phase A:** read how the win check currently finds the truck and decides cargo is loaded. Choose the least invasive way to route it through `CargoVehicle`. Bot parity must hold.

| ID | Vehicle | Target shape | Skill tested | Typical cargo count | Home world |
|---|---|---|---|---|---|
| V0 | Standard truck | Existing | Existing | — | All |
| **V1** | **Motorcycle with rear rack** | Tiny flat rack with a low rail | Extreme precision; cargo bounces off easily | **3** | Town |
| **V2** | **Pickup truck** | Short bed with low sides | Soft throws; hard throws slide out | 4–5 | Woods |
| **V3** | **Garbage truck** | Small top hopper opening | Steep arcs, like a basketball shot | 4–6 | Town / Downtown |
| **V4** | **Mail van slot** | Narrow horizontal slit in the side | Flat, precise throws only | 3–4 (small parcels) | Downtown |
| **V5** | **Dump truck** | Tilted bed | Cargo slides back, so order matters; heavy crates (M2) act as stoppers | 4–6 | Desert, Construction |
| **V6** | **Flatbed (no sides)** | Open flat surface | Stacking and balance | 4–6 | Freight Yard, Construction |
| **V7** | **Train flatcars** | 2–4 cars moving across the scene | Fill each car as it passes | 1–2 per car | Freight Yard |
| **V8** | **Helicopter with hanging net** ⭐ | Net hanging on a cable under a hovering helicopter, swinging | Hitting a moving pendulum target | 3–5 | **Sky Port** |
| V9 | Hot-air balloon basket | Basket that slowly rises and falls and sways | Vertical timing | 3–4 | Sky Port (stretch) |
| V10 | Food truck side window | Framed opening in the side | Sideways throws into a frame | 3–4 | Downtown (stretch) |

**Vehicle-specific notes:**
- **V1 Motorcycle:** "3 boxes, extremely accurate" is the design goal. Keep the rack 30–40% the width of a truck bed. Use the stars to reward few throws, not just success.
- **V7 Train:** the cars move on rails, driven by the level clock (D5). The win condition is "each car has at least its required cargo when it reaches the exit marker". Cargo that lands on a car rides with it, so the cars are `AnimatableBody2D` platforms carrying RigidBody cargo.
- **V8 Helicopter — the headline vehicle:**
  - The helicopter body hovers on a gentle scripted path: bobbing, plus a slow drift on later levels.
  - **The net swings on a scripted pendulum. Cargo landing in it does not affect the swing.** This keeps the game deterministic and the bot solvable. Real cable physics, where cargo weight changes the swing, is more fun but chaotic. Only consider it later as a "Hard mode" experiment.
  - The net is a container with soft walls: cargo inside sways with it but shouldn't fall out unless hit hard by another throw.
  - Win: the required cargo is in the net, then the helicopter lifts off. Use a big rotor sound and a camera shake on lift-off; this is a showcase moment.
  - It combines naturally with wind (existing mechanic), which can also push the net's swing in a scripted way, and with the harbor crane (M16) for two pendulums out of phase.
  - Art: build it from Kenney CC0 parts, or draw it in code like the truck. Rotor blur is two alternating frames.

---

## 4. Level map: 40 → 100

**Structure:** each of the 6 existing worlds gets an **Act II** of 5 new levels (30), plus **3 new worlds** of 10 levels each (30).

- Act II levels are **appended after the existing levels of that world** and get **new IDs**. Existing IDs never change (invariant 3).
- Each world ends with a **"special vehicle" boss level**.

### 4.1 Act II of existing worlds (30 levels)

| World | New levels | Main new content | Boss level (last of Act II) |
|---|---|---|---|
| Town | 5 | M17 garage door, M18 bus, V1 motorcycle, V3 garbage truck | Motorcycle through a garage door that's closing |
| Woods | 5 | M20 swinging log, V2 pickup, combined with existing wind | Pickup on a slope with two logs out of phase |
| Desert | 5 | M21 windmill, V5 dump truck, tumbleweed as a reskinned M22-style pusher | Dump truck behind a windmill, heavy crates as stoppers |
| Harbor | 5 | **M16 gantry crane**, M22 forklift | Ferry (M10) behind a swinging crane container |
| Snow | 5 | M19 ski lift, ice blocks (M11) on chairs, M24 icicles if kept | Load cargo by banking it off a moving ski-lift chair |
| Freight Yard | 5 | M18 passing train, M23 conveyor, V6 flatbed, V7 train flatcars | Train flatcars passing while a second train blocks the lane |

### 4.2 New worlds (30 levels)

| # | World | Levels | Identity | Content |
|---|---|---|---|---|
| 7 | **Downtown** | 10 | Busy city street at dusk; vehicle variety is the star | V3 garbage truck, V4 mail van, V10 food truck (stretch), M17, M18 bus. Boss: three different vehicles in one level, each needing a different kind of throw. |
| 8 | **Construction Site** | 10 | Cranes, scaffolding, dirt | V5 dump truck, V6 flatbed, M22 forklift, M23 conveyor, a tower crane (an M16 variant with a horizontal trolley). Boss: flatbed stacking while a forklift patrols. |
| 9 | **Sky Port** ⭐ | 10 | Cliffside heliport above the clouds, the finale world | **V8 helicopter** throughout, V9 balloon (stretch), wind. Difficulty climbs: hovering helicopter → bobbing → drifting → two helicopters → helicopter plus balloon. Boss (level 100): helicopter with a drifting, swinging net in crosswind. Every throw has to count. |

### 4.3 Difficulty and stars

- Each Act II and new world follows **introduce → practise → combine → twist → boss**.
- Star thresholds come from the bot's best solution plus a margin, following the Plan 1 rules. Boss levels get a tighter 3-star bar.
- New mechanics are introduced alone first, in a gentle level with no older complications, then combined.

### 4.4 Level select and unlocks at 100 levels

- The level-select UI must handle 9 worlds × 10–15 levels at 907×510: one page per world, swipe or arrows between worlds, and a total stars counter.
- Unlocks:
  - Act II of a world unlocks when Act I of that world is complete.
  - New worlds unlock at star thresholds.
  - Provisional thresholds: Downtown 90★, Construction 120★, Sky Port 150★. Tune them after play-testing.
- Each world card shows a small icon of its special vehicle, so players can see the helicopter waiting at the end.

---

## 5. Bot / QA upgrades

Moving obstacles and vehicles break the "static scene" assumption, so the bot needs one more search dimension: **when to throw**.

1. **Release-time search.** For each throw, search over `wait_frames` (for example 0 to one full obstacle cycle, in steps of 5 frames) as well as angle and power. Use the simulation-based solver from Plan 1.
2. **Deterministic replay.** A solution is `[(wait_frames, angle, power), ...]`. Replaying it from a fresh restart must reproduce the same result every time. Run each solution **3 times** and require identical outcomes. This is how D5 is enforced.
3. **Fairness checks for new levels:**
   - Every timed blocker has a throw window of at least **0.4 s** (about 24 frames).
   - Every 3-star solution survives a timing jitter of ±3 frames. If it only works on one exact frame, the level is too tight.
   - Helicopter levels: a 3-star solution has to exist in at least 2 different phases of the swing.
4. **Report.** Extend the bot's output with, per level: solvable, best stars, the number of release timings that work, and the jitter tolerance. Fail the build if any level 1–40 diverges from `baseline_1_40.json`.
5. **Performance smoke test.** Headless web-export run of the 5 heaviest levels, logging frame time.

---

## 6. Phased rollout

Each phase ends with: all invariants passing, the bot report clean, and a PR merged to main, which triggers the Pages deploy.

| Phase | Content | Levels after |
|---|---|---|
| **A — Foundations** | Baseline snapshot, LevelClock, `CargoVehicle` interface with the V0 adapter, height-limit bridge swap (§2), save-ID check or migration, bot release-time search, level-select UI for many worlds. **No new levels.** | 40 |
| **B — Harbor & Town Act II** | M16 crane, M17 garage door, M18 bus, M22 forklift, V1 motorcycle, V3 garbage truck. | 50 |
| **C — Remaining Act IIs** | Woods, Desert, Snow and Freight Yard Act IIs: M19, M20, M21, M23, (M24), V2, V5, V6, V7. | 70 |
| **D — Sky Port** ⭐ | V8 helicopter (and V9 balloon, if time allows), 10 levels, finale presentation. | 80 |
| **E — Downtown & Construction** | V4, (V10), tower crane variant, 20 levels. Sky Port's star unlock moves to the end once these worlds exist. | 100 |

*Why Sky Port comes before Downtown and Construction:* the helicopter is the most exciting feature, so it's worth getting it into players' hands and testing it early. Until Phase E, Sky Port unlocks directly after the existing worlds.

**Cut order if time runs short:** M24 icicles → V10 food truck → V9 balloon → Downtown reduced to 5 levels. The helicopter is not cut.

---

## 7. Kickoff prompts for Claude Code

**Phase A:**
> Read `EXPANSION_PLAN.md` and `EXPANSION_PLAN_2.md`. Execute Phase A of Plan 2 only. First, run the bot on levels 1–40 and save `tools/baseline_1_40.json`. Then investigate how win and loaded-cargo detection reference the truck, and how saves are keyed. Propose the minimal-touch design for `CargoVehicle` and `LevelClock` before writing it. Implement the height-limit bridge swap with no change to any level's outcome. Finish by proving bot parity on 1–40, and open a PR.

**Phase B–E (repeat per phase):**
> Read `EXPANSION_PLAN_2.md`. Execute Phase \<X\>. For each new mechanic or vehicle, build a test scene first, then the levels in introduce → practise → combine → twist → boss order. Run the full bot including fairness checks (§5) and the parity check on 1–40. Show me a GIF or screenshot of each new mechanic, then open a PR.

**Helicopter (Phase D) extra:**
> Before building levels, build a sandbox scene with the V8 helicopter and let me play-test the feel: hover height, swing period and amplitude, and net size. Expose these as exported variables so we can tune them together.

---

## 8. Open decisions for Shahar

1. **D2 confirm:** real bridge (assumed), covered box truck, or cut the height limit?
2. **M24 icicles:** keep or cut? They're the only obstacle that punishes cargo already loaded, which can feel unfair.
3. **Helicopter physics:** scripted swing (planned, deterministic) vs. real cable physics as an optional Hard mode later?
4. **Star unlock thresholds** for the new worlds (provisional 90 / 120 / 150).
5. **CrazyGames resubmission timing** (see note below).

---

## Note on resubmission

Don't wait for 100 levels to resubmit to CrazyGames. Their reviewers judge quality and the first minutes of play, not level count. If the 40-level build is polished, resubmit it now and ship Plan 2 as updates. Phases B and D make good update announcements ("new: Harbor crane", "new: Sky Port & the helicopter").
