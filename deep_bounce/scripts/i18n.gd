extends RefCounted
## Interface text in 12 languages. Strings live in res://i18n/<code>.json under stable keys; a value is a string
## or, for counted phrases, a dictionary of CLDR plural forms ("one", "few", "many", "other").
## Placeholders are named: {n}, {m}, {price}, {level}… The game title "Deep Bounce" is never translated.
## A key missing in a language falls back to English and is recorded in `missing` (shown by tests).

const LANGS := [
	["uk", "Українська"], ["en", "English"], ["pl", "Polski"], ["de", "Deutsch"], ["es", "Español"],
	["fr", "Français"], ["it", "Italiano"], ["pt_BR", "Português (Brasil)"], ["tr", "Türkçe"],
	["ja", "日本語"], ["ko", "한국어"], ["zh_CN", "简体中文"],
]

static var _tables := {}
static var missing := {}

static func codes() -> Array:
	var a: Array = []
	for l in LANGS:
		a.append(l[0])
	return a

static func native_name(code: String) -> String:
	for l in LANGS:
		if l[0] == code:
			return l[1]
	return code

static func table(code: String) -> Dictionary:
	if not _tables.has(code):
		var path := "res://i18n/%s.json" % code
		var d = {}
		if FileAccess.file_exists(path):
			d = JSON.parse_string(FileAccess.get_file_as_string(path))
		_tables[code] = d if typeof(d) == TYPE_DICTIONARY else {}
	return _tables[code]

static func detect(locale: String) -> String:
	## System locale → supported language. Regional variants map to their language (es_MX → es, pt_PT → pt_BR,
	## fr_CA → fr, de_AT → de); Traditional Chinese and anything unsupported → English.
	var l := locale.replace("-", "_")
	var parts := l.split("_")
	var lang := parts[0].to_lower()
	match lang:
		"uk", "pl", "de", "es", "fr", "it", "tr", "ja", "ko", "en":
			return lang
		"pt":
			return "pt_BR"
		"zh":
			for p in parts.slice(1):
				var u := String(p).to_upper()
				if u in ["HANT", "TW", "HK", "MO"]:
					return "en"
			return "zh_CN"
	return "en"

static func plural_form(code: String, n: int) -> String:
	## CLDR cardinal rules for integers.
	var m10 := n % 10
	var m100 := n % 100
	match code:
		"uk":
			if m10 == 1 and m100 != 11:
				return "one"
			if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
				return "few"
			return "many"
		"pl":
			if n == 1:
				return "one"
			if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
				return "few"
			return "many"
		"fr", "pt_BR":
			return "one" if n == 0 or n == 1 else "other"
		"ja", "ko", "zh_CN":
			return "other"
		_:
			return "one" if n == 1 else "other"

static func lookup(code: String, key: String):
	var t := table(code)
	if t.has(key):
		return t[key]
	if code != "en":
		missing["%s:%s" % [code, key]] = true
	var en := table("en")
	return en.get(key, key)

static func fill(s: String, args) -> String:
	if args is Dictionary:
		for k in args:
			s = s.replace("{%s}" % k, str(args[k]))
	elif args is Array:
		for i in args.size():
			s = s.replace("{%d}" % i, str(args[i]))
	return s

static func text(code: String, key: String, args = {}) -> String:
	var v = lookup(code, key)
	if v is Dictionary:
		v = v.get("other", v.values()[0])
	return fill(String(v), args)

static func text_n(code: String, key: String, n: int, args := {}) -> String:
	var v = lookup(code, key)
	var s := ""
	if v is Dictionary:
		var form := plural_form(code, n)
		s = String(v.get(form, v.get("other", v.get("many", ""))))
	else:
		s = String(v)
	var a := args.duplicate()
	a["n"] = n
	return fill(s, a)

static func placeholders(s: String) -> Array:
	var out: Array = []
	var re := RegEx.new()
	re.compile("\\{([a-z0-9_]+)\\}")
	for m in re.search_all(s):
		if not out.has(m.get_string(1)):
			out.append(m.get_string(1))
	out.sort()
	return out
