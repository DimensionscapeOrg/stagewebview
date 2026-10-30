#!/usr/bin/env bash
# Installs the debug report sample on a running emulator, waits for it to finish, and pulls its output
# (report-status.txt, the PDF and the preview capture) into the working directory.
set -uo pipefail

package=com.dimensionscape.stagewebview.report
apk=$(find bin/samples/report/android -name '*.apk' | head -1)
echo "installing $apk"
adb install -r "$apk"
adb logcat -c
adb shell am start -n "$package/$package.MainActivity"

status=""
directory=""
for attempt in $(seq 1 90); do
  sleep 2
  if [ -z "$directory" ]; then
    found=$(adb shell run-as "$package" find . -name report-status.txt 2>/dev/null | tr -d '\r' | head -1)
    directory=$(dirname "$found" 2>/dev/null)
    [ "$found" = "" ] && directory=""
  fi
  [ -n "$directory" ] || continue
  status=$(adb shell run-as "$package" cat "$directory/report-status.txt" 2>/dev/null | tr -d '\r')
  case "$status" in
    OK:*|FAIL:*) break ;;
  esac
done

echo "$status" | tee report-android-status.txt
if [ -n "$directory" ]; then
  adb exec-out run-as "$package" cat "$directory/stagewebview-report.pdf" > report-android.pdf
  sleep 4
  adb exec-out run-as "$package" cat "$directory/report-preview.png" > preview-android.png || true
fi

adb logcat -d | grep -E "Main.hx|StageWebView|AndroidRuntime|chromium" | tail -80

case "$status" in
  OK:*) exit 0 ;;
  *) exit 1 ;;
esac
