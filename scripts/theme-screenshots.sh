#!/bin/bash
#
# Capture every themed surface in both appearances, as PNGs you can actually look at.
#
#   ./scripts/theme-screenshots.sh [output-dir]
#
# Default output: /tmp/caloryn-theme-shots
#
# Why this exists: no XCTAssert reads a colour. The theme regressions this project has
# actually shipped — grouped-list rows rendering pure white, dark mode falling back to
# system greys, toolbar glyphs ignoring the accent — all passed the full test suite and a
# 5/5 review. The only thing that caught them was looking at pixels. See docs/theme.md.
#
# Prints an index at the end, and a colour census per screen so a drift shows up as a
# number before anyone opens an image.

set -euo pipefail

OUT="${1:-/tmp/caloryn-theme-shots}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULT="$(mktemp -d)/theme.xcresult"

# An iOS 26 iPhone simulator; the UI test target cannot run below 26.0. A already-booted one
# wins, so running this does not boot a second simulator alongside whichever one you are
# testing on by hand — an earlier version picked the first *available* device and did exactly
# that.
UDID="$(xcrun simctl list devices available -j \
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
')"

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

# Colour census. Drift is visible as a number before anyone opens an image.
TOKENS = {
    "page":  {"light": (243,241,236), "dark": (26,25,23)},    # #F3F1EC / #1A1917
    "card":  {"light": (250,250,247), "dark": (39,38,36)},    # #FAFAF7 / #272624
    "sage":  {"light": (124,142,107), "dark": (150,171,131)}, # #7C8E6B / #96AB83
}
try:
    from PIL import Image
except ImportError:
    print("\n(install pillow for the colour census: python3 -m pip install pillow)")
    Image = None

print(f"\n==> {out}\n")
print(f"{'screen':34} {'page':>7} {'card':>7} {'sage':>7} {'PURE WHITE':>11}")
for f in sorted(os.listdir(out)):
    if not f.endswith(".png"): continue
    if Image is None:
        print(f"  {f}"); continue
    mode = "dark" if "-dark" in f else "light"
    im = Image.open(os.path.join(out, f)).convert("RGB")
    px = list(im.getdata()); n = len(px)
    pct = lambda c: sum(1 for p in px if p == c) / n
    white = pct((255,255,255))
    # A screen showing the system keyboard registers a large legitimate white area in
    # light mode (the keys). Those captures are exempt rather than permanently flagged.
    keyboarded = f in {"03-food-search-results-light.png"}
    flag = "  <-- check" if white > 0.02 and not keyboarded else ("  (keyboard)" if keyboarded else "")
    print(f"  {f:32} {pct(TOKENS['page'][mode]):6.1%} {pct(TOKENS['card'][mode]):6.1%} "
          f"{pct(TOKENS['sage'][mode]):6.1%} {white:10.1%}{flag}")
print("\nPure white above ~2% usually means a List or Form row is painting its own")
print("background. Captures marked (keyboard) show the system keyboard, whose keys are")
print("legitimately white in light mode.")
print("See docs/theme.md, 'Row backgrounds, and the limit of the abstraction'.")
PY
