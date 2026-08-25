# ==============================================================================
# File: res://Systems/UpdateManager.gd
# Base Class: RefCounted (class_name UpdateManager)
# ==============================================================================

class_name UpdateManager
extends RefCounted

# 👉 Replace with your actual GitHub username and repository name
const GITHUB_REPO: String = "ryanbutinagumballmachine-alt/ownworld-dollhouse"

static func check_for_updates(caller_node: Node, on_result: Callable) -> void:
	if caller_node == null:
		return

	var http_request: HTTPRequest = HTTPRequest.new()
	caller_node.add_child(http_request)

	var url: String = "https://api.github.com/repos/%s/releases/latest" % GITHUB_REPO
	var headers: PackedStringArray = [
		"User-Agent: OwnWorld-Dollhouse-App",
		"Accept: application/vnd.github.v3+json"
	]

	http_request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		http_request.queue_free()

		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			on_result.call(false, "", "")
			return

		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not parsed is Dictionary:
			on_result.call(false, "", "")
			return

		var data: Dictionary = parsed as Dictionary
		var release_tag: String = str(data.get("tag_name", ""))
		var assets: Array = data.get("assets", [])
		var apk_download_url: String = ""

		for asset in assets:
			if asset is Dictionary:
				var asset_name: String = str(asset.get("name", ""))
				if asset_name.ends_with(".apk"):
					apk_download_url = str(asset.get("browser_download_url", ""))
					break

		var has_update: bool = not apk_download_url.is_empty()
		on_result.call(has_update, release_tag, apk_download_url)
	)

	http_request.request(url, headers)

static func download_update(apk_url: String) -> void:
	if not apk_url.is_empty():
		OS.shell_open(apk_url)
