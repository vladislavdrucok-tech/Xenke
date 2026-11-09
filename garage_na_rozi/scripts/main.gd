extends Node
## Flow of the game: garage, clients, close-up repairs, payment, finale,
## free play; pause, background and restore handling.

const GarageView := preload("res://scripts/garage_view.gd")
const Hud := preload("res://scripts/hud.gd")
const REPAIRS := {
	"m_headlight": "res://scripts/repairs/r_headlight.gd",
	"f_light": "res://scripts/repairs/r_headlight.gd",
	"m_mirror": "res://scripts/repairs/r_mirror.gd",
	"m_speedo": "res://scripts/repairs/r_speedo.gd",
	"m_fender": "res://scripts/repairs/r_fender.gd",
	"b_turn": "res://scripts/repairs/r_turn.gd",
	"b_horn": "res://scripts/repairs/r_horn.gd",
	"b_kickstand": "res://scripts/repairs/r_kickstand.gd",
	"b_case": "res://scripts/repairs/r_case.gd",
	"c_wiper": "res://scripts/repairs/r_wiper.gd",
	"f_wiper": "res://scripts/repairs/r_wiper.gd",
	"c_glovebox": "res://scripts/repairs/r_glovebox.gd",
	"c_dash": "res://scripts/repairs/r_dash.gd",
	"f_dash": "res://scripts/repairs/r_dash.gd",
	"c_window": "res://scripts/repairs/r_window.gd",
}
const FAMILY := ["#f0c3a0", "#e8b48f", "#f3cdb0"]

var world: Node2D
var garage: GarageView
var repair: RepairBase
var hud: Hud
var post: ColorRect
var busy := false
var mode := "title"          # title | garage | repair | finale
var in_background := false
var tutorial_timer := 0.0
var settings_back := ""
var tester: Node


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	garage = GarageView.new()
	garage.name = "Garage"
	world.add_child(garage)
	var pl := CanvasLayer.new()
	pl.layer = 5
	add_child(pl)
	post = ColorRect.new()
	post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/gouache.gdshader")
	mat.set_shader_parameter("noise_tex", Paint.grain_tex())
	post.material = mat
	pl.add_child(post)
	var ul := CanvasLayer.new()
	ul.layer = 10
	add_child(ul)
	hud = Hud.new()
	hud.name = "Hud"
	ul.add_child(hud)
	hud.action.connect(_on_action)
	get_viewport().size_changed.connect(_layout)
	_layout()
	restore_scene()
	refresh_goal()
	hud.open_title(Game.has_progress())
	mode = "title"
	for a in OS.get_cmdline_user_args():
		if (a == "--selftest" or a.begins_with("--shots")) and get_tree().root.get_node_or_null("SelfTest") == null:
			tester = load("res://scripts/selftest.gd").new()
			tester.name = "SelfTest"
			tester.main = self
			get_tree().root.add_child.call_deferred(tester)
			break


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	if not busy:
		garage.scale = Vector2.ONE
		garage.position = base_garage_pos()
	if repair:
		_layout_repair()


func base_garage_pos() -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	return Vector2((vs.x - 720.0) * 0.5, (vs.y - 1280.0) * 0.5)


func _layout_repair() -> void:
	var vs := get_viewport().get_visible_rect().size
	var top: float = 120.0 + hud.safe_top
	var bottom: float = 190.0 + hud.safe_bottom
	var avail := vs.y - top - bottom
	var s := minf(vs.x / 720.0, avail / 960.0)
	repair.scale = Vector2(s, s)
	repair.position = Vector2((vs.x - 720.0 * s) * 0.5, top + (avail - 960.0 * s) * 0.5)


# ------------------------------------------------------------------ scene state

func order_of(job: Dictionary) -> Dictionary:
	return Game.order(job["order"])


## Put the vehicle and client in place from the saved state, no animation.
func restore_scene() -> void:
	garage.vehicle = ""
	garage.client_look = {}
	garage.friend_look = {}
	garage.pulse_ids = []
	var job = Game.current()
	var res = Game.pending_result()
	var oid := ""
	if job != null:
		oid = job["order"]
	elif res != null:
		oid = res["order"]
	if Game.state.get("final_arrived", false) and not Game.state.get("free_play", false):
		oid = "f_light" if oid == "" else oid
	if Game.state.get("credits_pending", false):
		oid = "f_light"
	if oid == "":
		return
	var o := Game.order(oid)
	_place_vehicle(o)
	_place_client(o)


func _vehicle_spot(veh: String) -> Vector2:
	if veh == "car" or veh == "wagon":
		return garage.BAY
	return garage.STAND if Game.owns("stand") else garage.SPOT


func _client_spot(veh: String) -> Vector2:
	if veh == "car" or veh == "wagon":
		return Vector2(0.36, 0.74)
	if Game.owns("stand"):
		return Vector2(0.5, 0.56)
	return Vector2(0.78, 0.66)


func _place_vehicle(o: Dictionary) -> void:
	garage.vehicle = o["vehicle"]
	garage.veh_paint = Color(o.get("paint", "#5f8f4e"))
	garage.veh_uv = _vehicle_spot(o["vehicle"])
	garage.veh_facing = -1.0
	garage.veh_opts = {}
	if o["vehicle"] == "wagon":
		garage.veh_opts = {"faces": FAMILY, "luggage": true}
	garage.veh.modulate.a = 1.0


func _place_client(o: Dictionary) -> void:
	garage.client_look = Game.client_info(o["client"])
	garage.client_uv = _client_spot(o["vehicle"])
	garage.client_alpha = 1.0
	garage.client_wave = 0.0


func client_screen_pos() -> Vector2:
	return garage.get_global_transform() * (garage.g(garage.client_uv.x, garage.client_uv.y, 175))


func refresh_goal() -> void:
	var gl := Game.goal()
	var frac := -1.0
	if gl["item"] != "":
		frac = clampf(float(Game.balance()) / float(Game.price(gl["item"])), 0.0, 1.0)
	else:
		var st := Game.career_stage()
		if st == 1:
			frac = Game.count_done(Game.MOPED) / 4.0
		elif st == 2:
			frac = Game.count_done(Game.MOTO) / 4.0
		elif st == 3:
			frac = Game.count_done(Game.CAR) / 4.0
		elif st == 4:
			frac = Game.final_done_list().size() / 3.0
	hud.set_goal(gl["text"], frac)


# ------------------------------------------------------------------ garage state machine

## Decide what the garage shows now (bottom card, highlights).
func garage_idle() -> void:
	mode = "garage"
	refresh_goal()
	garage.pulse_ids = []
	hud.repair_mode(false)
	var job = Game.current()
	var res = Game.pending_result()
	if res != null:
		_show_result(res)
		return
	if Game.state.get("credits_pending", false):
		await play_finale()
		return
	if job != null:
		_show_order(job)
		return
	if Game.state.get("final_arrived", false) and not Game.final_complete():
		_show_final_card()
		return
	var buttons: Array = []
	var text := ""
	var gl := Game.goal()
	var next := _next_order()
	if gl["item"] != "" and Game.can_buy(gl["item"]):
		buttons.append(hud.btn("Купити: %s · %d" % [Game.item_name(gl["item"]), Game.price(gl["item"])], "buy_ask", gl["item"], true))
		garage.pulse_ids = ["stand_spot" if gl["item"] == "stand" else ("lift_spot" if gl["item"] == "lift" else "")]
	if next != "":
		buttons.append(hud.btn("Покликати клієнта", "call", null, buttons.is_empty()))
		if Game.state.get("free_play", false):
			text = "Майстерня відкрита. Наступний: %s." % Game.order(Game.peek_free_queue()[0])["title"]
	else:
		if not Game.owns("stand"):
			text = Game.data["story"]["stand_goal"]
		elif Game.count_done(Game.MOTO) >= 4 and not Game.owns("lift"):
			text = Game.data["story"]["lift_goal"] + " Ціна %d." % Game.price("lift")
	if gl["item"] != "" and not Game.can_buy(gl["item"]) and gl["need"] > 0:
		text = "%s: бракує %d монет." % [Game.item_name(gl["item"]), gl["need"]]
	if Game.state.get("free_play", false):
		var row: Array = [hud.btn("Дошка робіт", "board", null, false, 84), hud.btn("Покращення", "shop", null, false, 84)]
		buttons.append(row)
	hud.panel_idle(text, buttons)


func _next_order() -> String:
	if Game.state.get("free_play", false):
		var q: Array = Game.peek_free_queue()
		return q[0] if q.size() > 0 else ""
	return Game.next_career_order()


func _show_order(job: Dictionary) -> void:
	var o := order_of(job)
	var c := Game.client_info(o["client"])
	var zone_name := _zone_name(o["zone"], o["vehicle"])
	var started: bool = job.get("phase", "") == "repair"
	var btn_text := "Продовжити ремонт" if started else "Оглянути: " + zone_name
	var extra := ""
	if not started and not Game.tutorial_seen("tap_zone"):
		extra = "Торкнися: %s — або натисни кнопку." % zone_name
	hud.panel_order(c["name"], o["complaint"], o["title"], extra, [hud.btn(btn_text, "inspect", null, true)])
	garage.pulse_ids = [o["zone"]]


func _show_final_card() -> void:
	var fin: Dictionary = Game.data["final"]
	var lines: Array = []
	var buttons: Array = []
	for st in fin["stages"]:
		var done: bool = Game.final_done_list().has(st["id"])
		lines.append(("✓ " if done else "○ ") + st["title"])
		if not done:
			buttons.append(hud.btn(st["title"], "final_stage", st["id"], buttons.is_empty(), 84))
	hud.panel_order(Game.client_info(fin["client"])["name"], fin["complaint"] if Game.final_done_list().is_empty() else "Ще трохи — і в дорогу!", fin["title"], "   ".join(lines), buttons)
	garage.pulse_ids = []
	for st in fin["stages"]:
		if not Game.final_done_list().has(st["id"]):
			garage.pulse_ids.append(st["zone"])


func _zone_name(zone: String, veh: String) -> String:
	return {"front": "фара", "mirror": "дзеркало", "wheel": "колесо", "fender": "крило", "turn": "поворотник",
		"horn": "кнопка сигналу", "kickstand": "підніжка", "case": "кофр", "windshield": "вітрове скло",
		"door": "салон", "window": "бокове вікно"}.get(zone, zone)


func call_client() -> void:
	if busy or Game.has_client():
		return
	var id := _next_order()
	if id == "":
		return
	busy = true
	hud.clear_bottom()
	if id == "final":
		Game.state["final_arrived"] = true
		Game.save()
		var fo := Game.order("f_light")
		await _arrive(fo)
		hud.say(Game.data["final"]["complaint"], client_screen_pos(), 6.0)
		busy = false
		_show_final_card()
		return
	var kind := "free" if Game.state.get("free_play", false) else "career"
	if kind == "free":
		id = Game.next_free_order()
	var o := Game.order(id)
	Game.open_job(id, kind)
	# story moments
	var story := ""
	if id == "b_turn" and kind == "career":
		story = Game.data["story"]["moto_intro"]
	elif id == "c_wiper" and kind == "career":
		story = Game.data["story"]["car_intro"]
	await _arrive(o, id == "b_turn" and kind == "career")
	if story != "":
		var who := client_screen_pos()
		if id == "b_turn":
			hud.say("Остап: " + story, who, 3.2)
			await _wait(2.6)
		else:
			hud.say(story, who, 3.0)
			await _wait(2.4)
	hud.say(o["complaint"], client_screen_pos(), 5.0)
	busy = false
	if Game.current() != null:
		_show_order(Game.current())


func _arrive(o: Dictionary, with_friend := false) -> void:
	var veh: String = o["vehicle"]
	_place_vehicle(o)
	var spot := _vehicle_spot(veh)
	var cspot := _client_spot(veh)
	garage.client_look = Game.client_info(o["client"])
	garage.client_alpha = 1.0
	if with_friend:
		garage.friend_look = Game.client_info("ostap")
		garage.friend_uv = Vector2(1.9, cspot.y + 0.1)
	if veh == "car" or veh == "wagon":
		Sfx.play("gate")
		await _tween_prop(garage, "gate_open", 1.0, 1.0)
		garage.veh_uv = Vector2(spot.x, -0.08)
		garage.veh.modulate.a = 0.0
		garage.client_alpha = 0.0
		garage.client_uv = cspot
		Sfx.play("car")
		var tw := create_tween().set_parallel(true)
		tw.tween_property(garage, "veh_uv", spot, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(garage.veh, "modulate:a", 1.0, 0.6)
		await tw.finished
		await _tween_prop(garage, "client_alpha", 1.0, 0.4)
		Sfx.play("gate")
		_tween_prop(garage, "gate_open", 0.0, 1.0)
	else:
		garage.veh_uv = Vector2(1.55, spot.y)
		garage.client_uv = Vector2(1.75, cspot.y)
		Sfx.play("engine")
		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(garage, "veh_uv", spot, 2.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw2.tween_property(garage, "client_uv", cspot, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if with_friend:
			tw2.tween_property(garage, "friend_uv", cspot + Vector2(0.12, 0.12), 2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tw2.finished
	Sfx.play("bell")


func _depart() -> void:
	var veh := garage.vehicle
	if veh == "":
		return
	if veh == "car" or veh == "wagon":
		Sfx.play("gate")
		await _tween_prop(garage, "client_alpha", 0.0, 0.4)
		await _tween_prop(garage, "gate_open", 1.0, 0.9)
		Sfx.play("car")
		var tw := create_tween().set_parallel(true)
		tw.tween_property(garage, "veh_uv", Vector2(garage.veh_uv.x, -0.1), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(garage.veh, "modulate:a", 0.0, 0.6).set_delay(1.6)
		await tw.finished
		Sfx.play("gate")
		_tween_prop(garage, "gate_open", 0.0, 1.0)
	else:
		garage.veh_facing = 1.0
		Sfx.play("engine")
		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(garage, "veh_uv", Vector2(1.6, garage.veh_uv.y), 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw2.tween_property(garage, "client_uv", Vector2(1.8, garage.client_uv.y), 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if garage.friend_uv.x > -0.5:
			tw2.tween_property(garage, "friend_uv", Vector2(1.9, garage.friend_uv.y), 2.0)
		await tw2.finished
	garage.vehicle = ""
	garage.client_look = {}
	garage.friend_look = {}
	garage.friend_uv = Vector2(-1, -1)


func _tween_prop(obj: Object, prop: String, to: Variant, secs: float) -> void:
	var tw := create_tween()
	tw.tween_property(obj, prop, to, secs)
	await tw.finished


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout


# ------------------------------------------------------------------ repair

func inspect(zone_override := "") -> void:
	if busy:
		return
	var job = Game.current()
	if job == null:
		return
	Game.mark_tutorial("tap_zone")
	busy = true
	hud.hide_bubble()
	hud.clear_bottom()
	var o := order_of(job)
	var zp: Vector2 = garage.zone_pos(o["zone"])
	await _zoom_in(zp)
	_open_repair(job)
	await hud.fade(0.0, 0.3)
	busy = false


func _open_repair(job: Dictionary) -> void:
	var o := order_of(job)
	var path: String = REPAIRS[job["order"]]
	repair = load(path).new()
	repair.name = "Repair"
	var tut: bool = job["order"] == "m_headlight" and not Game.tutorial_seen("first_repair")
	world.add_child(repair)
	repair.coach.connect(_on_coach)
	repair.step_changed.connect(_on_step)
	repair.hint_ready.connect(func(on): hud.set_hint_button(on))
	repair.solved.connect(_on_solved)
	repair.setup(o, job, tut)
	Game.update_job({"phase": "repair"})
	garage.visible = false
	_layout_repair()
	hud.repair_mode(true, o["title"])
	hud.set_steps(repair.step)
	hud.panel_repair(repair.instruction() if not tut else repair.tutorial_line())
	mode = "repair"


func _on_coach(text: String) -> void:
	if mode != "repair":
		return
	hud.panel_repair(text)
	if repair and repair.tutorial:
		# a tutorial line holds the timer while it is read
		repair.set_paused("tutorial", true)
		tutorial_timer = 2.2


func _on_step(step: String) -> void:
	hud.set_steps(step)


func _process(delta: float) -> void:
	if repair and mode == "repair":
		hud.set_timer(repair.elapsed, float(repair.order["target"]), repair.started)
		if tutorial_timer > 0.0:
			tutorial_timer -= delta
			if tutorial_timer <= 0.0:
				repair.set_paused("tutorial", false)


func _on_solved() -> void:
	if busy:
		return
	busy = true
	var job = Game.current()
	if job == null:
		busy = false
		return
	if repair.tutorial:
		Game.mark_tutorial("first_repair")
	repair.set_paused("tutorial", false)
	var res := Game.complete_job(int(job["uid"]), repair.elapsed)
	hud.set_hint_button(false)
	hud.panel_repair("Перевірено! " + order_of(job)["thanks"] if not res.is_empty() else "Готово")
	await _wait(1.3)
	await _close_repair()
	busy = false
	var r = Game.pending_result()
	if r != null:
		_show_result(r)
	else:
		garage_idle()


func _close_repair() -> void:
	await hud.fade(1.0, 0.25)
	if repair:
		repair.queue_free()
		repair = null
	garage.visible = true
	hud.repair_mode(false)
	hud.snap_balance()
	hud.target_balance = Game.balance()
	var bal_now := Game.balance()
	var res = Game.pending_result()
	if res != null:
		hud.shown_balance = bal_now - int(res["base"]) - int(res["tip"])
	garage.scale = Vector2(2.4, 2.4)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(garage, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(garage, "position", base_garage_pos(), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hud.fade(0.0, 0.35)
	await tw.finished
	mode = "garage"


func _zoom_in(zp: Vector2) -> void:
	Sfx.play("whoosh")
	var vs := get_viewport().get_visible_rect().size
	var s := 2.4
	var target := vs * 0.5 - zp * s
	var tw := create_tween().set_parallel(true)
	tw.tween_property(garage, "scale", Vector2(s, s), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(garage, "position", target, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await hud.fade(1.0, 0.45)


func back_to_garage() -> void:
	if not repair or busy:
		return
	busy = true
	repair.set_paused("menu", false)
	repair.persist()
	hud.close_overlay()
	await _close_repair()
	busy = false
	garage_idle()


func _show_result(res: Dictionary) -> void:
	mode = "garage"
	var o := Game.order(res["order"])
	var c := Game.client_info(o["client"])
	if garage.vehicle == "":
		_place_vehicle(o)
		_place_client(o)
	var thanks: String = o["thanks"]
	var last_stage: bool = res["kind"] == "final" and res["events"].has("finale")
	if last_stage:
		thanks = Game.data["final"]["thanks"]
	hud.say(thanks, client_screen_pos(), 4.0)
	Sfx.play("cash")
	if int(res["tip"]) > 0:
		get_tree().create_timer(0.5).timeout.connect(func(): Sfx.play("tip"))
	var bt := "Далі"
	if res["kind"] == "final" and not last_stage:
		bt = "До наступної роботи"
	hud.panel_result(res, thanks, bt)
	garage.pulse_ids = []
	refresh_goal()


func after_result() -> void:
	if busy:
		return
	var res = Game.pending_result()
	if res == null:
		garage_idle()
		return
	busy = true
	Game.dismiss_result()
	hud.clear_bottom()
	hud.hide_bubble()
	var events: Array = res["events"]
	if res["kind"] == "final":
		if events.has("finale"):
			busy = false
			await play_finale()
			return
		busy = false
		_show_final_card()
		return
	if events.has("photo"):
		hud.say(Game.data["story"]["photo"], client_screen_pos(), 2.5)
		await _wait(1.2)
		Sfx.play("photo")
		await hud.fade(0.85, 0.08)
		garage.refresh()
		await hud.fade(0.0, 0.4)
		hud.flash("На стіні — перша спільна світлина!")
		await _wait(1.0)
	await _depart()
	if events.has("moto_unlocked"):
		hud.flash("Мопеди полагоджено! Хтось іде з мотоциклом…")
	elif events.has("lift_unlocked"):
		hud.flash("Тепер можна купити підйомник за %d!" % Game.price("lift"))
	elif events.has("final_unlocked"):
		hud.flash("Усі 12 ремонтів зроблено. Хтось сигналить біля воріт…")
	busy = false
	garage_idle()


func play_finale() -> void:
	if mode == "finale":
		return
	mode = "finale"
	busy = true
	hud.clear_bottom()
	var fo := Game.order("f_light")
	if garage.vehicle != "wagon":
		_place_vehicle(fo)
		_place_client(fo)
	# the sign: a gift from the first client
	hud.say("А це — тобі. Щоб усі знали, де тут гараж!", client_screen_pos(), 3.0)
	await _wait(1.6)
	garage.sign_drop = 0.0
	garage.refresh()
	Sfx.play("fanfare")
	await _tween_prop(garage, "sign_drop", 1.0, 1.2)
	hud.flash("Емальована вивіска «Гараж на розі»!", 2.6)
	await _wait(1.6)
	# the family drives out through the gate
	garage.client_wave = 1.0
	await _wait(0.8)
	await _depart()
	await _wait(0.6)
	hud.open_credits()
	busy = false


func finish_credits() -> void:
	hud.close_overlay()
	Game.finish_credits()
	mode = "garage"
	garage.refresh()
	hud.flash(Game.data["story"]["free_play"], 3.0)
	garage_idle()


# ------------------------------------------------------------------ buying

func buy(item: String) -> void:
	if Game.buy(item):
		hud.close_overlay()
		Sfx.play("buy")
		Sfx.buzz(30)
		garage.refresh()
		hud.flash("%s — у гаражі!" % Game.item_name(item))
		refresh_goal()
		if mode == "garage" and not busy:
			garage_idle()
	else:
		hud.close_overlay()


# ------------------------------------------------------------------ input & actions

func _unhandled_input(ev: InputEvent) -> void:
	if mode != "garage" or busy or hud.is_overlay():
		return
	if ev is InputEventScreenTouch and ev.pressed:
		var p: Vector2 = garage.get_global_transform().affine_inverse() * ev.position
		var allowed: Array = ["board", "stand_spot", "lift_spot"]
		var job = Game.current()
		if job != null:
			allowed.append(order_of(job)["zone"])
		if Game.state.get("final_arrived", false) and job == null and not Game.final_complete():
			for st in Game.data["final"]["stages"]:
				if not Game.final_done_list().has(st["id"]):
					allowed.append(st["zone"])
		if Game.state.get("free_play", false):
			allowed.append("gate")
		var id: String = garage.pick(p, allowed)
		if id == "":
			return
		get_viewport().set_input_as_handled()
		match id:
			"board":
				Sfx.play("pop")
				hud.open_board(Game.state.get("free_play", false), not Game.has_client())
			"stand_spot":
				if not Game.owns("stand"):
					hud.open_buy("stand")
			"lift_spot":
				if not Game.owns("lift"):
					hud.open_buy("lift")
			"gate":
				if Game.owns("decor_gate"):
					Game.toggle_gate_color()
			_:
				if job != null:
					inspect()
				else:
					for st in Game.data["final"]["stages"]:
						if st["zone"] == id and not Game.final_done_list().has(st["id"]):
							_start_final_stage(st["id"])
							break


func _start_final_stage(id: String) -> void:
	if busy or Game.has_client():
		return
	Game.open_final_stage(id)
	inspect()


func _on_action(act: String, arg: Variant) -> void:
	match act:
		"start":
			_start()
		"settings":
			settings_back = String(arg) if arg != null else ""
			if repair:
				repair.set_paused("menu", true)
			hud.open_settings(settings_back)
		"settings_done":
			_back_from_settings(String(arg))
		"toggle":
			Game.set_setting(arg, not Game.setting(arg))
			hud.open_settings(settings_back)
		"reset_ask":
			hud.open_reset_confirm(String(arg))
		"reset_do":
			_reset()
		"pause":
			if mode == "title" or busy:
				return
			if repair:
				repair.set_paused("menu", true)
			hud.open_pause(repair != null)
		"resume":
			hud.close_overlay()
			if repair:
				repair.set_paused("menu", false)
		"to_garage":
			back_to_garage()
		"board":
			hud.open_board(Game.state.get("free_play", false), not Game.has_client())
		"shop":
			hud.open_shop()
		"gate_toggle":
			Game.toggle_gate_color()
			hud.open_shop()
		"close":
			hud.close_overlay()
			if repair:
				repair.set_paused("menu", false)
		"call":
			call_client()
		"inspect":
			inspect()
		"final_stage":
			_start_final_stage(String(arg))
		"buy_ask":
			hud.open_buy(String(arg))
		"buy_do":
			buy(String(arg))
		"next":
			after_result()
		"hint":
			if repair:
				repair.set_paused("hint", true)
				repair.show_hint()
				hud.open_hint(repair.hint_text())
		"hint_close":
			hud.close_overlay()
			if repair:
				repair.set_paused("hint", false)
		"continue_bg":
			hud.close_overlay()
			if repair:
				repair.set_paused("background", false)
				repair.set_paused("menu", false)
		"take":
			_take_from_board(String(arg))
		"credits_done":
			finish_credits()


func _back_from_settings(back_to: String) -> void:
	if back_to == "title":
		hud.open_title(Game.has_progress())
	elif back_to == "pause":
		hud.open_pause(repair != null)
	else:
		hud.close_overlay()
		if repair:
			repair.set_paused("menu", false)


func _start() -> void:
	hud.close_overlay()
	mode = "garage"
	var job = Game.current()
	if job != null and job.get("phase", "") == "repair":
		# straight back into the interrupted repair
		busy = true
		_open_repair(job)
		await hud.fade(0.0, 0.2)
		busy = false
		return
	var first := not Game.has_progress()
	garage_idle()
	if first:
		await _wait(0.6)
		call_client()


func _take_from_board(id: String) -> void:
	if Game.has_client() or busy:
		return
	hud.close_overlay()
	busy = true
	hud.clear_bottom()
	var o := Game.order(id)
	Game.open_job(id, "free")
	await _arrive(o)
	hud.say(o["complaint"], client_screen_pos(), 4.0)
	busy = false
	_show_order(Game.current())


func _reset() -> void:
	hud.close_overlay()
	if repair:
		repair.queue_free()
		repair = null
	Game.reset_progress()
	garage.visible = true
	garage.scale = Vector2.ONE
	garage.position = base_garage_pos()
	restore_scene()
	hud.snap_balance()
	hud.repair_mode(false)
	hud.clear_bottom()
	refresh_goal()
	mode = "title"
	hud.open_title(false)


# ------------------------------------------------------------------ app lifecycle

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			go_background()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			come_back()
		NOTIFICATION_WM_CLOSE_REQUEST:
			go_background()
			get_tree().quit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()


func go_background() -> void:
	if in_background:
		return
	in_background = true
	if repair:
		repair.set_paused("background", true)
	Game.save()


func come_back() -> void:
	if not in_background:
		return
	in_background = false
	if repair and repair.pauses.has("background"):
		hud.open_continue()


func _on_back() -> void:
	# Android back button: close what is open, or pause.
	if hud.is_overlay("continue"):
		_on_action("continue_bg", null)
	elif hud.is_overlay("hint"):
		_on_action("hint_close", null)
	elif hud.is_overlay("title"):
		Game.save()
		get_tree().quit()
	elif hud.is_overlay():
		_on_action("close", null)
	elif mode == "repair" or mode == "garage":
		_on_action("pause", null)
