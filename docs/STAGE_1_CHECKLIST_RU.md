# Stage 1 чеклист

После установки проверь:

- [ ] Main.tscn запускается без ошибок.
- [ ] TV screen светится, но не заливает всю юрту.
- [ ] Radio display даёт маленький янтарный акцент.
- [ ] При подходе к TV/radio ближе 0.5 м появляется glitch.
- [ ] При отходе glitch исчезает.
- [ ] В юрте не стало слишком светло.
- [ ] Glow не делает всю сцену мыльной.
- [ ] FPS не просел заметно.

Если стало слишком ярко:

- уменьшить `tv_light_energy` до `0.25–0.35`;
- уменьшить `radio_light_energy` до `0.06–0.10`;
- уменьшить `glow_intensity` в `retro_visuals_runtime.gd` до `0.1–0.15`.

Если glitch слишком сильный:

- открыть `materials/postprocess/mat_glitch_double_vision_soft.tres`;
- `opacity` поставить `0.2–0.3`;
- `split` поставить `0.003–0.005`;
- `noise_strength` поставить `0.03–0.05`.

Если экран не найден:

Runtime ищет MeshInstance3D с именами, содержащими:

- screen
- display
- monitor
- crt

Переименуй MeshInstance3D экрана телевизора в `Screen`, а радио-дисплей в `Display`.
