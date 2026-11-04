@echo off
chcp 65001 >nul
rem Time Post — збирає файл для Google Play: build\timepost.aab
rem 1) Вкажіть шлях до Godot 4.7.2 нижче (файл Godot_v4.7.2-stable_win64.exe).
set GODOT=C:\Godot\Godot_v4.7.2-stable_win64.exe
rem 2) Android SDK і шаблони експорту Godot 4.7.2 мають бути встановлені (див. docs\RELEASE_ANDROID.md).

cd /d "%~dp0..\.."
if not exist "%GODOT%" (
  echo Не знайдено Godot: %GODOT%
  echo Відкрийте цей файл у Блокноті й виправте рядок set GODOT=...
  pause
  exit /b 1
)
set GODOT_ANDROID_KEYSTORE_RELEASE_PATH=%USERPROFILE%\timepost-upload.keystore
set GODOT_ANDROID_KEYSTORE_RELEASE_USER=timepost
set /p GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=Пароль ключа: 
if not exist build mkdir build
"%GODOT%" --headless --path . --install-android-build-template --export-release "Android Play (AAB)" build\timepost.aab
if exist build\timepost.aab (
  echo.
  echo УСПІХ: build\timepost.aab — завантажте його в Play Console.
) else (
  echo.
  echo Збірка не вдалася. Скопіюйте текст помилки вище й надішліть розробникові.
)
pause
