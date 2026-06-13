# Geometry Tubbu — Known Future Issues (Performance)

> Forward-looking performance audit. These are **not bugs today** — the game runs
> fine at current scale. They are structural costs that will bite as planned
> features land ([PLAN.md](PLAN.md): modifiers at CP 2.6, more enemy types at
> 3.2/3.3, bigger arenas at 3.4, the dense boss at 3.5, CRT at 4.1, and the
> friends-machine export at 4.6). Logged so they're addressed *before* the
> checkpoint that stresses them, not after.
>
> First audited 2026-06-13. Update status as items are tackled.

## Severity at a glance

| # | Issue | Bites at | Severity | Status |
|---|-------|----------|----------|--------|
| 1 | No collision broadphase — brute-force O(bullets × enemies), full-capacity scans every frame | CP 2.6, CP 3.5 | 🔴 High | open |
| 2 | Per-frame heap allocations in GDScript hot loops | CP 3.2+ | 🔴 High | open |
| 3 | Redundant collision passes — each spawner scans the whole bullet pool separately | CP 2.2+ | 🟠 Medium | open |
| 4 | Immediate-mode bullet draw (antialiased `draw_circle` per bullet) | CP 3.5 (MultiMesh already planned) | 🟠 Medium | planned (CP 3.5) |
| 5 | `CPUParticles2D` node churn on swarm/boss death | CP 3.5 / 3.6 | 🟠 Medium | open |
| 6 | Forward+ renderer for a 2D game (heavier baseline than Mobile) | CP 4.6 export | 🟠 Medium | open |
| 7 | Stacked full-screen post (glow now + CRT later) fill-rate | CP 4.1 | 🟡 Watch | open |
| 8 | MultiMesh plan covers rendering but **not collision** — the real ceiling | CP 3.5 | 🔴 (the gap) | open |

---

## The serious ones

### 1 + 8. Collision is brute-force with no spatial partitioning  🔴

**Where:** [collide_player_bullets](game/weapons/bullet_manager.gd#L186-L206) walks
the **entire** 256-slot player pool (`for slot in _player.capacity`, not
`live_count`) × the live-enemy list, every frame.
[collide_enemy_bullets_with_players](game/weapons/bullet_manager.gd#L214-L234)
walks all 512 enemy slots × players, and
[nearest_enemy_bullet](game/weapons/bullet_manager.gd#L241-L253) walks all 512
once *per player* for the graze check.

**Why it bites:**
- **CP 2.6 homing** needs every bullet to find its nearest enemy *every frame* — a
  second O(bullets × enemies) pass stacked on collision. **Chain** adds
  target-selection per hit. At 256 bullets × 100 enemies that's ~25k checks for
  collision *plus* ~25k for homing, per frame, in GDScript.
- **CP 3.5 boss** pushes the enemy band toward its 512 cap (dense patterns) right
  when the frame budget is tightest.
- The CP 3.5 plan moves *rendering* to MultiMesh but says nothing about collision,
  so the algorithmic ceiling stays (issue #8 — this is the gap).

**Mitigation:** a uniform spatial grid / hash for the broadphase (cell ≈
bullet/enemy radius); only test bullets against enemies in neighbouring cells.
Highest-leverage structural change; far cheaper to add before homing/chain ship.
Suggest a dedicated checkpoint right before CP 2.6.

### 2. Per-frame heap allocations (GDScript GC spikes)  🔴

Every frame, in the hot path:
- [enemy_pool.live_nodes()](game/enemies/enemy_pool.gd#L58-L59) → `_live.duplicate()`,
  **per spawner, per frame**.
- [collide_player_bullets](game/weapons/bullet_manager.gd#L190) → `targets.duplicate()`
  + a `hit` array built each call.
- [chaser._draw()](game/enemies/chaser/chaser.gd#L113-L119) → `BODY_POINTS.duplicate()`
  + a `Transform2D * outline` allocation, **per enemy, per redraw**. Same in
  [pattern_shooter._draw()](game/enemies/pattern_shooter/pattern_shooter.gd#L116-L131).

At 100–200 enemies that's hundreds of transient allocations/frame → GC pressure →
periodic frame-time spikes (stutter), which a one-hit dodging game can't afford.

**Mitigation:** iterate `_live` directly with an index guard instead of
duplicating; precompute each enemy type's closed/inner outline once (it's
constant) rather than rebuilding it in every `_draw`.

### 3. Redundant full-pool collision passes  🟠

[SandboxSpawner](game/enemies/sandbox_spawner.gd#L35) and
[PatternSpawner](game/enemies/pattern_spawner.gd#L38) each call
`collide_player_bullets` independently — two full 256-slot scans per frame today.
As CP 2.2/3.2/3.3 add enemy types and spawners, this becomes *K* full passes over
the bullet pool per frame.

**Mitigation:** one bullet-major pass over *all* collidable enemies (a single
registry the broadphase from #1 would naturally provide).

---

## Rendering / GPU

### 4. Immediate-mode bullet rendering  🟠 *(already planned)*

[BulletManager._draw()](game/weapons/bullet_manager.gd#L290-L326) issues per-bullet
`draw_line` + antialiased `draw_circle`. At 512 orbs that's ~1024 AA circles/frame,
each tessellated. This is the canonical bottleneck — the plan already calls the
**MultiMesh move at CP 3.5**, and the SoA pool is built for it. Flagged here only
so it stays on the radar; AA circles are pricier than they look.

### 5. `CPUParticles2D` node churn  🟠

[Burst.spawn()](game/fx/burst.gd#L14-L33) creates a **new `CPUParticles2D` node per
death**, adds it to the tree, and self-frees after 0.45 s (called from
[chaser.die()](game/enemies/chaser/chaser.gd#L89),
[pattern_shooter.die()](game/enemies/pattern_shooter/pattern_shooter.gd#L92),
[tubbu.try_kill()](game/player/tubbu.gd#L198)). A big swarm clear or the CP 3.6
boss "bloom-out" spawns many CPU-simulated particle nodes the same frame, plus
tree add/free churn.

**Mitigation:** pool the burst nodes, or switch death pops to `GPUParticles2D` / a
MultiMesh particle pass.

### 6. Forward+ renderer for a 2D game  🟠

[project.godot:92](project.godot#L92) sets `forward_plus`. Forward+ carries
clustered-lighting/depth machinery a pure-2D neon game never uses — heavier
baseline GPU cost, which matters most on the integrated GPUs your friends'
machines (the CP 4.6 export target) likely have. The **Mobile** renderer also
supports HDR 2D + glow and is lighter.

**Mitigation:** benchmark Mobile vs Forward+ for the same bloom look before the
export gate.

### 7. Stacked full-screen post (watch)  🟡

[Glow](game/game.gd#L159-L174) is a 4-level multi-pass blur (fill-rate heavy at
1080p+), and CP 4.1 adds a full-screen CRT shader on top of HDR 2D. Multiple
full-screen passes compound on weak GPUs. Readability audits are planned; the
*perf* of stacked post isn't explicitly budgeted. Watch at CP 4.1.

---

## Already handled well (don't "fix" these)

- Bullets are SoA pools with fixed capacity + free-lists — no per-bullet nodes,
  MultiMesh-ready ([bullet_manager.gd](game/weapons/bullet_manager.gd)).
- Enemies pool and never free; exhaustion *skips* spawns instead of churning
  ([enemy_pool.gd](game/enemies/enemy_pool.gd)).
- The warp grid is SoA with a reused force accumulator, pinned borders, and **one**
  `draw_multiline_colors` call ([grid_background.gd:154](game/fx/grid_background.gd#L154))
  — well-budgeted (its cost grows with arena size at CP 3.4, worth a re-check then).
- Dash/muzzle emitters are persistent, not per-shot; bullets cull on bounds + TTL.

---

## Recommended sequencing

1. **Before CP 2.6** — add the spatial broadphase (#1/#8) and kill the hot-loop
   allocations (#2/#3). These are load-bearing for homing/chain/orbitals. Build a
   stress-test scene (max bullets + 100+ enemies + a heavy modifier stack) and
   measure frame time before/after.
2. **At CP 3.5** — the planned MultiMesh bullet render (#4); pool/relocate death
   particles (#5) alongside the boss spectacle work.
3. **At CP 4.1** — re-check stacked post-process fill-rate (#7) during the CRT
   readability audit.
4. **Before CP 4.6 export** — benchmark the Mobile renderer (#6) on a low-end GPU.

> **Headline:** the SoA work makes *rendering* scale, but collision and steering
> are still brute-force with per-frame allocations — that's what homing/chain
> (CP 2.6) and the boss (CP 3.5) will actually choke on. Fix the broadphase and
> the allocations before those checkpoints, not after.
