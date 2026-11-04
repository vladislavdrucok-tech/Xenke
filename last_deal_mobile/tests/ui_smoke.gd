extends SceneTree
## UI-прохід: грає N днів через справжні кнопки інтерфейсу та робить скриншоти.
## Запуск (потрібен дисплей, напр. xvfb-run):
##   xvfb-run -a godot --path last_deal_mobile --rendering-driver opengl3 --resolution 720x1280 \
##       -s res://tests/ui_smoke.gd -- --ld-test --days=10 --shots=/шлях/до/папки

var main: Control
var shots_dir := ""
var days := 10
var errors := 0
var shot_n := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.split("=")[1])
		elif a.begins_with("--shots="):
			shots_dir = a.split("=")[1]
	run()


func wait(t: float) -> void:
	await create_timer(t).timeout


func shot(name: String) -> void:
	if shots_dir == "":
		return
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	shot_n += 1
	img.save_png("%s/%02d_%s.png" % [shots_dir, shot_n, name])


func press(b: Button) -> void:
	if b == null or not b.is_visible_in_tree() or b.disabled:
		var info := ""
		if main and main.shop_page:
			info = " busy=%s money=%d open=%s visible=%s" % [main.shop_page.busy, root.get_node("Game").session.money, root.get_node("Game").session.has_open_customer(), b.is_visible_in_tree() if b else false]
		printerr("UI: button not pressable: ", (b.text if b else "null"), info)
		errors += 1
		return
	b.pressed.emit()


func modal() -> Control:
	for ch in main.overlay.get_children():
		if ch.has_method("add_button") and not ch.is_queued_for_deletion():
			return ch
	return null


func modal_button(prefix: String) -> Button:
	var m := modal()
	if m == null:
		return null
	for b in m.find_children("*", "Button", true, false):
		if b.text.begins_with(prefix):
			return b
	return null


func run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await wait(0.6)
	await shot("tutorial")
	press(modal_button("Зрозуміло"))
	await wait(0.3)
	var ses: GameSession = root.get_node("Game").session
	var sp = main.shop_page
	var start_money := ses.money
	for d in days:
		var guard := 0
		while not ses.day_done() and guard < 20:
			guard += 1
			press(sp.btn_next)
			await wait(0.75)
			if d == 0 and guard == 1:
				await shot("customer")
			press(sp.btn_inspect)
			await wait(0.1)
			if d == 0 and guard == 1:
				await shot("inspected")
			var c := ses.current
			var est := (int(c["est_low"]) + int(c["est_high"])) / 2.0
			var target := int(est * 0.85)
			var rounds := 0
			while ses.has_open_customer() and rounds < 8:
				rounds += 1
				if ses.current_ask() <= target and ses.can_afford_ask():
					press(sp.btn_buy)
					break
				if not sp.offer_box.visible:
					press(sp.btn_haggle)
					await wait(0.05)
					if d == 0 and guard <= 2 and rounds == 1:
						await shot("haggle")
				# підганяємо пропозицію кнопками до цілі
				var want := mini(target, ses.money)
				var g2 := 0
				while sp.offer < want - 5 and g2 < 40:
					g2 += 1
					var before: int = sp.offer
					sp._on_step(2)
					if sp.offer == before:
						break
				while sp.offer > want and g2 < 80:
					g2 += 1
					var before2: int = sp.offer
					sp._on_step(1)
					if sp.offer == before2:
						break
				if sp.offer <= 0 or sp.btn_offer.disabled:
					break
				press(sp.btn_offer)
				await wait(0.45)
			if ses.has_open_customer():
				if sp.offer_box.visible:
					press(sp.btn_offer_back)
				press(sp.btn_decline)
			await wait(0.7)
		# продаж
		press(main.nav_buttons["inv"])
		await wait(0.2)
		if d == 0:
			await shot("inventory")
		if not main.inv_page.sell_all.disabled:
			press(main.inv_page.sell_all)
			await wait(0.3)
		# речі, що лежать довго, — продаємо
		for it in ses.inventory.items.duplicate():
			if ses.day - int(it["bought_day"]) >= 2:
				ses.sell(int(it["uid"]))
		press(main.nav_buttons["up"])
		await wait(0.2)
		if d == 1:
			await shot("upgrades")
		for u in Economy.UPGRADE_ORDER:
			if ses.money > int(Economy.UPGRADES[u]["cost"]) + 600:
				ses.buy_upgrade(u)
		press(main.nav_buttons["shop"])
		await wait(0.2)
		if d == 0:
			await shot("day_done")
		press(sp.btn_next)  # «Зачинити крамницю»
		await wait(0.5)
		if d == 0:
			await shot("summary")
		if ses.game_over:
			print("UI: bankrupt on day ", ses.day)
			break
		press(modal_button("Наступний день"))
		await wait(0.4)
	main._show_settings()
	await wait(0.4)
	await shot("settings")
	var m := modal()
	if m:
		m.close()
	print("UI RESULT: day=%d money=%d (start %d) bought=%d sold=%d errors=%d" % [ses.day, ses.money, start_money, ses.stats_total["bought"], ses.stats_total["sold"], errors])
	# перевірка: стан після «перезапуску» (повторне завантаження з JSON)
	var json := JSON.stringify(ses.to_dict())
	var s2 := GameSession.new()
	if not s2.from_dict(JSON.parse_string(json)) or JSON.stringify(s2.to_dict()) != json:
		printerr("UI: save roundtrip failed")
		errors += 1
	quit(1 if errors > 0 else 0)
