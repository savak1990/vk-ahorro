#!/usr/bin/env bash
# Creates the Android upload key, and publishes it to the release Environment
# so CI can sign with the same key. Both halves are skipped when already done,
# so this is safe to re-run: replacing a keystore Play has registered makes
# every later upload fail its signature check until Google resets it.
set -euo pipefail
cd "$(dirname "$0")/../flutter-ui/android"

ks=upload-keystore.jks
props=key.properties
env_name=release

# macOS ships keytool as a stub that exits with "Unable to locate a Java
# Runtime" when no JDK is installed. Gradle uses the one Android Studio
# bundles, so fall back to the same one rather than asking for a second JDK.
if ! keytool -help >/dev/null 2>&1; then
  for home in "${JAVA_HOME:-}" "$(/usr/libexec/java_home 2>/dev/null || true)" \
              "/Applications/Android Studio.app/Contents/jbr/Contents/Home"; do
    if [ -n "$home" ] && [ -x "$home/bin/keytool" ]; then
      PATH="$home/bin:$PATH"
      break
    fi
  done
fi
if ! keytool -help >/dev/null 2>&1; then
  echo "ANDROID-KEYSTORE: no JDK found. Install one with: brew install openjdk@17" >&2
  exit 1
fi

if [ -e "$ks" ] && [ -e "$props" ]; then
  echo "ANDROID-KEYSTORE: flutter-ui/android/$ks exists; leaving it untouched."
elif [ -e "$ks" ] || [ -e "$props" ]; then
  echo "ANDROID-KEYSTORE: one of $ks and $props exists without the other." >&2
  echo "ANDROID-KEYSTORE: refusing to guess. Move the leftover aside yourself." >&2
  exit 1
else
  read -rsp "passphrase for the new upload key: " pw; echo
  read -rsp "again: " pw2; echo
  [ "$pw" = "$pw2" ] || { echo "ANDROID-KEYSTORE: they differ." >&2; exit 1; }
  [ "${#pw}" -ge 6 ] || { echo "ANDROID-KEYSTORE: keytool needs at least 6 characters." >&2; exit 1; }

  # Both files hold key material and are readable by their owner alone. The
  # umask is set before keytool so the keystore is covered too, not just the
  # properties file that carries the passphrase in clear.
  umask 177

  keytool -genkeypair -v -keystore "$ks" -storetype PKCS12 \
    -keyalg RSA -keysize 2048 -validity 10000 -alias upload \
    -storepass "$pw" -keypass "$pw" -dname "CN=Ahorro, O=Ahorro, C=ES"

  # storeFile is read by app/build.gradle, whose file() resolves against
  # flutter-ui/android/app/, one level below this keystore.
  cat > "$props" <<PROPS
storePassword=$pw
keyPassword=$pw
keyAlias=upload
storeFile=../$ks
PROPS

  echo "ANDROID-KEYSTORE: wrote flutter-ui/android/$ks and $props."
  echo "ANDROID-KEYSTORE: put the keystore file and the passphrase in your password manager now."
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ANDROID-KEYSTORE: the key is in place, but gh is not logged in." >&2
  echo "ANDROID-KEYSTORE: run gh auth login, then this target again to publish the secrets." >&2
  exit 1
fi

# Read back rather than reuse the prompt, so a re-run can publish the secrets
# for a keystore an earlier run created.
pw="$(sed -n 's/^storePassword=//p' "$props")"
key_alias="$(sed -n 's/^keyAlias=//p' "$props")"

have="$(gh secret list --env "$env_name" --json name --jq '.[].name' 2>/dev/null || true)"

# The value arrives on stdin, never in argv, where the process table would
# show it to every other user on this machine.
set_secret() {
  if grep -qx "$1" <<<"$have"; then
    echo "ANDROID-KEYSTORE: $1 already set."
  else
    printf '%s' "$2" | gh secret set "$1" --env "$env_name"
    echo "ANDROID-KEYSTORE: $1 published."
  fi
}

set_secret ANDROID_KEYSTORE_BASE64 "$(base64 < "$ks" | tr -d '\n')"
set_secret ANDROID_KEYSTORE_PASSWORD "$pw"
set_secret ANDROID_KEY_ALIAS "$key_alias"
set_secret ANDROID_KEY_PASSWORD "$pw"

echo "ANDROID-KEYSTORE: neither file is in Git. This machine and the $env_name Environment hold the only copies."
