class_name InputActions
extends RefCounted
## Canonical names for the project's InputMap actions.
##
## Gameplay code must NOT pass raw action-name strings around; reference these
## consts instead. The action definitions live in project.godot.
##
## Co-op groundwork (PLAN.md Conventions): these actions describe *what* a
## physical input means, device-agnostically. Per-player, per-device reading is
## the job of PlayerInput (CP 0.2) — it filters these by the device bound to
## "player N" rather than reading the aggregated global InputMap.

const MOVE_LEFT := "move_left"
const MOVE_RIGHT := "move_right"
const MOVE_UP := "move_up"
const MOVE_DOWN := "move_down"

const AIM_LEFT := "aim_left"
const AIM_RIGHT := "aim_right"
const AIM_UP := "aim_up"
const AIM_DOWN := "aim_down"

const DASH := "dash"
