class_name Fx
extends RefCounted
## One-shot particle bursts (Kenney particle pack textures, tinted via modulate).

const TEX_STAR = preload("res://art/kenney/star_06.png")
const TEX_SPARK = preload("res://art/kenney/spark_05.png")
const TEX_SMOKE = preload("res://art/kenney/smoke_04.png")
const TEX_RING = preload("res://art/kenney/circle_05.png")


static func burst(parent: Node, pos: Vector2, tex: Texture2D, color: Color, amount := 12,
		speed := 260.0, life := 0.6, scale := 0.5, gravity := 600.0, spread := 180.0, dir := Vector2.UP):
	var p = CPUParticles2D.new()
	p.texture = tex
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.angular_velocity_min = -360
	p.angular_velocity_max = 360
	p.scale_amount_min = scale * 0.6
	p.scale_amount_max = scale
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	g.colors = PackedColorArray([color, color, Color(color.r, color.g, color.b, 0.0)])
	p.color_ramp = g
	p.position = pos
	p.z_index = 20
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


static func delivered(parent: Node, pos: Vector2):
	burst(parent, pos, TEX_STAR, Color("#FFD34E"), 14, 380.0, 0.7, 0.32, 700.0, 70.0)
	burst(parent, pos, TEX_SPARK, Color(1, 1, 1), 8, 260.0, 0.4, 0.3, 0.0)


static func dust(parent: Node, pos: Vector2, strength := 1.0):
	burst(parent, pos, TEX_SMOKE, Color(0.85, 0.82, 0.76, 0.8), int(6 * strength) + 2, 120.0 * strength,
		0.6, 0.35, -40.0, 70.0, Vector2.UP)


static func shatter(parent: Node, pos: Vector2, color: Color):
	burst(parent, pos, TEX_SPARK, color, 18, 420.0, 0.7, 0.35, 900.0)
	burst(parent, pos, TEX_SMOKE, Color(0.9, 0.9, 0.9, 0.7), 6, 140.0, 0.6, 0.4, -30.0)


static func ring(parent: Node, pos: Vector2, color: Color, size := 1.2):
	var s = Sprite2D.new()
	s.texture = TEX_RING
	s.modulate = color
	s.position = pos
	s.scale = Vector2.ONE * 0.2
	s.z_index = 19
	s.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(s)
	var tw = s.create_tween().set_parallel()
	tw.tween_property(s, "scale", Vector2.ONE * size, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(s.queue_free)


static func splash(parent: Node, pos: Vector2):
	burst(parent, pos, TEX_RING, Color("#BFE7F7"), 14, 420.0, 0.7, 0.18, 1100.0, 35.0, Vector2.UP)
	ring(parent, pos, Color("#BFE7F7"), 1.0)
