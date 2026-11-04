@echo off
chcp 65001 >nul
rem Time Post — створення ключа завантаження для Google Play (один раз).
rem Потрібна Java (встановлюється разом з Android Studio).
set KEYTOOL=keytool
if exist "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" set KEYTOOL="C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
echo.
echo Зараз буде створено файл timepost-upload.keystore у вашій папці користувача.
echo Придумайте пароль (мінімум 6 символів) і ЗАПИШІТЬ його.
echo На питання про ім'я, організацію, місто можна відповідати будь-що.
echo.
%KEYTOOL% -genkeypair -v -keystore "%USERPROFILE%\timepost-upload.keystore" -alias timepost -keyalg RSA -keysize 2048 -validity 10000
echo.
echo Готово: %USERPROFILE%\timepost-upload.keystore
echo ЗРОБІТЬ РЕЗЕРВНУ КОПІЮ цього файлу й пароля (флешка + хмара). Не додавайте його в GitHub.
pause
