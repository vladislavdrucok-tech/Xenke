class_name EndlessWorker
extends RefCounted
## Generates the next "Another Puzzle" on a background thread so the screen never waits for the
## solver. The generator itself limits both time and attempts; the caller falls back to the spare
## pool when nothing suitable came out.

var busy := false
var index := -1
var _thread: Thread
var _mutex := Mutex.new()
var _result: Dictionary = {}


func start(p_index: int, seed: int, tier: Dictionary, budget_usec := 1500000, attempts := 300) -> bool:
	if busy:
		return false
	index = p_index
	busy = true
	_result = {}
	_thread = Thread.new()
	_thread.start(_work.bind(seed, tier.duplicate(true), budget_usec, attempts))
	return true


func _work(seed: int, tier: Dictionary, budget_usec: int, attempts: int) -> void:
	var r := Generator.generate(seed, tier, budget_usec, attempts)
	_mutex.lock()
	_result = r
	_mutex.unlock()


## Empty while working; the generator's answer (plus "index") once it is done.
func poll() -> Dictionary:
	if not busy or _thread == null or _thread.is_alive():
		return {}
	_thread.wait_to_finish()
	busy = false
	_mutex.lock()
	var r := _result.duplicate(true)
	_mutex.unlock()
	r["index"] = index
	return r


func stop() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	busy = false
