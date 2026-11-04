extends SceneTree
## godot --headless --path chicago -s res://tools/import_art_cli.gd -- <package folder> [dest, default res://art]
## Validates, then imports. Run `godot --headless --path chicago --import` afterwards.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <package folder> [dest]")
		quit(2)
		return
	var src := args[0]
	if src.is_relative_path():
		src = OS.get_environment("PWD").path_join(src)
	var errs := ArtImporter.import_package(src, args[1] if args.size() > 1 else "res://art")
	for e in errs:
		print("ERROR ", e)
	print("imported" if errs.is_empty() else "%d problem(s)" % errs.size())
	quit(0 if errs.is_empty() else 1)
