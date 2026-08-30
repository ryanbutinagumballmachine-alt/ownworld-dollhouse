# ==============================================================================
# OWNWORLD — HIGH-THROUGHPUT CROSS-PLATFORM UPDATE MANAGER & INSTALLER
# File: res://Systems/UpdateManager.gd
# Base Class: Node (ready for Autoload singleton or scene instantiation)
#
# Responsibility:
# 1. Asynchronous GitHub Release polling with rate-limit and SemVer detection.
# 2. Cross-platform target asset resolution (Android APK, Windows EXE/ZIP).
# 3. High-throughput (512KB chunk) threaded streaming download.
# 4. Throttled progress reporting with live speed (MB/s) and ETA calculation.
# 5. Resilient Android FileProvider package installer with multi-layer fallback.
# ==============================================================================

class_name UpdateManager
extends Node

# ------------------------------------------------------------------------------
# SIGNALS
# ------------------------------------------------------------------------------
signal check_started()
signal check_completed(result: CheckResult, release_data: Dictionary)
signal download_started(total_bytes: int, target_path: String)
signal download_progress(percent: float, downloaded_bytes: int, total_bytes: int, speed_bytes_per_sec: float, eta_seconds: float)
signal download_completed(target_file_path: String)
signal installation_triggered(success: bool)
signal error_occurred(message: String)

# ------------------------------------------------------------------------------
# CONSTANTS & ENUMS
# ------------------------------------------------------------------------------
const GITHUB_REPO: String = "ryanbutinagumballmachine-alt/ownworld-dollhouse"
const DEFAULT_TIMEOUT_SECONDS: float = 15.0
const DOWNLOAD_TIMEOUT_SECONDS: float = 180.0
const DOWNLOAD_CHUNK_SIZE: int = 524288 # 512 KB high-throughput buffer for 60fps streaming
const PROGRESS_THROTTLE_INTERVAL: float = 0.08 # Max ~12 progress signals/sec to protect render thread

enum CheckResult {
	UPDATE_AVAILABLE,
	UP_TO_DATE,
	NO_COMPATIBLE_ASSET,
	RATE_LIMITED,
	NETWORK_ERROR,
	ERROR
}

enum UpdateState {
	IDLE,
	CHECKING,
	UPDATE_AVAILABLE,
	DOWNLOADING,
	READY_TO_INSTALL,
	FAILED
}

# ------------------------------------------------------------------------------
# STATE VARIABLES
# ------------------------------------------------------------------------------
var current_state: UpdateState = UpdateState.IDLE
var latest_release_data: Dictionary = {}
var active_download_url: String = ""
var target_local_file_path: String = ""

# Internal network nodes & metrics
var _check_http_request: HTTPRequest = null
var _download_http_request: HTTPRequest = null

var _last_progress_emit_time: float = 0.0
var _last_downloaded_bytes: int = 0
var _download_start_time: float = 0.0
var _smoothed_speed: float = 0.0


# ------------------------------------------------------------------------------
# LIFECYCLE
# ------------------------------------------------------------------------------
func _ready() -> void:
	# Disable process tick until downloading to eliminate idle CPU overhead
	set_process(false)


func _process(_delta: float) -> void:
	if current_state != UpdateState.DOWNLOADING or not is_instance_valid(_download_http_request):
		set_process(false)
		return

	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_progress_emit_time < PROGRESS_THROTTLE_INTERVAL:
		return

	_emit_download_progress(current_time)


# ------------------------------------------------------------------------------
# PUBLIC API: VERSION CHECKING
# ------------------------------------------------------------------------------
## Initiates an asynchronous query against the GitHub release API.
func check_for_updates() -> void:
	if current_state == UpdateState.CHECKING or current_state == UpdateState.DOWNLOADING:
		push_warning("UpdateManager: Query already in progress.")
		return

	current_state = UpdateState.CHECKING
	check_started.emit()

	if is_instance_valid(_check_http_request):
		_check_http_request.queue_free()

	_check_http_request = HTTPRequest.new()
	_check_http_request.use_threads = true
	_check_http_request.timeout = DEFAULT_TIMEOUT_SECONDS
	_check_http_request.max_redirects = 8
	_check_http_request.accept_gzip = true
	add_child(_check_http_request)

	var url: String = "https://api.github.com/repos/%s/releases/latest" % GITHUB_REPO
	var headers: PackedStringArray = [
		"User-Agent: OwnWorld-Dollhouse/%s (Godot Engine; %s)" % [get_current_app_version(), OS.get_name()],
		"Accept: application/vnd.github.v3+json",
		"X-GitHub-Api-Version: 2022-11-28"
	]

	_check_http_request.request_completed.connect(_on_check_request_completed)
	var err: Error = _check_http_request.request(url, headers)
	if err != OK:
		_cleanup_check_node()
		_handle_error(CheckResult.NETWORK_ERROR, "Failed to connect to update server (Code %d)." % int(err))


## Processes the GitHub Release JSON payload and resolves platform assets.
func _on_check_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_cleanup_check_node()

	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg: String = _translate_http_result(result)
		_handle_error(CheckResult.NETWORK_ERROR, error_msg)
		return

	if response_code == 403:
		_handle_error(CheckResult.RATE_LIMITED, "GitHub API rate limit exceeded. Please try again later.")
		return
	elif response_code == 404:
		_handle_error(CheckResult.NO_COMPATIBLE_ASSET, "No published releases found on repository.")
		return
	elif response_code != 200:
		_handle_error(CheckResult.ERROR, "Update server returned HTTP %d." % response_code)
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_handle_error(CheckResult.ERROR, "Received malformed JSON payload from release server.")
		return

	var data: Dictionary = parsed as Dictionary
	var remote_tag: String = str(data.get("tag_name", "")).strip_edges()
	var current_ver: String = get_current_app_version()
	var html_page_url: String = str(data.get("html_url", ""))
	var release_notes: String = str(data.get("body", ""))
	var assets: Array = data.get("assets", [])

	var resolved_asset_url: String = _resolve_platform_asset_url(assets)

	latest_release_data = {
		"tag_name": remote_tag,
		"current_version": current_ver,
		"download_url": resolved_asset_url,
		"release_url": html_page_url,
		"release_notes": release_notes,
		"published_at": str(data.get("published_at", "")),
		"is_newer": is_remote_version_newer(current_ver, remote_tag)
	}

	if not latest_release_data["is_newer"]:
		current_state = UpdateState.IDLE
		check_completed.emit(CheckResult.UP_TO_DATE, latest_release_data)
		return

	if resolved_asset_url.is_empty():
		current_state = UpdateState.UPDATE_AVAILABLE
		check_completed.emit(CheckResult.NO_COMPATIBLE_ASSET, latest_release_data)
		return

	active_download_url = resolved_asset_url
	current_state = UpdateState.UPDATE_AVAILABLE
	check_completed.emit(CheckResult.UPDATE_AVAILABLE, latest_release_data)


# ------------------------------------------------------------------------------
# PUBLIC API: ASYNCHRONOUS DOWNLOAD
# ------------------------------------------------------------------------------
## Starts high-throughput download to app sandbox storage with progress tracking.
func start_download(custom_url: String = "") -> void:
	var download_url: String = custom_url if not custom_url.is_empty() else active_download_url
	if download_url.is_empty():
		_handle_error(CheckResult.ERROR, "No valid download URL available.")
		return

	if current_state == UpdateState.DOWNLOADING:
		return

	target_local_file_path = get_target_file_path_for_platform()

	# Delete leftover or partial downloads
	if FileAccess.file_exists(target_local_file_path):
		DirAccess.remove_absolute(target_local_file_path)

	if is_instance_valid(_download_http_request):
		_download_http_request.queue_free()

	_download_http_request = HTTPRequest.new()
	_download_http_request.use_threads = true
	_download_http_request.download_chunk_size = DOWNLOAD_CHUNK_SIZE
	_download_http_request.timeout = DOWNLOAD_TIMEOUT_SECONDS
	_download_http_request.max_redirects = 10
	_download_http_request.download_file = target_local_file_path
	add_child(_download_http_request)

	_last_progress_emit_time = 0.0
	_last_downloaded_bytes = 0
	_smoothed_speed = 0.0
	_download_start_time = Time.get_ticks_msec() / 1000.0

	_download_http_request.request_completed.connect(_on_download_request_completed)

	var headers: PackedStringArray = [
		"User-Agent: OwnWorld-Dollhouse/%s (Godot Engine; %s)" % [get_current_app_version(), OS.get_name()],
		"Accept: application/octet-stream"
	]

	current_state = UpdateState.DOWNLOADING
	var err: Error = _download_http_request.request(download_url, headers)
	if err != OK:
		_cleanup_download_node()
		_handle_error(CheckResult.NETWORK_ERROR, "Failed to start download stream (Code %d)." % int(err))
		return

	download_started.emit(_download_http_request.get_body_size(), target_local_file_path)
	set_process(true)


func _emit_download_progress(current_time: float) -> void:
	if not is_instance_valid(_download_http_request):
		return

	var total_bytes: int = _download_http_request.get_body_size()
	var downloaded_bytes: int = _download_http_request.get_downloaded_bytes()
	var time_delta: float = current_time - _last_progress_emit_time
	var byte_delta: int = downloaded_bytes - _last_downloaded_bytes

	if time_delta > 0.0 and byte_delta > 0:
		var instant_speed: float = float(byte_delta) / time_delta
		_smoothed_speed = instant_speed if _smoothed_speed == 0.0 else lerpf(_smoothed_speed, instant_speed, 0.3)

	_last_progress_emit_time = current_time
	_last_downloaded_bytes = downloaded_bytes

	var percent: float = clampf(float(downloaded_bytes) / float(total_bytes), 0.0, 1.0) if total_bytes > 0 else 0.0
	var eta_seconds: float = float(total_bytes - downloaded_bytes) / _smoothed_speed if _smoothed_speed > 0.0 and total_bytes > 0 else 0.0

	download_progress.emit(percent, downloaded_bytes, total_bytes, _smoothed_speed, eta_seconds)


func _on_download_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	set_process(false)
	_cleanup_download_node()

	if result != HTTPRequest.RESULT_SUCCESS or (response_code != 200 and response_code != 302):
		var reason: String = _translate_http_result(result) if result != HTTPRequest.RESULT_SUCCESS else "HTTP %d" % response_code
		_handle_error(CheckResult.NETWORK_ERROR, "Download failed: %s" % reason)
		return

	current_state = UpdateState.READY_TO_INSTALL
	download_completed.emit(target_local_file_path)


# ------------------------------------------------------------------------------
# PUBLIC API: INSTALLATION HANDOFF
# ------------------------------------------------------------------------------
## Launches the native OS package installer or platform execution.
func install_update(file_path: String = "") -> void:
	var final_path: String = file_path if not file_path.is_empty() else target_local_file_path
	if final_path.is_empty() or not FileAccess.file_exists(final_path):
		_handle_error(CheckResult.ERROR, "Installation file not found at: %s" % final_path)
		return

	var global_path: String = ProjectSettings.globalize_path(final_path)

	if OS.has_feature("android"):
		var success: bool = _install_android_package(global_path)
		installation_triggered.emit(success)
		return

	# Windows / Desktop execution
	if OS.has_feature("windows"):
		if global_path.ends_with(".exe"):
			OS.create_process(global_path, [])
			installation_triggered.emit(true)
			return
		elif global_path.ends_with(".zip"):
			OS.shell_open(global_path)
			installation_triggered.emit(true)
			return

	# General OS shell open fallback
	var shell_result: Error = OS.shell_open(global_path)
	installation_triggered.emit(shell_result == OK)


## Resilient Android FileProvider intent invocation with full SDK backward compatibility.
func _install_android_package(global_apk_path: String) -> bool:
	if not Engine.has_singleton(&"AndroidRuntime") or not ClassDB.class_exists("JavaClassWrapper"):
		OS.shell_open(global_apk_path)
		return true

	var android_runtime: Object = Engine.get_singleton(&"AndroidRuntime")
	if not is_instance_valid(android_runtime):
		OS.shell_open(global_apk_path)
		return true

	var activity: Object = android_runtime.getActivity()
	var context: Object = android_runtime.getApplicationContext()
	if not is_instance_valid(activity) or not is_instance_valid(context):
		OS.shell_open(global_apk_path)
		return true

	var FileClass: JavaClass = JavaClassWrapper.wrap("java.io.File")
	var IntentClass: JavaClass = JavaClassWrapper.wrap("android.content.Intent")
	var UriClass: JavaClass = JavaClassWrapper.wrap("android.net.Uri")
	var BuildClass: JavaClass = JavaClassWrapper.wrap("android.os.Build$VERSION")

	var apk_file: Variant = FileClass.new(global_apk_path)
	var intent: Variant = IntentClass.new(IntentClass.ACTION_VIEW)

	if BuildClass.SDK_INT >= 24:
		var FileProviderClass: JavaClass = JavaClassWrapper.wrap("androidx.core.content.FileProvider")
		var package_name: String = str(context.getPackageName())
		var authority: String = package_name + ".fileprovider"
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
	return true


# ------------------------------------------------------------------------------
# PLATFORM & VERSION RESOLUTION HELPERS
# ------------------------------------------------------------------------------
## Matches release asset to current operating system architecture.
func _resolve_platform_asset_url(assets: Array) -> String:
	var is_android: bool = OS.has_feature("android")
	var is_windows: bool = OS.has_feature("windows")

	for asset: Variant in assets:
		if not asset is Dictionary:
			continue
		var asset_dict: Dictionary = asset as Dictionary
		var name_lower: String = str(asset_dict.get("name", "")).to_lower()
		var download_url: String = str(asset_dict.get("browser_download_url", ""))

		if is_android and name_lower.ends_with(".apk"):
			return download_url
		elif is_windows and (name_lower.ends_with(".exe") or name_lower.ends_with(".zip")):
			return download_url

	return ""


## Target storage path inside the safe sandboxed user directory.
static func get_target_file_path_for_platform() -> String:
	if OS.has_feature("android"):
		return "user://update.apk"
	elif OS.has_feature("windows"):
		return "user://update.exe"
	return "user://update.bin"


## Returns the active application version defined in ProjectSettings.
static func get_current_app_version() -> String:
	var ver: String = str(ProjectSettings.get_setting("application/config/version", "1.0.0")).strip_edges()
	return ver if not ver.is_empty() else "1.0.0"


## Robust SemVer comparator (supports prefixes 'v'/'V' and segment depths).
static func is_remote_version_newer(local_ver_str: String, remote_ver_str: String) -> bool:
	var clean_local: String = local_ver_str.trim_prefix("v").trim_prefix("V").split("-")[0].strip_edges()
	var clean_remote: String = remote_ver_str.trim_prefix("v").trim_prefix("V").split("-")[0].strip_edges()

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


# ------------------------------------------------------------------------------
# CLEANUP & ERROR HANDLING
# ------------------------------------------------------------------------------
func _handle_error(result: CheckResult, msg: String) -> void:
	current_state = UpdateState.FAILED
	error_occurred.emit(msg)
	check_completed.emit(result, {"error": msg})


func _cleanup_check_node() -> void:
	if is_instance_valid(_check_http_request):
		_check_http_request.queue_free()
		_check_http_request = null


func _cleanup_download_node() -> void:
	if is_instance_valid(_download_http_request):
		_download_http_request.queue_free()
		_download_http_request = null


static func _translate_http_result(result_code: int) -> String:
	match result_code:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect to server. Please check internet connection."
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "DNS resolution failed."
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection dropped or reset."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS/SSL security verification failed."
		HTTPRequest.RESULT_NO_RESPONSE:
			return "No response from server."
		HTTPRequest.RESULT_TIMEOUT:
			return "Connection timed out."
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "HTTP request failed."
		_:
			return "Network error code %d." % result_code
