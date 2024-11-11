class_name Util

static func get_closest_point_on_polygon(p: Vector2, polygon: PackedVector2Array):
    var min_dist = INF
    var closest_point = null

    for i in range(-1, polygon.size() - 1):
        var q = Geometry2D.get_closest_point_to_segment(p, polygon[i], polygon[i + 1])
        var d = p.distance_to(q)
        if d < min_dist:
            min_dist = d
            closest_point = q

    return closest_point

static func distance_segment_to_polygon(p: Vector2, q: Vector2, polygon: PackedVector2Array):
    var d = INF
    for i in range(-1, polygon.size() - 1):
        var a = Geometry2D.get_closest_points_between_segments(p, q, polygon[i], polygon[i + 1])
        d = minf(d, a[0].distance_to(a[1]))
    return d

