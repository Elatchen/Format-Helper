@echo off

:: BatchGotAdmin
:-------------------------------------
REM  --> Check for permissions
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

REM --> If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"

    "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%CD%"
    CD /D "%~dp0"
:--------------------------------------

setlocal 
title Format Helper
echo This .bat file will let you select a disk which it then clears, partitions and formats.
echo You can select between diffrent filesystems and quick or full format.
echo A warning promt will appear before any action is taken.
echo Written by Michael Elert 2023 - feel free to reproduce and share.

:START

del "tempFileFormatHelperDontDeleteIfRunning.txt" >nul 2>&1

echo:
echo Listing disks.
echo:
wmic diskdrive get model,size,mediaType,index | sort /r
set /p "DEVICE_INDEX_TO_FORMAT="Enter index number of disk you want to delete and format: "
:: FIX BUG: SET VARIABLE BEFORE PROMPT, AS TO NOT REUSE LAST ACTION IF REPEATED
:: FIX BUG: JUST HITTING THE ENTER KEY SELECTS DEVICE 0 THIS IS A BIG ISSUE
:: DO SOME MORE TESTING FOR REPEATED EXECUTIONS AFTER FIXING

wmic diskdrive where( index like '%DEVICE_INDEX_TO_FORMAT%' ) get model,size,mediaType,index > tempFileFormatHelperDontDeleteIfRunning.txt

set /p FIRST_CHAR_TO_PARSE=< tempFileFormatHelperDontDeleteIfRunning.txt  
if /i "%FIRST_CHAR_TO_PARSE:~2,2%" NEQ "I" goto ERRORDISKSELECT

echo:
echo Following disk will be deleted and formated.
echo:
type tempFileFormatHelperDontDeleteIfRunning.txt
echo:
set /p "YES_NO_DEVICE_SELECT=Are you sure you want to format this disk (Y to continue, any key to abort)? "
IF /i "%YES_NO_DEVICE_SELECT%" NEQ "Y" GOTO START

echo:
echo Select file system:
ECHO 1. NTFS (default)
ECHO 2. FAT32
ECHO 3. exFAT
ECHO 4. FAT
ECHO 5. UDF
ECHO 6. ReFS
echo:
CHOICE /C 123456 /M "Enter your choice:"

:: Note - list ERRORLEVELS in decreasing order
IF ERRORLEVEL 6 GOTO REFS
IF ERRORLEVEL 5 GOTO UDF
IF ERRORLEVEL 4 GOTO FAT
IF ERRORLEVEL 3 GOTO EXFAT
IF ERRORLEVEL 2 GOTO FAT32
IF ERRORLEVEL 1 GOTO NTFS

:NTFS
set FILESYSTEM=NTFS
GOTO SELECT_FORMAT
:FAT32
set FILESYSTEM=FAT32
GOTO SELECT_FORMAT
:EXFAT
set FILESYSTEM=EXFAT
GOTO SELECT_FORMAT
:FAT
set FILESYSTEM=FAT
GOTO SELECT_FORMAT
:UDF
set FILESYSTEM=UDF
GOTO SELECT_FORMAT
:REFS
set FILESYSTEM=REFS
GOTO SELECT_FORMAT

:SELECT_FORMAT
echo:
echo Formating as %FILESYSTEM%.

@timeout /t 3 /nobreak>nul
::just for usability

echo:
set /p FORMAT_SELECT_QUESTION="Would you like to quick format (Y to quick format, any key to full format)? "
IF /i "%FORMAT_SELECT_QUESTION%" NEQ "Y" GOTO FULLFORMAT

set "QUICK_OR_FULL=^ quick"
echo:
echo Quick format will be started.

@timeout /t 1 /nobreak>nul
::just for usability
GOTO FORMATCOMBINEOPTIONS

:FULLFORMAT
set "QUICK_OR_FULL="
echo:
echo Full format will be started.

@timeout /t 1 /nobreak>nul
::just for usability

:FORMATCOMBINEOPTIONS

set "tempVar1=format fs="
set "tempVar2= label="Volume""
set "tempVar3=select disk ^"

set "LINE_0=automount"
set "LINE_1=%tempVar3%%DEVICE_INDEX_TO_FORMAT%"
set "LINE_2=clean"
set "LINE_3=create partition primary"
set "LINE_4=select partition ^1"
set "LINE_5=%tempVar1%%FILESYSTEM%%tempVar2%%QUICK_OR_FULL%"

echo %LINE_0%>tempFileFormatHelperDontDeleteIfRunning.txt
echo %LINE_1%>>tempFileFormatHelperDontDeleteIfRunning.txt
echo %LINE_2%>>tempFileFormatHelperDontDeleteIfRunning.txt
echo %LINE_3%>>tempFileFormatHelperDontDeleteIfRunning.txt
echo %LINE_4%>>tempFileFormatHelperDontDeleteIfRunning.txt
echo %LINE_5%>>tempFileFormatHelperDontDeleteIfRunning.txt

echo:
echo Starting Diskpart and executing following commands:
echo:
type tempFileFormatHelperDontDeleteIfRunning.txt


::maybe add disk again, just to let user doublecheck


@timeout /t 2 /nobreak>nul
::just for usability

echo:
color 4
echo Operation will start now. Are you sure you want to continue?
set /p LAST_CHANCE="THIS ACTION CANNOT BE REVERSED AND WILL RESULT IN DATA LOSS FOR SELECTED DISK  (Y to continue, any key to abort)? "
IF /i "%LAST_CHANCE%" NEQ "Y" GOTO END
color 7


::TIMER STARTLINE
set start=%time%

diskpart /s tempFileFormatHelperDontDeleteIfRunning.txt

::Calculate Time it took
set end=%time%
set options="tokens=1-4 delims=:.,"
for /f %options% %%a in ("%start%") do set start_h=%%a&set /a start_m=100%%b %% 100&set /a start_s=100%%c %% 100&set /a start_ms=100%%d %% 100
for /f %options% %%a in ("%end%") do set end_h=%%a&set /a end_m=100%%b %% 100&set /a end_s=100%%c %% 100&set /a end_ms=100%%d %% 100
set /a hours=%end_h%-%start_h%
set /a mins=%end_m%-%start_m%
set /a secs=%end_s%-%start_s%
set /a ms=%end_ms%-%start_ms%
if %ms% lss 0 set /a secs = %secs% - 1 & set /a ms = 100%ms%
if %secs% lss 0 set /a mins = %mins% - 1 & set /a secs = 60%secs%
if %mins% lss 0 set /a hours = %hours% - 1 & set /a mins = 60%mins%
if %hours% lss 0 set /a hours = 24%hours%
if 1%ms% lss 100 set ms=0%ms%
set /a totalsecs = %hours%*3600 + %mins%*60 + %secs%
echo:
echo Process took %hours%h %mins%m %secs%s (%totalsecs%s total)

:END
color 7
del "tempFileFormatHelperDontDeleteIfRunning.txt" >nul 2>&1
endlocal
::  ASK IF NEED TO RUN AGAIN
echo:
set /p "START_AGAIN=Would you like to retry or format another disk (Y to continue, any key to close application)? "
IF /i "%START_AGAIN%" EQU "Y" GOTO START

echo:
echo|set /p="Closing"
for /l %%a in (1,1,100) do echo|set /p="."
echo.Bye!

exit

:ERRORDISKSELECT
echo:
echo Input error or disk no longer available. Try again.
@timeout /t 3 /nobreak>nul
::just for usability
GOTO START
