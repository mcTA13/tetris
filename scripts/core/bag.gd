class_name Bag
## 7種1巡（7-bag）。シードを渡すと同じ順番を再現できる。

var _rng := RandomNumberGenerator.new()
var _queue: Array[int] = []
var _taken := 0                 # これまでに取り出した数（1巡の区切りを知るため）


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
	_taken += 1
	return _queue.pop_front()


## 先頭から visible 個を見たあと、その 1 巡にまだ残っているミノ（見たものが 1 巡の終わりなら次の 1 巡の全種類）
func remaining_after(visible: int) -> Array[int]:
	var end := visible + (7 - (_taken + visible) % 7) % 7
	var rest := peek(maxi(end, visible)).slice(visible)
	if rest.is_empty():
		rest.assign(PieceData.ALL)
	return rest


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
