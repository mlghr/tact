## Global constants for the tactical RPG battle system.
## Access from any script as GameConstants.CONSTANT_NAME (no autoload required).
class_name GameConstants

## Horizontal size of one tile in world units (XZ plane).
const TILE_SIZE: float = 1.0

## World-space height increment per height level.
## A tile at height h has its top surface at Y = (h + 1) * HEIGHT_STEP.
const HEIGHT_STEP: float = 0.5

## CT value at which a unit gets their turn.
const CT_THRESHOLD: int = 100

## Collision layer bit-mask for tiles.
const TILE_COLLISION_LAYER: int = 1

## Collision layer bit-mask for units.
const UNIT_COLLISION_LAYER: int = 2

## Number of upcoming turns to show in the turn order preview bar.
const TURN_PREVIEW_COUNT: int = 8

## Camera rotation speed in degrees per keypress.
const CAMERA_ROTATE_DEGREES: float = 90.0

## Duration (seconds) for camera rotation tween.
const CAMERA_ROTATE_DURATION: float = 0.25

## Fall damage threshold: falling more than this many height levels deals damage.
const FALL_DAMAGE_THRESHOLD: int = 3

## Faction identifiers.
const FACTION_PLAYER: int = 0
const FACTION_ENEMY: int = 1
const FACTION_NEUTRAL: int = 2

## Highlight types for Tile.set_highlight().
const HIGHLIGHT_NONE: int = 0
const HIGHLIGHT_MOVE: int = 1
const HIGHLIGHT_ATTACK: int = 2
const HIGHLIGHT_HOVER: int = 3
const HIGHLIGHT_SELECTED: int = 4
const HIGHLIGHT_SKILL: int = 5
