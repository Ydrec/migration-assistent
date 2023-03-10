@echo off

setlocal EnableDelayedExpansion

set temp_folder=temporary
set instance_settings_to_update=name notes
set folders=mods config scripts resources
set keep_list=files_to_keep.txt
set disable_list=files_to_disable.txt
rem goto skipchoice

if not exist .minecraft (
    echo No .minecraft folder found.
    echo Place new modpack zip file and migrationassistent.bat where your .minecraft is located
    pause
    exit /b
)

set "zip_file="
for %%f in (*.zip) do (
    set "zip_file=%%~f"
    echo Found ZIP file: !zip_file!
    echo Do you want to use this ZIP file? "(y/n)"
    set /p choice=""
    if /i "!choice!"=="y" goto extract_zip
)

if not defined zip_file (
    echo No ZIP file found. Place modpack zip file in same folders
    echo Place modpack zip file and migrationassistent.bat where your .minecraft is located
    pause
    exit /b
)

:skipchoice
:extract_zip

rem goto skipzip
if exist %temp_folder% (
    rmdir /s /q %temp_folder%
)
mkdir %temp_folder%

echo Extracting files from !zip_file! ...
powershell -command "& {Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('!zip_file!', '%temp_folder%')}"
:skipzip
echo.

if exist %temp_folder% (
    echo Searching for updated files...
    echo.

    set "patchesfolder="
    for  /d /r "%temp_folder%" %%f in (*patches) do (
        set "patchesfolder=%%f"
        break
    )
    if exist !patchesfolder! (
        echo New patches folder found.
        if exist patches (
            echo Deleting old patches folder in current directory...
            rmdir /s /q "%~dp0patches"
        )
        echo Moving new patches folder to current directory...
        move /y "!patchesfolder!" "%~dp0"  >nul
    ) else (
        echo New patches folder not found. Skipping...
    )
    echo.

    set "mmc_pack="
    for /r "%temp_folder%" %%f in (mmc-pack*.*) do (
        set "mmc_pack=%%~f"
        echo New mmc-pack.json found
        break
    )
    if exist "!mmc_pack!" (
        echo Moving new mmc_pack.json to current directory.
        move /y "!mmc_pack!" "%~dp0"  >nul
    ) else (
        echo New mmc_pack.json not found. Skipping...
    )
    echo.

    set "newinstancecfg="
    for /r %temp_folder% %%f in ("instance*.*") do (
        set "newinstancecfg=%%f"
        break
    )

    if exist !newinstancecfg! (
        echo New instance.cfg found
        if not exist instance.cfg (
            echo Initial instance.cfg not found
            echo Moving new instance.cfg to current directory.
            move /y "!newinstancecfg!" "%~dp0"  >nul
        ) else (
            if exist instance_old.cfg (
                del /q "instance_old.cfg"
            )
            ren  "instance.cfg" "instance_old.cfg"

            rem need to create a file without a new line
            <nul >instance.cfg set /p=

            set "outputfile=instance.cfg"
            echo.
            for /f "tokens=1,* delims=:" %%a in ('findstr /n /r /c:"^" "instance_old.cfg"') do (
                set "lineN=%%a"
                set "line=%%b"
                set "found="
                set "keyword="
                for %%k in (%instance_settings_to_update%) do (
                    echo !line! | find "%%k" 1>nul && set "found=1" && set "keyword=%%k" && break
                )
                if defined found (
                    set "match="
                    for /f "tokens=1,* delims=:" %%c in ('findstr /n /r /c:^!keyword!= "!newinstancecfg!"') do (
                        set "match=1"
                        echo Updating !keyword! parameter from new instance.cfg
                        echo %%d>>"!outputfile!"
                    )
                    if not defined match (
                        echo !line!>>"!outputfile!"
                    )
                ) else (
                    echo !line!>>"!outputfile!"
                )
            )
        )
    ) else (
    echo New instance.cfg not found. Skipping...
    )
    echo.

    if not exist "%keep_list%" (
        echo File "%keep_list%" not found.
        echo Do you want to continue executing? "(y/n)"
        set /p continue=""
        if /i "!continue!" neq "y" (
            exit /b
        )
    )

    if not exist "%disable_list%" (
        echo File "%disable_list%" not found.
        echo Do you want to continue executing? "(y/n)"
        set /p continue=""
        if /i "!continue!" neq "y" (
            exit /b
        )
    )

    for %%f in (%folders%) do (
        if not exist ".minecraft\%%f" (
            echo Folder "%%~f" in .minecraft not found.
            echo Do you want to continue executing? "(y/n)"
            set /p continue=""
            if /i "!continue!" neq "y" (
                exit /b
            )
        )
    )
    echo.

    echo Deleting files in "%folders%" except those listed in "%keep_list%"...
    echo.

    for %%f in (%folders%) do call :clear_folders %%f
    echo Folders cleared
    echo.

    echo Copying over new folders
    rem moving folders constantly gives access denied so i gave up
    for /d /r %temp_folder% %%m in (*.minecraft) do (
        for %%f in (%folders%) do (
                if exist "%%m\%%~nxf" (
                    echo n | xcopy /-y /e "%%m\%%~nxf" ".minecraft\%%f" 1>nul
                    rem echo moved %%m\%%f to .minecraft\%%f
                )
            )
    )
    echo.

    echo Disabling unwanted mods
    if exist %disable_list% (
        for %%f in (%folders%) do call :disable_mods %%f
        echo Unnecessary mods disabled
        echo.
    )



    if exist %temp_folder% (
        rmdir /s /q %temp_folder%
    )
    echo Migration sucessful
) else (
    echo.
    echo Error extracting zip.
)
pause
goto :eof

:clear_folders
set "folder=%1"
rem set folder=config
echo Clearing .minecraft\%folder%
for /r .minecraft\%folder% %%F in (*) do (
rem for %%p in (.minecraft\%%f\*) do (
rem for %%p in (.minecraft\%%f\*.*) do (
    set delete_file=true
    if exist %keep_list% (
        for /f "tokens=*" %%K in ('findstr /b /v "^//" "%keep_list%"') do (
            echo %%~fF | findstr /i /r /c:"\.minecraft\\%folder%\\%%K" >nul && (
                echo Keeping "%%~nxF" because of "%%K" in %keep_list%
                set delete_file=false
            )
        )
    )

    if "!delete_file!"=="true" (
        if exist "%%~fF" (
            del "%%F"
        )
    )
)
echo.

for /f "delims=" %%c in ('dir /s /b /ad ".minecraft\%folder%" ^| sort /r') do (
    if exist %folder% (
        rmdir /q "%%c" 2>nul
    )
)
goto :eof


:disable_mods
set "folder=%1"
    for /r .minecraft\%folder% %%B in (*) do (
        rem echo %%B
        set disable_file=false
        for /f "tokens=*" %%D in ('findstr /b /v "^//" "%disable_list%"') do (
            echo %%~fB | findstr /i /r /c:"\.minecraft\\%folder%\\%%D" >nul && (
                echo Disabling "%%~nxB" because of "%%D" in %disable_list%
                set disable_file=true
            )
        )
        if "!disable_file!"=="true" (
            if exist "%%~fB" (
                ren  %%~fB %%~nxB.disabled
            )
        )
    )

goto :eof