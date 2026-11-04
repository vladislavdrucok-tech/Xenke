class_name ArtImporter
extends RefCounted
## Brings a delivered art package into the project, only if AssetValidator finds nothing wrong with it.
## Files are copied from <package>/assets/<category>/... to <dest>/<category>/... (default res://art); the manifest
## entries are rewritten to the new paths and merged into <dest>/manifest.json by id. An entry is replaced only by a
## higher "version" (no silent downgrades). The original package is left as it is (keep it as the source).
##
## CLI: godot --headless --path chicago -s res://tools/import_art_cli.gd -- <package folder>
## then: godot --headless --path chicago --import   (so Godot imports the new PNGs)

static func import_package(src: String, dest: String = "res://art") -> Array[String]:
	var errs := AssetValidator.validate_package(src)
	if not errs.is_empty():
		errs.push_front("package not valid - nothing imported")
		return errs
	var pkg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(src.path_join("manifest.json")))
	var mpath := dest.path_join("manifest.json")
	var current := {"assets": []}
	if FileAccess.file_exists(mpath):
		var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(mpath))
		if typeof(c) == TYPE_DICTIONARY:
			current = c
	var by_id := {}
	for a in current.get("assets", []):
		by_id[String(a.id)] = a
	var dest_abs := ProjectSettings.globalize_path(dest) if dest.begins_with("res://") or dest.begins_with("user://") else dest
	for a in pkg.assets:
		var id := String(a.id)
		if by_id.has(id) and int(by_id[id].get("version", 0)) >= int(a.get("version", 0)):
			errs.append("asset '%s': version %s is not newer than the imported %s - skipped" % [id, a.get("version"), by_id[id].get("version")])
			continue
		var entry: Dictionary = a.duplicate(true)
		for rel in _files_of(a):
			var to_rel := String(rel).trim_prefix("assets/")
			DirAccess.make_dir_recursive_absolute(dest_abs.path_join(to_rel.get_base_dir()))
			var e := DirAccess.copy_absolute(src.path_join(rel), dest_abs.path_join(to_rel))
			if e != OK:
				errs.append("asset '%s': copy %s failed (%s)" % [id, rel, error_string(e)])
		if entry.has("files"):
			entry.files = dest.path_join(String(entry.files).trim_prefix("assets/"))
		if entry.has("shadow"):
			entry.shadow = dest.path_join(String(entry.shadow).trim_prefix("assets/"))
		if entry.has("layers"):
			for k in entry.layers:
				entry.layers[k] = dest.path_join(String(entry.layers[k]).trim_prefix("assets/"))
		if entry.has("variants"):
			var vs := []
			for v in entry.variants:
				vs.append(dest.path_join(String(v).trim_prefix("assets/")))
			entry.variants = vs
		entry["package"] = String(pkg.get("package", ""))
		by_id[id] = entry
	current.assets = by_id.values()
	var f := FileAccess.open(mpath, FileAccess.WRITE)
	if f == null:
		errs.append("cannot write " + mpath)
		return errs
	f.store_string(JSON.stringify(current, "\t", true))
	f.close()
	return errs

static func _files_of(a: Dictionary) -> Array:
	var out := []
	if a.has("files") and a.has("states"):
		var mirror: Dictionary = a.get("mirror", {})
		for state in a.states:
			for d in a.directions:
				if mirror.has(d) and mirror[d] != null:
					continue
				for i in int(a.states[state].frames):
					out.append(String(a.files).replace("{state}", state).replace("{dir}", String(d)).replace("{nn}", "%02d" % i))
	if a.has("shadow"):
		out.append(a.shadow)
	if a.has("layers"):
		out.append_array(a.layers.values())
	if a.has("variants"):
		out.append_array(a.variants)
	return out
