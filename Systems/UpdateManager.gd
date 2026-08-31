# ============================================================
# File: res://Systems/UpdateManager.gd
# ============================================================

# ==============================================================================
# OWNWORLD — RESUMABLE HIGH-THROUGHPUT CROSS-PLATFORM UPDATE MANAGER
# File: res://Systems/UpdateManager.gd
# Base Class: Node
#
# Responsibility:
# 1. Asynchronous GitHub Release polling with ETag rate-limit protection and SemVer detection.
# 2. Resumable chunked file streaming with HTTP Range (206 Partial Content) support.
# 3. Multi-hop HTTP redirect traversal (301, 302, 303, 307, 308) to CDN assets.
# 4. Stale version guard via sidecar metadata (.part.json) preventing corrupted byte appending.
# 5. Asset size and SHA-256 cryptographic checksum validation.
# 6. Post-install garbage collection (auto-deleting old installer binaries on boot).
# 7. Pre-update automated save data backup (.ownpack) for disaster recovery.
# 8. Android 8.0+ unknown app sources intent and FileProvider package installation.
# ==============================================================================

class_name UpdateManager
extends Node

# ------------------------------------------------------------------------------
# SIGNALS
# ------------------------------------------------------------------------------
signal check_started()
signal check_completed(result: CheckResult, release_data: Dictionary)
signal download_started(total_bytes: int, target_path: String, is_resumed: bool)
signal download_progress(percent: float, downloaded_bytes: int, total_bytes: int, speed_bytes_per_sec: float, eta_seconds: float)
signal download_paused(downloaded_bytes: int, total_bytes: int, reason: String)
signal download_completed(target_file_path: String)
signal installation_triggered(success: bool)
signal error_occurred(message: String)

# ------------------------------------------------------------------------------
# CONSTANTS & ENUMS
# ------------------------------------------------------------------------------
const GITHUB_REPO: String = "ryanbutinagumballmachine-alt/ownworld-dollhouse"
const PATH_CHECK_CACHE: String = "user://update_check_cache.json"
const PATH_BACKUP_DIR: String = "user://backups/"
const DEFAULT_TIMEOUT_SECONDS: float = 15.0
const DOWNLOAD_POLL_TIMEOUT_SECONDS: float = 18.0
const PROGRESS_THROTTLE_INTERVAL: float = 0.08 # ~12 UI progress updates/sec
const MAX_REDIRECTS: int = 8
const BUFFER_FLUSH_THRESHOLD: int = 1048576 # Flush to disk every 1 MB

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
	PAUSED,
	READY_TO_INSTALL,
	FAILED
}

enum StreamStep {
	INIT,
	CONNECTING,
	SENDING_REQUEST,
	AWAITING_RESPONSE,
	STREAMING_BODY,
	DONE
}

# ------------------------------------------------------------------------------
# STATE VARIABLES
# ------------------------------------------------------------------------------
var current_state: UpdateState = UpdateState.IDLE
var latest_release_data: Dictionary = {}
var active_download_url: String = ""
var target_local_file_path: String = ""
var partial_file_path: String = ""
var sidecar_metadata_path: String = ""

# HTTPClient Streaming Engine
var _http_client: HTTPClient = null
var _check_http_request: HTTPRequest = null
var _file_handle: FileAccess = null

var _stream_step: StreamStep = StreamStep.INIT
var _current_url: String = ""
var _redirect_count: int = 0
var _step_start_time: float = 0.0

var _total_expected_bytes: int = 0
var _existing_bytes_on_start: int = 0
var _session_downloaded_bytes: int = 0
var _unflushed_bytes: int = 0
var _expected_sha256: String = ""

var _last_progress_emit_time: float = 0.0
var _last_speed_sample_bytes: int = 0
var _last_speed_sample_time: float = 0.0
var _smoothed_speed: float = 0.0


# ------------------------------------------------------------------------------
# LIFECYCLE & GARBAGE COLLECTION
# ------------------------------------------------------------------------------
func _ready() -> void:
	target_local_file_path = get_target_file_path_for_platform()
	partial_file_path = target_local_file_path + ".part"
	sidecar_metadata_path = target_local_file_path + ".part.json"

	_perform_post_install_garbage_collection()

	if is_package_ready():
		current_state = UpdateState.READY_TO_INSTALL
	elif has_partial_download():
		current_state = UpdateState.PAUSED

	set_process(false)


func _process(_delta: float) -> void:
	if current_state != UpdateState.DOWNLOADING or _http_client == null:
		set_process(false)
		return

	_step_download_engine()


## Deletes leftover installer binaries and temporary files once updated.
func _perform_post_install_garbage_collection() -> void:
	var current_ver: String = get_current_app_version()

	# If sidecar metadata indicates the partial download belongs to an older/current version, clean it
	if FileAccess.file_exists(sidecar_metadata_path):
		var meta: Dictionary = JsonFileStore.read_dictionary(sidecar_metadata_path)
		var meta_tag: String = str(meta.get("tag_name", "")).strip_edges()
		if not meta_tag.is_empty() and not is_remote_version_newer(current_ver, meta_tag):
			_purge_partial_files()

	# If a full installer package exists on disk but we are already running that version or newer, delete it
	if FileAccess.file_exists(target_local_file_path):
		if not is_remote_version_newer(current_ver, str(latest_release_data.get("tag_name", ""))):
			DirAccess.remove_absolute(target_local_file_path)


# ------------------------------------------------------------------------------
# PUBLIC API: STATE INSPECTION
# ------------------------------------------------------------------------------
func is_package_ready() -> bool:
	var path: String = get_ready_package_path()
	if FileAccess.file_exists(path):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if is_instance_valid(f):
			var length: int = f.get_length()
			f.close()
			return length > 1024
	return false


func has_partial_download() -> bool:
	if FileAccess.file_exists(partial_file_path):
		var f: FileAccess = FileAccess.open(partial_file_path, FileAccess.READ)
		if is_instance_valid(f):
			var length: int = f.get_length()
			f.close()
			return length > 0
	return false


func get_partial_download_bytes() -> int:
	if FileAccess.file_exists(partial_file_path):
		var f: FileAccess = FileAccess.open(partial_file_path, FileAccess.READ)
		if is_instance_valid(f):
			var length: int = f.get_length()
			f.close()
			return length
	return 0


func get_ready_package_path() -> String:
	return target_local_file_path if not target_local_file_path.is_empty() else get_target_file_path_for_platform()


func is_downloading() -> bool:
	return current_state == UpdateState.DOWNLOADING


func is_paused() -> bool:
	return current_state == UpdateState.PAUSED


func get_download_progress_snapshot() -> Dictionary:
	var total: int = _total_expected_bytes
	var downloaded: int = get_total_downloaded_bytes()
	var pct: float = clampf(float(downloaded) / float(total), 0.0, 1.0) if total > 0 else 0.0

	return {
		"state": int(current_state),
		"is_downloading": is_downloading(),
		"is_paused": is_paused(),
		"is_ready": is_package_ready(),
		"downloaded_bytes": downloaded,
		"total_bytes": total,
		"percent": pct,
		"speed_bytes_per_sec": _smoothed_speed,
		"eta_seconds": float(total - downloaded) / _smoothed_speed if _smoothed_speed > 0.0 and total > 0 else 0.0
	}


func get_total_downloaded_bytes() -> int:
	return _existing_bytes_on_start + _session_downloaded_bytes


# ------------------------------------------------------------------------------
# PUBLIC API: VERSION CHECKING & ETAG CACHING
# ------------------------------------------------------------------------------
## Initiates release checking with ETag (304 Not Modified) rate-limit protection.
func check_for_updates(include_prereleases: bool = false) -> void:
	if current_state == UpdateState.CHECKING or current_state == UpdateState.DOWNLOADING:
		return

	current_state = UpdateState.CHECKING
	check_started.emit()

	if is_instance_valid(_check_http_request):
		_check_http_request.queue_free()

	_check_http_request = HTTPRequest.new()
	_check_http_request.use_threads = true
	_check_http_request.timeout = DEFAULT_TIMEOUT_SECONDS
	_check_http_request.max_redirects = MAX_REDIRECTS
	_check_http_request.accept_gzip = true
	add_child(_check_http_request)

	var url: String = "https://api.github.com/repos/%s/releases" % GITHUB_REPO if include_prereleases else "https://api.github.com/repos/%s/releases/latest" % GITHUB_REPO
	var headers: PackedStringArray = [
		"User-Agent: OwnWorld-Dollhouse/%s (Godot Engine; %s)" % [get_current_app_version(), OS.get_name()],
		"Accept: application/vnd.github.v3+json",
		"X-GitHub-Api-Version: 2022-11-28"
	]

	# Add cached ETag header to prevent consuming GitHub 60 req/hr rate limits
	var cached_etag: String = _get_cached_etag()
	if not cached_etag.is_empty():
		headers.append("If-None-Match: " + cached_etag)

	_check_http_request.request_completed.connect(_on_check_request_completed.bind(include_prereleases))
	var err: Error = _check_http_request.request(url, headers)
	if err != OK:
		_cleanup_check_node()
		_handle_error(CheckResult.NETWORK_ERROR, "Failed to connect to update server (Code %d)." % int(err))


func _on_check_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, include_prereleases: bool) -> void:
	_cleanup_check_node()

	# 1. Handle 304 Not Modified (Using Cached Release Data with Zero Rate Limit Hit)
	if response_code == 304:
		var cached_data: Dictionary = JsonFileStore.read_dictionary(PATH_CHECK_CACHE)
		var cached_release: Dictionary = cached_data.get("release", {})
		if not cached_release.is_empty():
			latest_release_data = cached_release
			current_state = UpdateState.UPDATE_AVAILABLE if bool(cached_release.get("is_newer", false)) else UpdateState.IDLE
			var check_res: CheckResult = CheckResult.UPDATE_AVAILABLE if bool(cached_release.get("is_newer", false)) else CheckResult.UP_TO_DATE
			check_completed.emit(check_res, latest_release_data)
			return

	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg: String = _translate_http_result(result)
		_handle_error(CheckResult.NETWORK_ERROR, error_msg)
		return

	if response_code == 403:
		_handle_error(CheckResult.RATE_LIMITED, "GitHub API rate limit reached. Please try again later.")
		return
	elif response_code == 404:
		_handle_error(CheckResult.NO_COMPATIBLE_ASSET, "No releases found on repository.")
		return
	elif response_code != 200:
		_handle_error(CheckResult.ERROR, "Release server returned HTTP %d." % response_code)
		return

	# Extract response ETag header for future checks
	var new_etag: String = ""
	for h: String in headers:
		if h.to_lower().begins_with("etag:"):
			new_etag = h.substr(5).strip_edges()
			break

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	var raw_release: Dictionary = {}

	if include_prereleases and parsed is Array:
		var releases_arr: Array = parsed as Array
		if not releases_arr.is_empty() and releases_arr[0] is Dictionary:
			raw_release = releases_arr[0] as Dictionary
	elif parsed is Dictionary:
		raw_release = parsed as Dictionary

	if raw_release.is_empty():
		_handle_error(CheckResult.ERROR, "Received invalid release payload from server.")
		return

	var remote_tag: String = str(raw_release.get("tag_name", "")).strip_edges()
	var current_ver: String = get_current_app_version()
	var html_page_url: String = str(raw_release.get("html_url", ""))
	var release_notes: String = str(raw_release.get("body", ""))
	var assets: Array = raw_release.get("assets", [])

	var asset_info: Dictionary = _resolve_platform_asset_info(assets)
	var resolved_asset_url: String = str(asset_info.get("url", ""))
	var asset_size: int = int(asset_info.get("size", 0))

	# Resolve optional SHA-256 digest string if provided in assets
	_expected_sha256 = _resolve_sha256_digest(assets)

	latest_release_data = {
		"tag_name": remote_tag,
		"current_version": current_ver,
		"download_url": resolved_asset_url,
		"asset_size": asset_size,
		"sha256": _expected_sha256,
		"release_url": html_page_url,
		"release_notes": release_notes,
		"published_at": str(raw_release.get("published_at", "")),
		"is_newer": is_remote_version_newer(current_ver, remote_tag)
	}

	# Cache response payload and ETag
	if not new_etag.is_empty():
		JsonFileStore.write_dictionary(PATH_CHECK_CACHE, {
			"etag": new_etag,
			"release": latest_release_data
		})

	if not latest_release_data["is_newer"]:
		current_state = UpdateState.IDLE
		check_completed.emit(CheckResult.UP_TO_DATE, latest_release_data)
		return

	if resolved_asset_url.is_empty():
		current_state = UpdateState.UPDATE_AVAILABLE
		check_completed.emit(CheckResult.NO_COMPATIBLE_ASSET, latest_release_data)
		return

	active_download_url = resolved_asset_url
	_total_expected_bytes = asset_size
	current_state = UpdateState.UPDATE_AVAILABLE
	check_completed.emit(CheckResult.UPDATE_AVAILABLE, latest_release_data)


func _get_cached_etag() -> String:
	if FileAccess.file_exists(PATH_CHECK_CACHE):
		var data: Dictionary = JsonFileStore.read_dictionary(PATH_CHECK_CACHE)
		return str(data.get("etag", "")).strip_edges()
	return ""


# ------------------------------------------------------------------------------
# RESUMABLE DOWNLOAD PIPELINE (HTTPClient + Byte-Ranges + Stale Version Guard)
# ------------------------------------------------------------------------------
## Starts or resumes downloading from the exact byte where it left off.
func start_download(custom_url: String = "") -> void:
	var download_url: String = custom_url if not custom_url.is_empty() else active_download_url
	if download_url.is_empty():
		_handle_error(CheckResult.ERROR, "No download URL available.")
		return

	if current_state == UpdateState.DOWNLOADING:
		return

	_close_file_handle()
	_close_http_client()

	target_local_file_path = get_target_file_path_for_platform()
	partial_file_path = target_local_file_path + ".part"
	sidecar_metadata_path = target_local_file_path + ".part.json"

	# Stale Version Check: Verify if partial file belongs to the requested tag and URL
	var remote_tag: String = str(latest_release_data.get("tag_name", ""))
	if FileAccess.file_exists(sidecar_metadata_path):
		var meta: Dictionary = JsonFileStore.read_dictionary(sidecar_metadata_path)
		var meta_url: String = str(meta.get("url", ""))
		var meta_tag: String = str(meta.get("tag_name", ""))
		if (not meta_url.is_empty() and meta_url != download_url) or (not meta_tag.is_empty() and meta_tag != remote_tag):
			_purge_partial_files()

	_current_url = download_url
	_redirect_count = 0
	_session_downloaded_bytes = 0
	_unflushed_bytes = 0
	_smoothed_speed = 0.0
	_last_speed_sample_bytes = 0
	_last_speed_sample_time = Time.get_ticks_msec() / 1000.0
	_last_progress_emit_time = 0.0

	_existing_bytes_on_start = get_partial_download_bytes()
	var is_resuming: bool = _existing_bytes_on_start > 0

	# Write sidecar descriptor
	JsonFileStore.write_dictionary(sidecar_metadata_path, {
		"url": download_url,
		"tag_name": remote_tag,
		"expected_total_bytes": _total_expected_bytes
	})

	current_state = UpdateState.DOWNLOADING
	download_started.emit(_total_expected_bytes, target_local_file_path, is_resuming)

	_initiate_connection_to_url(_current_url)
	set_process(true)


func cancel_download() -> void:
	set_process(false)
	_close_file_handle()
	_close_http_client()
	_purge_partial_files()
	current_state = UpdateState.IDLE
	EventBus.notification_requested.emit("Download cancelled and storage cleared.", true)


func _purge_partial_files() -> void:
	if FileAccess.file_exists(partial_file_path):
		DirAccess.remove_absolute(partial_file_path)
	if FileAccess.file_exists(sidecar_metadata_path):
		DirAccess.remove_absolute(sidecar_metadata_path)
	_existing_bytes_on_start = 0
	_session_downloaded_bytes = 0


func _initiate_connection_to_url(url: String) -> void:
	_close_http_client()

	var parsed: Dictionary = parse_url(url)
	if not bool(parsed.get("valid", false)):
		_handle_download_failure("Invalid download URL: " + url)
		return

	_http_client = HTTPClient.new()
	_http_client.blocking_mode_enabled = false
	_http_client.read_chunk_size = 524288 # 512 KB high-throughput buffer

	var host: String = str(parsed["host"])
	var port: int = int(parsed["port"])
	var is_https: bool = str(parsed["scheme"]) == "https"
	var tls_opts: TLSOptions = TLSOptions.client() if is_https else null

	var err: Error = _http_client.connect_to_host(host, port, tls_opts)
	if err != OK:
		_handle_download_failure("Cannot connect to host %s (Error %d)." % [host, int(err)])
		return

	_stream_step = StreamStep.CONNECTING
	_step_start_time = Time.get_ticks_msec() / 1000.0


func _step_download_engine() -> void:
	if _http_client == null:
		set_process(false)
		return

	var err: Error = _http_client.poll()
	if err != OK:
		_handle_connection_loss("Network polling error (Code %d)." % int(err))
		return

	var now: float = Time.get_ticks_msec() / 1000.0
	var status: HTTPClient.Status = _http_client.get_status()

	match _stream_step:
		StreamStep.CONNECTING:
			if status == HTTPClient.STATUS_CONNECTED:
				_send_http_get_request()
			elif status in [HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR]:
				_handle_connection_loss("Failed to establish server connection.")
			elif now - _step_start_time > DOWNLOAD_POLL_TIMEOUT_SECONDS:
				_handle_connection_loss("Connection attempt timed out.")

		StreamStep.SENDING_REQUEST:
			if status == HTTPClient.STATUS_REQUESTING:
				_stream_step = StreamStep.AWAITING_RESPONSE
				_step_start_time = now
			elif status != HTTPClient.STATUS_CONNECTED:
				_handle_connection_loss("Request submission interrupted.")

		StreamStep.AWAITING_RESPONSE:
			if _http_client.has_response() or status == HTTPClient.STATUS_BODY:
				_handle_http_response_headers()
			elif status in [HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_DISCONNECTED]:
				_handle_connection_loss("Connection lost while waiting for response.")
			elif now - _step_start_time > DOWNLOAD_POLL_TIMEOUT_SECONDS:
				_handle_connection_loss("Timed out waiting for response from server.")

		StreamStep.STREAMING_BODY:
			if status == HTTPClient.STATUS_BODY:
				_stream_response_body_chunks(now)
			elif status in [HTTPClient.STATUS_CONNECTED, HTTPClient.STATUS_DISCONNECTED]:
				_finalize_download()
			elif status == HTTPClient.STATUS_CONNECTION_ERROR:
				_handle_connection_loss("Network connection dropped during download.")


func _send_http_get_request() -> void:
	var parsed: Dictionary = parse_url(_current_url)
	var path_and_query: String = str(parsed["path"])
	var headers: PackedStringArray = [
		"User-Agent: OwnWorld-Dollhouse/%s (Godot Engine; %s)" % [get_current_app_version(), OS.get_name()],
		"Accept: */*"
	]

	# Add HTTP Range header if resuming from existing bytes
	if _existing_bytes_on_start > 0:
		headers.append("Range: bytes=%d-" % _existing_bytes_on_start)

	var err: Error = _http_client.request(HTTPClient.METHOD_GET, path_and_query, headers)
	if err != OK:
		_handle_download_failure("Failed to send HTTP GET request (Error %d)." % int(err))
		return

	_stream_step = StreamStep.SENDING_REQUEST
	_step_start_time = Time.get_ticks_msec() / 1000.0


func _handle_http_response_headers() -> void:
	var response_code: int = _http_client.get_response_code()
	var raw_headers: Dictionary = _http_client.get_response_headers_as_dictionary()

	# 1. Handle HTTP Redirects (301, 302, 303, 307, 308)
	if response_code in [301, 302, 303, 307, 308]:
		_redirect_count += 1
		if _redirect_count > MAX_REDIRECTS:
			_handle_download_failure("Exceeded maximum HTTP redirects.")
			return

		var location: String = get_header_case_insensitive(raw_headers, "location")
		if location.is_empty():
			_handle_download_failure("Received redirect without Location header.")
			return

		if location.begins_with("/"):
			var base_parsed: Dictionary = parse_url(_current_url)
			location = "%s://%s%s" % [str(base_parsed["scheme"]), str(base_parsed["host"]), location]

		_current_url = location
		_initiate_connection_to_url(_current_url)
		return

	# 2. Handle 206 Partial Content (Successful Resumption)
	if response_code == 206:
		var content_range: String = get_header_case_insensitive(raw_headers, "content-range")
		if not content_range.is_empty() and "/" in content_range:
			var total_str: String = content_range.split("/")[-1].strip_edges()
			if total_str.is_valid_int():
				_total_expected_bytes = total_str.to_int()

		if _total_expected_bytes <= 0:
			var content_len: int = _http_client.get_response_body_length()
			if content_len > 0:
				_total_expected_bytes = _existing_bytes_on_start + content_len

		_file_handle = FileAccess.open(partial_file_path, FileAccess.READ_WRITE)
		if not is_instance_valid(_file_handle):
			_handle_download_failure("Cannot open partial file for writing: " + partial_file_path)
			return

		_file_handle.seek_end()
		_stream_step = StreamStep.STREAMING_BODY
		return

	# 3. Handle 200 OK (Full Content / Server Ignored Range)
	if response_code == 200:
		_existing_bytes_on_start = 0
		_session_downloaded_bytes = 0
		_total_expected_bytes = _http_client.get_response_body_length()

		_file_handle = FileAccess.open(partial_file_path, FileAccess.WRITE)
		if not is_instance_valid(_file_handle):
			_handle_download_failure("Cannot create file for writing: " + partial_file_path)
			return

		_stream_step = StreamStep.STREAMING_BODY
		return

	# 4. Handle 416 Range Not Satisfiable (File already finished or offset mismatch)
	if response_code == 416:
		_purge_partial_files()
		_initiate_connection_to_url(_current_url)
		return

	# 5. Generic HTTP Error
	_handle_download_failure("Server returned HTTP status %d." % response_code)


func _stream_response_body_chunks(now: float) -> void:
	var chunk: PackedByteArray = _http_client.read_response_body_chunk()
	if chunk.size() > 0:
		if is_instance_valid(_file_handle):
			_file_handle.store_buffer(chunk)
			_session_downloaded_bytes += chunk.size()
			_unflushed_bytes += chunk.size()

			if _unflushed_bytes >= BUFFER_FLUSH_THRESHOLD:
				_file_handle.flush()
				_unflushed_bytes = 0

	# Calculate throttled smoothed throughput metrics
	var time_delta: float = now - _last_speed_sample_time
	if time_delta >= 0.25:
		var bytes_delta: int = _session_downloaded_bytes - _last_speed_sample_bytes
		var instant_speed: float = float(bytes_delta) / maxf(time_delta, 0.001)
		_smoothed_speed = instant_speed if _smoothed_speed <= 0.0 else lerpf(_smoothed_speed, instant_speed, 0.35)
		_last_speed_sample_bytes = _session_downloaded_bytes
		_last_speed_sample_time = now

	if now - _last_progress_emit_time >= PROGRESS_THROTTLE_INTERVAL:
		_last_progress_emit_time = now
		var total: int = _total_expected_bytes
		var current_downloaded: int = get_total_downloaded_bytes()
		var pct: float = clampf(float(current_downloaded) / float(total), 0.0, 1.0) if total > 0 else 0.0
		var eta: float = float(total - current_downloaded) / _smoothed_speed if _smoothed_speed > 0.0 and total > 0 else 0.0

		download_progress.emit(pct, current_downloaded, total, _smoothed_speed, eta)


func _finalize_download() -> void:
	set_process(false)
	_close_file_handle()
	_close_http_client()

	var total_downloaded: int = get_total_downloaded_bytes()

	# 1. Size Verification
	if _total_expected_bytes > 0 and total_downloaded < _total_expected_bytes:
		_handle_connection_loss("Download stream ended prematurely (%d/%d bytes)." % [total_downloaded, _total_expected_bytes])
		return

	# 2. Checksum Verification (if SHA-256 digest was provided in release assets)
	if not _expected_sha256.is_empty():
		var computed_hash: String = FileAccess.get_sha256(partial_file_path).to_lower().strip_edges()
		if computed_hash != _expected_sha256.to_lower().strip_edges():
			_purge_partial_files()
			_handle_download_failure("SHA-256 verification failed (corrupted download).")
			return

	# 3. Promote partial file to final executable binary
	if FileAccess.file_exists(target_local_file_path):
		DirAccess.remove_absolute(target_local_file_path)

	var err: Error = DirAccess.rename_absolute(partial_file_path, target_local_file_path)
	if err != OK:
		DirAccess.copy_absolute(partial_file_path, target_local_file_path)
		DirAccess.remove_absolute(partial_file_path)

	if FileAccess.file_exists(sidecar_metadata_path):
		DirAccess.remove_absolute(sidecar_metadata_path)

	_existing_bytes_on_start = 0
	_session_downloaded_bytes = 0
	_total_expected_bytes = 0
	current_state = UpdateState.READY_TO_INSTALL
	download_completed.emit(target_local_file_path)


func _handle_connection_loss(reason: String) -> void:
	set_process(false)
	_close_file_handle()
	_close_http_client()

	_existing_bytes_on_start = get_partial_download_bytes()
	_session_downloaded_bytes = 0
	current_state = UpdateState.PAUSED

	download_paused.emit(_existing_bytes_on_start, _total_expected_bytes, reason)
	error_occurred.emit(reason)


func _handle_download_failure(reason: String) -> void:
	set_process(false)
	_close_file_handle()
	_close_http_client()

	current_state = UpdateState.FAILED
	error_occurred.emit(reason)


# ------------------------------------------------------------------------------
# PUBLIC API: PRE-UPDATE BACKUP & INSTALLATION HANDOFF
# ------------------------------------------------------------------------------
func create_pre_update_safety_backup() -> bool:
	JsonFileStore.ensure_directory(PATH_BACKUP_DIR)
	var backup_file: String = PATH_BACKUP_DIR.path_join("pre_update_backup_%s.ownpack" % AppState.universe_id)
	SaveSystem.save_current_room_state()
	return OwnPackManager.export_universe_pack(
		AppState.universe_name, "@AutoBackup", AppState.universe_id, backup_file
	)


func install_update(file_path: String = "") -> void:
	var final_path: String = file_path if not file_path.is_empty() else target_local_file_path
	if final_path.is_empty() or not FileAccess.file_exists(final_path):
		_handle_error(CheckResult.ERROR, "Installation file not found at: " + final_path)
		return

	# Automatically trigger safety backup before installing
	create_pre_update_safety_backup()

	var global_path: String = ProjectSettings.globalize_path(final_path)

	if OS.has_feature("android"):
		var success: bool = _install_android_package(global_path)
		installation_triggered.emit(success)
		return

	if OS.has_feature("windows"):
		if global_path.ends_with(".exe"):
			OS.create_process(global_path, [])
			installation_triggered.emit(true)
			return
		elif global_path.ends_with(".zip"):
			OS.shell_open(global_path)
			installation_triggered.emit(true)
			return

	var shell_result: Error = OS.shell_open(global_path)
	installation_triggered.emit(shell_result == OK)


## Resilient Android FileProvider intent invocation with API 26+ permission verification.
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
	var SettingsClass: JavaClass = JavaClassWrapper.wrap("android.provider.Settings")

	var apk_file: Variant = FileClass.new(global_apk_path)
	var intent: Variant = IntentClass.new(IntentClass.ACTION_VIEW)

	# Android 8.0+ (API 26+): Verify Unknown App Sources Permission
	if BuildClass.SDK_INT >= 26:
		var pm: Variant = context.getPackageManager()
		if pm != null and not bool(pm.canRequestPackageInstalls()):
			var settings_intent: Variant = IntentClass.new(SettingsClass.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
			var package_uri: Variant = UriClass.parse("package:" + str(context.getPackageName()))
			settings_intent.setData(package_uri)
			settings_intent.addFlags(IntentClass.FLAG_ACTIVITY_NEW_TASK)
			activity.startActivity(settings_intent)
			EventBus.notification_requested.emit("Please allow 'Install unknown apps' and return to install.", true)
			return false

	# Android 7.0+ (API 24+): FileProvider Content URI
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
# URL & HTTP UTILITIES
# ------------------------------------------------------------------------------
static func parse_url(url: String) -> Dictionary:
	var result: Dictionary = {
		"scheme": "https",
		"host": "",
		"port": 443,
		"path": "/",
		"valid": false
	}
	var clean_url: String = url.strip_edges()
	if clean_url.is_empty():
		return result

	var is_https: bool = true
	if clean_url.begins_with("https://"):
		clean_url = clean_url.trim_prefix("https://")
		is_https = true
	elif clean_url.begins_with("http://"):
		clean_url = clean_url.trim_prefix("http://")
		is_https = false
	else:
		return result

	var slash_pos: int = clean_url.find("/")
	var host_port: String = clean_url.substr(0, slash_pos) if slash_pos != -1 else clean_url
	var path: String = clean_url.substr(slash_pos) if slash_pos != -1 else "/"

	var host: String = host_port
	var port: int = 443 if is_https else 80

	var colon_pos: int = host_port.find(":")
	if colon_pos != -1:
		host = host_port.substr(0, colon_pos)
		var port_str: String = host_port.substr(colon_pos + 1)
		if port_str.is_valid_int():
			port = port_str.to_int()

	result["scheme"] = "https" if is_https else "http"
	result["host"] = host
	result["port"] = port
	result["path"] = path
	result["valid"] = not host.is_empty()
	return result


static func get_header_case_insensitive(headers: Dictionary, header_name: String) -> String:
	var target: String = header_name.to_lower()
	for k: Variant in headers.keys():
		if str(k).to_lower() == target:
			return str(headers[k]).strip_edges()
	return ""


func _resolve_platform_asset_info(assets: Array) -> Dictionary:
	var is_android: bool = OS.has_feature("android")
	var is_windows: bool = OS.has_feature("windows")

	for asset: Variant in assets:
		if not asset is Dictionary:
			continue
		var asset_dict: Dictionary = asset as Dictionary
		var name_lower: String = str(asset_dict.get("name", "")).to_lower()
		var download_url: String = str(asset_dict.get("browser_download_url", ""))
		var size: int = int(asset_dict.get("size", 0))

		if is_android and name_lower.ends_with(".apk"):
			return {"url": download_url, "size": size, "name": name_lower}
		elif is_windows and (name_lower.ends_with(".exe") or name_lower.ends_with(".zip")):
			return {"url": download_url, "size": size, "name": name_lower}

	return {}


func _resolve_sha256_digest(assets: Array) -> String:
	for asset: Variant in assets:
		if not asset is Dictionary:
			continue
		var name_lower: String = str((asset as Dictionary).get("name", "")).to_lower()
		if name_lower.ends_with(".sha256") or name_lower.ends_with(".sha256sum"):
			return str((asset as Dictionary).get("browser_download_url", ""))
	return ""


static func get_target_file_path_for_platform() -> String:
	if OS.has_feature("android"):
		return "user://update.apk"
	elif OS.has_feature("windows"):
		return "user://update.exe"
	return "user://update.bin"


static func get_current_app_version() -> String:
	var ver: String = str(ProjectSettings.get_setting("application/config/version", "1.0.0")).strip_edges()
	return ver if not ver.is_empty() else "1.0.0"


static func is_remote_version_newer(local_ver_str: String, remote_ver_str: String) -> bool:
	var clean_local: String = local_ver_str.trim_prefix("v").trim_prefix("V").split("-")[0].strip_edges()
	var clean_remote: String = remote_ver_str.trim_prefix("v").trim_prefix("V").split("-")[0].strip_edges()

	if clean_local == clean_remote or clean_remote.is_empty():
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
# CLEANUP
# ------------------------------------------------------------------------------
func _close_file_handle() -> void:
	if is_instance_valid(_file_handle):
		_file_handle.flush()
		_file_handle.close()
		_file_handle = null


func _close_http_client() -> void:
	if _http_client != null:
		_http_client.close()
		_http_client = null


func _cleanup_check_node() -> void:
	if is_instance_valid(_check_http_request):
		_check_http_request.queue_free()
		_check_http_request = null


func _handle_error(result: CheckResult, msg: String) -> void:
	current_state = UpdateState.FAILED
	error_occurred.emit(msg)
	check_completed.emit(result, {"error": msg})


static func _translate_http_result(result_code: int) -> String:
	match result_code:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect to update server. Check connection."
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "DNS resolution failed."
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection dropped or reset."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS security verification failed."
		HTTPRequest.RESULT_NO_RESPONSE:
			return "No response from server."
		HTTPRequest.RESULT_TIMEOUT:
			return "Connection timed out."
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "HTTP request failed."
		_:
			return "Network error code %d." % result_code
