extends RefCounted
class_name BasementWallUpgradeBuilder

const BROKEN_BRICK_WALL_MATERIAL: Material = preload("res://materials/polyhaven/mat_basement_broken_brick_wall.tres")
const BASEMENT_WALL_HEIGHT := 4.85


static func wall_material() -> Material:
	return BROKEN_BRICK_WALL_MATERIAL


static func wall_height() -> float:
	return BASEMENT_WALL_HEIGHT


static func wall_center_y(floor_y: float = 0.0) -> float:
	return floor_y + BASEMENT_WALL_HEIGHT * 0.5
