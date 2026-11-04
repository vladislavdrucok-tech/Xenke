extends SceneTree
## Перевірка «перезапуску»: крок 1 грає й зберігає, крок 2 (новий процес) порівнює завантажений стан.
## godot --headless --path . -s res://tests/restart_check.gd -- --step=1 ; потім --step=2

const EXPECT := "user://restart_expect.json"
const BACKUP := "user://restart_backup.json"


func _initialize() -> void:
	var step := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--step="):
			step = int(a.split("=")[1])
	await process_frame
	var game = root.get_node("Game")
	if step == 1:
		SaveSystem.write_json(BACKUP, SaveSystem.read_json(SaveSystem.SAVE_PATH))
		game.new_game()
		var s: GameSession = game.session
		for i in 3:
			s.next_customer()
			s.inspect()
			if s.can_afford_ask():
				s.buy()
			else:
				s.decline()
		s.next_customer()  # клієнт посеред торгу теж має зберегтися
		s.offer(10)
		await process_frame  # відкладене автозбереження
		SaveSystem.write_json(EXPECT, s.to_dict())
		print("RESTART step1 money=%d inv=%d" % [s.money, s.inventory.count()])
		quit(0)
	else:
		var s: GameSession = game.session
		var exp := SaveSystem.read_json(EXPECT)
		var ok: bool = game.loaded_from_save and JSON.stringify(s.to_dict()) == JSON.stringify(exp)
		print("RESTART step2 loaded=%s money=%d inv=%d match=%s" % [game.loaded_from_save, s.money, s.inventory.count(), ok])
		var bk := SaveSystem.read_json(BACKUP)
		if bk.is_empty():
			SaveSystem.delete_save()
		else:
			SaveSystem.write_json(SaveSystem.SAVE_PATH, bk)
		quit(0 if ok else 1)
