@echo off
REM Builds the Accommo Mobile SPA using Node v24 (required; default node v22 breaks the build).
set PATH=C:\Program Files\nodejs;%PATH%
cd /d C:\Users\kylev\BloxBot\accommo-mobile

echo Using Node:
node -v
echo.

echo Building SPA (this takes ~1-2 minutes)...
call node_modules\.bin\quasar.CMD build -m spa

echo.
if exist "dist\spa\index.html" (
  echo BUILD OK. Deploy the "dist\spa" folder to https://app.netlify.com/drop
) else (
  echo BUILD FAILED. Check the output above.
)
pause
