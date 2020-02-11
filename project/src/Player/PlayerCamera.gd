extends Camera2D


export var do_position_when_map_up := true
export var do_position_when_map_down := true
export var max_zoom := 5.0

var _start_zoom := zoom
var _start_position := Vector2.ZERO

var remote_transform: RemoteTransform2D

onready var tween := $Tween


func _ready() -> void:
	if has_node("RemoteTransform2D"):
		remote_transform = $RemoteTransform2D


func toggle_map(map_up: bool, tween_time: float) -> void:
	set_tween(map_up, tween_time)
	tween.start()


func set_tween(map_up: bool, tween_time: float) -> void:
	if map_up:
		_start_position = position
		tween.interpolate_property(
				self,
				"zoom",
				zoom,
				Vector2(max_zoom,max_zoom),
				tween_time,
				Tween.TRANS_LINEAR,
				Tween.EASE_OUT_IN
		)
		if do_position_when_map_up:
			tween.interpolate_property(
					self,
					"position",
					position,
					Vector2.ZERO,
					tween_time,
					Tween.TRANS_LINEAR,
					Tween.EASE_OUT_IN
			)
	else:
		tween.interpolate_property(
				self,
				"zoom",
				zoom,
				_start_zoom,
				tween_time,
				Tween.TRANS_LINEAR,
				Tween.EASE_OUT_IN
		)
		if do_position_when_map_down:
			tween.interpolate_property(
					self,
					"position",
					position,
					_start_position,
					tween_time,
					Tween.TRANS_LINEAR,
					Tween.EASE_OUT_IN
			)