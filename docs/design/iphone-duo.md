# iPhone Duo

How Caloryn behaves on the foldable iPhone, what was changed for it, and how to look at it.
Sources: Apple's *Preparing your app for iPhone Duo* (Technology Overviews), the HIG page
*Designing for iPhone Duo*, and the Xcode 27.1 SDK interfaces. Both Apple pages are
JavaScript-rendered; their text is served from
`developer.apple.com/tutorials/data/documentation/technologyoverviews/preparing-your-app-for-iphone-duo.json`
and `.../design/human-interface-guidelines/designing-for-iphone-duo.json`.

## The device, in numbers

| Display | Points (portrait) | Size classes | Chrome |
|---|---|---|---|
| Outer (closed) | 466 × 678 @3x | compact width, regular height | status bar, tab bar and toolbar in a **vertical bar on the trailing edge** (84 pt safe-area inset); the camera is top-trailing |
| Inner (open) | 669 × 951 @3x | regular width, regular height | horizontal bars in portrait, vertical bar in landscape |
| Inner, partially folded | as above, minus a 40 pt **division** region with 20 pt margins | | the fold is a `ReservedRegion` of kind `.division`, active only while partially folded |

The outer display is wider and shorter than any other iPhone, and the inner display is the
first iPhone with a regular width. Split View multitasking on the inner display gives each
app roughly half of 951 pt, which is compact width again.

## What Apple asks for (and where Caloryn stands)

1. **Resize from the proposal, never the screen.** No `UIScreen.main`, no orientation or
   idiom checks, no fixed widths. Caloryn had none; its `AnyLayout` and `ViewThatFits`
   switches key off Dynamic Type and the proposal already.
2. **Use system containers.** `TabView`, `NavigationStack`, sheets, alerts, `List` and
   `ScrollView` adapt around the fold, the camera and the vertical bar on their own. Caloryn
   is built on them, which is why the outer display needed nothing: the tab bar, the
   custom back chevron, Close, Delete and Create glyphs all moved into the vertical bar by
   themselves (see the before captures).
3. **Bars.** Give every toolbar item a title *and* a symbol: the vertical bar can only show
   a symbol, the overflow menu shows symbol and title, and a custom view or a title-only
   item stays in a horizontal bar. Put Back/Close in `.cancellationAction`, and a Done/Save
   that must never overflow in `.topBarPinnedTrailing` (iOS 27). Text-only Save/Skip/Select
   are allowed to stay horizontal; the HIG only asks to keep them few.
4. **Regular width is the new work.** The HIG wants the existing hierarchy to *expand*, not
   a new design: "show an additional level of hierarchy on the larger inner display if it
   makes sense". A layout that is already an `HStack`/`VStack` of two regions should become
   an `ArrangementView` with the `.split` style, which places the regions side by side when
   wider than tall, stacked when taller than wide, and on either side of the fold when the
   device is partially open. Keep navigation containers *outside* it, never put it in a
   `List` or `ScrollView`, and keep an earlier-OS fallback of the same hierarchy.
5. **Reserved regions and the hinge** are for custom, manually laid-out UI only. Caloryn has
   none; `onHingeChange` is for effects, never layout.

## What changed for the Duo

- **Today expands at regular width** instead of padding the phone page: a wider hero, and
  the first level of Nutrition Details promoted onto the page. See *Today at regular width*
  below for the breakpoints.
- **Toolbar items carry a title with their symbol** (`Label`, still drawn symbol-only), so
  the vertical bar and the overflow menu have something to show; the custom back button
  uses the `.cancellationAction` placement Apple names for it.
- **The UI-test tab bar page object** finds tabs by label when there is no `tabBars`
  element, which is the case in the vertical bar.

## Today at regular width

The HIG's "additional level of hierarchy" for Today is the top of Nutrition Details: the
*Against your targets* rows become a panel on the page, with an **All nutrients** button
that opens the full sheet (the hero still opens it too). `TodayDashboardLayout`
(`Caloryn/Models/`) picks a breakpoint from the size classes and the page's own size — never
the device — so the same rules serve iPad.

| Breakpoint | When | Today shows |
|---|---|---|
| **compact** | compact width: every iPhone in portrait, the closed Duo, narrow iPad windows | unchanged: one list with the date, the two-column hero (legend under the number), a full-width Nutri-Score or Copy Yesterday row, then the meals |
| **narrow-regular** | regular width, unless wide-regular: the inner display in portrait (669×951), an iPad mini in portrait (744pt), half an iPad in Split View, a regular-width iPhone held landscape (compact height, too short to split) | one list. The hero takes three columns (donut 168 + figures 200 + legend 220pt) once the content is 624pt wide. Under it the targets panel, with the Nutri-Score chips or Copy Yesterday as a 240pt trailing cluster |
| **wide-regular** | regular width *and* height, and either wider than tall (the inner display in landscape, 951×669; a full iPad in landscape) or at least 820pt wide (an 11" or 13" iPad in portrait) | the dashboard column (40%, never under 380pt) beside the meals. It holds the date, the two-column hero, the targets panel and the cluster. Wider than tall, the two sit in the split arrangement (an `HStack` before iOS 27.1). Taller than wide, they always sit in the `HStack`: with no fold to arrange around, an arrangement view would stack them and clip the dashboard |

At regular width the meal rows stop at 672pt, the system's readable width, leading-aligned with
their separators. The inner display never reaches it (629pt of content in portrait, about 530
in the landscape split). An iPad mini in portrait, a Split View half and a regular-width iPhone
in landscape do, and so does the landscape split's meal column with the iPad sidebar hidden.
Large text lifts the cap.

The dashboard column is 40% of the page but never under 380pt: the column the inner display's
landscape split gives it, the narrowest one that has been signed off. A tall split needs 820pt,
that 380pt plus 440pt for the meals, the width of the widest iPhone page. That takes in every 11"
iPad in portrait (820pt Air, 834pt Pro), whose dashboard sits at the 380pt floor, and leaves the
iPad mini (744pt) on the single list. Until then the gate was 950pt, the width at which a plain 40%
reaches 380pt, and an 11" iPad in portrait kept the single list with its meal rows stopping short
of a blank strip, unlike the 13" layout the App Store screenshots show. In
#207 a 13" iPad in portrait put the panel and cluster beside a three-column hero instead, over
meal rows about 990pt wide. That read as a phone list stretched across a tablet, and the split
replaced it.

Large text (xxxLarge and up, one step below the accessibility sizes) keeps the stacking
two-column hero, even when three columns are asked for, and stacks the panel, its header
and the cluster under it. The panel only appears when the profile has nutrient targets.
Height is in the wide-regular gate because a split on a closed Duo in landscape shows only
the primary view.

**iPad.** `MainTabView` uses `.sidebarAdaptable`: a top tab bar with a sidebar toggle in
portrait, the sidebar in landscape; an iPhone, the Duo included, keeps its tab bar. Sheets
need nothing: Nutrition Details presents as a centred sheet about 580pt wide. The app
and its widget extension target iPhone and iPad (`TARGETED_DEVICE_FAMILY = "1,2"`). With
`1` the build installs on an iPad but runs in the scaled iPhone compatibility window, and
none of this layout is reachable. The simulator shows the same window, so check the setting
before trusting an iPad capture.

## Looking at it

The simulator (`iPhone Duo`, iOS 27.1 runtime, Xcode 27.1) boots closed, on the outer
display. The fold is a Device Hub control (buttons under the device; hold ⌥ for the hinge
slider) and has no `simctl`/`devicectl` command. What *does* work from a shell:

```bash
# the two displays: id 1 is the outer LCD, id 3 the inner LCD-1 (lit only when open)
xcrun devicectl device info displays --device <udid>
xcrun simctl io <udid> screenshot --display=1 outer.png

# rotate the closed device
xcrun devicectl device orientation set --device <udid> landscapeLeft

# Apple's resizability test: host the app on a "Resizable" display at any size.
# 669x951 and 951x669 are the inner display; ~470 wide is Split View.
xcrun devicectl device appResize start --device <udid> --preferred-size 669x951   # keeps running
xcrun devicectl device appResize set   --device <udid> --preferred-size 951x669
xcrun simctl io <udid> screenshot --display=5 inner.png       # id from `info displays`
```

`CalorynUITests/PoseScreenshotTests` photographs the surfaces the Duo rearranges, on every
screen (so a resizable session is captured too), named by `CALORYN_POSE`:

```bash
CALORYN_POSE=inner-portrait xcodebuild test -project Caloryn.xcodeproj -scheme Caloryn \
  -only-testing:CalorynUITests/PoseScreenshotTests -destination "id=<udid>" \
  -resultBundlePath pose.xcresult CODE_SIGNING_ALLOWED=NO
```

`appResize` is Duo-only: an iPad simulator (iOS 27.0) reports "Resizable App Management is
not supported". Rotate an iPad with `devicectl device orientation set`, and approximate a
Split View half on the Duo's resizable display (`--preferred-size 683x1024`), which yields
the same regular width.

Two gotchas seen while doing this: `xcodebuild test` against the Duo (and an iPad on iOS 27.0)
hung for good after the tests finished, with the result bundle still in `Staging/`; the PNGs are intact in
`<bundle>/Data/` and sort by modification time in capture order. And `ThemeScreenshotTests`
asserts `app.tabBars` exists, which the vertical bar is not — `TabBar.go(to:)` now falls
back to the tab's label for that reason.

The partially folded poses were **not** captured: folding needs Device Hub's own buttons.
