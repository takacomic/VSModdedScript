@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

REM --- Step 1: Get Steam directory from registry ---
FOR /F "usebackq tokens=2*" %%A IN (`reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul`) DO (
    SET "STEAM_DIR=%%B"
)

IF NOT DEFINED STEAM_DIR (
    echo Steam directory not found in registry!
    pause
    exit /b
)

REM --- Append steamapps\common ---
SET "STEAM_DIR=%STEAM_DIR%/steamapps/common"

REM --- Step 2: Define required directories ---
SET "VSMODDED=%STEAM_DIR%/VSModded"
SET "VSORIGINAL=%STEAM_DIR%/Vampire Survivors"
SET "VSBACKUP=%STEAM_DIR%/VSDLCBackup"

REM --- Create directories if they don't exist ---
FOR %%D IN ("%VSMODDED%" "%VSORIGINAL%" "%VSBACKUP%") DO (
    IF NOT EXIST "%%D" (
        echo Creating directory %%D...
        mkdir "%%D"
    )
)

REM --- Step 3: Define the 6 folders to swap ---
SET "FOLDERS=2230760 2313550 2690330 2887680 3210350 3451100"

REM --- Move folders from Vampire Survivors to backup ---
echo Backing up original folders from Vampire Survivors...
FOR %%F IN (%FOLDERS%) DO (
    IF EXIST "%VSORIGINAL%\%%F" (
        move /Y "%VSORIGINAL%\%%F" "%VSBACKUP%\%%F"
    )
)

REM --- Move folders from VSModded to Vampire Survivors ---
echo Swapping in modded folders...
FOR %%F IN (%FOLDERS%) DO (
    IF EXIST "%VSMODDED%\%%F" (
        move /Y "%VSMODDED%\%%F" "%VSORIGINAL%\%%F"
    )
)

REM --- Step 4: Launch Vampire Survivors from VSModded and wait ---
echo Launching Vampire Survivors...
START /WAIT "" "%VSMODDED%\VampireSurvivors.exe"

REM --- Step 5: Reverse the folder moves ---
echo Reverting folders to original state...

REM Move folders from Vampire Survivors back to VSModded
FOR %%F IN (%FOLDERS%) DO (
    IF EXIST "%VSORIGINAL%\%%F" (
        move /Y "%VSORIGINAL%\%%F" "%VSMODDED%\%%F"
    )
)

REM Move folders from backup back to Vampire Survivors
FOR %%F IN (%FOLDERS%) DO (
    IF EXIST "%VSBACKUP%\%%F" (
        move /Y "%VSBACKUP%\%%F" "%VSORIGINAL%\%%F"
    )
)

echo All done. Folders restored.
pause
