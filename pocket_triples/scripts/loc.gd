class_name Loc
extends RefCounted
## Languages. All visible text lives in translations/strings.csv (key, en, uk). Nodes register the
## key and the numbers to put into it; switching language re-renders every registered text at once,
## so the current screen updates without touching the puzzle, the move history or the progress.

const LANGS := ["uk", "en"]
static var _bound: Array = []


## First launch: Ukrainian for a Ukrainian system, English for everything else.
static func detect(os_locale: String) -> String:
	var l := os_locale.to_lower().replace("-", "_")
	if l == "uk" or l.begins_with("uk_"):
		return "uk"
	return "en"


static func apply(lang: String) -> void:
	if not LANGS.has(lang):
		lang = "en"
	TranslationServer.set_locale(lang)
	refresh()


static func lang() -> String:
	return TranslationServer.get_locale().substr(0, 2)


static func t(key: String, args := {}) -> String:
	var s := TranslationServer.translate(key)
	if args.is_empty():
		return s
	return s.format(args)


## Remembers which key (and numbers) a node shows, sets the text now and after every language switch.
static func bind(node: Object, key: String, args := {}, prop := "text") -> void:
	for e in _bound:
		if e[0].get_ref() == node and e[3] == prop:
			e[1] = key
			e[2] = args
			node.set(prop, t(key, args))
			return
	_bound.append([weakref(node), key, args, prop])
	node.set(prop, t(key, args))


static func refresh() -> void:
	var alive := []
	for e in _bound:
		var n = e[0].get_ref()
		if n == null or not is_instance_valid(n):
			continue
		n.set(e[3], t(e[1], e[2]))
		alive.append(e)
	_bound = alive
