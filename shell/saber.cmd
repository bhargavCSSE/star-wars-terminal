@echo off
rem star-wars-terminal: lightsaber color for Command Prompt (Clink). Usage: saber green
rem Shares saber.txt with the other shells. Red is kept for failed commands.
setlocal
if defined SWT_HOME (set "home=%SWT_HOME%") else (set "home=%USERPROFILE%\.config\star-wars-terminal")
set "pick=%~1"
if "%pick%"=="" (
  if defined JEDI_SABER (echo Current saber: %JEDI_SABER%. Options: blue, green, purple, yellow, white) else (echo Current saber: blue. Options: blue, green, purple, yellow, white)
  exit /b 0
)
for %%c in (blue green purple yellow white) do if /i "%pick%"=="%%c" (set "pick=%%c" & goto :valid)
echo saber: "%pick%" isn't a saber color. Options: blue, green, purple, yellow, white 1>&2
exit /b 1
:valid
>"%home%\saber.txt" echo %pick%
endlocal & set "JEDI_SABER=%pick%"
