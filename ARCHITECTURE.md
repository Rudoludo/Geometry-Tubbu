# Geometry Tubbu — Code Map

> **Navigation guide for the codebase.** Where things live, how they connect, and
> the patterns that explain *why* the code looks the way it does. This is the
> *where*; [DESIGN.md](DESIGN.md) is the *what* and [PLAN.md](PLAN.md) is the
> *how & in what order* (with the per-session protocol and the Conventions that
> govern all code). If a fact here drifts from the code, fix the code or fix this
> file — don't let it rot.

## The doc trio

| Doc | Role |
|-----|------|
| [DESIGN.md](DESIGN.md) | The vision: pillars, player kit, milestones. Source of truth for *what the game is*. |
| [PLAN.md](PLAN.md) | Checkpoint-by-checkpoint build order, the **session protocol** (how to resume), **Conventions** (engine, layout, co-op/asset/readability/testing rules), and **local tooling** (the Godot binary path + canonical commands — never filesystem-search for it). |
| **ARCHITECTURE.md** (this) | The code map: directory layout, subsystem guide, load-bearing patterns, and a "where do I change X" index. |

## Orientation

Godot 4.6.3, GDScript, Forward+ with HDR 2D (for neon bloom). Boot path:
`res://main.tscn` → its root is [game/flow/game_flow.gd](game/flow/game_flow.gd)
(a `GameFlow` node) which owns the state machine and builds
[game/game.gd](game/game.gd) (`Game`) when a run starts. Five autoloads form the
spine (see below). Tests are GUT, headless, in [tests/](tests/) — one suite per
pure-logic unit; **the suite must be green at every checkpoint commit.**

## Directory map

```
res://
  main.tscn                       # root scene; root node = GameFlow
  core/                           # autoloads ONLY (no autoload references a specific player)
    event_bus.gd                  # typed gameplay signals: player_spawned/player_died/enemy_killed
    settings_store.gd             # player settings + `changed` signal: effect intensities, input_mode, autofire
    audio_registry.gd             # sound ID -> stream map (stub; real assets swap here later)
    save_store.gd                 # versioned save schema (stub; disk persistence at CP 3.8)
    run_state.gd                  # RunState: seed, room_index, taken_upgrades, shields — serializable
  game/
    flow/
      game_state_machine.gd       # pure state machine (RefCounted): BOOT/TITLE/IN_RUN/ROOM_TRANSITION/DEATH/RUN_END + legal-transition table
      game_flow.gd                # owns the machine, maps transitions -> scene wiring; Title/Death stubs
    game.gd / game.tscn           # the in-run play scene: arena, players, enemies, juice. Binds input devices.
    player/
      tubbu.gd / tubbu.tscn       # the player ship (movement, fire, dash, death, personality)
      player_input.gd             # per-player device-bound input — THE only place that touches Input.*
      input_actions.gd            # InputMap action-name consts (move_*, fire, dash, restart)
      dash_ability.gd             # dash impulse + i-frames (RefCounted, owner-ticked)
      skin_resource.gd            # Tubbu visual data (body points, colors, idle params) — the skin layer
      idle_animation.gd           # idle squash/bob/blink curves (RefCounted, pure)
      near_miss_reaction.gd       # graze flinch clock (RefCounted, pure)
    weapons/
      weapon.gd                   # fire cadence + muzzle geometry (RefCounted, owner-ticked)
      bullet_manager.gd           # ALL projectiles: pooled SoA storage (player + enemy bands), one update + one draw pass
      bullet_pattern.gd           # static pattern math: ring(), aimed_burst()
    enemies/
      enemy_pool.gd               # pooled enemy NODES (RefCounted, injected factory + capacity)
      sandbox_spawner.gd          # chaser swarm population (debug sandbox)
      pattern_spawner.gd          # pattern-shooter population + hosts the global enemy-bullet -> player pass
      chaser/chaser.gd            # Enemy 1: contact swarm, steers at nearest player
      pattern_shooter/pattern_shooter.gd  # Enemy 2: stationary emitter, ring + aimed-burst patterns
    arena/
      arena.gd                    # bounded rect arena, neon walls, static slide_inside() containment
      arena_camera.gd             # follow/lead camera, arena-clamped (owned by Game, not the player)
    fx/
      palette_resource.gd         # color palette (enemies, bullets, arena, grid) — the asset layer
      burst.gd                    # one-shot particle pop (enemy/player death, graze spark)
      fx.gd                       # particle builder lib: make_muzzle(), make_dash_trail()
      screen_shake.gd             # trauma-based shake curve (RefCounted, pure)
      hit_stop.gd                 # brief global time-freeze on kills (Node, real-time clock)
      warp_grid.gd                # spring-mass warp grid sim (RefCounted, pure, SoA)
      grid_background.gd          # warp grid world wiring + one draw pass (Node2D)
    ui/
      debug_panel.gd              # sandbox tuning + input controls (debug-gated; real settings menu is CP 4.4)
  assets/
    skins/default_skin.tres       # default SkinResource (Classic Tubbu)
    palettes/default_palette.tres # default PaletteResource (neon)
  tests/                          # GUT suites, test_*.gd — pure logic only (never feel/visuals)
```

## The autoload spine (`core/`)

Registered in [project.godot](project.godot) `[autoload]`. **No autoload depends
on another autoload, and none references a specific player** (co-op rule).
- **EventBus** — typed gameplay signals, the only cross-system glue. Carries a
  `player_index`, never a player reference.
- **SettingsStore** — in-memory player settings + a `changed(key, value)` signal.
  Holds effect intensities (screenshake/hitstop/flash/CRT), and the input
  settings (`input_mode`, `autofire`). Effects read it *live* so they're
  settings-scaled from day one (readability rule).
- **RunState** — the serializable run: `run_seed`, `room_index`,
  `taken_upgrades`, `shields`, with `start_new_run()/to_dict()/from_dict()`.
- **AudioRegistry**, **SaveStore** — stubs; gameplay asks by ID so real assets
  drop in later by editing the registry / save schema only.

## Load-bearing patterns (read before editing)

These recur everywhere; matching them keeps the code coherent.

- **Pure/node split.** Anything testable as math lives in a `RefCounted` helper
  that an owner node *ticks* once per frame (`Weapon`, `DashAbility`,
  `IdleAnimation`, `NearMissReaction`, `ScreenShake`, `WarpGrid`,
  `GameStateMachine`). The node does I/O and drawing; the helper holds the logic
  and is unit-tested. Add new logic the same way.
- **Per-player input, never raw `Input.*` in gameplay.** Only
  [player_input.gd](game/player/player_input.gd) touches the `Input` singleton.
  Gameplay reads intents (move / aim / fire / dash) off a `PlayerInput` the
  player owns. See the Input subsystem below.
- **Co-op-ready by index.** Players live in an `Array[Tubbu]` addressed by index
  (`_players`), never a singleton. HUD/camera/scoring take N players even though
  v1 ships N=1.
- **No hard-coded colors/shapes/audio in feature code.** Visuals read a
  `SkinResource` (Tubbu) or `PaletteResource` (everything else); audio goes
  through `AudioRegistry` IDs. Feature code names *what*, the asset layer says
  *how it looks/sounds*.
- **Bullets are not nodes.** [bullet_manager.gd](game/weapons/bullet_manager.gd)
  is struct-of-arrays pools behind a narrow `spawn_*/collide_*/clear/count`
  facade, so the planned MultiMesh move (CP 3.5) stays internal. Two bands
  (player, enemy), separate capacity.
- **Readability beats juice (one-hit game).** Bullets draw at `z_index 5` above
  every ship and particle so an incoming orb is never hidden. The player hitbox
  is tiny (`Tubbu.HIT_RADIUS`) vs the ~16px body. Effect intensities are
  settings-scaled.
- **Recycle vs. skip on pool exhaustion.** Bullets recycle the *oldest* (the gun
  never stutters); enemies *skip* the spawn (teleporting a live enemy onto the
  player would be an unfair one-hit kill).

---

## Subsystem guide

### Input  *(reworked for issues #1/#3/#4 — see [PLAN.md](PLAN.md) session log)*

The single source of input truth is
[player_input.gd](game/player/player_input.gd) (`PlayerInput`, RefCounted). Each
player owns one; [game.gd](game/game.gd) binds it to a device and calls
`update()` once per frame (parents tick before children, so the ship reads fresh
latches that frame).

**Device families are exclusive.** A `PlayerInput` is, at any moment, either
`KEYBOARD_MOUSE` or `GAMEPAD` (`device_kind`) — the two never bleed together:
- The kb+m InputMap actions in [project.godot](project.godot) (`move_*`, `fire`,
  `dash`, `restart`) are **keyboard/mouse only** — no joypad events ride them.
  (Reading via the InputMap keeps key rebinding free.)
- Gamepads are read **raw, per-device** (`Input.get_joy_axis(device_id, …)`),
  because InputMap actions aggregate every device and can't isolate "this pad".
- There are **no `aim_*` actions** — gamepad aim is the raw right stick.

**Mode picks the active family** (`PlayerInput.Mode`):
- `AUTO` (default) — follows the **last-used device**, sticky: a pad wins the
  moment a stick deflects or a face/dash/start button is pressed; kb+m wins on
  any of its actions; idle keeps the current one. This is what makes the right
  stick "just work" the moment you pick up a pad (issue #1).
- `KEYBOARD_MOUSE` / `GAMEPAD` — lock one family; the other does nothing (issue
  #4, exclusive choice).

`Game._configure_input()` maps `SettingsStore.input_mode` (an int:
`INPUT_MODE_AUTO/KB_MOUSE/GAMEPAD`) → the bound `PlayerInput`, and re-binds live
when `SettingsStore.changed` fires. The int→enum map lives in Game so the core
`SettingsStore` autoload imports nothing from `game/`.

**Fire policy** (`is_fire_held(aim)`):
- `GAMEPAD`: the right stick **is** the trigger — deflection past the deadzone
  fires (per DESIGN.md).
- `KEYBOARD_MOUSE`: hold the `fire` button (**left mouse**) to shoot; the
  `autofire` setting flips it back to always-on (issue #3).

**Where input lives:**

| Concern | File |
|---------|------|
| Device reads, mode, fire policy, deadzone | [game/player/player_input.gd](game/player/player_input.gd) |
| Action-name consts | [game/player/input_actions.gd](game/player/input_actions.gd) |
| The actual key/mouse/pad bindings | [project.godot](project.godot) `[input]` |
| Binding the device from the setting | [game/game.gd](game/game.gd) `_configure_input` / `_on_setting_changed` |
| `input_mode` / `autofire` settings | [core/settings_store.gd](core/settings_store.gd) |
| Live dev controls (device dropdown, autofire) | [game/ui/debug_panel.gd](game/ui/debug_panel.gd) |
| Tests | [tests/test_player_input.gd](tests/test_player_input.gd) |

The full settings *menu* (user-facing, controller-navigable) is CP 4.4; the
glyph/hot-swap polish is CP 4.5. The debug panel is the interim surface.

### Player ship

[tubbu.gd](game/player/tubbu.gd) does movement (accel/friction + heading/banking),
firing (through the injected `BulletManager`, along the exact aim vector),
dashing ([dash_ability.gd](game/player/dash_ability.gd)), one-hit death, and
personality ([idle_animation.gd](game/player/idle_animation.gd) +
[near_miss_reaction.gd](game/player/near_miss_reaction.gd)). **The kill gate is
`Tubbu.try_kill()`** — every killer routes through it, so dash i-frames can't be
forgotten at a call site. Live feel knobs (`max_speed`, `friction`, fire rate,
dash) survive the death/restart loop (reset clears clocks, not instances).

### Weapons & bullets

[weapon.gd](game/weapons/weapon.gd) is just fire cadence (CP 2.4 will feed it a
resolved stat config). [bullet_manager.gd](game/weapons/bullet_manager.gd) owns
all projectiles in two SoA pools. Enemy-bullet lethality =
`Tubbu.HIT_RADIUS + BulletManager.ENEMY_BULLET_RADIUS`; the visual orb is sized
to stay readable and leave a graze band below `Tubbu.GRAZE_RADIUS`.
[bullet_pattern.gd](game/weapons/bullet_pattern.gd) is the shared pattern math
(the boss will reuse it).

### Enemies

Pooled **nodes** via [enemy_pool.gd](game/enemies/enemy_pool.gd) (one folder per
type, distinct behaviors). [chaser/chaser.gd](game/enemies/chaser/chaser.gd) is
the contact swarm; [pattern_shooter/pattern_shooter.gd](game/enemies/pattern_shooter/pattern_shooter.gd)
the bullet emitter. [pattern_spawner.gd](game/enemies/pattern_spawner.gd) also
hosts the **single global enemy-bullet → player collision pass** for the Phase-1
sandbox (CP 2.2's room owner will likely absorb it). Real wave spawning with
telegraphs is CP 2.2 — the current spawners are sandbox population.

### FX & juice

All settings-scaled. [screen_shake.gd](game/fx/screen_shake.gd) (trauma curve) +
[arena_camera.gd](game/arena/arena_camera.gd) (translation-only offset);
[hit_stop.gd](game/fx/hit_stop.gd) (real-time-clock time-freeze on kills);
[burst.gd](game/fx/burst.gd) + [fx.gd](game/fx/fx.gd) (particles);
[warp_grid.gd](game/fx/warp_grid.gd) + [grid_background.gd](game/fx/grid_background.gd)
(the reactive backdrop, drawn at `z -10`). Glow is a `WorldEnvironment` built in
`Game._setup_glow` — only overbright (>1.0) palette colors bloom.

### Flow & run state

[game_state_machine.gd](game/flow/game_state_machine.gd) is the pure transition
table; [game_flow.gd](game/flow/game_flow.gd) is `main.tscn`'s root and maps
states to scene wiring. `Game` is built **once** and **reset in place** on retry
(`reset_run()`), not rebuilt — preserving instant-retry feel and live tuning. It
emits `run_lost` when the last player dies; GameFlow turns that into DEATH.

---

## "Where do I change X?"

| I want to… | Go to |
|------------|-------|
| Rebind a key / add an input action | [project.godot](project.godot) `[input]` + [input_actions.gd](game/player/input_actions.gd) |
| Change how a device is read / add a device mode | [player_input.gd](game/player/player_input.gd) |
| Add a player setting | [settings_store.gd](core/settings_store.gd) (+ a debug control in [debug_panel.gd](game/ui/debug_panel.gd)) |
| Tune player feel (speed, fire rate, dash, hitbox) | [tubbu.gd](game/player/tubbu.gd) consts (most are live in the debug panel) |
| Tune bullet size/speed/lethality | [bullet_manager.gd](game/weapons/bullet_manager.gd) consts |
| Add/tune an enemy | `game/enemies/<type>/` + its spawner |
| Add a new bullet pattern | [bullet_pattern.gd](game/weapons/bullet_pattern.gd) |
| Change Tubbu's look / add a skin | a `SkinResource` `.tres` in [assets/skins/](assets/skins/) — no feature code |
| Recolor enemies/bullets/arena/grid | a `PaletteResource` `.tres` in [assets/palettes/](assets/palettes/) |
| Add a cross-system event | [event_bus.gd](core/event_bus.gd) (typed signal, carries `player_index`) |
| Add a game state / transition | [game_state_machine.gd](game/flow/game_state_machine.gd) + wire it in [game_flow.gd](game/flow/game_flow.gd) |
| Run the game / tests | commands in [PLAN.md](PLAN.md) → Conventions → "Local tooling & commands" |
