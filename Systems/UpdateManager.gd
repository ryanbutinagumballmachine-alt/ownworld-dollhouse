# ==============================================================================
# OWNWORLD — IN-APP UPDATE MANAGER & APK INSTALLER (SCOPED STORAGE RESILIENT)
# File: res://Systems/UpdateManager.gd
# Base Class: RefCounted (class_name UpdateManager)
# ==============================================================================

class_name UpdateManager
extends RefCounted

const GITHUB_REPO: String = "ryanbutinagumballmachine-alt/ownworld-dollhouse"
const DEFAULT_TIMEOUT_SECONDS: float = 15.0
const DOWNLOAD_TIMEOUT_SECONDS: float = 90.0

enum CheckResult {
	UPDATE_AVAILABLE,
	UP_TO_DATE,
	NO_APK_FOUND,
	ERROR
}


## Reads the installed application version from project configuration.
static func get_current_app_version() -> String:
	var ver: String = str(ProjectSettings.get_setting("application/config/version", "1.0.0")).strip_edges()
	return ver if not ver.is_empty() else "1.0.0"


## Queries GitHub releases API asynchronously with mobile network resilience.
static func check_for_updates(caller_node: Node, on_result: Callable) -> void:
	if caller_node == null:
		return

	var current_version: String = get_current_app_version()
	var http_request: HTTPRequest = HTTPRequest.new()
	http_request.use_threads = true
	http_request.timeout = DEFAULT_TIMEOUT_SECONDS
	http_request.max_redirects = 8
	http_request.accept_gzip = false
	caller_node.add_child(http_request)

	var url: String = "https://api.github.com/repos/%s/releases/latest" % GITHUB_REPO
	var headers: PackedStringArray = [
		"User-Agent: OwnWorld-Dollhouse-App/1.0 (Godot Engine; Android/Mobile)",
		"Accept: application/vnd.github.v3+json",
		"X-GitHub-Api-Version: 2022-11-28"
	]

	http_request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		http_request.queue_free()

		if result != HTTPRequest.RESULT_SUCCESS:
			var err_desc: String = _translate_http_result_code(result)
			on_result.call(CheckResult.ERROR, "", "", "Network error: %s" % err_desc)
			return

		if response_code == 403:
			on_result.call(CheckResult.ERROR, "", "", "GitHub API rate limit exceeded. Please try again later.")
			return
		elif response_code == 404:
			on_result.call(CheckResult.ERROR, "", "", "No releases published yet on repository.")
			return
		elif response_code != 200:
			on_result.call(CheckResult.ERROR, "", "", "Server returned HTTP %d" % response_code)
			return

		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not parsed is Dictionary:
			on_result.call(CheckResult.ERROR, "", "", "Invalid JSON payload received from update server.")
			return

		var data: Dictionary = parsed as Dictionary
		var release_tag: String = str(data.get("tag_name", "")).strip_edges()
		var assets: Array = data.get("assets", [])
		var apk_download_url: String = ""

		for asset: Variant in assets:
			if asset is Dictionary:
				var asset_name: String = str((asset as Dictionary).get("name", ""))
				if asset_name.ends_with(".apk"):
					apk_download_url = str((asset as Dictionary).get("browser_download_url", ""))
					break

		if release_tag.is_empty():
			on_result.call(CheckResult.ERROR, "", "", "No release tag found on repository.")
			return

		if not is_remote_version_newer(current_version, release_tag):
			on_result.call(CheckResult.UP_TO_DATE, release_tag, "", "You are on the latest version (%s)" % current_version)
			return

		if apk_download_url.is_empty():
			on_result.call(CheckResult.NO_APK_FOUND, release_tag, "", "New version %s found, but no APK package attached." % release_tag)
			return

		on_result.call(CheckResult.UPDATE_AVAILABLE, release_tag, apk_download_url, "New update available: %s" % release_tag)
	)

	var err: Error = http_request.request(url, headers)
	if err != OK:
		http_request.queue_free()
		on_result.call(CheckResult.ERROR, "", "", "Failed to initiate update connection (Error %d)." % int(err))


## Returns the 100% permission-safe app sandbox path for package updates
static func get_apk_target_path() -> String:
	return "user://update.apk"


## Downloads the remote APK file with polled progress callbacks and triggers installation.
static func download_and_install_update(caller_node: Node, apk_url: String, on_progress: Callable, on_complete: Callable, on_error: Callable) -> void:
	if caller_node == null or apk_url.is_empty():
		if on_error.is_valid(): on_error.call("Invalid download parameters")
		return

	var target_file_path: String = get_apk_target_path()
	if FileAccess.file_exists(target_file_path):
		DirAccess.remove_absolute(target_file_path)

	var http_downloader: HTTPRequest = HTTPRequest.new()
	http_downloader.use_threads = true
	http_downloader.timeout = DOWNLOAD_TIMEOUT_SECONDS
	http_downloader.max_redirects = 8
	http_downloader.download_file = target_file_path
	caller_node.add_child(http_downloader)

	var progress_timer: Timer = Timer.new()
	progress_timer.wait_time = 0.15
	progress_timer.autostart = true
	caller_node.add_child(progress_timer)

	progress_timer.timeout.connect(func() -> void:
		if not is_instance_valid(http_downloader):
			progress_timer.queue_free()
			return
		var body_size: int = http_downloader.get_body_size()
		var downloaded: int = http_downloader.get_downloaded_bytes()
		if on_progress.is_valid():
			var percent: float = clampf(float(downloaded) / float(body_size), 0.0, 1.0) if body_size > 0 else 0.0
			on_progress.call(percent, downloaded, maxi(body_size, 0))
	)

	http_downloader.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		progress_timer.stop()
		progress_timer.queue_free()
		http_downloader.queue_free()

		if result != HTTPRequest.RESULT_SUCCESS or (response_code != 200 and response_code != 302):
			if on_error.is_valid():
				var reason: String = _translate_http_result_code(result) if result != HTTPRequest.RESULT_SUCCESS else "HTTP %d" % response_code
				on_error.call("Download failed (%s)" % reason)
			return

		if on_complete.is_valid():
			on_complete.call()

		install_apk_file(target_file_path)
	)

	var headers: PackedStringArray = [
		"User-Agent: OwnWorld-Dollhouse-App/1.0 (Godot Engine; Android/Mobile)",
		"Accept: application/octet-stream"
	]

	var err: Error = http_downloader.request(apk_url, headers)
	if err != OK and on_error.is_valid():
		progress_timer.queue_free()
		http_downloader.queue_free()
		on_error.call("Failed to initiate download stream (Error %d)." % int(err))


## Invokes native package installer on Android via FileProvider or opens target file in OS shell.
static func install_apk_file(apk_file_path: String) -> void:
	var global_path: String = ProjectSettings.globalize_path(apk_file_path)

	if OS.has_feature("android"):
		var android_runtime: Object = Engine.get_singleton("AndroidRuntime") if Engine.has_singleton("AndroidRuntime") else null
		if android_runtime != null:
			var activity: Object = android_runtime.getActivity()
			var context: Object = android_runtime.getApplicationContext()

			var FileClass: JavaClass = JavaClassWrapper.wrap("java.io.File")
			var IntentClass: JavaClass = JavaClassWrapper.wrap("android.content.Intent")
			var UriClass: JavaClass = JavaClassWrapper.wrap("android.net.Uri")
			var BuildClass: JavaClass = JavaClassWrapper.wrap("android.os.Build$VERSION")

			var apk_file: Variant = FileClass.new(global_path)
			var intent: Variant = IntentClass.new(IntentClass.ACTION_VIEW)

			if BuildClass.SDK_INT >= 24:
				var FileProviderClass: JavaClass = null
				if ClassDB.class_exists("JavaClassWrapper"):
					FileProviderClass = JavaClassWrapper.wrap("androidx.core.content.FileProvider")

				var authority: String = str(context.getPackageName()) + ".fileprovider"
				var content_uri: Variant = null

				if FileProviderClass != null:
					content_uri = FileProviderClass.getUriForFile(context, authority, apk_file)

				if content_uri != null:
					intent.setDataAndType(content_uri, "application/vnd.android.package-archive")
					intent.addFlags(IntentClass.FLAG_GRANT_READ_URI_PERMISSION)
				else:
					intent.setDataAndType(UriClass.fromFile(apk_file), "application/vnd.android.package-archive")
			else:
				intent.setDataAndType(UriClass.fromFile(apk_file), "application/vnd.android.package-archive")

			intent.addFlags(IntentClass.FLAG_ACTIVITY_NEW_TASK)
			activity.startActivity(intent)
			return

	OS.shell_open(global_path)


## Compares two semver strings (e.g. "1.0.22" vs "1.0.23").
static func is_remote_version_newer(local_ver_str: String, remote_ver_str: String) -> bool:
	var clean_local: String = local_ver_str.trim_prefix("v").trim_prefix("V").strip_edges()
	var clean_remote: String = remote_ver_str.trim_prefix("v").trim_prefix("V").strip_edges()

	if clean_local == clean_remote:
		return false

	var local_parts: PackedStringArray = clean_local.split(".")
	var remote_parts: PackedStringArray = clean_remote.split(".")

	var max_len: int = maxi(local_parts.size(), remote_parts.size())
	for i: int in range(max_len):
		var local_num: int = local_parts[i].to_int() if i < local_parts.size() and local_parts[i].is_valid_int() else 0
		var remote_num: int = remote_parts[i].to_int() if i < remote_parts.size() and remote_parts[i].is_valid_int() else 0

		if remote_num > local_num:
			return true
		elif remote_num < local_num:
			return false

	return false


static func _translate_http_result_code(result_code: int) -> String:
	match result_code:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect to server. Check your network connection."
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "DNS resolution failed. Check internet access."
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection error / socket reset."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS/SSL security handshake failed."
		HTTPRequest.RESULT_NO_RESPONSE:
			return "No response from server."
		HTTPRequest.RESULT_TIMEOUT:
			return "Request timed out."
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "Request failed to send."
		_:
			return "Code %d" % result_code
