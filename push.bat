@echo off
echo === Security Report Push ===
echo.
echo Make sure VPN is ON and SSH key is added to GitHub:
echo   https://github.com/settings/keys
echo.

set /p GITHUB_USER="GitHub username: "
set /p REPO_NAME="Repo name [lspdfrcn-api-security-analysis]: "
if "%REPO_NAME%"=="" set REPO_NAME=lspdfrcn-api-security-analysis

echo.
echo 1. Create repo at: https://github.com/new?name=%REPO_NAME%
echo    Set to PUBLIC, do NOT add README
echo.
pause

git remote add origin git@github.com:%GITHUB_USER%/%REPO_NAME%.git
git branch -M main
git push -u origin main

echo.
echo Done! Check: https://github.com/%GITHUB_USER%/%REPO_NAME%
pause
