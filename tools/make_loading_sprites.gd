extends SceneTree
## The loading screen's pictures (0.50): Pépito running, drawn by the game's own Render (his rig is no
## sprite sheet), eight steps of his stride side by side, at 3 real pixels per art pixel as in the game.
## The pygmies, the mounts and the missile are the game's own sheets (html/make_shell.py takes them as they are).
##
##   Godot --path . -s tools/make_loading_sprites.gd        (with a window: a SubViewport is drawn)
##
## Writes assets/src/loading/hero-run.png. Then: python html/make_shell.py

const Q := 3                       # real pixels per art pixel (the game draws him smoothed, 4 times finer)
const CW := 56                     # one picture, in art pixels
const CH := 84
const FRAMES := 8

class Painter extends Node2D:
	var render: Render
	func _draw() -> void:
		render.draw_hero(self, null)

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	Art.load_all()
	var vp = SubViewport.new()
	vp.size = Vector2i(CW * Q, CH * Q)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var r = Render.new()
	r.q = Q
	var run = Game.new_run({}, "endless")
	run.speed = 700.0
	run.relic = 0.0
	run.sx = 26 * Game.PIXEL                        # his feet at x 26, y 80 of the picture
	run.p.y = 80 * Game.PIXEL
	run.p.ground = true
	r.run = run
	var painter = Painter.new()
	painter.render = r
	painter.scale = Vector2(Q, Q)
	painter.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vp.add_child(painter)
	var sheet = Image.create(CW * Q * FRAMES, CH * Q, false, Image.FORMAT_RGBA8)
	for i in FRAMES:
		run.p.phase = i * TAU / FRAMES
		r.t = i * 0.045
		painter.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var im = vp.get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(im, Rect2i(0, 0, CW * Q, CH * Q), Vector2i(i * CW * Q, 0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/src/loading"))
	sheet.save_png("res://assets/src/loading/hero-run.png")
	print("assets/src/loading/hero-run.png : %d x %d" % [sheet.get_width(), sheet.get_height()])
	quit()
