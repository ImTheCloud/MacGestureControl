# 🖐️ MacGesture Control

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013%2B-blue?style=for-the-badge&logo=apple" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-5.9%2B-orange?style=for-the-badge&logo=swift" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="MIT License">
  <img src="https://img.shields.io/badge/Universal-Apple%20Silicon%20%26%20Intel-purple?style=for-the-badge" alt="Universal">
</p>

<p align="center">
  <b>A small, open-source macOS menu bar app that turns spare trackpad gestures into
  volume, media and window controls — without getting in the way of the gestures
  macOS already gives you.</b>
</p>

---

## ✨ Highlights

- **Quiet by default.** A fresh install binds nothing at all: every macOS trackpad gesture keeps working untouched until you deliberately claim one.
- **Reads the trackpad directly.** Uses the `MultitouchSupport` framework for true finger counts, so gestures are recognised by how many fingers are down — not by intercepting scroll events. Built-in and external Magic Trackpads both work.
- **Gestures that don't collide.** One touch produces one gesture: a swipe locks to a single axis, a pinch cannot fire mid-swipe, and a swipe can never be mistaken for a tap.
- **Both directions from one binding.** Bind "Next Track" to a horizontal swipe and the reverse swipe gives you "Previous Track" automatically. Same for snapping left/right and maximise/minimise.
- **Nothing macOS already does.** Mission Control, App Exposé and desktop switching are three-finger swipes built into macOS, so the app leaves them there instead of shipping a second, worse copy. What it adds is what the trackpad cannot do on its own: volume, brightness, media, windows.
- **20 actions** across audio, display, media, windows and system, grouped in the picker.
- **Tells you when macOS is in the way.** Bind a gesture macOS already uses and the app says so, and offers to switch the system one off — and to put it back.
- **Live HUD and haptics.** A floating overlay confirms every action, with a progress bar for volume and brightness, and a Taptic Engine tick as it fires.
- **Live trackpad view.** Watch what the engine sees while you configure gestures.

---

## 🖐️ Gesture matrix

| Gesture | Default | Notes |
|---|---|---|
| **4-finger swipe ↕** | *off* | Continuous actions repeat while you keep swiping |
| **4-finger tap** | *off* | |
| **4-finger swipe ↔** | *off* | |
| **4-finger pinch / spread** | *off* | |
| **3-finger swipe ↕ ↔, tap, pinch / spread** | *off* | |
| **1-finger corner taps** (×4) | *off* | Tap a corner of the trackpad |

Two fingers are macOS's own: swiping is scrolling, a tap is a secondary click,
pinching is zoom, and none of it can be switched off — so there is no
two-finger slot to bind against it.

Every slot can be bound to any action:

| Category | Actions |
|---|---|
| **Audio** | System Volume · Mute / Unmute · Mute / Unmute Microphone |
| **Display** | Screen Brightness · Lock Screen |
| **Media** | Play / Pause · Next Track · Previous Track |
| **Windows** | Snap Left / Right / Top / Bottom · Maximize · Center · Minimize · Toggle Full Screen · Close Window |
| **System** | Screenshot to Clipboard · Spotlight · Launch Application |

---

## 🚀 Install

The app is not signed with an Apple Developer certificate — that costs $99 a
year — so macOS asks once whether you really want to open it. The steps below
are the whole story; nothing else is hiding behind them.

### 1. Get the app

**Download it** from the [latest release](https://github.com/ImTheCloud/MacGestureControl/releases/latest),
unzip, and drag `MacGestureControl.app` into your **Applications** folder.

Or **build it yourself** — no Xcode needed, just the command line tools:

```bash
git clone https://github.com/ImTheCloud/MacGestureControl.git
cd MacGestureControl
./Scripts/build-app.sh
```

That produces a universal (Apple Silicon + Intel) `dist/MacGestureControl.app`,
and a zip beside it. Drag the app into **Applications**.

### 2. Open it the first time

Because the app is unsigned, double-clicking it shows *"MacGestureControl cannot
be opened"*. That is Gatekeeper, and you get past it once:

- **right-click** (or Control-click) the app → **Open** → **Open** in the dialog.

If macOS refuses outright — some versions of macOS 15+ hide the Open button —
strip the download flag instead, then open it normally:

```bash
xattr -dr com.apple.quarantine /Applications/MacGestureControl.app
```

An app you built yourself is never quarantined, so this step does not apply.

### 3. Give it Accessibility access

Nothing has to be configured for the app to *see* your trackpad, but pressing a
media key or moving a window on your behalf needs permission:

1. The app asks on first launch — click **Open System Settings**.
2. **Privacy & Security → Accessibility**, switch **MacGestureControl** on.
3. The dot in the popover turns green and says *Active & listening*.

### 4. Bind a gesture

There is deliberately nothing bound on a fresh install, so every macOS gesture
still behaves exactly as it did. Click the menu bar icon, pick a tab
(**4 Fingers**, **3 Fingers**, **Corners**), and choose an action next to a
gesture. It works immediately — no restart, no logging out.

If macOS already uses that gesture, the app says so under the row and offers to
switch the system one off. It remembers what it turned off, hands it back the
moment you unbind the gesture, and the **Restore** button in Preferences puts
everything back at once.

Turn on **Launch at Login** in Preferences and you are done.

### Uninstall

Quit from the popover, drag the app to the Trash, and — if you ever let it
switch a macOS gesture off — press **Restore** before you do. To clear its
settings as well:

```bash
defaults delete com.imthecloud.MacGestureControl
```

---

## 🔒 Permissions

**Accessibility** is the only permission the app asks for, and it is what lets a
gesture press a media key, move a window or open Spotlight on your behalf.
Reading the trackpad works without it — the actions do not. An action that
cannot run says so in the overlay instead of pretending it worked.

No network access, no analytics, no bundled dependencies. Settings live in
`UserDefaults`, and the app never writes anything outside its own preferences —
except the macOS trackpad gestures you explicitly ask it to switch off, which it
can put back.

### "It is already switched on, but the app still asks"

macOS attaches the grant to the *code signature* it was given, not to the name
in the list. A build from `swift build` is signed ad-hoc, so every rebuild
produces a file the old grant no longer covers: the entry stays in the list,
still on, while the app sees no access. Remove it with **–**, then add the
current binary back — the banner's **Reveal** button selects it in Finder.

This only bites while you are working on the app. To stop it happening on every
rebuild, sign with a self-signed certificate — Keychain Access → Certificate
Assistant → *Create a Certificate…*, type **Code Signing** — and point the
scripts at it:

```bash
export MACGESTURE_CODESIGN_IDENTITY="MacGestureControl Dev"
./Scripts/build-app.sh    # or ./Scripts/dev.sh
```

---

## 🛠️ How it works

| File | Responsibility |
|---|---|
| `MultitouchEngine` | Reads raw finger frames and recognises swipes, taps, pinches and corner taps |
| `GestureSlot` / `GestureAction` | Describe every bindable gesture and every action once, so the engine, UI and storage cannot drift apart |
| `AppSettings` | Persistence, plus an immutable snapshot the realtime touch thread can read safely |
| `SystemController` | Performs the action: CoreAudio, DisplayServices, media keys, synthesised keystrokes |
| `WindowManager` | Window geometry through the Accessibility API |
| `SettingsView` | The popover, generated from the gesture slots |
| `NativeGestureConflicts` | Spots gestures macOS already claims, and switches them off on request |
| `KeyboardLayout` | Resolves key codes on the user's own keyboard layout |
| `HUDOverlay` | The floating confirmation panel |

`MultitouchEngine.handleFrame` is the single boundary where a raw frame becomes
a finger count, and it reads settings through an injectable provider — which is
what makes the recogniser testable.

**Recognition, briefly.** Fingers never land at exactly the same moment, so the
engine waits for the finger count to hold steady before any movement counts.
Movement is then measured from the settled position: a swipe locks onto whichever
axis crosses its threshold first, continuous actions (volume, brightness) repeat
as you keep going while discrete ones fire once per swipe, and a touch that
produced no motion at all — brief and barely moved — is what becomes a tap.

---

## 🤝 Contributing

Issues and pull requests are welcome.

```bash
swift build            # debug build
swift test             # gesture recognition tests
./Scripts/dev.sh       # rebuild and relaunch, streaming logs
./Scripts/build-app.sh # universal .app plus a zip, in dist/
```

Actions can be tried from the terminal without binding them to a gesture first:

```bash
./.build/debug/MacGestureControl --list-actions
./.build/debug/MacGestureControl --run-action volume --down
```

To publish a version, run `./Scripts/build-app.sh` and attach
`dist/MacGestureControl.zip` to a GitHub release.

The recogniser is driven by synthetic touch frames in
`Tests/MacGestureControlTests`, so gesture behaviour — taps versus swipes, axis
locking, direction handling, corner regions — can be verified without a
trackpad and without touching your system.

1. Fork the project
2. Create a branch (`git checkout -b feature/amazing-gesture`)
3. Commit your changes
4. Open a pull request

New actions only need a case in `GestureAction` (title, icon, category, and its
`inverse` if the reverse swipe should do something different) plus a branch in
`SystemController.execute` — the settings UI picks them up on its own.

Never hard-code a virtual key code for a letter: they name physical positions,
so key 13 is `W` on QWERTY and `Z` on AZERTY. Use `KeyboardLayout.keyCode(for:)`.

---

## 📄 License

MIT — see [LICENSE](LICENSE).
