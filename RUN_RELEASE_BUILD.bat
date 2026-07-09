@echo off
setlocal
set "OUTEXE=C:\GameDev\retro_journal_proto\builds\windows\RetroJournalPrototype.exe"

if not exist "%OUTEXE%" (
    echo Release build not found:
    echo "%OUTEXE%"
    echo.
    echo Build and run it with:
    echo BUILD_AND_RUN_RELEASE.bat
    exit /b 1
)

start "" "%OUTEXE%"
