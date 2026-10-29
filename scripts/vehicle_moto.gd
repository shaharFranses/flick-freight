extends VehicleBase
## V1: courier motorcycle with a small rear rack (about a third of a truck bed) and a low
## rail. One parcel per bike: it rides off and the next courier pulls in (level "cap": 1),
## so every throw has to be extremely accurate. The rider counts as the "cab".

const RACK_W := 96.0
## A different courier each time: bike colour, jacket, helmet.
const LOOKS = [[Color("#E4572E"), Color("#3D8BDB"), Color("#FFD34E")],
	[Color("#3DDC97"), Color("#7A4EC2"), Color("#F2F2EE")],
	[Color("#F2B134"), Color("#E4572E"), Color("#3D8BDB")],
	[Color("#7A4EC2"), Color("#3DDC97"), Color("#E4572E")]]


func _init():
	full_text = "DELIVERY! NEXT BIKE"


func _define(_cfg: Dictionary) -> Dictionary:
	var half = RACK_W * 0.5
	return {
		"zone": Rect2(-half + 2, -300, RACK_W - 4, 300),
		"floor_w": RACK_W,
		"floor": Rect2(-half - 6, 0, RACK_W + 12, 10),
		"rear": Rect2(-half - 6, -16, 6, 16),
		# backrest bar at the front of the rack: stops boxes sliding into the rider
		"walls": [Rect2(half - 2, -44, 8, 54)],
		# rider + tank + handlebars, in front of the backrest
		"front": [PackedVector2Array([Vector2(half + 8, 10), Vector2(half + 8, -62), Vector2(half + 34, -96),
			Vector2(half + 66, -92), Vector2(half + 84, -40), Vector2(half + 130, -30), Vector2(half + 130, 10)])],
		"reach": Rect2(-half - 50, -320, RACK_W + 230, 340),
		"ride": 74.0,
		"wheels": [[Vector2(-30, 48), 26.0], [Vector2(half + 112, 48), 26.0]],
	}


func _draw_back(n: Node2D):
	var half = RACK_W * 0.5
	# frame and swing arm
	n.draw_line(Vector2(-30, 48), Vector2(half + 20, 22), NAVY, 9.0)
	n.draw_line(Vector2(-30, 48), Vector2(half + 20, 22), Color("#5B6574"), 5.0)
	n.draw_line(Vector2(half + 112, 48), Vector2(half + 92, -38), NAVY, 8.0)


func _draw_front(n: Node2D):
	var half = RACK_W * 0.5
	var look: Array = LOOKS[posmod(palette, LOOKS.size())]
	var red: Color = look[0]
	# rack: steel tray with a low rear rail
	n.draw_rect(Rect2(-half - 6, 0, RACK_W + 12, 10), NAVY)
	n.draw_rect(Rect2(-half - 4, 2, RACK_W + 8, 6), Color("#AEB6C2"))
	n.draw_rect(Rect2(-half - 6, -16, 6, 26), NAVY)
	n.draw_rect(Rect2(half - 3, -46, 10, 56), NAVY)  # backrest bar
	n.draw_rect(Rect2(half - 1, -44, 6, 52), Color("#AEB6C2"))
	for x in [-half + 20, 0.0, half - 20]:
		n.draw_line(Vector2(x, 10), Vector2(x * 0.3 + 10, 30), NAVY, 4.0)
	# body: seat, tank, front fairing
	var body = PackedVector2Array([Vector2(half, 18), Vector2(half, -8), Vector2(half + 60, -14),
		Vector2(half + 96, -40), Vector2(half + 124, -28), Vector2(half + 128, 18)])
	n.draw_colored_polygon(body, NAVY)
	n.draw_colored_polygon(Geometry2D.offset_polygon(body, -3)[0], red)
	n.draw_rect(Rect2(half + 2, -14, 56, 9), Color("#2E3440"))  # seat
	n.draw_circle(Vector2(half + 124, -22), 7, Color("#FFE27A"))  # headlight
	# rider: helmet, torso, arm to the bars
	var torso = PackedVector2Array([Vector2(half + 8, -10), Vector2(half + 22, -66), Vector2(half + 46, -66), Vector2(half + 52, -10)])
	n.draw_colored_polygon(torso, NAVY)
	n.draw_colored_polygon(Geometry2D.offset_polygon(torso, -3)[0], look[1])
	n.draw_line(Vector2(half + 40, -56), Vector2(half + 86, -40), NAVY, 9.0)
	n.draw_line(Vector2(half + 40, -56), Vector2(half + 86, -40), look[1], 5.0)
	n.draw_circle(Vector2(half + 36, -80), 17, NAVY)
	n.draw_circle(Vector2(half + 36, -80), 14, look[2])
	n.draw_rect(Rect2(half + 38, -84, 14, 8), Color("#BFE7F7"))  # visor
