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
SET "STEAM_DIR=%STEAM_DIR:/=\%"

SET "PATHSEP=\"

SET "STEAM_DIR=%STEAM_DIR%%PATHSEP%steamapps%PATHSEP%common"

SET "VSMODDED=%STEAM_DIR%%PATHSEP%VSModded"
SET "VSORIGINAL=%STEAM_DIR%%PATHSEP%Vampire Survivors"
SET "VSBACKUP=%STEAM_DIR%%PATHSEP%VSDLCBackup"

REM --- Create directories if they don't exist ---
FOR %%D IN ("%VSMODDED%" "%VSORIGINAL%" "%VSBACKUP%") DO (
    IF NOT EXIST "%%D" (
        echo Creating directory %%D...
        mkdir "%%D"
    )
)

SET "FOLDERS=2230760 2313550 2690330 2887680 3210350 3451100"

REM --- Move folders from Vampire Survivors to backup ---
echo Backing up original folders from Vampire Survivors...
FOR %%F IN (%FOLDERS%) DO (
    IF EXIST "%VSORIGINAL%%PATHSEP%%%F" (
        robocopy "%VSORIGINAL%%PATHSEP%%%F" "%VSBACKUP%%PATHSEP%%%F" /MOVE /E
        rmdir /S /Q "%VSORIGINAL%%PATHSEP%%%F"
    )
)

REM --- Move folders from VSModded to Vampire Survivors ---
echo Swapping in modded folders...
FOR %%F IN (%FOLDERS%) DO (
    IF EXIST "%VSMODDED%%PATHSEP%%%F" (
        robocopy "%VSMODDED%%PATHSEP%%%F" "%VSORIGINAL%%PATHSEP%%%F" /MOVE /E
        rmdir /S /Q "%VSMODDED%%PATHSEP%%%F"
    )
)

REM --- Launch Vampire Survivors from VSModded and wait ---
echo Launching Vampire Survivors...
START /WAIT "" "%VSMODDED%%PATHSEP%VampireSurvivors.exe"

REM --- Reverse the folder moves ---
echo Reverting folders to original state...

REM Move folders from Vampire Survivors back to VSModded
FOR %%F IN (%FOLDERS%) DO (
    IF EXIST "%VSORIGINAL%%PATHSEP%%%F" (
        robocopy "%VSORIGINAL%%PATHSEP%%%F" "%VSMODDED%%PATHSEP%%%F" /MOVE /E
        rmdir /S /Q "%VSORIGINAL%%PATHSEP%%%F"
    )
)

REM Move folders from backup back to Vampire Survivors
FOR %%F IN (%FOLDERS%) DO (
    IF EXIST "%VSBACKUP%%PATHSEP%%%F" (
        robocopy "%VSBACKUP%%PATHSEP%%%F" "%VSORIGINAL%%PATHSEP%%%F" /MOVE /E
        rmdir /S /Q "%VSBACKUP%%PATHSEP%%%F"
    )
)

echo All done. Folders restored.
