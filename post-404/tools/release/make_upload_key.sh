#!/bin/sh
# Time Post — create the Google Play upload key once (macOS/Linux).
echo "Creates ~/timepost-upload.keystore. Choose a password and WRITE IT DOWN."
keytool -genkeypair -v -keystore "$HOME/timepost-upload.keystore" -alias timepost -keyalg RSA -keysize 2048 -validity 10000
echo "Done. Back up the file and the password. Never commit it to git."
