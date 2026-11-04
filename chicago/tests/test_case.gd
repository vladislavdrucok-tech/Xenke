class_name TestCase
extends RefCounted
## Base for test files (tests/test_*.gd). Every method named test_* runs with a fresh new game.
## Assertions record failures instead of stopping, so one run reports everything.

var tree: SceneTree
var failures: Array[String] = []
var current := ""

func before_each() -> void:
	pass

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])

func eq(a: Variant, b: Variant, msg: String = "") -> void:
	if not (typeof(a) == typeof(b) and a == b) and not ((typeof(a) in [TYPE_INT, TYPE_FLOAT]) and (typeof(b) in [TYPE_INT, TYPE_FLOAT]) and float(a) == float(b)):
		failures.append("%s: %s expected %s, got %s" % [current, msg, var_to_str(b), var_to_str(a)])

func near(a: float, b: float, eps: float, msg: String = "") -> void:
	if absf(a - b) > eps:
		failures.append("%s: %s expected %.4f±%.4f, got %.4f" % [current, msg, b, eps, a])

func frames(n: int) -> void:
	for i in n:
		await tree.physics_frame
