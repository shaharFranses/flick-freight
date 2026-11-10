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


static func _call(fn: String):
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.ffPortal && window.ffPortal.%s()" % fn)
