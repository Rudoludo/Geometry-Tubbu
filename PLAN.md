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

- **Next checkpoint:** CP 1.4 — Enemy 1: contact swarm + death loop
- **Phase:** 1 — The Toy
- **Last updated:** 2026-06-12 (CP 1.2 + 1.3 builds + tests done; awaiting Ludo's aim/autofire and dash playtests)

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
- [ ] Playtest: streams of glowing shots in aim direction; aiming feels 1:1 on stick and mouse
- [x] Tests: green (33/33, 5 suites)

### CP 1.3 — Dash with i-frames

**Goal:** The survival verb.

- [x] Dash impulse along move (or aim-neutral fallback) with ~1 s cooldown const
- [x] I-frame window during dash; hitbox disabled, visual state clearly distinct (ghost/trail)
- [x] Cooldown feedback (subtle ship glow refill — readable without HUD)
- [x] Tests: cooldown timing, i-frame window state machine

**Exit criteria**
- [ ] Playtest: dash-weaving through the empty arena already feels like a game
- [x] Tests: green (41/41, 6 suites)

### CP 1.4 — Enemy 1: contact swarm + death loop

**Goal:** The Geometry Wars surf, and the consequence.

- [ ] Chaser enemy: cheap steering toward nearest player, slight flocking jitter; pooled spawning
- [ ] Contact kill: player one-hit death (tiny hitbox per Conventions), death burst, instant restart loop (R / button)
- [ ] Continuous spawner for sandbox testing (debug panel: spawn rate slider)
- [ ] Enemy death: player bullets kill chasers, particles + score-less pop for now

**Exit criteria**
- [ ] Playtest: surfing a 50+ chaser swarm with dash escapes is tense and readable
- [ ] Tests: green (pool reuse across deaths)

### CP 1.5 — Enemy 2: pattern shooter & enemy bullets

**Goal:** The bullet-hell half of the threat mix.

- [ ] Enemy bullet support in `BulletManager` (separate pool, distinct palette entry, grazing-friendly sizes)
- [ ] Pattern shooter enemy: stationary/slow, fires simple choreographed patterns (radial ring, aimed burst) from a small pattern-definition helper (reused later by boss)
- [ ] Enemy bullets respect player hitbox + dash i-frames
- [ ] Tests: pattern math (ring angles, aimed direction), bullet TTL/cleanup

**Exit criteria**
- [ ] Playtest: weaving a radial pattern while a few chasers pressure you — readable at all times
- [ ] Tests: green

### CP 1.6 — Juice pass 1 (bloom, particles, shake, hit-stop)

**Goal:** Full juice from day one, as the design demands.

- [ ] WorldEnvironment glow tuned for neon wireframe look
- [ ] Particle library in `game/fx/`: muzzle, enemy pop, player death, dash trail
- [ ] Screenshake system (trauma-based, settings-scaled) + brief hit-stop on kills
- [ ] All intensities behind `SettingsStore` values

**Exit criteria**
- [ ] Playtest: killing things feels crunchy; effects never hide enemy bullets
- [ ] Tests: green

### CP 1.7 — Reactive grid background

**Goal:** The signature Geometry Wars stage presence.

- [ ] Spring-mesh or shader grid filling the arena; reacts to player, dashes, deaths, (later: explosions)
- [ ] Perf check: grid + 100 enemies + bullets holds 60 fps; record approach notes here if shader vs mesh tradeoffs made
- [ ] Grid colors from `PaletteResource`

**Exit criteria**
- [ ] Playtest: grid ripples sell every explosion; 60 fps sustained in worst sandbox case
- [ ] Tests: green

### CP 1.8 — Tubbu personality & 🎮 FEEL GATE

**Goal:** Tubbu is a character; Milestone 1 verdict.

- [ ] Idle animation (squash/blink/bob) in the skin layer
- [ ] Near-miss reaction (bullet graze → Tubbu flinch/spark + tiny slowdown shimmer)
- [ ] Tuning session: expose key feel consts (speeds, fire rate, dash, shake) in a debug panel; iterate with Ludo
- [ ] **GATE: Ludo plays the sandbox and rules "dodging and shooting is fun bare"**

**Exit criteria**
- [ ] 🎮 Ludo signs off Milestone 1 (record verdict + tuning notes in Session log)
- [ ] Tests: green

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
- 2026-06-12 — CP 1.3 build done (same Fable session as CP 1.2; 1.3 isn't 🧠 but running a routine cp on the bigger model is fine — the policy only forbids the reverse). `DashAbility` (game/player/, RefCounted, owner-ticked like PlayerInput/Weapon): DASH_SPEED 1500 / DASH_DURATION 0.16 / I_FRAMES 0.16 / COOLDOWN 1.0 from dash start; i-frames on their OWN clock so CP 2.7's longer-i-frames upgrade is a number change; `is_invulnerable()` exposed on Tubbu — this IS the "hitbox disabled" mechanism, CP 1.4's contact kill must check it (no hitbox node exists yet). Dash direction = move vector, else last nonzero move dir (aim-neutral fallback — never the gun direction; init +X = spawn facing). During dash control is suspended (velocity = dash vector each frame; wall slide still applies → no snag), exit keeps the speed and friction reclaims it (glide out). Visuals via self_modulate only (scales the skin's own colors, asset rule intact; trail is a separate canvas item so it stays vivid): ghost body alpha 0.4 while dashing, body brightness 0.55→1.0 refilling with cooldown = the no-HUD readiness cue. Tests 41/41 (+8 dash: cooldown timing, i-frame window, fraction refill). Boot clean. Checkpoint NOT closed: Ludo's dash-weave playtest pending (plus the CP 1.2 aim playtest).
- 2026-06-12 — CP 1.2 build done on Fable (🧠 cp). Load-bearing decisions: (1) `PlayerInput.get_aim_vector(shooter: Node2D)` — mouse only becomes a direction relative to a world anchor, so the ship passes itself; kb+m aim is never zero (cursor always somewhere) and a degenerate on-ship cursor holds the last aim; gamepad path = deadzoned right stick, ZERO = not aiming. Trigger policy is explicit in `is_fire_held(aim)` (stick past deadzone fires; kb+m autofire always on), not implicit in aim==zero. (2) `BulletManager` (game/weapons/): bullets are NOT nodes — slot-stable parallel arrays (SoA) behind a narrow spawn/clear/count API so the CP 3.5 MultiMesh move is internal (stable slot → instance index); free-list pool, exhaustion recycles the OLDEST bullet (gun never stutters); wall-bounds cull + TTL backstop; `owner_index` per bullet for co-op/scoring attribution; one `_draw` pass (streak + core, palette color). (3) `Weapon` RefCounted in game/weapons/ (FIRE_RATE 9/s, MUZZLE_OFFSET 22): cooldown accumulator — instant first shot, no banked shots, multi-shot catch-up on hitch frames; the exact seam CP 2.4's stat pipeline replaces. Tubbu: facing now follows aim (travel-dir fallback for neutral pad stick); bullets fly the EXACT aim vector — the nose slew is cosmetic, so aiming is 1:1. Tests 33/33 (+16: pool 9, weapon 5, trigger policy 2). Boot clean. Gotcha: CanvasItem has no `global_position` — type world-anchored params as Node2D. Checkpoint NOT closed: Ludo's stick+mouse aim playtest pending.
- 2026-06-12 — CP 1.1 build done on Opus (not a 🧠 FABLE cp): real movement on Tubbu (accel/friction via move_toward, MAX_SPEED 560 / ACCEL 4200 / FRICTION 3000; heading slews to travel dir, banking via skew from turn rate — all tuning consts in one block, CP 1.8 lifts them to a debug panel). New `game/arena/`: Arena (script-only Node2D, centred rect bounds at world origin, double-line neon walls from palette, static pure `slide_inside` = per-axis clamp + into-wall velocity cancel = slide-no-snag) and ArenaCamera (script-only Camera2D, smoothed follow + velocity-lead by LEAD_TIME, arena-clamped via limits; owned by Game not the player, co-op note left). Engine trail = top_level Line2D (z -1) fed rear-of-ship world points, gradient+width taper from skin.trail_color (collapses to a dot when idle). Game wires arena+camera+player; arena default size 2000×1300 (larger than the 1280×720 view so follow/lead reads). Tests 17/17 (added test_arena: inside/slide/corner/radius). Headless 150-frame boot clean (no errors). Checkpoint NOT closed: Ludo's 2-min kb+m+controller flying playtest pending (also closes the deferred CP 0.2 wiggle test). Next CP 1.2 is 🧠 FABLE — needs `/model fable`.
- 2026-06-12 — CP 0.2 build finished on Fable: PlayerInput in game/player/ (kb+m via InputMap actions, gamepad via raw per-device axes; radial deadzone w/ rescale; dash edge latch via update()); input_actions.gd moved core/→game/player/ (core/ is autoloads-only); SkinResource (game/player/) + PaletteResource (game/fx/) + default .tres in assets/skins|palettes (overbright neon for HDR bloom); Game shell draws rect arena from palette, spawns Tubbu by index w/ bound kb+m PlayerInput (pad drives it too via device -1 action events — fine for v1 N=1); main boots into Game until CP 2.1. Tests 13/13 green. Gotcha: new class_name needs a `--headless --import` pass before headless runs see it. Checkpoint NOT closed: Ludo's kb+m+controller wiggle playtest pending.
- 2026-06-12 — CP 0.2 started on Fable per model policy (earlier Opus drafts discarded/redone). Autoload spine done: EventBus (gameplay events only, player_index rule), SettingsStore (own `changed` signal — no autoload→autoload deps), AudioRegistry (ID→stream, warn+fallback), SaveStore (versioned schema stub); registered + headless-verified. Stopped after step 1 per Ludo; next: PlayerInput (note: belongs in game/player/ per layout, not core/).
- 2026-06-12 — CP 0.1 done: Godot 4.6.3 pinned, Forward+/HDR 2D, folder layout, input map verified headless, GUT v9.6.0 installed (no tests in 0.1 per Ludo), git init + first commit.
- 2026-06-12 — Plan created from DESIGN.md (no code yet). Next: CP 0.1.
