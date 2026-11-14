class_name Analytics
extends RefCounted
## Gameplay events for the standalone build (docs/ANALYTICS.md). The page shell batches them
## and POSTs them to the configured endpoint; on the CrazyGames build, on desktop and in the
## bot every call is a no-op. Nothing personal is sent: an anonymous random id per browser.

static var log_to_console := false  # dev: print events when running outside the browser


static func track(event: String, props := {}):
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.ffAnalytics && window.ffAnalytics.track(%s, %s)" % [JSON.stringify(event), JSON.stringify(props)])
	elif log_to_console:
		print("[analytics] %s %s" % [event, JSON.stringify(props)])


## The fields every level event carries.
static func level_props(i: int) -> Dictionary:
	return {"level": Levels.number_of(i), "id": i + 1, "world": Levels.world_of(i).name}
