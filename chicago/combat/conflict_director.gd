extends Node
## Combat, witnesses and police for the loaded district (owned by world.gd).
##
## Player weapons: fists always; the M1911 once Enzo has it (story: in the glovebox of Marco's car). Desktop aims with
## the mouse; touch aims at the nearest visible enemy in front (optional aim assist, on by default on touch).
## Shots are traced against buildings (layer 1) and enemies (layer 16) only: civilians and named NPCs cannot be hit
## in chapter 1 (no friendly fire by design); they react by fleeing instead.
## Cover: standing within reach of a cover point (crates) protects from shooters on the far side of it.
## Police: a crime only matters if someone saw or heard it. Heard shots -> a call -> a dispatch delay (game minutes)
## -> a patrol car enters from the district edge. Seen by the patrol -> wanted level stays; unseen for LOSE_TIME ->
## the police give up. Caught on foot -> a fine. Hiding indoors speeds up losing them. Chases never resume on load.

const SHOT_NOISE := 900.0          # ground px: who hears a shot
const DISPATCH_MINUTES := 15
const LOSE_TIME := 18.0            # s unseen to lose the police
const POLICE_SIGHT := 520.0
const CATCH_DIST := 70.0
const CATCH_TIME := 2.5
const FINE_CENTS := 1000
const REGEN_PER_S := 1.5
const BODY_HALF_WIDTH := 22.0      # screen px around the chest line

var world: Node
var rng := RandomNumberGenerator.new()
var weapon := "fists"
var mag := 0
var reload_t := 0.0
var cooldown := 0.0
var hostiles: Array = []
var police: PoliceUnit
var dispatch_at := -1              # game minute when the patrol arrives
var report_pos := Vector2.ZERO
var unseen_t := 0.0
var catch_t := 0.0
var in_combat_t := 0.0
var tracers: Array = []            # [from, to, t, color]
var fx: Node2D
var aim_assist := true
var regen_acc := 0.0
var _crimes_this_session := {}
var _ram_cooldown := 0.0

func _ready() -> void:
	rng.seed = 4711
	EventBus.game_event.connect(_on_event)
	EventBus.district_loaded.connect(_on_district_loaded)
	EventBus.minute_passed.connect(_on_minute)
	EventBus.day_changed.connect(_on_day)

func _fx() -> Node2D:
	if fx == null or not is_instance_valid(fx):
		fx = Node2D.new()
		fx.z_index = 50
		fx.draw.connect(_draw_fx)
		world.add_child(fx)
	return fx

# ================================================================== player weapons
func player_attack() -> void:
	if cooldown > 0.0 or world.player.hp <= 0:
		return
	if weapon == "m1911" and mag > 0 and reload_t <= 0.0:
		_fire()
	elif weapon == "m1911" and mag == 0 and reload_t <= 0.0 and _reserve() > 0:
		reload()
	else:
		_punch()

func _reserve() -> int:
	return GameState.item_count("pistol_ammo")

func reload() -> void:
	if weapon != "m1911" or reload_t > 0.0 or mag >= int(DataRegistry.get_def("weapons", "m1911").mag) or _reserve() <= 0:
		return
	reload_t = float(DataRegistry.get_def("weapons", "m1911").reload_s)

func _finish_reload() -> void:
	var w := DataRegistry.get_def("weapons", "m1911")
	var take := mini(int(w.mag) - mag, _reserve())
	GameState.add_item("pistol_ammo", -take)
	mag += take

func _aim_point() -> Vector2:
	var p: Vector2 = world.player.position
	var best: Node2D = null
	var best_d := INF
	var touch_ui: bool = world.hud.touch.visible
	if (Settings.aim_assist and touch_ui) or InputRouter.bot_active:
		for h in hostiles:
			if is_instance_valid(h) and h.alive() and can_see(world.player, h):
				var d := Player.ground_dist(p, h.position)
				if d < best_d:
					best = h
					best_d = d
		if best:
			return best.position
	if not InputRouter.bot_active and not touch_ui:
		return world.get_global_mouse_position() + Vector2(0, 60)
	var f := {"E": Vector2(1, 0), "W": Vector2(-1, 0), "N": Vector2(0, -1), "S": Vector2(0, 1), "NE": Vector2(1, -0.5),
		"NW": Vector2(-1, -0.5), "SE": Vector2(1, 0.5), "SW": Vector2(-1, 0.5)}.get(world.player.facing, Vector2(0, 1)) as Vector2
	return p + f * 400.0

func _fire() -> void:
	var w := DataRegistry.get_def("weapons", "m1911")
	mag -= 1
	cooldown = float(w.fire_interval_s)
	var from: Vector2 = world.player.position + Vector2(0, -64)
	var target := _aim_point() + Vector2(0, -64)
	var dir := (target - from).normalized().rotated(deg_to_rad(rng.randf_range(-float(w.spread_deg), float(w.spread_deg))))
	var to := from + dir * float(w.range_px)
	# Walls stop bullets (physics ray on layer 1); a gunman is hit if the line passes within his body width before
	# the wall. Bodies are ~40 px wide on screen: a foot-ellipse test would be far smaller than what the player sees.
	var wall := _trace(from, to, 1)
	var end: Vector2 = wall.get("position", to)
	var best: Hostile = null
	var best_t := INF
	for h in hostiles:
		if not is_instance_valid(h) or h.state == Hostile.S.DEAD:
			continue
		var c: Vector2 = h.position + Vector2(0, -64)
		var seg := end - from
		var tt := clampf((c - from).dot(seg) / maxf(seg.length_squared(), 0.001), 0.0, 1.0)
		if (from + seg * tt).distance_to(c) < BODY_HALF_WIDTH and tt < best_t:
			best = h
			best_t = tt
	if best:
		end = from + (end - from) * best_t
		best.take_damage(int(w.damage))
	tracers.append([from, end, 0.12, Color("#ffe9a8")])
	_fx().queue_redraw()
	in_combat_t = 6.0
	_crime("shots_fired_street", world.player.position, SHOT_NOISE)

func _punch() -> void:
	var w := DataRegistry.get_def("weapons", "fists")
	cooldown = float(w.fire_interval_s)
	world.player.figure.hurt_t = 0.0
	for h in hostiles:
		if is_instance_valid(h) and h.state != Hostile.S.DEAD and Player.ground_dist(world.player.position, h.position) < float(w.range_px) + 20.0:
			h.take_damage(int(w.damage))
			in_combat_t = 6.0
			_crime("assault_street", world.player.position, float(w.noise_px))
			return

func _trace(from: Vector2, to: Vector2, mask: int) -> Dictionary:
	var space: PhysicsDirectSpaceState2D = world.get_world_2d().direct_space_state
	# Bullets fly at chest height: test against the ground footprints, shifted down by the same height.
	var q := PhysicsRayQueryParameters2D.create(from + Vector2(0, 64), to + Vector2(0, 64), mask)
	var r := space.intersect_ray(q)
	if r.has("position"):
		r.position -= Vector2(0, 64)
	return r

## Line of sight between two ground positions, blocked by buildings only.
func can_see(a: Node2D, b: Node2D) -> bool:
	if a == null or b == null:
		return false
	var who: Node2D = b
	if b == world.player and world._driving():
		who = world._driving()
	if Player.ground_dist(a.position, who.position) > Hostile.SIGHT:
		return false
	var space: PhysicsDirectSpaceState2D = world.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(a.position, who.position, 1)
	return space.intersect_ray(q).is_empty()

# ================================================================== enemy fire
func player_moving() -> bool:
	return world.player.velocity.length() > 40.0

## 1.0 = exposed, 0.25 = a cover point stands between the shooter and Enzo.
func player_cover_factor(shooter: Vector2) -> float:
	var p: Vector2 = world.player.position
	for c in _cover_points():
		if Player.ground_dist(p, c) < 70.0:
			var to_c := c - p
			var to_s := shooter - p
			if to_c.normalized().dot(to_s.normalized()) > 0.3:
				return 0.25
	return 1.0

func on_hostile_shot(h: Hostile, hit: bool, dmg: int) -> void:
	var from := h.position + Vector2(0, -70)
	var to: Vector2 = world.player.position + Vector2(0, -60)
	tracers.append([from, to if hit else to + Vector2(rng.randf_range(-40, 40), rng.randf_range(-30, 30)), 0.12, Color("#ff9a7a")])
	_fx().queue_redraw()
	in_combat_t = 6.0
	_crime("shots_fired_street", h.position, SHOT_NOISE, false)
	if hit and not world._driving():
		damage_player(dmg)

func damage_player(n: int) -> void:
	var p: Player = world.player
	p.hp = maxi(p.hp - n, 0)
	p.figure.hurt_t = 0.3
	if p.hp == 0:
		_player_down()

## Knocked down: the encounter restarts from its checkpoint (quest retry), a doctor's bill is paid if possible.
func _player_down() -> void:
	var p: Player = world.player
	EventBus.emit_event("player_down", {})
	EventBus.toast.emit("TOAST_PLAYER_DOWN", [])
	GameState.pay(-500, "medic:%d" % WorldClock.total_minutes, "medic")
	p.hp = p.max_hp
	if GameState.quests.state("ch1_ambush") == QuestSystem.ACTIVE:
		GameState.quests.fail("ch1_ambush")
		GameState.quests.retry("ch1_ambush")
		_clear_hostiles()
		var amb: Dictionary = world.district.def.get("ambush", {})
		p.position = Iso.to_screen(world.district.nearest_free(Vector2(20.6, 18.5)))
		_start_ambush(amb)

# ================================================================== the rail yard ambush
func _on_event(id: String, data: Dictionary) -> void:
	if id == "ambush_start":
		var amb: Dictionary = world.district.def.get("ambush", {}) if world and world.district else {}
		if not amb.is_empty():
			_start_ambush(amb)

func _on_district_loaded(_id: String) -> void:
	hostiles.clear()
	police = null
	if fx and is_instance_valid(fx):
		fx.queue_free()
	fx = null
	if GameState.item_count("pistol_ammo") > 0 or GameState.get_flag("has_pistol") == true:
		weapon = "m1911"
	# Still wanted after a district change: indoors the search fails soon; outside a new patrol comes.
	if int(GameState.wanted.level) > 0 and dispatch_at < 0:
		dispatch_at = WorldClock.total_minutes + 5
		report_pos = world.player.position
	# The encounter is replay-safe: entering the district while it is unresolved starts it again.
	var amb: Dictionary = world.district.def.get("ambush", {})
	if not amb.is_empty() and GameState.quests.state("ch1_ambush") == QuestSystem.ACTIVE and not GameState.quests.objective_done("ch1_ambush", "survive"):
		_start_ambush(amb)
	elif not amb.is_empty() and GameState.quests.state("ch1_ambush") == QuestSystem.ACTIVE and GameState.item_count("ledger_book") == 0:
		_drop_ledger(amb)

func _start_ambush(amb: Dictionary) -> void:
	_clear_hostiles()
	if GameState.get_flag("has_pistol") != true:
		GameState.set_flag("has_pistol", true)
		GameState.add_item("pistol_ammo", 14)
		EventBus.toast.emit("TOAST_GLOVEBOX_PISTOL", [])
	weapon = "m1911"
	# Encounter checkpoint: a (re)started fight begins with the ammo it was designed for (7 + 14), never less -
	# a retry must stay winnable. Extra rounds the player had are kept.
	mag = int(DataRegistry.get_def("weapons", "m1911").mag)
	if GameState.item_count("pistol_ammo") < 14:
		GameState.add_item("pistol_ammo", 14 - GameState.item_count("pistol_ammo"))
	var base := Vector2(float(amb.enemy_spawn[0]), float(amb.enemy_spawn[1]))
	for i in 2:
		var h := Hostile.new()
		h.director = self
		h.target = world.player
		h.rng.seed = 100 + i
		h.position = Iso.to_screen(world.district.nearest_free(base + Vector2(-1.2 * i, -0.4 * i)))
		for c in _cover_points():
			h.cover_points.append(c + Vector2(30, -20))
		h.died.connect(_on_hostile_gone)
		h.fled.connect(_on_hostile_gone)
		world.district.entities.add_child(h)
		hostiles.append(h)

func _cover_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if world and world.district:
		for c in world.district.def.get("ambush", {}).get("cover", []):
			out.append(Iso.to_screen(Vector2(float(c[0]), float(c[1]))))
	return out

func _clear_hostiles() -> void:
	for h in hostiles:
		if is_instance_valid(h):
			h.queue_free()
	hostiles.clear()

func _on_hostile_gone(_h: Hostile) -> void:
	for h in hostiles:
		if is_instance_valid(h) and h.alive():
			return
	EventBus.emit_event("ambush_resolved", {})
	_drop_ledger(world.district.def.get("ambush", {}))

func _drop_ledger(amb: Dictionary) -> void:
	if amb.is_empty() or GameState.item_count("ledger_book") > 0 or GameState.get_flag("ledger_taken") == true:
		return
	world.district._add_interactable({"id": "ledger_pickup", "kind": "pickup", "item": "ledger_book",
		"pos": amb.ledger_drop, "verb": "HUD_ACT_PICKUP"})

func pickup(it: Interactable) -> void:
	var item := String(it.def.get("item", ""))
	if item == "" or GameState.once.has("pickup:" + it.id):
		return
	GameState.once["pickup:" + it.id] = true
	GameState.add_item(item, 1)
	if item == "ledger_book":
		GameState.set_flag("ledger_taken", true)
		EventBus.toast.emit("TOAST_LEDGER_FOUND", [])
	world.district.interactables.erase(it)
	it.queue_free()
	_check_wanted_clear()

# ================================================================== witnesses and police
## A crime at `at`: who could know? Named NPCs and passers-by within `noise` who are in this district (shots are
## heard through walls; fist fights only with line of sight). Witnesses remember; a heard crime may be reported.
func _crime(event: String, at: Vector2, noise: float, by_player: bool = true) -> void:
	for h in hostiles:
		if is_instance_valid(h) and Player.ground_dist(h.position, at) < noise:
			h.hear()
	var witnesses: Array[String] = []
	var hearers: Array[String] = []
	var heard := 0
	for n in world.npcs.values():
		if Player.ground_dist(n.position, at) < noise:
			if _los(n.position, at):
				witnesses.append(n.npc_id)
			elif noise >= SHOT_NOISE:
				hearers.append(n.npc_id)
	for p in get_tree().get_nodes_in_group("pedestrian"):
		if world.district.is_ancestor_of(p) and Player.ground_dist(p.position, at) < noise:
			heard += 1
			p.scare(6.0)
	if not witnesses.is_empty() or not hearers.is_empty() or heard > 0:
		var key := "%s:%d" % [event, WorldClock.total_minutes]
		if not _crimes_this_session.has(key):
			_crimes_this_session[key] = true   # one record per crime per game minute (not saved)
			EventBus.emit_event(event, {"witnesses": witnesses, "hearers": hearers, "importance": 2, "heard": heard, "by_player": by_player})
			GameState.flags["neighbors_heard_" + event] = WorldClock.day()
		_report(at)

func _los(a: Vector2, b: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = world.get_world_2d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters2D.create(a, b, 1)).is_empty()

func _report(at: Vector2) -> void:
	report_pos = at
	if dispatch_at < 0 and police == null:
		dispatch_at = WorldClock.total_minutes + DISPATCH_MINUTES
		GameState.wanted.level = maxi(int(GameState.wanted.level), 1)
		GameState.wanted.heat = float(GameState.wanted.heat) + 25.0
		GameState.set_flag("wanted_clear", false)
		EventBus.wanted_changed.emit(int(GameState.wanted.level))

func _on_minute(m: int) -> void:
	if dispatch_at >= 0 and m >= dispatch_at and world and world.district and not world.transitioning:
		dispatch_at = -1
		if world.district.is_interior:
			# He is indoors: the patrol searches the street and leaves.
			_lose_police()
			return
		var edge: Array = world.district.def.get("ambush", {}).get("police_arrive_from", [0.5, 0.5])
		police = PoliceUnit.new()
		police.director = self
		police.position = Iso.to_screen(world.district.nearest_free(Vector2(float(edge[0]), float(edge[1])), 0.5))
		police.goal = report_pos
		police.district = world.district
		police.rammed.connect(_on_police_rammed)
		world.district.entities.add_child(police)
		unseen_t = 0.0

func _process(delta: float) -> void:
	if world == null or world.district == null or world.transitioning:
		return
	cooldown = maxf(cooldown - delta, 0.0)
	_ram_cooldown = maxf(_ram_cooldown - delta, 0.0)
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			_finish_reload()
	in_combat_t = maxf(in_combat_t - delta, 0.0)
	var p: Player = world.player
	if in_combat_t <= 0.0 and p.hp < p.max_hp:
		regen_acc += REGEN_PER_S * delta
		if regen_acc >= 1.0:
			p.hp = mini(p.max_hp, p.hp + int(regen_acc))
			regen_acc -= floorf(regen_acc)
	if not tracers.is_empty():
		for tr_ in tracers:
			tr_[2] -= delta
		tracers = tracers.filter(func(x): return x[2] > 0.0)
		_fx().queue_redraw()
	if police and is_instance_valid(police):
		var follow: Node2D = world._driving() if world._driving() else p
		var seen := Player.ground_dist(police.position, follow.position) < POLICE_SIGHT and _los(police.position, follow.position)
		police.pursuing = seen and world._driving() != null
		if seen:
			unseen_t = 0.0
			police.goal = follow.position
			GameState.wanted.last_seen_min = WorldClock.total_minutes
		else:
			unseen_t += delta
			if unseen_t > LOSE_TIME:
				_lose_police()
				return
		# Caught: on foot next to the patrol, or in a car that is boxed in (barely moving) with the patrol alongside.
		var dv: Vehicle = world._driving()
		var boxed: bool = dv != null and absf(dv.speed) < 0.4 and Player.ground_dist(police.position, dv.position) < CATCH_DIST * 1.8
		if boxed or (dv == null and Player.ground_dist(police.position, p.position) < CATCH_DIST):
			catch_t += delta
			if catch_t > CATCH_TIME:
				_arrested()
		else:
			catch_t = 0.0

## Enzo's car hit the patrol car: a new crime the officers saw themselves. Wanted goes up (max 3) and the search
## starts over; one report per second at most.
func _on_police_rammed(strength: float) -> void:
	if strength < 0.5 or _ram_cooldown > 0.0:
		return
	GameState.wanted.level = mini(int(GameState.wanted.level) + 1, 3)
	unseen_t = 0.0
	EventBus.wanted_changed.emit(int(GameState.wanted.level))
	EventBus.toast.emit("TOAST_RAMMED_POLICE", [])
	EventBus.emit_event("police_rammed", {"witnesses": ["kowalski"] if world.npcs.has("kowalski") else [], "importance": 2})
	GameState.memory.remember("kowalski", "enzo_rammed_police", WorldClock.total_minutes, 2, "told")
	_ram_cooldown = 1.0

func _lose_police() -> void:
	if police and is_instance_valid(police):
		police.queue_free()
	police = null
	dispatch_at = -1
	GameState.wanted = {"level": 0, "heat": 0.0, "last_seen_min": WorldClock.total_minutes}
	EventBus.wanted_changed.emit(0)
	EventBus.toast.emit("TOAST_POLICE_LOST", [])
	EventBus.emit_event("police_lost", {})
	_check_wanted_clear()

func _arrested() -> void:
	catch_t = 0.0
	if not GameState.pay(-FINE_CENTS, "fine:%d" % WorldClock.total_minutes, "police:fine"):
		GameState.add_debt("city_court", FINE_CENTS, "fine:%d" % WorldClock.total_minutes)
	GameState.memory.remember("kowalski", "enzo_detained", WorldClock.total_minutes, 3, "seen")
	EventBus.toast.emit("TOAST_ARRESTED", [Ledger.dollars(FINE_CENTS)])
	EventBus.emit_event("player_arrested", {})
	_lose_police()

func _check_wanted_clear() -> void:
	if int(GameState.wanted.level) == 0 and dispatch_at < 0 and police == null:
		GameState.set_flag("wanted_clear", true)
		EventBus.emit_event("wanted_cleared", {})

## Gossip: what the street heard yesterday reaches the neighbours (told, not seen).
func _on_day(day: int) -> void:
	for k in GameState.flags.keys():
		if String(k).begins_with("neighbors_heard_") and int(GameState.flags[k]) == day - 1:
			var ev := String(k).substr(16)
			for npc in ["rosa", "salvatore"]:
				GameState.memory.remember(npc, ev, WorldClock.total_minutes, 2, "told")

func is_unsafe_to_save() -> bool:
	for h in hostiles:
		if is_instance_valid(h) and h.alive():
			return true
	return police != null or dispatch_at >= 0

func status_text() -> String:
	var parts: Array[String] = []
	if weapon == "m1911":
		parts.append(tr("WPN_M1911") + " " + Loc.t("HUD_AMMO", [mag, _reserve()]) + (" …" if reload_t > 0.0 else ""))
	if world and world.player.hp < world.player.max_hp:
		parts.append(tr("HUD_HP") + " %d" % world.player.hp)
	if player_cover_factor(world.player.position + Vector2(0, -400)) < 1.0 or _near_cover():
		parts.append(tr("HUD_IN_COVER"))
	return "  ".join(parts)

func _near_cover() -> bool:
	for c in _cover_points():
		if Player.ground_dist(world.player.position, c) < 70.0:
			return true
	return false

func _draw_fx() -> void:
	for tr_ in tracers:
		var c: Color = tr_[3]
		c.a = clampf(tr_[2] / 0.12, 0.0, 1.0)
		fx.draw_line(tr_[0], tr_[1], c, 2.0)
