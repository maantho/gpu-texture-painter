class_name MaxRectsPacker
extends Object

# Public API
static func pack_into_square(rects: Array[Vector2]) -> Array[Rect2]:
    # rects: Array of Vector2(width, height)
    # Returns: Array<Rect2> placements in normalized 0–1 coordinates

    var total_area: int = 0
    var max_side: int = 0
    for r: Vector2 in rects:
        total_area += int(r.x * r.y)
        max_side = max(max_side, int(max(r.x, r.y)))

    var min_side: int = int(ceil(sqrt(total_area)))
    var low: int = max(min_side, max_side)
    var high: int = low
    while high < low * 2:
        high *= 2  # safe upper bound

    while low < high:
        var mid: int = (low + high) / 2
        if _can_pack(rects, mid):
            high = mid
        else:
            low = mid + 1

    var final_size: int = low
    var placements: Array[Rect2] = _do_pack(rects, final_size)

    # Normalize placements to 0–1 (both position and size)
    var normalized: Array[Rect2] = []
    for r: Rect2 in placements:
        var pos: Vector2 = r.position / final_size
        var size: Vector2 = r.size / final_size
        normalized.append(Rect2(pos, size))

    return normalized

# Internal helpers
static func _can_pack(rects: Array[Vector2], side: int) -> bool:
    var packer: _Atlas = _Atlas.new(side, side)
    for r: Vector2 in rects:
        var placed: Rect2 = packer.insert(int(r.x), int(r.y))
        if placed.size == Vector2.ZERO:
            return false
    return true

static func _do_pack(rects: Array[Vector2], side: int) -> Array[Rect2]:
    var packer: _Atlas = _Atlas.new(side, side)
    var placements: Array[Rect2] = []
    for r: Vector2 in rects:
        var placed: Rect2 = packer.insert(int(r.x), int(r.y))
        if placed.size == Vector2.ZERO:
            return []
        placements.append(placed)
    return placements

# Inner Atlas class implementing MaxRects
class _Atlas:
    var free_rects: Array[Rect2]
    var used_rects: Array[Rect2]

    func _init(w: int, h: int) -> void:
        free_rects = [Rect2(Vector2(0, 0), Vector2(w, h))]
        used_rects = []

    func insert(w: int, h: int) -> Rect2:
        var best_rect: Rect2 = Rect2()
        var best_short_side: float = INF
        var found: bool = false

        for fr: Rect2 in free_rects:
            if w <= fr.size.x and h <= fr.size.y:
                var leftover_h: float = abs(fr.size.y - h)
                var leftover_w: float = abs(fr.size.x - w)
                var short_side: float = min(leftover_h, leftover_w)
                if short_side < best_short_side:
                    best_rect = Rect2(fr.position, Vector2(w, h))
                    best_short_side = short_side
                    found = true

        if not found:
            return Rect2()  # sentinel (0,0,0,0)

        used_rects.append(best_rect)
        _split_free_rects(best_rect)
        _prune_free_list()
        return best_rect

    func _split_free_rects(placed: Rect2) -> void:
        var new_free: Array[Rect2] = []
        for fr: Rect2 in free_rects:
            if not fr.intersects(placed):
                new_free.append(fr)
                continue

            # Left
            if placed.position.x > fr.position.x:
                new_free.append(Rect2(fr.position, Vector2(placed.position.x - fr.position.x, fr.size.y)))
            # Right
            if placed.position.x + placed.size.x < fr.position.x + fr.size.x:
                new_free.append(Rect2(Vector2(placed.position.x + placed.size.x, fr.position.y),
                                      Vector2(fr.position.x + fr.size.x - (placed.position.x + placed.size.x), fr.size.y)))
            # Top
            if placed.position.y > fr.position.y:
                new_free.append(Rect2(fr.position, Vector2(fr.size.x, placed.position.y - fr.position.y)))
            # Bottom
            if placed.position.y + placed.size.y < fr.position.y + fr.size.y:
                new_free.append(Rect2(Vector2(fr.position.x, placed.position.y + placed.size.y),
                                      Vector2(fr.size.x, fr.position.y + fr.size.y - (placed.position.y + placed.size.y))))

        free_rects = new_free

    func _prune_free_list() -> void:
        var i: int = 0
        while i < free_rects.size():
            var j: int = i + 1
            while j < free_rects.size():
                if free_rects[i].encloses(free_rects[j]):
                    free_rects.remove_at(j)
                    j -= 1
                elif free_rects[j].encloses(free_rects[i]):
                    free_rects.remove_at(i)
                    i -= 1
                    break
                j += 1
            i += 1
