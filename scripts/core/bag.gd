class_name Bag
## 7種1巡（7-bag）。シードを渡すと同じ順番を再現できる。

var _rng := RandomNumberGenerator.new()
var _queue: Array[int] = []


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value


## 先頭から count 個を見る（取り出さない）
func peek(count: int) -> Array[int]:
	while _queue.size() < count:
		_refill()
	return _queue.slice(0, count)


func pop() -> int:
	if _queue.is_empty():
		_refill()
	return _queue.pop_front()


func _refill() -> void:
	var pieces: Array[int] = []
	pieces.assign(PieceData.ALL)
	# Fisher-Yates（RNGを固定するため shuffle() は使わない）
	for i in range(pieces.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := pieces[i]
		pieces[i] = pieces[j]
		pieces[j] = tmp
	_queue.append_array(pieces)
