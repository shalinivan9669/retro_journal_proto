class_name FilmRevealProfile
extends Resource

## All timings, tolerances and feedback strengths for one reusable film reveal.

@export_group("Inventory")
@export var slot_action: StringName = &"film_slot_4"
@export_range(0.05, 1.0, 0.01) var equip_time_s: float = 0.22
@export_range(40.0, 1000.0, 1.0) var stow_offset_px: float = 340.0

@export_group("Target acquisition")
@export_range(0.1, 30.0, 0.05) var acquire_angle_deg: float = 12.0
@export_range(0.1, 35.0, 0.05) var release_angle_deg: float = 18.0
@export_range(0.05, 2.0, 0.01) var dwell_s: float = 0.35
@export_range(0.1, 8.0, 0.1) var dwell_decay_multiplier: float = 2.5
@export_range(10.0, 2000.0, 1.0) var maximum_target_distance_m: float = 420.0

@export_group("Reveal timeline")
@export_range(0.05, 2.0, 0.01) var camera_lock_s: float = 0.28
@export_range(1.0, 15.0, 0.05) var reveal_s: float = 4.80
@export_range(0.0, 2.0, 0.01) var post_lock_hold_s: float = 0.35
@export_range(0.0, 0.25, 0.005) var undeveloped_trace: float = 0.06

@export_group("Physical feedback")
@export_range(0.0, 8.0, 0.05) var film_shake_px: float = 7.0
@export_range(0.0, 3.0, 0.01) var film_tilt_deg: float = 1.35
@export_range(0.0, 0.5, 0.005) var camera_shake_deg: float = 0.12
@export_range(0.0, 0.03, 0.0005) var camera_shake_m: float = 0.0035
@export_range(0.07, 0.10, 0.005) var capture_flash_s: float = 0.085
@export_range(0.0, 1.0, 0.01) var capture_flash_strength: float = 0.32
@export_range(0.0, 1.0, 0.01) var radiation_idle_ratio: float = 0.12
@export_range(0.0, 1.0, 0.01) var radiation_aim_ratio: float = 0.35
@export_range(0.0, 1.0, 0.01) var radiation_peak: float = 1.0
@export_range(0.1, 2.0, 0.05) var radiation_release_s: float = 0.65
@export_range(0.0, 12.0, 0.1) var hum_peak_boost_db: float = 7.0
@export_range(0.1, 50.0, 0.1) var geiger_peak_rate_hz: float = 22.0
@export_range(0.0, 8.0, 0.1) var geiger_peak_volume_boost_db: float = 5.8

@export_group("Film optics")
@export_range(0.0, 1.0, 0.01) var film_opacity: float = 0.52
@export_range(0.0, 2.0, 0.01) var exposure_gain: float = 1.08
@export_range(0.0, 1.0, 0.01) var bleach_low: float = 0.56
@export_range(0.0, 1.5, 0.01) var bleach_high: float = 0.84
@export_range(0.0, 0.5, 0.01) var aim_brightness_boost: float = 0.28
@export_range(0.0, 0.5, 0.01) var aim_contrast_boost: float = 0.18
@export var cold_negative_tint := Color(0.69, 0.82, 0.94, 1.0)
@export var film_base_tint := Color(0.43, 0.52, 0.60, 1.0)
