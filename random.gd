class_name Random

const A = 6364136223846793005
const C = 1442695040888963407

static var rand = int(Time.get_unix_time_from_system() * 1000)

static func seed(x):
    rand = x

static func randf_range(lo, hi):
    rand = rand * A + C
    var r = rand >> 32
    if r < 0:
        r += 0x100000000
    return lo + (hi - lo) * r / 0x100000000
