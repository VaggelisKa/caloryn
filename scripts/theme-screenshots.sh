#!/bin/bash

set -euo pipefail

OUT="${1:-/tmp/caloryn-theme-shots}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULT="$(mktemp -d)/theme.xcresult"

UDID="${CALORYN_UDID:-$(xcrun simctl list devices available -j \
  | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
fallback=None
for runtime, devices in d.items():
    if "iOS-26" not in runtime: continue
    for dev in devices:
        if not (dev.get("isAvailable") and "iPhone" in dev["name"]): continue
        if dev.get("state") == "Booted":
            print(dev["udid"]); raise SystemExit
        if fallback is None: fallback = dev["udid"]
if fallback is None: raise SystemExit("no available iOS 26 iPhone simulator")
print(fallback)
')}"

echo "==> simulator $UDID"
echo "==> running ThemeScreenshotTests (both appearances, ~3 min)"

set -o pipefail
xcodebuild test \
  -project "$ROOT/Caloryn.xcodeproj" \
  -scheme Caloryn \
  -only-testing:CalorynUITests/ThemeScreenshotTests \
  -destination "id=$UDID" \
  -resultBundlePath "$RESULT" \
  CODE_SIGNING_ALLOWED=NO \
  > "${RESULT%.xcresult}.log" 2>&1 || {
    echo "FAILED — the harness asserts it reached every screen, so this is usually a"
    echo "navigation break rather than a colour problem. Log: ${RESULT%.xcresult}.log"
    grep -E "failed - " "${RESULT%.xcresult}.log" | head -5 || true
    exit 1
  }

rm -rf "$OUT"; mkdir -p "$OUT"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT/.raw" > /dev/null

python3 - "$OUT" <<'PY'
import json, os, re, shutil, sys
out = sys.argv[1]; raw = os.path.join(out, ".raw")
for entry in json.load(open(os.path.join(raw, "manifest.json"))):
    for a in entry.get("attachments", []):
        name = a["suggestedHumanReadableName"]
        if not name.endswith(".png"): continue
        shutil.copy(os.path.join(raw, a["exportedFileName"]),
                    os.path.join(out, re.sub(r"_0_[A-F0-9-]+\.png$", ".png", name)))
shutil.rmtree(raw)

TOKENS = {
    "page":  {"light": (254,253,250), "dark": (20,22,20)},
    "card":  {"light": (255,255,255), "dark": (38,42,38)},
    "sage":  {"light": (124,142,107), "dark": (150,171,131)},
}
SYSTEM = {
    "light": [(242,242,247)],
    "dark":  [(28,28,30), (0,0,0), (44,44,46)],
}
try:
    from PIL import Image
except ImportError:
    print("\n(install pillow for the colour census: python3 -m pip install pillow)")
    Image = None

print(f"\n==> {out}\n")
print(f"{'screen':42} {'page':>7} {'card':>7} {'sage':>7} {'SYSTEM':>8}")
for f in sorted(os.listdir(out)):
    if not f.endswith(".png"): continue
    if Image is None:
        print(f"  {f}"); continue
    mode = "dark" if "-dark" in f else "light"
    im = Image.open(os.path.join(out, f)).convert("RGB")
    px = list(im.getdata()); n = len(px)
    pct = lambda c: sum(1 for p in px if p == c) / n
    system = sum(pct(c) for c in SYSTEM[mode])
    flag = "  <-- check" if system > 0.02 else ""
    print(f"  {f:40} {pct(TOKENS['page'][mode]):6.1%} {pct(TOKENS['card'][mode]):6.1%} "
          f"{pct(TOKENS['sage'][mode]):6.1%} {system:7.1%}{flag}")
print("\nSYSTEM above ~2% means a List or Form is painting a system grey over the theme:")
print("#F2F2F7 in light, #1C1C1E / #000000 / #2C2C2E in dark. A missing row background is")
print("only visible in the dark column, because the light system row is the same white as")
print("CardBackground. Page and card at 0.0% means the appearance never switched.")
print("See docs/theme.md, 'Row backgrounds, and the limit of the abstraction'.")
PY
