# Geometry Tubbu

Roguelite twin-stick bullet-hell (Geometry Wars look) for PC with controller
support. Godot 4.6.3, GDScript, Forward+ / HDR 2D. Built across many sessions by
Claude against a fixed plan.

## Read these first

| Doc | What it gives you |
|-----|-------------------|
| [PLAN.md](PLAN.md) | **Start here.** The build order, the **session protocol** (how to resume work), the **Conventions** (engine, layout, co-op/asset/readability/testing rules), and **Local tooling** — the Godot binary path + the canonical run/test commands. |
| [ARCHITECTURE.md](ARCHITECTURE.md) | The **code map**: directory layout, subsystem guide, load-bearing patterns, and a "where do I change X" index. Read this to navigate the code. |
| [DESIGN.md](DESIGN.md) | The vision: pillars, player kit, milestones. Source of truth for *what the game is* (it wins over PLAN.md on conflicts). |
| [future_issues.md](future_issues.md) | Known **performance debt** — structural costs that will bite as planned features land (broadphase, hot-loop allocations, etc.), with the checkpoint to fix each *before*. Not bugs today. |

## Working rules (the short version — full rules in PLAN.md)

- **Follow [PLAN.md](PLAN.md).** Its **Status** names the next checkpoint; resume
  via its session protocol. The checkpoints marked **🧠 FABLE** must run on the
  Fable model — never a smaller one. When unsure, stop rather than guess.
- **The Godot binary is not on `PATH`.** Its path and the canonical
  `--import` / GUT / boot-smoke commands are in [PLAN.md](PLAN.md) → Conventions →
  "Local tooling & commands". Use them; never filesystem-search for the binary.
- **Tests stay green.** GUT, headless, in [tests/](tests/) — pure logic only. The
  whole suite must pass at every checkpoint commit.
- **Honor the Conventions** in [PLAN.md](PLAN.md): co-op-ready by index (no player
  singleton; input via per-player `PlayerInput`), the asset abstraction layer
  (Skin/Palette resources + AudioRegistry — no hard-coded colors/shapes/audio in
  feature code), and bullet readability over juice (one-hit game).
- **Keep [ARCHITECTURE.md](ARCHITECTURE.md) current.** When you add or move a
  system, update the code map so it doesn't rot.
