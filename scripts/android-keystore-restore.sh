#!/usr/bin/env bash
# The CI mirror of android-keystore.sh: writes the upload keystore and
# key.properties from the four Environment secrets, so the release build type
# signs with the real key instead of falling back to the debug key.
#
# Both files are gitignored and neither outlives the runner.
set -euo pipefail

: "${KEYSTORE_BASE64:?ANDROID_KEYSTORE_BASE64 is not set. Is this job on an Environment that holds it?}"
: "${KEYSTORE_PASSWORD:?ANDROID_KEYSTORE_PASSWORD is not set}"
: "${KEY_ALIAS:?ANDROID_KEY_ALIAS is not set}"
: "${KEY_PASSWORD:?ANDROID_KEY_PASSWORD is not set}"

cd "$(dirname "$0")/../flutter-ui/android"

# Before the first write, not after it: a keystore created world-readable
# stays world-readable once chmod is the second step.
umask 177

printf '%s' "$KEYSTORE_BASE64" | base64 -d > upload-keystore.jks

# storeFile is relative because Gradle's file() in the app module resolves
# against flutter-ui/android/app/, one level below this directory.
cat > key.properties <<EOF
storePassword=$KEYSTORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=../upload-keystore.jks
EOF

echo "KEYSTORE: restored for alias $KEY_ALIAS."
