# ==============================================================================
# OWNWORLD — UPDATE MANAGER & IN-APP INSTALLER
# File: res://Systems/UpdateManager.gd
# Base Class: RefCounted (class_name UpdateManager)
# ==============================================================================

class_name UpdateManager
extends RefCounted

const GITHUB_REPO: String = "ryanbutinagumballmachine-alt/ownworld-dollhouse"

enum CheckResult {
	UPDATE_AVAILABLE,
	UP_TO_DATE,
	NO_APK_FOUND,
	ERROR
}

# --- 1. GET INSTALLED VERSION ---

static func get_current_app_version() -> String:
	# Reads version from Project Settings -> application/config/version, fallback to "1.0.0"
	var ver: String = str(ProjectSettings.get_setting("application/config/version", "1.0.22")).strip_edges()
	return ver if not ver.is_empty() else "1.0.22"


# --- 2. CHECK FOR UPDATES ---

static func check_for_updates(caller_node: Node, on_result: Callable) -> void:
	if caller_node == null:
		return

	var current_version: String = get_current_app_version()
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
			var err_msg = "Network error (HTTP %d)" % response_code if response_code != 0 else "Cannot connect to update server"
			on_result.call(CheckResult.ERROR, "", "", err_msg)
			return

		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not parsed is Dictionary:
			on_result.call(CheckResult.ERROR, "", "", "Invalid response from server")
			return

		var data: Dictionary = parsed as Dictionary
		var release_tag: String = str(data.get("tag_name", "")).strip_edges()
		var assets: Array = data.get("assets", [])
		var apk_download_url: String = ""

		for asset in assets:
			if asset is Dictionary:
				var asset_name: String = str(asset.get("name", ""))
				if asset_name.ends_with(".apk"):
					apk_download_url = str(asset.get("browser_download_url", ""))
					break

		if release_tag.is_empty():
			on_result.call(CheckResult.ERROR, "", "", "No release tag found on GitHub")
			return

		# Check if remote release is newer than current app version
		if not is_remote_version_newer(current_version, release_tag):
			on_result.call(CheckResult.UP_TO_DATE, release_tag, "", "You are on the latest version (%s)" % current_version)
			return

		if apk_download_url.is_empty():
			on_result.call(CheckResult.NO_APK_FOUND, release_tag, "", "New release %s found, but no .apk asset attached" % release_tag)
			return

		on_result.call(CheckResult.UPDATE_AVAILABLE, release_tag, apk_download_url, "New update available: %s" % release_tag)
	)

	var err: Error = http_request.request(url, headers)
	if err != OK:
		http_request.queue_free()
		on_result.call(CheckResult.ERROR, "", "", "Failed to send update request")


# --- 3. IN-APP DOWNLOAD & INSTALLATION ---

static func get_apk_target_path() -> String:
	if OS.has_feature("android"):
		var downloads_dir: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		if not downloads_dir.is_empty() and DirAccess.dir_exists_absolute(downloads_dir):
			return downloads_dir.path_join("OwnWorld_Update.apk").replace("\\", "/")
	return "user://update.apk"


static func download_and_install_update(caller_node: Node, apk_url: String, on_progress: Callable, on_complete: Callable, on_error: Callable) -> void:
	if caller_node == null or apk_url.is_empty():
		if on_error.is_valid(): on_error.call("Invalid download parameters")
		return

	var target_file_path: String = get_apk_target_path()
	if FileAccess.file_exists(target_file_path):
		DirAccess.remove_absolute(target_file_path)

	var http_downloader: HTTPRequest = HTTPRequest.new()
	http_downloader.download_file = target_file_path
	caller_node.add_child(http_downloader)

	# Progress polling timer
	var progress_timer: Timer = Timer.new()
	progress_timer.wait_time = 0.1
	progress_timer.autostart = true
	caller_node.add_child(progress_timer)

	progress_timer.timeout.connect(func() -> void:
		if not is_instance_valid(http_downloader):
			progress_timer.queue_free()
			return
		var body_size: int = http_downloader.get_body_size()
		var downloaded: int = http_downloader.get_downloaded_bytes()
		if body_size > 0 and on_progress.is_valid():
			var percent: float = clampf(float(downloaded) / float(body_size), 0.0, 1.0)
			on_progress.call(percent, downloaded, body_size)
	)

	http_downloader.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		progress_timer.stop()
		progress_timer.queue_free()
		http_downloader.queue_free()

		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			if on_error.is_valid():
				on_error.call("Download failed (HTTP %d)" % response_code)
			return

		if on_complete.is_valid():
			on_complete.call()

		# Trigger system package installer
		install_apk_file(target_file_path)
	)

	var err: Error = http_downloader.request(apk_url)
	if err != OK and on_error.is_valid():
		progress_timer.queue_free()
		http_downloader.queue_free()
		on_error.call("Failed to initiate download stream")


static func install_apk_file(apk_file_path: String) -> void:
	var global_path: String = ProjectSettings.globalize_path(apk_file_path)

	if OS.has_feature("android"):
		var android_runtime = Engine.get_singleton("AndroidRuntime")
		if android_runtime:
			var activity = android_runtime.getActivity()
			var context = android_runtime.getApplicationContext()

			var File = JavaClassWrapper.wrap("java.io.File")
			var Intent = JavaClassWrapper.wrap("android.content.Intent")
			var Uri = JavaClassWrapper.wrap("android.net.Uri")
			var Build = JavaClassWrapper.wrap("android.os.Build$VERSION")

			var apk_file = File.new(global_path)
			var intent = Intent.new(Intent.ACTION_VIEW)

			if Build.SDK_INT >= 24: # Android 7.0+
				var FileProvider = JavaClassWrapper.wrap("androidx.core.content.FileProvider")
				var authority = context.getPackageName() + ".fileprovider"
				
				# If FileProvider authority fails, fall back to direct file URI
				var content_uri = null
				if FileProvider != null:
					content_uri = FileProvider.getUriForFile(context, authority, apk_file)
				
				if content_uri != null:
					intent.setDataAndType(content_uri, "application/vnd.android.package-archive")
					intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
				else:
					intent.setDataAndType(Uri.fromFile(apk_file), "application/vnd.android.package-archive")
			else:
				intent.setDataAndType(Uri.fromFile(apk_file), "application/vnd.android.package-archive")

			intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			activity.startActivity(intent)
			return

	# Fallback for Windows desktop or systems with native handlers
	OS.shell_open(global_path)


# --- 4. VERSION COMPARISON HELPER ---

static func is_remote_version_newer(local_ver_str: String, remote_ver_str: String) -> bool:
	var clean_local = local_ver_str.trim_prefix("v").trim_prefix("V").strip_edges()
	var clean_remote = remote_ver_str.trim_prefix("v").trim_prefix("V").strip_edges()

	if clean_local == clean_remote:
		return false

	var local_parts: PackedStringArray = clean_local.split(".")
	var remote_parts: PackedStringArray = clean_remote.split(".")

	var max_len: int = maxi(local_parts.size(), remote_parts.size())
	for i in range(max_len):
		var local_num: int = local_parts[i].to_int() if i < local_parts.size() and local_parts[i].is_valid_int() else 0
		var remote_num: int = remote_parts[i].to_int() if i < remote_parts.size() and remote_parts[i].is_valid_int() else 0

		if remote_num > local_num:
			return true
		elif remote_num < local_num:
			return false

	return false
