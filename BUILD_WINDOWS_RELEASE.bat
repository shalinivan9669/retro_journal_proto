@echo off
setlocal
cd /d "C:\GameDev\retro_journal_proto"

set "GODOT=C:\Users\Linux\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe"
set "OUTDIR=C:\GameDev\retro_journal_proto\builds\windows"
set "OUTEXE=%OUTDIR%\RetroJournalPrototype.exe"

if not exist "%OUTDIR%" mkdir "%OUTDIR%"

"%GODOT%" --headless --path "C:\GameDev\retro_journal_proto" --export-release "Windows Desktop" "%OUTEXE%"
if errorlevel 1 (
    echo.
    echo Build failed. If Godot reports missing export templates, open Godot and install them:
    echo Editor ^> Manage Export Templates ^> Download and Install.
    pause
    exit /b 1
)

echo.
echo Built release: "%OUTEXE%"
pause
