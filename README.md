# MacGestureControl

A lightweight macOS menu‑bar application that lets you control system functions with custom trackpad gestures.

## Features (v0.1)
- Adjust system volume with a four‑finger swipe up/down (already implemented).
- **Future extensions** (planned):
  - Adjust display brightness.
  - Toggle mute/unmute.
  - Media playback controls (play/pause, next, previous).
  - Change mouse tracking speed.
  - Custom trackpad shortcuts.
  - Window tiling / snapping.
  - Launch or quit applications via gestures.

## Installation
```bash
# Clone the repo
git clone https://github.com/ImTheCloud/MacGestureControl.git
cd MacGestureControl

# Build the app
swift build -c release

# Run the app (adds a speaker icon to the menu bar)
./.build/release/MacGestureControl &
```
The app will request **Accessibility** permission on first launch – grant it in **System Settings → Privacy & Security → Accessibility**.

## Contributing
Feel free to open issues or submit pull requests to add new gestures or improve the UI. The project is MIT‑licensed.
