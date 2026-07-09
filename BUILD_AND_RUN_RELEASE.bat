@echo off
setlocal
cd /d "C:\GameDev\retro_journal_proto"

set "GODOT=C:\Users\Linux\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe"
set "TEMPLATE=C:\Users\Linux\AppData\Roaming\Godot\export_templates\4.7.stable\windows_release_x86_64.exe"
set "OUTDIR=C:\GameDev\retro_journal_proto\builds\windows"
set "OUTEXE=%OUTDIR%\RetroJournalPrototype.exe"

if not exist "%TEMPLATE%" (
    echo Missing Godot export template:
    echo "%TEMPLATE%"
    echo.
    echo Install it once in Godot:
    echo Editor ^> Manage Export Templates ^> Download and Install
    echo.
    echo Fast editor run still works with:
    echo RUN_TEXTURED_PROTOTYPE.bat
    exit /b 1
)

if not exist "%OUTDIR%" mkdir "%OUTDIR%"

"%GODOT%" --headless --path "C:\GameDev\retro_journal_proto" --export-release "Windows Desktop" "%OUTEXE%"
if errorlevel 1 exit /b 1

start "" "%OUTEXE%"
