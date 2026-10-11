#!/usr/bin/env bash
# Creates the Android upload key, once. Replacing a keystore that Play has
# already registered makes every later upload fail its signature check until
# Google resets it, which takes days - so this refuses rather than overwrites.
set -euo pipefail
cd "$(dirname "$0")/../flutter-ui/android"

ks=upload-keystore.jks
props=key.properties

for f in "$ks" "$props"; do
  if [ -e "$f" ]; then
    echo "ANDROID-KEYSTORE: flutter-ui/android/$f already exists." >&2
    echo "ANDROID-KEYSTORE: refusing to overwrite it. Move it aside yourself if you mean to." >&2
    exit 1
  fi
done

read -rsp "passphrase for the new upload key: " pw; echo
read -rsp "again: " pw2; echo
[ "$pw" = "$pw2" ] || { echo "ANDROID-KEYSTORE: they differ." >&2; exit 1; }
[ "${#pw}" -ge 6 ] || { echo "ANDROID-KEYSTORE: keytool needs at least 6 characters." >&2; exit 1; }

keytool -genkeypair -v -keystore "$ks" -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload \
  -storepass "$pw" -keypass "$pw" -dname "CN=Ahorro, O=Ahorro, C=ES"

# storeFile is read by app/build.gradle, whose file() resolves against
# flutter-ui/android/app/, one level below this keystore.
umask 177
cat > "$props" <<PROPS
storePassword=$pw
keyPassword=$pw
keyAlias=upload
storeFile=../upload-keystore.jks
PROPS

echo "ANDROID-KEYSTORE: wrote flutter-ui/android/$ks and $props."
echo "ANDROID-KEYSTORE: put the keystore file and the passphrase in your password manager now."
echo "ANDROID-KEYSTORE: neither is in Git, so this machine is the only copy."
