class_name Touge01Layout
## "Pass 1", downhill. Corner sequence from docs/research/touge-arcade-handling.md (map spec):
## radii follow Japan's Road Structure Ordinance minimums for 20–40 km/h design speeds.
## Arc "a" > 0 turns right. "g" is grade (negative = downhill).

const NAME := "Pass 1 · Downhill"
const START_DISTANCE := 25.0
## Finish line distance back from the end of the road (60 m after the final hairpin, then run-off).
const FINISH_BACK := 22.0

const SEGMENTS := [
	{ "s": 120.0, "g": -0.04 },                        # start straight, gallery
	{ "r": 90.0, "a": -40.0, "g": -0.06 },              # 1  fast sweeper L
	{ "s": 40.0, "g": -0.07 },
	{ "r": 45.0, "a": 60.0, "g": -0.07 },               # 2  medium R
	{ "s": 50.0, "g": -0.07 },
	{ "r": 15.0, "a": -170.0, "g": -0.04 },             # 3  hairpin L (first handbrake)
	{ "s": 90.0, "g": -0.08 },                          # 4  chute
	{ "r": 50.0, "a": 40.0, "g": -0.06 },               # 5  decreasing radius R ...
	{ "r": 25.0, "a": 60.0, "g": -0.06 },               #    ... tightens
	{ "s": 30.0, "g": -0.06 },
	{ "r": 35.0, "a": -50.0, "g": -0.06 },              # 6  esses L
	{ "s": 40.0, "g": -0.06 },
	{ "r": 35.0, "a": 50.0, "g": -0.06 },               #    esses R
	{ "s": 60.0, "g": -0.05 },
	{ "s": 45.0, "g": 0.025 },                          # 7  blind crest rise
	{ "r": 120.0, "a": -15.0, "g": -0.05 },             #    kink L over the top
	{ "s": 40.0, "g": -0.09 },
	{ "r": 15.0, "a": 170.0, "g": -0.05 },              # 8a hairpin R
	{ "s": 60.0, "g": -0.10 },                          #    10% section
	{ "r": 18.0, "a": -170.0, "g": -0.06 },             # 8b hairpin L
	{ "s": 50.0, "g": -0.08 },
	{ "r": 40.0, "a": 55.0, "g": -0.06, "camber": -0.03 },  # 9  off-camber R
	{ "s": 40.0, "g": -0.06 },
	{ "r": 30.0, "a": -60.0, "g": -0.06 },              # 10 double apex L ...
	{ "s": 15.0, "g": -0.06 },
	{ "r": 30.0, "a": -60.0, "g": -0.06 },              #    ... second apex
	{ "s": 150.0, "g": -0.06 },                         # 11 overtaking straight
	{ "r": 20.0, "a": 170.0, "g": -0.04 },              # 12 final hairpin R
	{ "s": 82.0, "g": -0.03 },                          #    finish 60 m after exit, run-off
]
