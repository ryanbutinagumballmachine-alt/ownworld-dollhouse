# ==============================================================================
# OWNWORLD — TOAST COMPATIBILITY FACADE
# File: res://AutoLoads/ToastManager.gd
# ==============================================================================

extends Node

func show_toast(message: String, is_success: bool = true) -> void:
	NotificationService.show_notification(message, is_success)
