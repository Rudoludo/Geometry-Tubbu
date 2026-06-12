# Geometry Tubbu — Design Document

> Resolved 2026-06-12 via design interview. Seed idea in [IDEA.MD](IDEA.MD).

## Vision

A **roguelite twin-stick bullet-hell** with Geometry Wars DNA, built for fun as a
hobby project. Game feel and juice take priority over meta-systems. PC, with
controller and keyboard+mouse as equal first-class citizens.

## Core decisions

| Branch | Decision |
|---|---|
| Goal | Fun hobby project — playable by author and friends |
| Engine | Godot 4 (GDScript) |
| Structure | Roguelite runs, Hades-style arena-to-arena rooms |
| Topology | Linear run, ~12–15 rooms (~20 min), 2–3 reward-previewing exit doors per clear, boss as final room |
| Build system | Stacking **shot modifiers** that visibly transform one base weapon (Nova Drift model) + dash/ability upgrades |
| Player kit | Left stick move, right stick aim+autofire (stick = trigger), dash with i-frames (~1s cooldown). KB+M: WASD + mouse aim + space/shift dash |
| Health | **One-hit death** + rechargeable shield charges earned via upgrades; getting hit resets the score multiplier |
| Enemies | Bullet-hell leaning patterns, **interleaved with pure contact-swarm "surf" rooms** to keep the GW crowd-surfing mechanic |
| Arenas | A few bounded shapes (rect, circle, oval), occasional obstacle rooms as spice |
| Boss | Giant pattern boss — slow/stationary core cycling dense choreographed bullet patterns (Touhou-style setpiece) |
| Meta-progression | **Cosmetics only**: Tubbu ship skins unlock via score/feat thresholds. All gameplay content available from run one |
| Scoring | Kills build a multiplier, hits reset it; per-skin high-score board; score + feats gate skin unlocks |
| Identity | Title is **Geometry Tubbu**; Tubbu is the ship — a small geometric mascot with personality (idle animation, near-miss reactions); skins are Tubbu variants |
| Visuals | Neon wireframe + bloom + particles + reactive grid, wrapped in **CRT arcade retro** post (curvature, scanlines). CRT layer must be subtle and individually toggleable — bullet readability is non-negotiable in a one-hit game |
| Audio | Chiptune soundtrack + modern, punchy SFX |
| Co-op | Single-player v1, **co-op-ready architecture**: no player singletons, player code is "player N", input device bound per player |

## Design constraints & rationale

- **One-hit + bullet-hell is the hard edge of this design.** Tuning levers:
  small hitbox relative to ship sprite (bullet-hell convention), slow & highly
  visible bullets early, shield upgrades reasonably common in door pools,
  brief post-hit invulnerability.
- Room threat flavor (pattern room vs swarm-surf room) is the primary variety
  axis; arena shape and obstacles are secondary.
- Shot modifiers must be *visible* transformations (spread, pierce, ricochet,
  homing, chain, orbitals…) — projectiles are glowing shapes, so transformation
  is cheap to render and dramatic to see.
- Score multiplier creates the moment-to-moment risk/reward (play greedy vs
  play safe) on top of the run-level door choices.

## Milestones

1. **The Toy (feel first)** — one arena, Tubbu with move/aim-autofire/dash,
   two enemy types (contact swarm + one bullet-pattern shooter), full juice
   from day one: bloom, particles, screenshake, reactive grid. No rooms, doors,
   or upgrades. Exit criterion: dodging and shooting is fun bare.
2. **Run skeleton** — room flow, door choices with reward previews, 6–8 shot
   modifiers, death/restart loop.
3. **The climb** — boss, score + multiplier, skins + unlock thresholds,
   enemy roster filled out (~6–8 types), arena shapes/obstacle rooms.
4. **The wrap** — CRT post layer (toggleable), chiptune soundtrack + SFX pass,
   menus/settings, input glyph swapping, high-score board.
