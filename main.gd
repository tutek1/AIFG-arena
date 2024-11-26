extends Node2D

@onready var Arena = preload('res://arena.tscn')

var random_seed = -1
var last_seed = -1

var scores = []

var arena

func _ready():
    var args = OS.get_cmdline_user_args()
    var i = 0
    while i < args.size():
        match args[i]:
            '-seed':
                i += 1
                var nums = args[i].split(':')
                random_seed = int(nums[0])
                if nums.size() > 1:
                    last_seed = int(nums[1])
            _:
                print('usage: godot -- [-seed <int>]')
                get_tree().quit()
        i += 1
        
    start_game()

func start_game():
    arena = Arena.instantiate()
    if random_seed != -1:
        print('running game with seed %d' % random_seed)
        arena.random_seed = random_seed
        arena.use_agent = true

    arena.game_over.connect(on_game_over)
    add_child(arena)

func on_game_over():
    if last_seed != -1:
        scores.append(arena.score)

        if random_seed < last_seed:
            remove_child(arena)
            arena.queue_free()
            random_seed += 1
            start_game()
        else:
            var num_games = scores.size()
            var sum = 0
            for x in scores:
                sum += x
            var avg = 1.0 * sum / num_games
            print('scores: ' + str(scores))
            print('average score (%d games): %.1f' % [num_games, avg])

            if num_games >= 10:
                # Compute a one-sample t test for the average win rate.
                const t = 2.0   # approx. critical t value for upper-tail probability 0.025
                sum = 0
                for x in scores:
                    sum += (x - avg) ** 2
                var s = sqrt(sum / (num_games - 1))     # sample standard deviation
                var m = t * s / sqrt(num_games)
                print('~95%% confidence interval for win rate: [%.1f, %.1f]' % [avg - m, avg + m])
