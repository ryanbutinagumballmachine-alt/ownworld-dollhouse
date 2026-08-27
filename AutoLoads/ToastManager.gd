# ==============================================================================
# OWNWORLD — TOAST COMPATIBILITY FACADE
# File: res://AutoLoads/ToastManager.gd
# Autoload Singleton: ToastManager
# Base Class: Node
#
# Responsibility: Lightweight backward-compatibility facade delegating
# notification toast requests to NotificationService.
# ==============================================================================

extends Node


func show_toast(message: String, is_success: bool = true) -> void:
	NotificationService.show_notification(message, is_success)
