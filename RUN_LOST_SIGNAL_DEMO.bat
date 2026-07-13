@echo off
setlocal
set "GODOT=C:\Users\Linux\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe"
if not exist "%GODOT%" set "GODOT=C:\Users\Linux\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe"
start "Lost Signal" "%GODOT%" --path "%~dp0" res://scenes/lost_signal/road/NightDrive.tscn
endlocal
