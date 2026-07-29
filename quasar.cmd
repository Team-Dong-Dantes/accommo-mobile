@echo off
setlocal
set "PORTABLE_NODE=..\..\node-v22.23.1-win-x64\node.exe"
if exist "%PORTABLE_NODE%" (
  "%PORTABLE_NODE%" "node_modules\@quasar\app-vite\bin\quasar.js" %*
) else (
  npx quasar %*
)
