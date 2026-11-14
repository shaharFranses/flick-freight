class_name Portal
extends RefCounted
## CrazyGames SDK v3 events. The page shell (custom_html/custom_shell.html) loads and inits
## the SDK and exposes window.ffPortal; every call here is a no-op off the web, off
## CrazyGames, or when the SDK didn't load.


static func gameplay_start():
	_call("gameplayStart")


static func gameplay_stop():
	_call("gameplayStop")


## Big moments only (CrazyGames: not every level end): a world's final level beaten.
static func happytime():
	_call("happytime")


## The save kept on the player's CrazyGames account (Data module), "" when there is none.
static func save_get() -> String:
	if not OS.has_feature("web"):
		return ""
	var r = JavaScriptBridge.eval("(window.ffPortal && window.ffPortal.saveGet) ? window.ffPortal.saveGet() : ''")
	return r if r is String else ""


static func save_set(text: String):
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.ffPortal && window.ffPortal.saveSet && window.ffPortal.saveSet(%s)" % JSON.stringify(text))


static func _call(fn: String):
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.ffPortal && window.ffPortal.%s()" % fn)
