class_name Random

# A linear congruential random number generator.
#
# We use our own random number generator so that games will be reproducible in
# high-speed simulations.  Godot's generator does not seem to always produce
# reproducible results, even when we seed it with a constant value.  It may be
# that Godot calls its own generator internally at times that vary with the
# simulation speed.

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

static func randi_range(lo, hi):
    var x = Random.randf_range(0.0, 1.0)
    return int(lo + (hi - lo + 1) * x)
