# Geometry Tubbu — Development Plan

> Derived from [DESIGN.md](DESIGN.md) on 2026-06-12. The design doc is the *what*;
> this is the *how and in what order*. If they conflict, DESIGN.md wins — update
> this file to match.

## How to use this document (session protocol)

This plan is executed by Claude across many sessions. Each checkpoint is sized
for one session (~1–3 h of work) and **must end with the game runnable**.

**Model:** default to **Opus** for routine sessions (`/model opus`, id
`claude-opus-4-8`; optionally `/fast`). Switch to **Fable** (`/model fable`, id
`claude-fable-5`) for the *crucial, architecture-defining checkpoints* — the ones
where a wrong call is expensive to unwind across the whole project. Those are
flagged **🧠 FABLE** in their headers: **CP 0.2, CP 1.2, CP 2.1, CP 2.4, CP 3.5**.
Never run a 🧠 FABLE checkpoint on a smaller model.

**To resume work:**

1. Read [DESIGN.md](DESIGN.md) and the **Conventions** section below.
2. Look at **Status** — it names the next checkpoint.
3. Sanity-check the previous state: run the test suite, then optionally boot
   the project. **Exact binary path + all commands are in Conventions → "Local
   tooling & commands"** — use them; never search for the Godot binary.
4. Do the checkpoint's **Build** list. Verify every **Exit criteria** item.
5. Tick the boxes, update **Status**, append one line to the **Session log**,
   and commit with the checkpoint ID in the message (e.g. `CP 1.3: dash with i-frames`).

A checkpoint may be split mid-session: tick the Build boxes done so far, note
the stopping point in the Session log, leave the checkpoint unchecked.

Checkpoints marked **🎮 FEEL GATE** end with a human playtest verdict from Ludo —
Claude prepares the build and tuning knobs, but does not self-certify fun.

## Status

- **Next checkpoint:** CP 1.8 — Tubbu personality (build done) → awaiting the 🎮 FEEL GATE
- **Phase:** 1 — The Toy
- **Last updated:** 2026-06-13 (CP 1.8 build + tests done — idle squash/bob/blink, near-miss flinch+spark, live feel-tuning panel. NOT closed: this is the Milestone-1 🎮 FEEL GATE — Ludo must play the sandbox, tune via the panel, and rule "dodging and shooting is fun bare"; record verdict + tuning notes here. CP 1.7 grid/60fps playtest signed off by Ludo; CP 1.4 swarm-surf playtest still pending. CP 1.5/1.6 waived; CP 1.2 + 1.3 signed off)

---

## Conventions

### Engine & project

- **Godot 4, GDScript.** Pinned version: **Godot 4.6.3 stable** (`v4.6.3.stable.official.7d41c59c4`).
- Renderer: **Forward+** with **HDR 2D enabled** (required for 2D glow/bloom).
- Project layout (scenes and scripts colocated by feature):

  ```
  res://
    core/        # autoloads only: EventBus, RunState, AudioRegistry, SettingsStore, SaveStore
    game/
      player/    # tubbu.tscn/.gd, player_input.gd, dash, hitbox
      weapons/   # base shot, modifier pipeline, bullet_manager
      enemies/   # one folder-per-enemy-type
      boss/
      arena/     # arena shapes, bounds, obstacles
      rooms/     # room defs, wave spawner, doors
      upgrades/  # UpgradeDef resources + apply logic
      fx/        # particles, screenshake, grid, hit-stop, CRT shader
      ui/        # HUD, menus, settings, results
    assets/      # palettes, SkinResource .tres, audio files, fonts, shaders
    tests/       # GUT tests (test_*.gd)
  ```

### Local tooling & commands (this machine — don't re-discover)

Godot 4.6.3 lives at this winget path (use it directly; **don't `where godot` or
filesystem-search for it** — it isn't on `PATH`):

```
C:\Users\mazzu\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\
  Godot_v4.6.3-stable_win64.exe          # windowed — playtests / opening the game
  Godot_v4.6.3-stable_win64_console.exe  # console — headless runs (captures stdout)
```

Canonical commands (run from the repo root; `$G` = the **console** exe above):

```powershell
$G --headless --import                                      # after adding any class_name, before headless runs see it
$G --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit   # run the GUT suite
$G --headless --quit-after 150                              # boot smoke-test (catch _ready/_process runtime errors)
```

Open the game to play: `Godot_v4.6.3-stable_win64.exe --path "<repo root>"` (run
in background), or just **F5** in the editor. If the path ever moves, update it
here once.

### Co-op-ready rules (from day one, non-negotiable)

- **No player singleton.** No autoload references a specific player.
- Player scenes are instanced and addressed by **index** (`player 0`, `player 1`).
- All input flows through a per-player **PlayerInput** object bound to a device
  (kb+m or a specific gamepad), never raw `Input.is_action_pressed` in gameplay code.
- HUD, camera, scoring accept N players even though v1 ships N=1.

### Asset abstraction rules (so real designs can drop in later)

- **No hard-coded colors/shapes in feature code.** Every visual reads from a
  `SkinResource` (Tubbu) or `PaletteResource` (enemies, bullets, arena, grid).
- **All audio through `AudioRegistry`**: gameplay code asks for a sound/music
  *ID*; the registry maps ID → stream. Generated/placeholder audio swaps to
  real assets by editing the registry only.
- All UI styling through one Godot **Theme** resource.
- Tubbu's visuals (body, idle anim, reactions, trail, death burst) live entirely
  in the skin layer — the player scene is logic + a skin slot.

### Testing rules

- **GUT**, tests in `res://tests/`, run headless (command in session protocol).
- Test **pure logic only**: multiplier math, modifier stacking, unlock
  thresholds, room sequencing, pooling, save/load. Never test feel or visuals.
- The whole suite must be green at every checkpoint commit.

### Readability & accessibility rules

- One-hit game: **bullet readability beats every visual effect.** Bloom, CRT,
  particles must never obscure bullets; player hitbox is small relative to the ship.
- Screenshake/flash intensity and CRT are settings-toggleable from the moment
  they exist, not retrofitted.

---

## Phase 0 — Bootstrap

### CP 0.1 — Repo & project init

**Goal:** Versioned, runnable, testable empty project.

- [x] `git init`; Godot `.gitignore` (`.godot/`, exports) and `.gitattributes`
- [x] Create Godot 4 project (Forward+, HDR 2D on); pin version in Conventions above
- [x] Folder layout from Conventions; empty `main.tscn` that boots to a clear-color screen
- [x] Input map: `move_*`, `aim_*`, `dash` for both kb+m and controller, plus per-device action sets groundwork for player-N binding
- [x] Install GUT (v9.6.0). Trivial test skipped per Ludo — first real tests land at CP 0.2
- [x] First commit

**Exit criteria**
- [x] Playtest: project opens in editor and runs to a blank screen without errors (verified headless: boots, no errors)
- [x] Tests: GUT installed; headless command verified at CP 0.2 (no tests authored in 0.1 per Ludo)

### CP 0.2 — Core architecture skeleton 🧠 FABLE

**Goal:** The autoload spine and the player-N pattern exist before any gameplay.

- [x] Autoloads: `EventBus` (typed signals), `SettingsStore` (stub), `AudioRegistry` (stub, ID→stream map), `SaveStore` (stub)
- [x] `PlayerInput` class: device-bound, exposes move vector / aim vector / dash pressed; kb+m and gamepad implementations
- [x] `SkinResource` + `PaletteResource` definitions with one default of each (placeholder neon palette)
- [x] `Game` scene shell: spawns player 0 with a bound `PlayerInput`, inside a placeholder rect arena
- [x] Tests: PlayerInput device binding, AudioRegistry lookup fallback

**Exit criteria**
- [x] Playtest: a placeholder wireframe shape sits in an arena; both kb+m and a controller wiggle it (crude movement OK)
- [x] Tests: green (13/13, 2 suites)

---

## Phase 1 — The Toy (Milestone 1: feel first)

One arena, Tubbu with move/aim-autofire/dash, two enemy types, full juice.
**Milestone exit: dodging and shooting is fun bare.**

### CP 1.1 — Movement & arena feel

**Goal:** Gliding around the arena feels good before anything shoots.

- [x] Tubbu movement: acceleration/friction model, tunable consts in one place; rotation/banking toward movement
- [x] Bounded rect arena with visible neon walls; soft wall collision (slide, no bounce jank)
- [x] Camera: subtle follow/lead, arena-clamped
- [x] Tubbu placeholder body drawn from `SkinResource` (wireframe polygon + engine trail)

**Exit criteria**
- [x] Playtest: 2 minutes of just flying feels responsive on both input types; no wall snags
- [x] Tests: existing suite green (17/17, 3 suites)

### CP 1.2 — Aim & autofire 🧠 FABLE

**Goal:** Right stick = aim **and** trigger; mouse aim + autofire for kb+m.

- [x] Aim from `PlayerInput` (stick deflection past deadzone fires; mouse aims, fire is automatic per design)
- [x] `BulletManager`: pooled player projectiles, single update loop, designed so storage/rendering can later move to MultiMesh without touching gameplay callers
- [x] Base shot: glowing shape projectile from `PaletteResource`, muzzle offset, fire rate const
- [x] Tests: pool acquire/release/exhaustion behavior

**Exit criteria**
- [x] Playtest: streams of glowing shots in aim direction; aiming feels 1:1 on stick and mouse
- [x] Tests: green (33/33, 5 suites)

### CP 1.3 — Dash with i-frames

**Goal:** The survival verb.

- [x] Dash impulse along move (or aim-neutral fallback) with ~1 s cooldown const
- [x] I-frame window during dash; hitbox disabled, visual state clearly distinct (ghost/trail)
- [x] Cooldown feedback (subtle ship glow refill — readable without HUD)
- [x] Tests: cooldown timing, i-frame window state machine

**Exit criteria**
- [x] Playtest: dash-weaving through the empty arena already feels like a game
- [x] Tests: green (41/41, 6 suites)

### CP 1.4 — Enemy 1: contact swarm + death loop

**Goal:** The Geometry Wars surf, and the consequence.

- [x] Chaser enemy: cheap steering toward nearest player, slight flocking jitter; pooled spawning
- [x] Contact kill: player one-hit death (tiny hitbox per Conventions), death burst, instant restart loop (R / button)
- [x] Continuous spawner for sandbox testing (debug panel: spawn rate slider)
- [x] Enemy death: player bullets kill chasers, particles + score-less pop for now

**Exit criteria**
- [ ] Playtest: surfing a 50+ chaser swarm with dash escapes is tense and readable
- [x] Tests: green (57/57, 9 suites — incl. pool reuse across deaths)

### CP 1.5 — Enemy 2: pattern shooter & enemy bullets

**Goal:** The bullet-hell half of the threat mix.

- [x] Enemy bullet support in `BulletManager` (separate pool, distinct palette entry, grazing-friendly sizes)
- [x] Pattern shooter enemy: stationary/slow, fires simple choreographed patterns (radial ring, aimed burst) from a small pattern-definition helper (reused later by boss)
- [x] Enemy bullets respect player hitbox + dash i-frames
- [x] Tests: pattern math (ring angles, aimed direction), bullet TTL/cleanup

**Exit criteria**
- [x] Playtest: weaving a radial pattern while a few chasers pressure you — readable at all times (self-certified; Ludo waived the human playtest for CP 1.5/1.6)
- [x] Tests: green (76/76, 10 suites)

### CP 1.6 — Juice pass 1 (bloom, particles, shake, hit-stop)

**Goal:** Full juice from day one, as the design demands.

- [x] WorldEnvironment glow tuned for neon wireframe look
- [x] Particle library in `game/fx/`: muzzle, enemy pop, player death, dash trail
- [x] Screenshake system (trauma-based, settings-scaled) + brief hit-stop on kills
- [x] All intensities behind `SettingsStore` values

**Exit criteria**
- [x] Playtest: killing things feels crunchy; effects never hide enemy bullets (self-certified; Ludo waived the human playtest. Readability protected structurally — all bullets render at z 5 above every particle, shake is translation-only + kept low + settings-scaled, glow blooms only the overbright neon. Final intensities are Ludo's to tune)
- [x] Tests: green (82/82, 11 suites)

### CP 1.7 — Reactive grid background

**Goal:** The signature Geometry Wars stage presence.

- [x] Spring-mesh or shader grid filling the arena; reacts to player, dashes, deaths, (later: explosions)
- [x] Perf check: grid + 100 enemies + bullets holds 60 fps; record approach notes here if shader vs mesh tradeoffs made
- [x] Grid colors from `PaletteResource`

> **Approach (spring-mesh, not shader):** chose a CPU spring-mass warp grid
> (`WarpGrid`, the canonical GW technique) over a shader. Why: it must react to a
> *variable set of discrete world impulses* (each kill at its spot, every dash,
> each death) — trivial as explosive forces on point masses, awkward as shader
> uniforms; and the integration + force primitives are pure, so they're
> unit-tested (the project's testing rule rewards this; a shader grid is
> untestable). Perf is kept in budget structurally: SoA storage (no nodes), O(n)
> per frame over a coarse lattice (~37×24 ≈ 888 points / ~1.7k edges at 56 px
> spacing), border points pinned, and **one** `draw_multiline_colors` call per
> frame. A debug-panel "warp grid" toggle hides+stops it for a true A/B. If a
> dense future room ever needs it, the lattice coarsens with one const (SPACING).
> The hard 60-fps-in-worst-case sustain is the playtest item below.

**Exit criteria**
- [x] Playtest: grid ripples sell every explosion; 60 fps sustained in worst sandbox case
- [x] Tests: green (94/94, 12 suites)

### CP 1.8 — Tubbu personality & 🎮 FEEL GATE

**Goal:** Tubbu is a character; Milestone 1 verdict.

- [x] Idle animation (squash/blink/bob) in the skin layer
- [x] Near-miss reaction (bullet graze → Tubbu flinch/spark + tiny slowdown shimmer)
- [x] Tuning session: expose key feel consts (speeds, fire rate, dash, shake) in a debug panel; iterate with Ludo
- [ ] **GATE: Ludo plays the sandbox and rules "dodging and shooting is fun bare"**

**Exit criteria**
- [ ] 🎮 Ludo signs off Milestone 1 (record verdict + tuning notes in Session log)
- [x] Tests: green (110/110, 14 suites)

---

## Phase 2 — Run Skeleton (Milestone 2)

Room flow, door choices with reward previews, 6–8 shot modifiers, death/restart loop.
**Milestone exit: a full (boss-less) run is playable end to end.**

### CP 2.1 — Game state machine & run state 🧠 FABLE

**Goal:** Menu → run → death → restart as real states, not a sandbox.

- [ ] Game flow state machine: Boot, Title (stub), InRun, RoomTransition, Death, RunEnd
- [ ] `RunState` (autoload or resource owned by Game): seed, room index, taken upgrades, shields — serializable from the start
- [ ] Death screen stub with restart; sandbox debug panel moves behind a debug flag
- [ ] Tests: state transitions, RunState reset/serialize round-trip

**Exit criteria**
- [ ] Playtest: start run → die → restart cleanly, no leaked nodes (check remote tree)
- [ ] Tests: green

### CP 2.2 — Rooms, waves, clear detection

**Goal:** Combat happens in authored room definitions.

- [ ] `RoomDef` resource: arena shape ref, threat flavor (**pattern** | **swarm-surf**), wave list (enemy type, count, timing)
- [ ] Wave spawner with spawn telegraphs (no off-screen cheap deaths)
- [ ] Room-clear detection → EventBus signal; 4–5 handcrafted RoomDefs to play with
- [ ] Tests: wave sequencing, clear detection edge cases (simultaneous last kills)

**Exit criteria**
- [ ] Playtest: clear a 3-room chain (hardwired order), alternating swarm and pattern flavors
- [ ] Tests: green

### CP 2.3 — Doors with reward previews

**Goal:** The run-level choice loop.

- [ ] On clear, 2–3 doors spawn at arena edge, each previewing its reward (icon + name from UpgradeDef)
- [ ] Door selection → transition (brief room hand-off, no loading hitch) → next RoomDef
- [ ] Linear run sequencer: picks RoomDefs and door reward pools per room index (~12–15 rooms; boss slot empty for now)
- [ ] Tests: sequencer (seeded run determinism, no duplicate door rewards)

**Exit criteria**
- [ ] Playtest: clear → walk into a previewed door → next room; choice feels deliberate
- [ ] Tests: green

### CP 2.4 — Upgrade pipeline core 🧠 FABLE

**Goal:** The stat/modifier architecture every later upgrade rides on.

- [ ] `UpgradeDef` resource: id, name, icon hook, rarity/weight, apply spec
- [ ] Weapon stat pipeline: base shot stats → ordered modifier stack → resolved shot config; `BulletManager` consumes the result
- [ ] Stat-level upgrades work end to end as proof (fire rate, shot speed, damage)
- [ ] Tests: stacking math, ordering invariance where required, pipeline resolve

**Exit criteria**
- [ ] Playtest: pick fire-rate door, visibly shoot faster next room
- [ ] Tests: green

### CP 2.5 — Shot modifiers batch 1: spread, pierce, ricochet

**Goal:** Visible transformations begin.

- [ ] Spread (multi-shot fan, stacks widen/add), pierce (N pass-throughs), ricochet (wall bounce with remaining-bounce count)
- [ ] Each visibly distinct (per design: transformation must be dramatic) — palette/shape variation per modifier
- [ ] Tests: per-modifier behavior + cross-stacking (spread×pierce×ricochet)

**Exit criteria**
- [ ] Playtest: all three stack together and look obviously different from base shot
- [ ] Tests: green

### CP 2.6 — Shot modifiers batch 2: homing, chain, orbitals

**Goal:** The exotic half.

- [ ] Homing (steering cap so dodging skill still matters for enemies), chain (arc to nearest on hit), orbitals (persistent shapes circling Tubbu, damage on contact)
- [ ] Perf check: heavy stacks at swarm density hold 60 fps
- [ ] Tests: chain target selection, orbital damage ticks, homing steering clamp

**Exit criteria**
- [ ] Playtest: a 5-modifier build feels absurd and readable; 60 fps holds
- [ ] Tests: green

### CP 2.7 — Shields, hits, dash upgrades

**Goal:** The survivability economy from the design's hard-edge mitigations.

- [ ] Shield charges: gained via UpgradeDefs (reasonably common per design), HUD pips, recharge rules
- [ ] Getting hit with shield: lose charge, **brief post-hit invulnerability**, clear audiovisual feedback; without shield: death
- [ ] Multiplier-reset hook stubbed (fires event; scoring lands in Phase 3)
- [ ] 2–3 dash/ability upgrades (cooldown reduction, dash leaves damage trail, longer i-frames)
- [ ] Tests: shield consume/recharge, invuln window, dash upgrade application

**Exit criteria**
- [ ] Playtest: tanking a hit on shield reads instantly and never double-kills during invuln
- [ ] Tests: green

### CP 2.8 — Full run loop & difficulty scaffold

**Goal:** Milestone 2 closes: a complete run exists.

- [ ] Fill the sequencer to ~12–15 rooms with a difficulty curve scaffold (wave size/speed scaling per room index)
- [ ] Pattern/swarm interleave rhythm per design (variety axis #1); placeholder "victory" final room
- [ ] Death → run summary stub (rooms cleared, upgrades taken) → restart
- [ ] Run length sanity: a full clear lands near ~20 min
- [ ] Tests: full-run sequencer simulation (no crashes, curve monotonicity where intended)

**Exit criteria**
- [ ] Playtest: one sitting, full run start → final room, death/restart loop solid
- [ ] Tests: green

---

## Phase 3 — The Climb (Milestone 3)

Boss, score + multiplier, skins + unlocks, enemy roster to ~6–8, arena variety.
**Milestone exit: a real run with a real ending, worth replaying for score.**

### CP 3.1 — Scoring & multiplier

**Goal:** The moment-to-moment risk/reward engine.

- [ ] Kill score × multiplier; multiplier builds on kills, **resets on any hit** (hooks from CP 2.7)
- [ ] HUD: score + multiplier with milestone flourishes (×10, ×25…)
- [ ] Multiplier-greed feedback: near-miss grazes nudge multiplier or charge meter (tunable; ties to Tubbu reactions)
- [ ] Tests: multiplier build/reset/decay math, score accumulation, per-player attribution (player-N rule)

**Exit criteria**
- [ ] Playtest: losing a ×30 multiplier hurts; chasing it changes how you play
- [ ] Tests: green

### CP 3.2 — Enemy roster batch 1 (+2 types)

**Goal:** Roster toward 6–8; new behaviors, not reskins. Suggested: **Weaver** (sine-strafes, aimed bursts), **Splitter** (splits into smaller chasers on death — swarm rooms get a GW classic).

- [ ] Two new enemy types, palette-driven visuals, pooled, spawn telegraphs
- [ ] Slot into RoomDef wave tables; new RoomDefs that feature them
- [ ] Tests: splitter spawn logic, any new pattern math

**Exit criteria**
- [ ] Playtest: each new type forces a recognizably different response
- [ ] Tests: green

### CP 3.3 — Enemy roster batch 2 (+2 types)

**Goal:** Same as 3.2. Suggested: **Sniper** (long telegraph, fast lance — punishes camping), **Spinner** (rotating spiral emitter — moving pattern terrain).

- [ ] Two more types, wave-table integration, featured RoomDefs
- [ ] Roster pass: confirm 6–8 total with distinct silhouettes at a glance
- [ ] Tests: new behavior logic

**Exit criteria**
- [ ] Playtest: late-run mixed waves stay readable (silhouette + palette check)
- [ ] Tests: green

### CP 3.4 — Arena shapes & obstacle rooms

**Goal:** Variety axis #2.

- [ ] Circle and oval arenas (bounds, camera clamp, grid fill, wall visuals)
- [ ] Obstacle rooms as spice: a few static neon obstacles; ricochet interacts deliciously; spawner respects obstacles
- [ ] Sequencer mixes shapes; obstacle rooms occasional per design
- [ ] Tests: bounds math for each shape, spawn-point validity with obstacles

**Exit criteria**
- [ ] Playtest: each shape changes movement flow; no collision jank in corners/curves
- [ ] Tests: green

### CP 3.5 — Boss part 1: core & first patterns 🧠 FABLE

**Goal:** The Touhou setpiece skeleton.

- [ ] Boss scene: giant slow/stationary core, phase state machine, health bar, phase-transition spectacle
- [ ] Pattern system grown from CP 1.5 helper: 2 dense choreographed patterns (e.g. rotating walls with gaps, aimed-burst interleave)
- [ ] Perf: dense pattern + grid + juice at 60 fps — if node bullets choke, this is the planned moment to move `BulletManager` storage to MultiMesh (interface already isolates it)
- [ ] Boss room wired as final sequencer room
- [ ] Tests: phase transitions, pattern math

**Exit criteria**
- [ ] Playtest: phase 1–2 fight is legible, dodgeable, alive at 60 fps
- [ ] Tests: green

### CP 3.6 — Boss part 2: full choreography & victory

**Goal:** Finish the fight.

- [ ] 3–4 more patterns across phases, escalating; brief safe beats between phases for breath
- [ ] Boss death spectacle (grid shockwave, slow-mo, particle bloom-out) + victory/results screen (score, time, build recap)
- [ ] Full-run balance touch: rooms 12–15 → boss difficulty continuity
- [ ] Tests: full phase sequence simulation

**Exit criteria**
- [ ] Playtest: full run into boss kill feels like a finale; victory screen lands
- [ ] Tests: green

### CP 3.7 — Skins, unlocks & feats

**Goal:** The cosmetics-only meta — where asset abstraction pays off.

- [ ] `SkinResource` pipeline proven: 3–4 generated Tubbu skins (shape/palette/trail/idle variants) swap live with zero feature-code changes
- [ ] Unlock system: score thresholds + feats (e.g. shieldless run, ×50 multiplier, no-dash boss) defined as data
- [ ] Skin select on title/pre-run screen; locked skins show their unlock condition
- [ ] Per-skin high score tracked in `RunState`→`SaveStore` hand-off
- [ ] Tests: threshold/feat evaluation, per-skin score isolation

**Exit criteria**
- [ ] Playtest: unlock a skin via a feat, switch to it, run with it
- [ ] Tests: green

### CP 3.8 — Persistence & 🎮 FEEL GATE

**Goal:** Progress survives restarts; Milestone 3 verdict.

- [ ] `SaveStore` real: scores, unlocks, settings to `user://` (versioned schema, corrupt-file fallback)
- [ ] Balance pass with Ludo: difficulty curve, shield availability in door pools, modifier rarity weights
- [ ] **GATE: Ludo plays full runs and rules the loop "worth replaying for score"**
- [ ] Tests: save/load round-trip, schema-version migration stub

**Exit criteria**
- [ ] 🎮 Ludo signs off Milestone 3 (verdict + balance notes in Session log)
- [ ] Tests: green

---

## Phase 4 — The Wrap (Milestone 4)

CRT layer, audio, menus/settings, input glyphs, high-score board.
**Milestone exit: shippable-to-friends build.**

### CP 4.1 — CRT post layer

**Goal:** The arcade retro wrapper — subtle, toggleable, readability-safe.

- [ ] Full-screen CRT shader: curvature, scanlines, slight vignette/chromatic touch; intensity params in `SettingsStore`
- [ ] Individually toggleable per design; default subtle
- [ ] **Readability audit: densest boss pattern with CRT on — bullets must remain unambiguous** (design calls this non-negotiable)
- [ ] Tests: suite green (shader untested by design)

**Exit criteria**
- [ ] Playtest: CRT on/off toggle live; boss pattern readable with it on
- [ ] Tests: green

### CP 4.2 — SFX pass

**Goal:** Modern punchy SFX through the registry.

- [ ] Audio buses (Master/Music/SFX) wired to settings sliders
- [ ] Generate/source SFX set (jsfxr/ChipTone-style + free packs): fire, kill, dash, shield hit, death, door, multiplier milestones, boss phases — all via `AudioRegistry` IDs
- [ ] Polish: pitch variance on rapid sounds, voice limiting so swarm kills don't clip
- [ ] Tests: registry completeness (every gameplay event ID resolves)

**Exit criteria**
- [ ] Playtest: eyes-closed kill streak still feels good; mix survives swarm chaos
- [ ] Tests: green

### CP 4.3 — Music

**Goal:** Chiptune soundtrack via the same swap-friendly layer.

- [ ] Music manager: title / run (intensity-aware or per-room-band) / boss tracks, crossfades, death sting
- [ ] Source free/licensed chiptune tracks as placeholders-or-keepers; registry IDs so Ludo's later picks drop in cleanly (per asset answer)
- [ ] Tests: suite green

**Exit criteria**
- [ ] Playtest: title → run → boss → death musical arc works
- [ ] Tests: green

### CP 4.4 — Menus & settings

**Goal:** Frame the game like a finished thing.

- [ ] Title screen (Tubbu idle showcase, skin select entry), pause menu, settings (audio sliders, CRT toggle/intensity, screenshake/flash, fullscreen)
- [ ] Death/victory screens to final quality; all UI through the single Theme
- [ ] Controller-navigable everywhere (no mouse-only traps)
- [ ] Tests: settings persistence round-trip

**Exit criteria**
- [ ] Playtest: full menu loop on controller only, then kb+m only
- [ ] Tests: green

### CP 4.5 — Input glyphs & device handling

**Goal:** Both input types as true first-class citizens.

- [ ] Glyph system: prompts swap kb+m/controller automatically on last-used device
- [ ] Hot-swap mid-run safe (pause on controller disconnect)
- [ ] Co-op-readiness audit: confirm player-N + per-device binding rules held all project (fix any drift); document adding player 1 in a `COOP.md` note
- [ ] Tests: device-binding logic, glyph resolution

**Exit criteria**
- [ ] Playtest: unplug/replug controller mid-run; prompts always match device
- [ ] Tests: green

### CP 4.6 — High-score board, export & 🎮 SHIP GATE

**Goal:** Done means friends can play it.

- [ ] Per-skin high-score board UI (scores, feats earned) from `SaveStore`
- [ ] Windows export preset; exported build smoke-tested on a clean machine/profile
- [ ] Final feel pass with Ludo; fix-list triage (ship blockers vs post-v1)
- [ ] **GATE: Ludo plays the exported build start to finish and calls it v1**
- [ ] Tag `v1.0` in git

**Exit criteria**
- [ ] 🎮 Ludo signs off v1 on the exported build
- [ ] Tests: green

---

## Backlog (explicitly post-v1)

- Local co-op player 2 (architecture is ready by design; see `COOP.md` after CP 4.5)
- More skins/feats, more modifiers, alternate bosses, daily-seed runs
- Ludo's own art/audio replacing generated assets (drop-in via SkinResource/AudioRegistry)

## Session log

<!-- Newest first. One line: date — checkpoint(s) touched — outcome/notes. -->
- 2026-06-13 — CP 1.8 build done on Opus (routine cp). Tubbu personality + the feel-tuning panel; build complete, the 🎮 FEEL GATE itself (Ludo's "fun bare" verdict) is still open. Load-bearing decisions: (1) Same pure/visual split the project uses everywhere — two RefCounted, owner-ticked, unit-tested helpers hold the curves, Tubbu applies them. `IdleAnimation` (game/player/): squash/stretch breathe + world-space bob (both sinusoids of an accumulated clock) + a periodic eye blink (openness 1→0→1 over BLINK_DURATION at the start of each blink_interval). `NearMissReaction` (game/player/): a flinch clock with a COOLDOWN gate so a wake of fire *pulses* the flinch instead of strobing it, and a `closeness` 0..1 (1 at the kill edge) that scales it. (2) Idle params live in the SkinResource (idle_bob/breathe/cycle, blink_interval, eye_offset/radius) so each Tubbu variant emotes differently — the asset rule's "idle anim lives in the skin layer" = the *data* is in the skin, Tubbu is the logic that draws it (exactly like body_points/colors). Defaults give the Classic skin a single forward eye. (3) Idle bob/breathe FADE OUT between IDLE_SPEED_FULL(30)→IDLE_SPEED_NONE(160) px/s (an "idle factor" off velocity), so the personality only plays when calm and never fights the flight feel; the blink runs at any speed (subtle). Applied in _draw via ONE draw_set_transform (scale = (1+b,1-b), bob counter-rotated by -rotation so it stays world-vertical regardless of facing); the eye is a filled ellipse drawn under that same transform so it breathes/bobs with the body. Tubbu now queue_redraw()s every frame in play (tiny polyline + eye). (4) Near-miss = a graze band (lethal 10 < dist ≤ GRAZE_RADIUS 34) over a NEW read-only `BulletManager.nearest_enemy_bullet(point)` (enemy band only — your own shots don't graze). On a fresh graze: a one-shot spark Burst at the orb in the threat colour + a body brightness spike (FLINCH_BRIGHTNESS, settings-scaled by flash_intensity) + a scale pop (FLINCH_SCALE), composed in a new `_update_body_visual` alongside the dash ghost/cooldown-refill brightness. DESIGN's "tiny slowdown shimmer" is rendered as this visual flinch, NOT a real time-slow — slowing the player's own reaction window on a near-miss is unfair/unreadable in a one-hit game; left a note that an explicit micro-slowmo is a knob if Ludo wants it. Ordering is safe: BulletManager.step (tree order) → Tubbu near-miss check (sees fresh orbs, skips anything ≤ lethal) → PatternSpawner kill pass, so no spurious graze on the frame of a death. (5) Feel-tuning panel: the key consts became live vars seeded from the consts (kept as defaults so the existing tests, which reference the UPPERCASE consts, stay green) — Tubbu.max_speed/friction, Weapon.fire_rate, DashAbility.dash_speed/cooldown(+duration/i_frames). DebugPanel got six sliders (move speed, friction, fire rate, dash speed, dash cooldown, shake→SettingsStore.screenshake_intensity) writing to ALL players (co-op-safe). Key gotcha solved: revive() used to `= Weapon.new()/DashAbility.new()`, which would WIPE Ludo's live tuning every death — added reset() to both (clears only the clocks, keeps the instance + tuning), and revive now calls reset(); the panel holds the stable Weapon/DashAbility instances via new Tubbu.weapon()/dash() accessors, so a tweak survives the restart loop. Tests 110/110 (+16: idle 7, near-miss 6, nearest_enemy_bullet 3). Import pass run (new class_names) + boot clean over 250 frames (idle draw transform + blink + near-miss path + the panel building & firing all six knob lambdas). Also: Ludo signed off the CP 1.7 grid/60fps playtest (checked its box).
- 2026-06-13 — CP 1.7 build done on Opus (routine cp). Reactive warp-grid backdrop — the GW stage presence. Load-bearing decisions: (1) Spring-mass mesh on the CPU, NOT a shader (decision recorded inline above the checkpoint). Same split the project uses everywhere: `WarpGrid` (game/fx/, RefCounted, pure & unit-tested) is the whole sim; `GridBackground` (Node2D) owns the world wiring + one draw pass. Reason for mesh-over-shader: it has to react to a *variable set of discrete world impulses* (each kill at its position, every dash, each death) — natural as explosive forces on point masses, awkward as shader uniforms — AND the integration + force primitives are pure logic the testing rule wants tested (a shader grid is untestable). (2) WarpGrid is SoA (parallel Packed*Arrays: home/pos/vel/inv_mass + flat edge lists), like the BulletManager pool — allocation-free per frame, flat-indexable, cheap to walk. Border points pinned (inv_mass 0) so the lattice never tears off the arena walls; built FLUSH to bounds (step fitted so corners land on the walls). Model = Hoffman/Shape-Blaster warp grid: pull-only neighbour springs (stiffness 0.28, damp 0.06) propagate ripples, a weak per-point home anchor (0.012) + velocity damping (0.95/frame) guarantee it settles flat. (3) Step is FRAME-BASED (one step == one 60fps frame), not dt-scaled — stiff explicit springs blow up under variable dt and a background ripple slowing with framerate is invisible; GridBackground calls step() once per _process. Impulses (apply_explosive/implosive/directed) add straight to velocity = an instantaneous kick fired between frames. (4) Reactions: per-frame DIRECTED force along each alive player's velocity = the wake (self-limiting, no runaway, "reacts to player/movement"); EXPLOSIVE on the dash rising edge (polled via new Tubbu.is_dashing(); DASH_FORCE 15/r200), on EventBus.enemy_killed at the pop (KILL 6/r150), and on player_died at the ship — read off players[index] since player_died carries only the index per the co-op rule (DEATH 28/r340). Game.reset() flattens the mesh on restart so the revive starts calm. (5) Render: ONE draw_multiline_colors/frame into preallocated buffers (NOTE: this engine wants one colour PER SEGMENT, not per point — points = 2×colours, else it errors). Per-point brightness from displacement/home; each segment takes the brighter endpoint, so a ripple front lights up and crosses 1.0 into the HDR bloom at a peak = "ripples sell explosions." Drawn at z -10 behind everything — readability rule unaffected (bullets still z 5, grid is thin/dim backdrop). grid_color from PaletteResource (asset rule). DebugPanel got a "warp grid" toggle (hide + set_process(false)) for a true A/B perf check. Gotchas hit & fixed during boot: `_was_dashing` was sized in _ready from players.size() but Game shares its _players array BEFORE spawning into it (was empty) → size it lazily in _drive_players; and the per-point→per-segment colour-count mismatch above. Settling fix: the velocity-snap was freezing nodes ~1.5px off home (weak anchor → sub-threshold velocity) → now snaps to rest only when BOTH slow AND near home, else keeps creeping in (test_ripple_settles_back_flat). Tests 94/94 (+13 WarpGrid: build/pinning, the 3 force primitives + falloff + radius cutoff, ripple propagation through the springs, border-pinned-under-blast, settle-back-flat, reset). Boot clean over 220 frames (sim + draw + glow + kill/death/dash ripple paths). Checkpoint NOT closed: Ludo's "ripples sell every explosion + 60fps worst-case" playtest pending (next CP 1.8 is the Milestone-1 🎮 FEEL GATE anyway).
- 2026-06-13 — CP 1.6 build done on Opus (routine cp), same Ludo-waived-playtest run as CP 1.5. Full juice-from-day-one pass. Load-bearing decisions: (1) Screenshake is the GDC trauma model split across two objects — `ScreenShake` (game/fx/, RefCounted, pure & unit-tested) holds only the 0..1 trauma curve (add clamps to 1, linear DECAY 3.0/s, shake()=trauma² so small bumps barely move and swarm kills don't pile into a bullet-hiding rattle); `ArenaCamera` owns the pixel mapping + sources. TRANSLATION-ONLY via Camera2D.offset (NOT global_position, so it never fights the follow/limit clamp) — no roll, because ignore_rotation=true would silently eat camera.rotation anyway AND roll smears bullets worse than it's worth in a one-hit game. SHAKE_MAX_OFFSET 22px, KILL_TRAUMA 0.08 (small), DEATH_TRAUMA 0.8; scaled by SettingsStore.screenshake_intensity. (2) `HitStop` (game/fx/, Node under Game): drops Engine.time_scale to 0.02 (not 0 — keeps frames/audio ticking so it can thaw) on REAL time via Time.get_ticks_usec (immune to the scaled clock it just set; _process delta is useless while frozen). Kill taps are COOLDOWN-gated (0.13s) so a 50-kill swarm frame doesn't strobe; player death is a separate longer freeze (0.18s). Overlaps EXTEND (maxi), never cut short. Gated by new SettingsStore.hitstop_intensity (0=off). _exit_tree restores time_scale (CP 2.1 transitions). NOT unit-tested on purpose (global Engine state + real time → would bleed across the suite); boot-verified instead. (3) New `EventBus.enemy_killed(at)` — first multi-listener gameplay event (shake + hitstop now, score/audio later); emitted in chaser.die() + pattern_shooter.die(). Death reuses existing player_died. Camera + HitStop both subscribe; no autoload→autoload coupling. (4) Particle library completed in game/fx/: `Fx` (RefCounted builder lib) make_muzzle (tight forward spray, rides exact aim at the muzzle point — emitting=firing) + make_dash_trail (slow radial afterimage puff, emitting=is_dashing); both world-space (local_coords off, top_level). Burst (CP 1.4) stays the one-shot pop for enemy/player death. Tubbu now gets PALETTE injected (muzzle = palette.player_bullet_color so it reads as the gun; dash = skin.trail_color) and builds the two emitters in _ready ONLY when their color source is present, so headless logic tests (no skin/palette, often out-of-tree) stay node-light and untouched. Emitters killed on death. (5) Glow: WorldEnvironment built in Game._setup_glow — BG_CANVAS, SCREEN blend, glow_hdr_threshold 1.0 so ONLY the overbright (>1.0) neon palette/skin colors bloom (dark bg + UI stay crisp), levels 1-4. Kept a constant (base aesthetic, not a player-facing intensity); Ludo tunes the look. KEY readability consequence carried from CP 1.5: every bullet draws at z 5 ABOVE all particles, so muzzle/dash/pop FX can never hide an enemy orb — the design's non-negotiable. Tests 82/82 (+6 ScreenShake trauma math). Boot clean (glow + the death hit-stop/time-scale cycle + emitters all ran headless).
- 2026-06-13 — CP 1.5 build done on Opus (routine cp). Ludo waived the human playtests for CP 1.5 + 1.6 ("do cp 1.5, then cp 1.6, no need for human playtest") — self-certified via tests + headless boot. Load-bearing decisions: (1) BulletManager refactored to a private inner `_Pool` (SoA + free list + recycle-the-oldest), instanced TWICE — player band + enemy band, separate capacity/seq so neither starves the other, each maps 1:1 to a future MultiMesh (CP 3.5 contract intact). The narrow facade (spawn_*/collide_*/clear/counts) is unchanged, so all CP 1.2/1.4 tests stayed green through the refactor. Enemy bullets carry a full VELOCITY (shooter owns the speed, patterns vary it) vs player bullets' direction+const. (2) `collide_enemy_bullets_with_players(players, radius)` routes every kill through Tubbu.try_kill — dash i-frames honored at the ONE gate (CP 1.3/1.4 rule), never re-checked. Consume-on-kill, PASS-THROUGH on i-frames (you dashed through it = bullet survives). Lethal radius = Tubbu.HIT_RADIUS(6) + ENEMY_BULLET_RADIUS(4) = 10; visual orb disc 6.5 so bullets clip the ~16px body wireframe before they're lethal = the graze window. (3) Bullets now draw ABOVE ships (bullet_manager.z_index=5) — an incoming enemy orb must never hide under your own sprite (one-hit readability rule; reverses the CP 1.2 ship-over-bullets order, justified). Enemy orbs render as soft-halo + solid core, deliberately unlike the player's fast streaks. (4) `BulletPattern` (game/weapons/, static pure helper, RefCounted): ring(count, phase) + aimed_burst(aim, count, spread) → unit dirs; the boss (CP 3.5) grows its choreography from these. Y-down: ring(4,0) = RIGHT/DOWN/LEFT/UP. zero aim or count<=0 → empty (caller skips). (5) PatternShooter (game/enemies/pattern_shooter/, pooled like Chaser, stationary hexagon, MAX_HP 8 so it's a pattern not a snipe, cosmetic spin): layers a slow rotating ring (RING_COUNT 10, 1.5s, phase-step 0.32 rad spiral, 230 px/s) + aimed burst (3 shots, 0.42 rad fan, 2.5s, 320 px/s) — slow & visible per the hard-edge mitigation; timers start at a random offset so a crowd desyncs. take_hit()→bool gates the kill (one bullet = 1 dmg/frame via the bullet-major pass). (6) PatternSpawner (game/enemies/, parallel to SandboxSpawner): keeps SHOOTER_COUNT 2 alive (RESPAWN_DELAY 2s), drives BOTH bullet passes, processes AFTER players so it reads fresh ship+bullet positions. It hosts the single global enemy-bullet→player pass for now; CP 2.1's run owner likely absorbs it. Game wires it + clears both bands on restart (no stray orb kills the revive). DebugPanel gained a pattern-shooter toggle + shooter/enemy-bullet readouts. Tests 76/76 (+19: bullet_pattern 9, enemy band 6, collide_enemy 4 incl. the i-frame pass-through). Boot clean (shooters fired + the kill path ran headless).
- 2026-06-13 — CP 1.4 build done on Fable (routine cp; bigger model is fine). Ludo signed off the CP 1.2 + 1.3 playtests himself first ("test done" commits) — both checkpoints closed. Load-bearing decisions: (1) Enemies are pooled NODES, not SoA — the roster grows folder-per-type with distinct behaviors, so `EnemyPool` (game/enemies/, RefCounted, injected factory + capacity, lazy build, never frees) manages identity only; on exhaustion acquire() = null and the spawn is SKIPPED — deliberate opposite of BulletManager's oldest-recycle (teleporting a live enemy under the player = unfair one-hit death; dropping a spawn costs nothing). (2) Bullet↔enemy collision is ONE bullet-major pass `BulletManager.collide_player_bullets(targets, radius)` so the SoA stays sealed (callers get nodes back, never slots); one bullet kills ≤1 target (pierce is CP 2.5), a hit target leaves the working set (corpse soaks no shots); Chaser.BULLET_HIT_RADIUS 12 must stay >~10 or 1150 px/s bullets tunnel between 60 fps frames. (3) Kill gate centralized in `Tubbu.try_kill()` (dead/i-frames → false) — every future killer (CP 1.5 enemy bullets) calls it, so the dash rule can't be forgotten at a call site; HIT_RADIUS 6 vs ~16 px body (hard-edge mitigation); revive(at) = fresh ship + cleared trail. (4) Input ownership moved to Game: it binds devices, so it calls every PlayerInput.update() (parents process before children → fresh latches for all; a dead non-ticking ship still latches its restart edge). New `restart` action (R / pad Start) read via PlayerInput (co-op rule held); restart only armed by death; wipes bullets+chasers, revives at center. Chaser (game/enemies/chaser/): accel-steered toward nearest alive player (static pure helper, tested) with per-instance speed roll 0.85–1.1 + sinusoidal heading wobble = cheap swarm read; palette.enemy_color double-line diamond. Burst (game/fx/, CPUParticles2D one-shot, self-frees; color injected — skin for player death, palette for enemy pop; CP 1.6 replaces). SandboxSpawner (cap 200, min spawn dist 380 rejection-sampled — telegraphs are CP 2.2, spawning frozen while nobody's alive) + DebugPanel (game/ui/, CanvasLayer slider; CP 2.1 puts it behind a debug flag). Gotcha: GUT `autofree()` returns Variant — `:=` can't infer, annotate the type. Tests 57/57 (+16: pool 5, tubbu kill/revive 4, bm collision 4, chaser targeting 3). Boot clean. Checkpoint NOT closed: Ludo's 50+ swarm-surf playtest pending.
- 2026-06-12 — CP 1.3 build done (same Fable session as CP 1.2; 1.3 isn't 🧠 but running a routine cp on the bigger model is fine — the policy only forbids the reverse). `DashAbility` (game/player/, RefCounted, owner-ticked like PlayerInput/Weapon): DASH_SPEED 1500 / DASH_DURATION 0.16 / I_FRAMES 0.16 / COOLDOWN 1.0 from dash start; i-frames on their OWN clock so CP 2.7's longer-i-frames upgrade is a number change; `is_invulnerable()` exposed on Tubbu — this IS the "hitbox disabled" mechanism, CP 1.4's contact kill must check it (no hitbox node exists yet). Dash direction = move vector, else last nonzero move dir (aim-neutral fallback — never the gun direction; init +X = spawn facing). During dash control is suspended (velocity = dash vector each frame; wall slide still applies → no snag), exit keeps the speed and friction reclaims it (glide out). Visuals via self_modulate only (scales the skin's own colors, asset rule intact; trail is a separate canvas item so it stays vivid): ghost body alpha 0.4 while dashing, body brightness 0.55→1.0 refilling with cooldown = the no-HUD readiness cue. Tests 41/41 (+8 dash: cooldown timing, i-frame window, fraction refill). Boot clean. Checkpoint NOT closed: Ludo's dash-weave playtest pending (plus the CP 1.2 aim playtest).
- 2026-06-12 — CP 1.2 build done on Fable (🧠 cp). Load-bearing decisions: (1) `PlayerInput.get_aim_vector(shooter: Node2D)` — mouse only becomes a direction relative to a world anchor, so the ship passes itself; kb+m aim is never zero (cursor always somewhere) and a degenerate on-ship cursor holds the last aim; gamepad path = deadzoned right stick, ZERO = not aiming. Trigger policy is explicit in `is_fire_held(aim)` (stick past deadzone fires; kb+m autofire always on), not implicit in aim==zero. (2) `BulletManager` (game/weapons/): bullets are NOT nodes — slot-stable parallel arrays (SoA) behind a narrow spawn/clear/count API so the CP 3.5 MultiMesh move is internal (stable slot → instance index); free-list pool, exhaustion recycles the OLDEST bullet (gun never stutters); wall-bounds cull + TTL backstop; `owner_index` per bullet for co-op/scoring attribution; one `_draw` pass (streak + core, palette color). (3) `Weapon` RefCounted in game/weapons/ (FIRE_RATE 9/s, MUZZLE_OFFSET 22): cooldown accumulator — instant first shot, no banked shots, multi-shot catch-up on hitch frames; the exact seam CP 2.4's stat pipeline replaces. Tubbu: facing now follows aim (travel-dir fallback for neutral pad stick); bullets fly the EXACT aim vector — the nose slew is cosmetic, so aiming is 1:1. Tests 33/33 (+16: pool 9, weapon 5, trigger policy 2). Boot clean. Gotcha: CanvasItem has no `global_position` — type world-anchored params as Node2D. Checkpoint NOT closed: Ludo's stick+mouse aim playtest pending.
- 2026-06-12 — CP 1.1 build done on Opus (not a 🧠 FABLE cp): real movement on Tubbu (accel/friction via move_toward, MAX_SPEED 560 / ACCEL 4200 / FRICTION 3000; heading slews to travel dir, banking via skew from turn rate — all tuning consts in one block, CP 1.8 lifts them to a debug panel). New `game/arena/`: Arena (script-only Node2D, centred rect bounds at world origin, double-line neon walls from palette, static pure `slide_inside` = per-axis clamp + into-wall velocity cancel = slide-no-snag) and ArenaCamera (script-only Camera2D, smoothed follow + velocity-lead by LEAD_TIME, arena-clamped via limits; owned by Game not the player, co-op note left). Engine trail = top_level Line2D (z -1) fed rear-of-ship world points, gradient+width taper from skin.trail_color (collapses to a dot when idle). Game wires arena+camera+player; arena default size 2000×1300 (larger than the 1280×720 view so follow/lead reads). Tests 17/17 (added test_arena: inside/slide/corner/radius). Headless 150-frame boot clean (no errors). Checkpoint NOT closed: Ludo's 2-min kb+m+controller flying playtest pending (also closes the deferred CP 0.2 wiggle test). Next CP 1.2 is 🧠 FABLE — needs `/model fable`.
- 2026-06-12 — CP 0.2 build finished on Fable: PlayerInput in game/player/ (kb+m via InputMap actions, gamepad via raw per-device axes; radial deadzone w/ rescale; dash edge latch via update()); input_actions.gd moved core/→game/player/ (core/ is autoloads-only); SkinResource (game/player/) + PaletteResource (game/fx/) + default .tres in assets/skins|palettes (overbright neon for HDR bloom); Game shell draws rect arena from palette, spawns Tubbu by index w/ bound kb+m PlayerInput (pad drives it too via device -1 action events — fine for v1 N=1); main boots into Game until CP 2.1. Tests 13/13 green. Gotcha: new class_name needs a `--headless --import` pass before headless runs see it. Checkpoint NOT closed: Ludo's kb+m+controller wiggle playtest pending.
- 2026-06-12 — CP 0.2 started on Fable per model policy (earlier Opus drafts discarded/redone). Autoload spine done: EventBus (gameplay events only, player_index rule), SettingsStore (own `changed` signal — no autoload→autoload deps), AudioRegistry (ID→stream, warn+fallback), SaveStore (versioned schema stub); registered + headless-verified. Stopped after step 1 per Ludo; next: PlayerInput (note: belongs in game/player/ per layout, not core/).
- 2026-06-12 — CP 0.1 done: Godot 4.6.3 pinned, Forward+/HDR 2D, folder layout, input map verified headless, GUT v9.6.0 installed (no tests in 0.1 per Ludo), git init + first commit.
- 2026-06-12 — Plan created from DESIGN.md (no code yet). Next: CP 0.1.
