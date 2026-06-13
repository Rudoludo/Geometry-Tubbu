extends Node
## Global gameplay event bus. Autoload "EventBus".
##
## Policy (keep this bus honest):
## - Only cross-system *gameplay* events live here — things with no natural
##   single owner (e.g. a kill concerns scoring, FX, audio and room-clear at
##   once). Autoloads that own a domain emit their own signals instead
##   (e.g. SettingsStore.changed), so autoloads never depend on each other.
## - Signals are added by the checkpoint that first needs them, never
##   speculatively.
## - Co-op rule (PLAN.md): no autoload references a specific player. Every
##   player-scoped signal carries the player index.

signal player_spawned(player_index: int)
signal player_died(player_index: int)

## An enemy died to player fire (CP 1.6). No single owner — juice (screenshake,
## hit-stop), and later scoring (CP 3.1) and audio all react. Carries the death
## position for placed FX; player attribution lands with scoring.
signal enemy_killed(at: Vector2)
