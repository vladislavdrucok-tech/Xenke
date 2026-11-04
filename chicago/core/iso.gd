class_name Iso
extends RefCounted
## The one world <-> screen transform of the game (2:1 isometric ground plane). See docs/TECH_ARCHITECTURE.md §Iso.
##
## World (grid) space: X runs to the screen's lower-right, Y to the lower-left, in TILE units (1.0 = one tile edge).
## Screen space: Godot canvas pixels, +x right, +y down.
## Grid point (0, 0) - the top vertex of tile (0, 0) - is screen (0, 0). Tile (i, j) covers grid [i, i+1] x [j, j+1];
## its centre is grid (i + 0.5, j + 0.5).
## One tile is TILE_W x TILE_H = 128 x 64 px on screen (2:1).
## Depth: everything standing on the ground sorts by the screen y of its FOOT point (Godot y-sort). Larger y = nearer.
## Heights (z) are screen pixels up from the ground and never change the sort key.

const TILE_W := 128.0
const TILE_H := 64.0
const HALF_W := TILE_W / 2.0
const HALF_H := TILE_H / 2.0

static func to_screen(g: Vector2) -> Vector2:
	return Vector2((g.x - g.y) * HALF_W, (g.x + g.y) * HALF_H)

static func to_grid(s: Vector2) -> Vector2:
	return Vector2(s.x / HALF_W + s.y / HALF_H, s.y / HALF_H - s.x / HALF_W) * 0.5

static func tile_at(s: Vector2) -> Vector2i:
	var g := to_grid(s)
	return Vector2i(floori(g.x), floori(g.y))

static func tile_center(t: Vector2i) -> Vector2:
	return to_screen(Vector2(t) + Vector2(0.5, 0.5))

## The four screen corners of a grid rectangle [x, x+w] x [y, y+h]: top, right, bottom, left.
static func rect_corners(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		to_screen(r.position),
		to_screen(r.position + Vector2(r.size.x, 0)),
		to_screen(r.position + r.size),
		to_screen(r.position + Vector2(0, r.size.y)),
	])

## Converts a desired on-screen direction (stick / WASD, any length <= 1) into a screen velocity that is the same
## ground speed in every direction: on a 2:1 plane a step "up the screen" covers twice the ground of the same number
## of pixels sideways, so the vertical component is halved. `speed` is in screen px/s along the horizontal axis.
static func ground_velocity(screen_dir: Vector2, speed: float) -> Vector2:
	if screen_dir.length() > 1.0:
		screen_dir = screen_dir.normalized()
	return Vector2(screen_dir.x, screen_dir.y * 0.5) * speed

## 8-way facing name for a screen-space direction (N = screen up). Used to pick animation sets.
const DIRS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

static func facing(screen_dir: Vector2) -> String:
	if screen_dir.length() < 0.001:
		return "S"
	# Undo the 2:1 squash so the eight sectors are even on the ground, not on the screen.
	var a := atan2(screen_dir.y * 2.0, screen_dir.x)
	var i := posmod(roundi(a / (PI / 4.0)), 8)
	return DIRS[i]
