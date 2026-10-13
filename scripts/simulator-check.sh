#!/bin/bash
# Builds Lamplight for the iPad simulator, tries every link on the reading list,
# and takes screenshots of the main screens.
set -eo pipefail

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
c=[x for r,l in d.items() if "iOS" in r for x in l if x["name"].startswith("iPad Pro") and "13" in x["name"]]
c=c or [x for r,l in d.items() if "iOS" in r for x in l if x["name"].startswith("iPad")]
c.sort(key=lambda x:x["name"])
print(c[-1]["udid"])')
echo "Using simulator $UDID"

xcodebuild -project Lamplight.xcodeproj -scheme Lamplight -configuration Debug -sdk iphonesimulator \
  -destination "id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO build 2>&1 | tee build.log | grep -E "error:|warning: unre|BUILD (SUCCEEDED|FAILED)" || true
grep -q "BUILD SUCCEEDED" build.log || { echo "::error::Build failed"; grep -E "error:" build.log | head -60; exit 1; }

APP=build/Build/Products/Debug-iphonesimulator/Lamplight.app
BID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")

xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl ui "$UDID" appearance dark
xcrun simctl status_bar "$UDID" override --time "21:41" --batteryState charged --batteryLevel 100 --wifiBars 3 || true
xcrun simctl install "$UDID" "$APP"
mkdir -p shots

# 1. Try every link on the reading list.
xcrun simctl launch --terminate-running-process "$UDID" "$BID" -LamplightSelfTest
DATA=""
for i in $(seq 1 450); do
  DATA=$(xcrun simctl get_app_container "$UDID" "$BID" data)
  [ -f "$DATA/Documents/selftest.json" ] && break
  sleep 2
done
if [ -f "$DATA/Documents/selftest.json" ]; then
  cp "$DATA/Documents/selftest.json" shots/selftest.json
  python3 scripts/selftest-summary.py shots/selftest.json
else
  echo "::warning::Self-test produced no result"
fi
xcrun simctl terminate "$UDID" "$BID" || true

# 2. Screenshots (night 2 shown as tonight, pieces already downloaded by the self-test).
shoot() { # name, wait, extra args
  local name=$1 wait=$2; shift 2
  xcrun simctl launch --terminate-running-process "$UDID" "$BID" -LamplightDemo -LamplightDemoNight 2 "$@"
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "shots/$name.png"
}
shoot tonight 5
shoot reader 9 -LamplightDemoReader
shoot paper 9 -LamplightDemoPDF
shoot plan 5 -LamplightDemoPlan
shoot settings 5 -LamplightDemoSettings
shoot complete 5 -LamplightDemoComplete
xcrun simctl status_bar "$UDID" clear || true
ls -la shots
