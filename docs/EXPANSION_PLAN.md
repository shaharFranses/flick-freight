# Flick Freight — Expansion Plan: Additive Mechanics & 40 Levels

> Hand this file to Claude Code. Put it at `docs/EXPANSION_PLAN.md` in the repo.
> Work phase by phase, one branch and PR per phase.
> **Before writing code, Claude Code must read** `scripts/levels.gd`, `game.gd`, `cargo.gd`, `truck.gd` and `tools/bot.gd`.
> It must also confirm or adjust the data keys proposed below against the real schema.

---

## 1. Core principle: mechanics are added, never changed

Depth comes from **stacking**. Every mechanic a player has learned keeps working exactly as it did. New mechanics layer on top and combine with the old ones. A player in level 35 is using skills from level 3.

### Invariants (hard rules for every PR)

1. **Existing levels 1–15 are frozen.** Do not edit their level dictionaries, star thresholds, or ordering.
2. **Existing mechanic behavior is frozen.** This covers moving trucks, heavy crates, barrels, fragile cargo, pillars, low beams, wind, and tall tailgates. Do not retune their physics values, resolve rules, or scoring.
3. **New mechanics are opt-in by data.** A level only gets a mechanic if its dictionary declares it. A missing key means the mechanic is off, so old levels behave identically.
4. **Regression gate.** The bot must produce the same pass/star results on levels 1–15 before and after every PR (see §5).
5. **Save compatibility.** Existing saves must load, and stars for levels 1–15 are preserved. New levels are only appended, never inserted.
6. **Readability at 907×510.** Every new element must be readable at CrazyGames' smallest iframe, so there are no tiny or dark-on-dark visuals. This was a rejection cause before.
7. **Every new mechanic must interact with at least one older mechanic** in at least two levels. If it can't combine with anything, it doesn't ship.

---

## 2. Current state (baseline)

- Godot 4.3, landscape 1280×720, single-threaded web export, deployed through GitHub Pages
- 15 levels in 3 worlds: **Town (1–5)**, **Woods (6–10)**, **Desert (11–15)**
- Existing mechanics (M1–M7): moving trucks · heavy crates · barrels (tip over) · fragile cargo · pillars and low beams · wind · tall tailgates
- Stars: about 50% loaded for 1★, about 75% for 2★, all cargo for 3★
- QA bot (`tools/bot.gd`) solves throws ballistically and plays every level at error 0 and 0.5

---

## 3. New mechanics (M8–M15), in introduction order

For each mechanic, Claude Code must:
- implement it behind its own data key
- extend the bot so it can still solve levels that use it
- add a small HUD tutorial pop-up the first time the mechanic appears, reusing the existing tutorial system

### M8 — Bounce pads (Harbor, introduced in L16)
- **Behavior:** a spring pad on the road or a wall. Cargo that hits it is reflected with a fixed restitution, plus a small boost. It enables bank shots around pillars and low beams.
- **Data (proposed):** `bounce_pads: [{pos: Vector2, angle: deg, power: float}]`
- **Touchpoints:** `game.gd` scene build. Add a new StaticBody2D with its own physics material, separate from walls so wall bounciness stays unchanged. Add a squash animation and a "boing" SFX.
- **Combines with:** pillars and low beams (shot around them), wind (the bounce arc drifts), fragile cargo (a pad hit must **not** count as a hard wall hit; define this explicitly).
- **Bot:** needs a simulation solver (see §5); the analytic ballistic solver can't handle bounces.

### M9 — Color-coded trucks (Harbor, L19)
- **Behavior:** cargo and trucks are tinted with 2–3 colors. Cargo landing in the wrong-colored truck counts as **missed**, not delivered. Two trucks are on screen at different distances. The cargo queue shows the next 2–3 items so the player can plan.
- **Data:** `trucks: [{color, x, moving?...}]` and a `color` field per cargo entry in the queue.
- **Accessibility:** use color **plus** an icon or pattern on the crate and on the truck side (circle, triangle, square). Never use color alone.
- **Combines with:** moving trucks (the far truck moves), heavy crates (a heavy red crate destined for the far truck), tall tailgates.
- **Scoring:** wrong-truck cargo stays in the truck as dead weight and takes up space. That makes a mistake cost you later, which adds depth.

### M10 — Bobbing ferry (Harbor, L22)
- **Behavior:** the truck sits on a ferry deck that bobs on a sine wave (vertical plus a slight roll). Cargo already in the truck moves with it.
- **Data:** `ferry: {amp_y, amp_rot, period}`
- **Touchpoints:** `truck.gd` motion. Reuse the "truck bodies follow truck" fix so carried cargo doesn't fall through.
- **Combines with:** barrels (the roll tips them), fragile cargo, tall tailgates (the tailgate height effectively changes with phase).

### M11 — Ice blocks and icy beds (Snow, L26)
- **Behavior:** an ice cargo type with very low friction slides on the truck bed. Some levels have an icy bed where **all** cargo slides more. A sliding item can fall out the open back unless a tailgate stops it.
- **Data:** cargo type `ice`; truck flag `icy_bed: true`
- **Combines with:** tall tailgates (they now matter defensively), fragile cargo (sliding into the cab wall at speed can break it), moving trucks (acceleration makes cargo slide).

### M12 — Bouncy cargo (Snow, L28)
- **Behavior:** tires and balls with high restitution are easy to land and hard to keep. They need a tailgate, a pile of other cargo to settle into, or a soft landing.
- **Data:** cargo type `bouncy`
- **Combines with:** bounce pads (very strong bank shots), tall tailgates, ice (bounce plus slide).

### M13 — Long cargo (Snow, L30)
- **Behavior:** planks and pipes are 2–3× wider than a crate and rotate during flight at a fixed spin. They count as delivered only if they settle mostly flat inside the bed.
- **Data:** cargo type `long` with `length` and `spin`
- **Combines with:** low beams (a rotating plank clips the beam), stacking (a plank on top makes a shelf for later cargo).
- **Tuning warning:** the spin must be deterministic and readable, with no randomness. If testers call it "random," reduce spin before anything else.

### M14 — Height limit bridge (Snow, L33)
- **Behavior:** a bridge or height bar is shown on the truck's exit route. When the truck leaves, any cargo above the line is knocked off and counts as missed. This rewards placing cargo low and spread out, not just landing it.
- **Data:** `height_limit: float` (in pixels above the bed). Draw a clear dashed line over the truck.
- **Combines with:** heavy crates (hard to place precisely), long cargo (planks keep the stack flat), bouncy cargo.

### M15 — Gas canisters (Freight Yard, L36)
- **Behavior:** a canister cargo type. A hard landing (impact speed above a threshold) "pops" it, pushing nearby cargo outward with an impulse. Soft landings are safe.
- **Data:** cargo type `canister` with `pop_speed` and `pop_force`
- **Combines with:** fragile cargo (a pop breaks neighbors), stacking and height limits, cargo order (throw it first and gently, or last).
- **Visual:** a clear "careful" icon and a pressure gauge on the canister. Use a puff of smoke, not explosion or violence imagery.

---

## 4. Level map (40 levels)

Pattern in each world: **introduce** (mechanic alone, easy) → **practice** → **combine** with old mechanics → **remix finale**.
Notation: **bold** = mechanic introduced here.

### Existing (frozen): L1–15 Town / Woods / Desert

### World 4 — Harbor (L16–25)
| L | Focus | Mechanics |
|---|---|---|
| 16 | **Bounce pads** intro | M8 |
| 17 | Bank shot around a pillar | M8 + pillars |
| 18 | Bank shot in wind | M8 + wind + fragile |
| 19 | **Color trucks** intro (2 colors, static) | M9 |
| 20 | Far truck moves | M9 + moving trucks |
| 21 | 3 colors, heavy crates | M9 + heavy + tall tailgate |
| 22 | **Ferry** intro | M10 |
| 23 | Ferry plus barrels | M10 + barrels + fragile |
| 24 | Two trucks: one on a ferry, one on the dock | M9 + M10 + moving |
| 25 | **Harbor finale** remix | M8 + M9 + M10 + wind |

### World 5 — Snow (L26–35)
| L | Focus | Mechanics |
|---|---|---|
| 26 | **Ice blocks** intro | M11 |
| 27 | Icy bed plus moving truck | M11 + moving + tall tailgate |
| 28 | **Bouncy cargo** intro | M12 |
| 29 | Bouncy plus bounce pads | M12 + M8 + low beam |
| 30 | **Long cargo** intro | M13 |
| 31 | Planks under low beams | M13 + low beams + wind |
| 32 | Plank shelf for fragile cargo | M13 + fragile + heavy |
| 33 | **Height limit** intro | M14 |
| 34 | Height limit plus color trucks | M14 + M9 + ice |
| 35 | **Snow finale** remix | M11–M14 + M8 |

### World 6 — Freight Yard (L36–40)
| L | Focus | Mechanics |
|---|---|---|
| 36 | **Gas canisters** intro | M15 |
| 37 | Canister order puzzle | M15 + fragile + height limit |
| 38 | Convoy: 3 color trucks, moving, wind | M9 + moving + wind + heavy |
| 39 | Ferry, ice, canisters | M10 + M11 + M15 |
| 40 | **Grand finale**: one of everything | All |

**Difficulty curve:** each intro level should be *easier* than the previous world's finale. Players should exhale before the next ramp.

---

## 5. Testing and tooling

### Regression gate (Phase 0, before any feature work)
1. Run the bot on L1–15 at `--error=0` and `--error=0.5` with a fixed seed. Save the results to `tools/baseline_v2.json` (pass, stars, and delivered/missed/broken counts per level).
2. Add `tools/regress.gd` (or a bot flag `--compare=baseline_v2.json`) that fails if any L1–15 result differs.
3. Add a frozen-data check: hash the dictionaries for L1–15 from `levels.gd` and fail if the hash changes.
4. Every PR runs: regression gate → bot on all levels → web export builds.

### Bot upgrade: simulation solver
The analytic ballistic solver breaks once pads, bounce, ice, rotation, and pops are involved. Add a **search solver**:
- For each throw, sample a grid of (angle, power) candidates, simulate the throw headlessly at fixed FPS (the physics is deterministic), score the outcome, and pick the best.
- Snapshot and restore level state between candidates, or simulate in a duplicated scene.
- Keep the old analytic solver for L1–15 so the regression baseline stays byte-identical.
- Report per level whether it passes at error 0 and error 0.5, the stars reached, and the number of candidates tried. Flag levels where 3★ needs fewer than 2% of candidates, since those are too precise for humans.

### Human play-test checklist (each phase)
- Chrome desktop at full size and at a 907×510 iframe
- Phone in landscape (touch drag)
- Each new mechanic's tutorial pop-up appears once and is readable
- No level takes more than about 90 seconds for a first clear

---

## 6. Supporting work

- **Level select:** 6 worlds × up to 10 levels. Paginate by world (one card per world, with arrows or swipe). World N unlocks once world N−1 has at least X stars total, and X needs tuning. Existing saves unlock correctly.
- **Art (Kenney CC0 only, update `art/v2/CREDITS.md`):** harbor water and ferry, snow tiles, ice block, tire, plank and pipe, bridge, gas canister, colored truck tints and icons.
- **Music:** reuse the loop or add one variant per new world through `tools/make_music.py`.
- **Covers:** regenerate with `tools/cover.gd` after Phase 1 so they can show the new mechanics.
- **README:** update the mechanics list and level count after each phase.

---

## 7. Phases

| Phase | Scope | Exit criteria |
|---|---|---|
| **0 — Guardrails** | Baseline JSON, regression gate, frozen-data hash, simulation solver in the bot (still analytic for L1–15) | Gate passes on main; no gameplay change |
| **1 — Harbor** | M8, M9, M10; L16–25; level-select pagination; harbor art | Regression green; bot passes L16–25 at error 0 and 0.5; human play-test done → **resubmit to CrazyGames here** |
| **2 — Snow** | M11–M14; L26–35; snow art | Same gates |
| **3 — Freight Yard and polish** | M15; L36–40; covers, README, music variants | Same gates; full 40-level run by the bot and a human |

One branch and one PR per phase, merged to main to deploy. Inside a phase, commit per mechanic so a broken mechanic can be reverted alone.

---

## 8. Kickoff prompts for Claude Code

**Phase 0**
> Read docs/EXPANSION_PLAN.md, §1 and §5. Inspect levels.gd, game.gd, cargo.gd, truck.gd, and tools/bot.gd. Then implement Phase 0 only: the baseline JSON for L1–15, the regression gate, the frozen-data hash, and a simulation solver in the bot, keeping the analytic solver for L1–15. No gameplay changes. Show me the baseline results before committing.

**Phase 1**
> Read docs/EXPANSION_PLAN.md. Implement Phase 1 (M8–M10, L16–25, level-select pagination) on a branch. First propose the exact level-data keys based on the real schema in levels.gd and wait for my OK. After each mechanic: run the regression gate and the bot, and commit. Never edit L1–15 or the M1–M7 behavior.

**Phases 2 and 3:** same as Phase 1, with that phase's scope.

---

## 9. Open decisions (owner: Shahar)

1. Should the world unlock threshold use stars, or just completing the previous world? Stars add replay value; plain completion is friendlier for portal players.
2. Should color trucks use 2 colors max or 3? Three adds depth but may be hard to read at 907×510.
3. Should M15 (gas canisters) be cut if Phase 3 runs long? It's the most optional mechanic.
4. Should there be a separate "endless/daily" mode later for retention? It's out of scope for this plan.
