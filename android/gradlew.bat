@echo off
setlocal
set GRADLE_VERSION=8.14.3
if "%GRADLE_USER_HOME%"=="" (set GRADLE_BASE=%USERPROFILE%\.gradle\manual-dists) else (set GRADLE_BASE=%GRADLE_USER_HOME%\manual-dists)
set GRADLE_DEST=%GRADLE_BASE%\gradle-%GRADLE_VERSION%
if not exist "%GRADLE_DEST%\bin\gradle.bat" (
  if not exist "%GRADLE_BASE%" mkdir "%GRADLE_BASE%"
  set GRADLE_ZIP=%GRADLE_BASE%\gradle-%GRADLE_VERSION%-bin.zip
  if not exist "%GRADLE_BASE%\gradle-%GRADLE_VERSION%-bin.zip" powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://services.gradle.org/distributions/gradle-%GRADLE_VERSION%-bin.zip' -OutFile '%GRADLE_BASE%\gradle-%GRADLE_VERSION%-bin.zip'"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Force '%GRADLE_BASE%\gradle-%GRADLE_VERSION%-bin.zip' '%GRADLE_BASE%'"
)
call "%GRADLE_DEST%\bin\gradle.bat" %*
exit /b %ERRORLEVEL%
