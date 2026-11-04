class_name UpgradesPage
extends ScrollContainer
## Покращення магазину + загальна статистика.

var box: VBoxContainer


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box = UIKit.vbox(12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(box)


func refresh() -> void:
	for ch in box.get_children():
		box.remove_child(ch)
		ch.queue_free()
	var ses := Game.session
	box.add_child(UIKit.pixel_label("Покращення крамниці", UIKit.FS_BIG + 4, UIKit.PINK))
	var icons := {"scanner": "res://assets/art/items/cpu.png", "neon": "res://assets/art/neon_sign.png", "charisma": "res://assets/icons/heart_full.png"}
	for id in Economy.UPGRADE_ORDER:
		var u: Dictionary = Economy.UPGRADES[id]
		var owned: bool = ses.upgrades.get(id, false)
		var p := UIKit.panel(UIKit.PANEL_2, UIKit.GREEN if owned else UIKit.BORDER)
		box.add_child(p)
		var h := UIKit.hbox(12)
		p.add_child(h)
		h.add_child(UIKit.icon_rect(icons[id], 72))
		var v := UIKit.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UIKit.label(u["name"], UIKit.FS, UIKit.AMBER))
		v.add_child(UIKit.label(u["desc"], UIKit.FS_SMALL, UIKit.MUTED, true))
		var b: Button
		if owned:
			b = UIKit.button("Встановлено", "neutral", UIKit.FS_SMALL + 2, 92)
			b.disabled = true
		else:
			b = UIKit.button("Купити\n%s" % UIKit.money_text(int(u["cost"])), "primary", UIKit.FS_SMALL + 2, 92)
			b.disabled = not ses.can_buy_upgrade(id)
			b.pressed.connect(_on_buy.bind(id, b))
		b.custom_minimum_size.x = 190
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)

	box.add_child(UIKit.pixel_label("Статистика", UIKit.FS_BIG + 4, UIKit.CYAN))
	var st := ses.stats_total
	var sp := UIKit.panel()
	box.add_child(sp)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 6)
	sp.add_child(g)
	var rows := [
		["Поточний день", str(ses.day)],
		["Днів відпрацьовано", str(st.get("days", 0))],
		["Куплено речей", "%d (%s)" % [st.get("bought", 0), UIKit.money_text(int(st.get("spent", 0)))]],
		["Продано речей", "%d (%s)" % [st.get("sold", 0), UIKit.money_text(int(st.get("revenue", 0)))]],
		["Прибуток з продажів", UIKit.money_text(int(st.get("profit", 0)))],
		["Сплачено оренди", UIKit.money_text(int(st.get("rent", 0)))],
		["Рекорд балансу", UIKit.money_text(int(st.get("max_money", 0)))],
		["Найкраща угода", ("%s, +%s" % [st.get("best_deal_name", ""), UIKit.money_text(int(st.get("best_deal", 0)))]) if int(st.get("best_deal", 0)) > 0 else "—"],
	]
	for r in rows:
		var a := UIKit.label(r[0], UIKit.FS_SMALL, UIKit.MUTED, true)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(a)
		var bl := UIKit.label(r[1], UIKit.FS_SMALL, UIKit.TEXT, true)
		bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		g.add_child(bl)
	if ses.history.size() > 0:
		box.add_child(UIKit.label("Баланс за останні дні", UIKit.FS, UIKit.TEXT))
		var chart := BalanceChart.new()
		chart.custom_minimum_size = Vector2(0, 180)
		chart.data = ses.history.map(func(h): return int(h.get("money", 0)))
		box.add_child(chart)


func _on_buy(id: String, b: Button) -> void:
	b.disabled = true
	if Game.session.buy_upgrade(id):
		Sfx.play("upgrade")
		Game.vibrate(40)
	refresh()


class BalanceChart extends Control:
	var data: Array = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UIKit.PANEL)
		if data.is_empty():
			return
		var mx := 100
		var mn := 0
		for v in data:
			mx = maxi(mx, int(v))
			mn = mini(mn, int(v))
		var n := data.size()
		var bw := minf(size.x / maxf(n, 1), 48.0)
		var span := float(mx - mn)
		var zero_y := size.y - 8 - (0 - mn) / span * (size.y - 16)
		for i in n:
			var v: int = int(data[i])
			var y := size.y - 8 - (v - mn) / span * (size.y - 16)
			var r := Rect2(size.x - (n - i) * bw + 2, minf(y, zero_y), maxf(bw - 4, 2), absf(zero_y - y))
			draw_rect(r, UIKit.GREEN if v >= 0 else UIKit.RED)
		draw_line(Vector2(0, zero_y), Vector2(size.x, zero_y), UIKit.BORDER, 2)
