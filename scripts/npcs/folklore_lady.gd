extends Node3D

signal requested_passage_after_dialogue

@export var prompt_text: String = "Говорить [E]"
@export var speaker_name: String = "Женщина в красной вуали"
@export_multiline var first_intro_text: String = "Ты пришёл ниже земли, но всё ещё думаешь, что спустился в подвал. Нет. Подвалы строят люди. Это место старше их страха."
@export_multiline var repeat_intro_text: String = "Ты вернулся не ко мне. Ты вернулся к вопросу, который не смог унести."

@onready var lamp_light: OmniLight3D = $LampLight

var has_spoken_once := false
var npc_lady_spoken := false
var _flicker_time := 0.0
var _base_lamp_energy := 1.2


func _ready() -> void:
	add_to_group("folklore_lady_npc")
	if lamp_light != null:
		_base_lamp_energy = lamp_light.light_energy


func _process(delta: float) -> void:
	if lamp_light == null:
		return

	_flicker_time += delta
	var slow_wave := sin(_flicker_time * 3.7) * 0.08
	var fast_wave := sin(_flicker_time * 11.3 + 0.8) * 0.035
	lamp_light.light_energy = _base_lamp_energy + slow_wave + fast_wave


func interact(dialogue_ui: Node) -> void:
	if dialogue_ui == null:
		return

	var intro := repeat_intro_text if has_spoken_once else first_intro_text
	has_spoken_once = true

	if dialogue_ui.has_method("show_choice_dialogue"):
		dialogue_ui.call("show_choice_dialogue", self, speaker_name, intro, _dialogue_choices())
	elif dialogue_ui.has_method("show_message"):
		dialogue_ui.call("show_message", "%s\n\n%s" % [speaker_name, intro])


func get_interaction_prompt() -> String:
	return prompt_text


func get_dialogue_look_target() -> Node3D:
	return get_node_or_null("LookTarget") as Node3D


func on_dialogue_choice_completed(choice_index: int) -> void:
	if choice_index != 3:
		return

	npc_lady_spoken = true
	_on_passage_dialogue_completed()


func _dialogue_choices() -> Array:
	return [
		{
			"label": "Кто ты?",
			"response": "Имя — это узда. Его надевают на живых, чтобы вести их туда, куда они не хотят идти.\nЗови меня так, как тебе удобнее: хозяйка угла, тень под тканью, последняя, кто не отвернулся.",
			"close_after_response": false,
		},
		{
			"label": "Почему ты сидишь здесь?",
			"response": "Потому что кто-то должен сидеть там, где все проходят мимо.\nЛюди любят двери, коридоры и выходы. Они редко смотрят в углы.\nА в углах остаётся то, что не поместилось в их отчёты.",
			"close_after_response": false,
		},
		{
			"label": "Что это за место?",
			"response": "Это не подвал. Это склад последствий.\nСюда стекает то, что наверху называли прогрессом, испытанием, планом, приказом.\nЗдесь эти слова гниют без формы. Здесь они наконец пахнут тем, чем были.",
			"close_after_response": false,
		},
		{
			"label": "Мне нужно пройти дальше.",
			"response": "Дальше проходят только те, кто перестал искать чистую дорогу.\nИди. Но не думай, что тьма впереди хуже человека, который принёс сюда свет.",
			"close_after_response": true,
		},
	]


func _on_passage_dialogue_completed() -> void:
	# Future hook: open a passage, change light, start sound, or show text here.
	requested_passage_after_dialogue.emit()
