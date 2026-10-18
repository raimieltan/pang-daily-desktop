class_name StoryBridge
extends Node
## Sound that crosses a cut. A scene change frees the director and everything it plays; this
## node lives on the root (autoload "StoryAudio"), so a sound started in one scene can run on
## under the black and fade out in the next: the J-cut (the next place heard before it is seen)
## and the L-cut (this place heard after it is gone). Beats ask for it through "enter" / "exit"
## (StoryDirector._exit). Plays on Master: comic pages mute the car's buses, not these.

const AMBIENCE := {
	"rain": preload("res://assets/audio/ambience/rain_loop.wav"),
	"crickets": preload("res://assets/audio/ambience/crickets_loop.wav"),
	"wind": preload("res://assets/audio/ambience/wind_loop.wav"),
	"dog": preload("res://assets/audio/ambience/dog_bark_far.wav"),
	"engine": preload("res://assets/audio/engine/i4_loop.wav"),
}

var _playing := {}


## Every sound a bridge can name: the ambience above and the story's one-shots.
static func sounds() -> Array:
	return AMBIENCE.keys() + StoryDialogue.SFX.keys()


static func stream_for(sound: String, loop: bool) -> AudioStream:
	var s: AudioStream = AMBIENCE.get(sound, StoryDialogue.SFX.get(sound))
	if s is AudioStreamWAV and loop:
		var w: AudioStreamWAV = s.duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		return w
	return s


## The bridge on the root (made on first use when the autoload is not there, as in tests).
static func node() -> StoryBridge:
	var tree := Engine.get_main_loop() as SceneTree
	var n := tree.root.get_node_or_null("StoryAudio") as StoryBridge
	if n == null:
		n = StoryBridge.new()
		n.name = "StoryAudio"
		tree.root.add_child(n)
	return n


## Start `sound` (a loop keeps going until release()); `fade_in` seconds from silence.
func play(sound: String, db := -8.0, loop := false, fade_in := 0.3) -> void:
	var stream := stream_for(sound, loop)
	if stream == null:
		return
	release(sound, 0.15)
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -60.0 if fade_in > 0.0 else db
	add_child(p)
	p.play()
	if fade_in > 0.0:
		create_tween().tween_property(p, "volume_db", db, fade_in)
	_playing[sound] = p
	if not loop:
		p.finished.connect(func():
			if _playing.get(sound) == p:
				_playing.erase(sound)
			p.queue_free())


func is_playing(sound: String) -> bool:
	return _playing.has(sound)


## Fade `sound` out over `seconds` and drop it.
func release(sound: String, seconds := 1.5) -> void:
	var p: AudioStreamPlayer = _playing.get(sound)
	if p == null:
		return
	_playing.erase(sound)
	if not is_instance_valid(p):
		return
	var t := create_tween()
	t.tween_property(p, "volume_db", -60.0, maxf(seconds, 0.05))
	t.tween_callback(p.queue_free)


func release_all(seconds := 1.0) -> void:
	for s in _playing.keys():
		release(s, seconds)
