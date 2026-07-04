#!/usr/bin/env bash
# Creates and boots an iPhone simulator once Xcode has an iOS runtime installed.
# Install runtime first: Xcode → Settings → Platforms → iOS 26.5 Simulator (+).

set -euo pipefail

SIM_NAME="MyTogether iPhone 15"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-15"

pick_runtime() {
  xcrun simctl list runtimes available -j \
    | python3 - <<'PY'
import json, sys
data = json.load(sys.stdin)
ios = [r for r in data.get("runtimes", []) if r.get("platform") == "iOS" and r.get("isAvailable")]
if not ios:
    sys.exit(1)
ios.sort(key=lambda r: r.get("version", ""), reverse=True)
print(ios[0]["identifier"])
PY
}

if ! RUNTIME_ID="$(pick_runtime 2>/dev/null)"; then
  echo "No iOS Simulator runtime found."
  echo "Install one in Xcode: Settings → Platforms → download iOS Simulator."
  open -a Xcode >/dev/null 2>&1 || true
  exit 1
fi

EXISTING_ID="$(SIM_NAME="$SIM_NAME" xcrun simctl list devices available -j | python3 - <<'PY'
import json, os, sys
name = os.environ["SIM_NAME"]
data = json.load(sys.stdin)
for d in data.get("devices", {}).values():
    for dev in d:
        if dev.get("name") == name and dev.get("isAvailable"):
            print(dev["udid"])
            sys.exit(0)
sys.exit(1)
PY
)" || true

if [[ -z "${EXISTING_ID:-}" ]]; then
  EXISTING_ID="$(xcrun simctl create "$SIM_NAME" "$DEVICE_TYPE" "$RUNTIME_ID")"
  echo "Created simulator: $SIM_NAME ($EXISTING_ID)"
else
  echo "Using existing simulator: $SIM_NAME ($EXISTING_ID)"
fi

xcrun simctl boot "$EXISTING_ID" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$EXISTING_ID"
echo "Booted $SIM_NAME. Run: flutter run -d \"$SIM_NAME\""
