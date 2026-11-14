extends VehicleBase
## V1: courier scooter with a small rear cargo tray (about a third of a truck bed) and a low
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
		"wheels": [[Vector2(-4, 48), 26.0], [Vector2(half + 116, 48), 26.0]],
	}


func _draw_back(n: Node2D):
	var half = RACK_W * 0.5
	# swing arm to the rear wheel, front fork, and the stand under the cargo tray
	ArtDraw.ink_line(n, Vector2(-4, 48), Vector2(half + 30, 30), ArtPalette.STEEL_LIGHT, 10.0, 2.6)
	ArtDraw.ink_line(n, Vector2(half + 116, 48), Vector2(half + 100, -30), ArtPalette.CHROME, 9.0, 2.6)
	for x in [-half + 14, half - 14]:
		ArtDraw.ink_line(n, Vector2(x, 8), Vector2(x * 0.4, 30), ArtPalette.STEEL_LIGHT, 7.0, 2.6)


func _draw_front(n: Node2D):
	var half = RACK_W * 0.5
	var look: Array = LOOKS[posmod(palette, LOOKS.size())]
	var paint: Color = look[0]
	# rear body over the back wheel, flat floorboard, tall front shield: a delivery scooter
	var rear = PackedVector2Array([Vector2(-half + 4, 12), Vector2(half + 56, 12), Vector2(half + 64, 40),
		Vector2(half + 30, 46), Vector2(30, 30), Vector2(-half + 16, 30)])
	var inner = ArtDraw.ink_poly(n, rear, paint, ArtDraw.PROP)
	ArtDraw.clip_rect(n, inner, Rect2(-half, 30, 200, 20), paint.darkened(0.22))
	ArtDraw.ink_rect(n, Rect2(half + 52, 38, 50, 10), ArtPalette.STEEL_LIGHT, 2.6, 3.0)  # floorboard
	var shield = PackedVector2Array([Vector2(half + 92, 50), Vector2(half + 94, -26), Vector2(half + 104, -36),
		Vector2(half + 116, -30), Vector2(half + 124, 6), Vector2(half + 112, 50)])
	inner = ArtDraw.ink_poly(n, shield, paint, ArtDraw.PROP)
	ArtDraw.clip_rect(n, inner, Rect2(half + 90, 24, 40, 30), paint.darkened(0.22))
	# front mudguard over the wheel
	n.draw_arc(Vector2(half + 116, 48), 33, deg_to_rad(-150), deg_to_rad(-20), 14, ArtPalette.INK, 11.0)
	n.draw_arc(Vector2(half + 116, 48), 33, deg_to_rad(-147), deg_to_rad(-23), 14, paint, 6.0)
	ArtDraw.ink_circle(n, Vector2(half + 121, -12), 8, ArtPalette.HEADLIGHT, 3.0)
	# handlebar with a mirror
	ArtDraw.ink_line(n, Vector2(half + 102, -34), Vector2(half + 92, -52), ArtPalette.CHROME, 7.0, 2.6)
	ArtDraw.ink_circle(n, Vector2(half + 90, -54), 6, ArtPalette.TYRE, 2.6)
	ArtDraw.ink_line(n, Vector2(half + 96, -50), Vector2(half + 106, -66), ArtPalette.CHROME, 4.0, 2.0)
	ArtDraw.ink_circle(n, Vector2(half + 108, -70), 7, ArtPalette.GLASS, 2.6)
	ArtDraw.ink_rect(n, Rect2(half + 8, 0, 52, 13), ArtPalette.TYRE, 2.6, 5.0)  # seat
	# rider: leg down to the floorboard, torso, arm to the bars, helmet with a visor (no face)
	ArtDraw.ink_line(n, Vector2(half + 34, 2), Vector2(half + 70, 8), ArtPalette.SLATE, 13.0, 3.0)
	ArtDraw.ink_line(n, Vector2(half + 70, 8), Vector2(half + 76, 36), ArtPalette.SLATE, 12.0, 3.0)
	ArtDraw.ink_rect(n, Rect2(half + 66, 30, 26, 10), ArtPalette.TYRE, 2.6, 4.0)  # boot
	var torso = PackedVector2Array([Vector2(half + 10, 2), Vector2(half + 22, -58), Vector2(half + 48, -58), Vector2(half + 50, 2)])
	ArtDraw.ink_poly(n, torso, look[1], ArtDraw.PROP)
	ArtDraw.ink_line(n, Vector2(half + 40, -46), Vector2(half + 88, -50), look[1], 11.0, 3.0)
	ArtDraw.ink_circle(n, Vector2(half + 37, -74), 18, look[2], ArtDraw.PROP)
	ArtDraw.ink_rect(n, Rect2(half + 39, -81, 17, 12), ArtPalette.GLASS, 2.6, 3.0)
	# cargo tray: an open delivery box, drawn last so the cargo sits inside it
	ArtDraw.ink_rect(n, Rect2(half - 2, -44, 8, 56), ArtPalette.CHROME, 2.0)  # backrest bar
	var tray = Rect2(-half - 6, -16, RACK_W + 12, 28)
	ArtDraw.ink_rect(n, tray, ArtPalette.CREAM, ArtDraw.PROP, 4.0)
	n.draw_rect(Rect2(tray.position + Vector2(4, 19), Vector2(tray.size.x - 8, 6)), ArtPalette.CREAM_SHADE)
	n.draw_rect(Rect2(tray.position + Vector2(4, 9), Vector2(tray.size.x - 8, 5)), paint)
	# parcel mark, so the tray reads as "put the box here"
	var c = tray.get_center() + Vector2(0, 1)
	ArtDraw.ink_rect(n, Rect2(c - Vector2(10, 9), Vector2(20, 18)), ArtPalette.BOX, 2.6, 2.0)
	n.draw_line(c + Vector2(0, -8), c + Vector2(0, 8), ArtPalette.AMBER_SHADE, 3.0)
