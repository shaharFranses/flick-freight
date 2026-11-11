extends VehicleBase
## V1: courier motorcycle with a small rear rack (about a third of a truck bed) and a low
## rail. One parcel per bike: it rides off and the next courier pulls in (level "cap": 1),
## so every throw has to be extremely accurate. The rider counts as the "cab".

const RACK_W := 96.0
## A different courier each time: bike colour, jacket, helmet.
const LOOKS = [[ArtPalette.CORAL, ArtPalette.BLUE, ArtPalette.GOLD],
	[ArtPalette.MINT, ArtPalette.SLATE_BLUE, ArtPalette.CREAM],
	[ArtPalette.AMBER, ArtPalette.CORAL, ArtPalette.BLUE],
	[ArtPalette.BLUE, ArtPalette.MINT, ArtPalette.CORAL]]


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
	# frame, swing arm and front fork
	ArtDraw.ink_line(n, Vector2(-30, 48), Vector2(half + 20, 22), ArtPalette.STEEL_LIGHT, 10.0, 2.6)
	ArtDraw.ink_line(n, Vector2(half + 112, 48), Vector2(half + 92, -38), ArtPalette.CHROME, 9.0, 2.6)


func _draw_front(n: Node2D):
	var half = RACK_W * 0.5
	var look: Array = LOOKS[posmod(palette, LOOKS.size())]
	# rack: steel tray with a low rear rail and a backrest bar (the bed ends)
	for x in [-half + 20, 0.0, half - 20]:
		n.draw_line(Vector2(x, 8), Vector2(x * 0.3 + 10, 30), NAVY, 4.0)
	ArtDraw.ink_rect(n, Rect2(-half - 6, 0, RACK_W + 12, 10), ArtPalette.DECK_PLATE, 2.6)
	ArtDraw.ink_rect(n, Rect2(-half - 6, -16, 6, 26), ArtPalette.CHROME, 2.0)
	ArtDraw.ink_rect(n, Rect2(half - 2, -44, 8, 54), ArtPalette.CHROME, 2.0)
	# body: seat, tank, front fairing
	var body = PackedVector2Array([Vector2(half, 18), Vector2(half, -8), Vector2(half + 60, -14),
		Vector2(half + 96, -40), Vector2(half + 124, -28), Vector2(half + 128, 18)])
	var inner = ArtDraw.ink_poly(n, body, look[0], ArtDraw.PROP)
	ArtDraw.clip_rect(n, inner, Rect2(half, 6, 130, 12), look[0].darkened(0.22))
	ArtDraw.ink_rect(n, Rect2(half + 2, -17, 56, 11), ArtPalette.TYRE, 2.6, 4.0)  # seat
	ArtDraw.ink_circle(n, Vector2(half + 122, -22), 8, ArtPalette.HEADLIGHT, 3.0)
	# rider: torso, arm to the bars, helmet with a visor (no face)
	var torso = PackedVector2Array([Vector2(half + 8, -10), Vector2(half + 22, -66), Vector2(half + 46, -66), Vector2(half + 52, -10)])
	ArtDraw.ink_poly(n, torso, look[1], ArtDraw.PROP)
	ArtDraw.ink_line(n, Vector2(half + 40, -56), Vector2(half + 86, -40), look[1], 10.0, 3.0)
	ArtDraw.ink_circle(n, Vector2(half + 36, -80), 17, look[2], ArtDraw.PROP)
	ArtDraw.ink_rect(n, Rect2(half + 37, -86, 16, 11), ArtPalette.GLASS, 2.6)
