extends SceneTree
## godot --headless --path chicago -s res://tools/validate_assets_cli.gd -- <package folder>
## Prints every problem and exits 1, or prints "valid" and exits 0.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <package folder>")
		quit(2)
		return
	var dir := args[0]
	if dir.is_relative_path():
		dir = OS.get_environment("PWD").path_join(dir)
	var errs := AssetValidator.validate_package(dir)
	for e in errs:
		print("ERROR ", e)
	print("valid" if errs.is_empty() else "%d problem(s)" % errs.size())
	quit(0 if errs.is_empty() else 1)
