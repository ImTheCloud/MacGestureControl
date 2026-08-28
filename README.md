# 🖐️ MacGesture Control Pro

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013%2B-blue?style=for-the-badge&logo=apple" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-5.9%2B-orange?style=for-the-badge&logo=swift" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="MIT License">
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20%26%20Intel-purple?style=for-the-badge" alt="Universal">
</p>

<p align="center">
  <b>A lightweight, ultra-sleek open-source macOS menu bar app that brings powerful multi-touch trackpad gestures, window snapping, media controls, middle-click simulation, and a Dynamic HUD to your Mac.</b>
</p>

---

## ✨ Key Highlights

- 🔇 **Zero Interference by Default**: All gestures are disabled out of the box except **4-Finger Vertical Swipe for System Volume**, preserving 100% of standard macOS 2-finger web scrolling and native gestures.
- 🖐️ **Native Multitouch Engine**: Direct hardware trackpad touch tracking for **2, 3, and 4 fingers**, including Swipes, Quick Taps, Pinch / Spread, and Corner Taps.
- 🪟 **Instant Window Snapping**: Snap windows to **Left Half**, **Right Half**, **Maximize**, **Center**, or **Minimize** with a single gesture.
- 🎯 **3-Finger Middle Click**: Simulate genuine middle-clicks on trackpads for opening links in new browser tabs, closing tabs, or CAD 3D navigation.
- 🖥️ **Dynamic Island / Sonoma HUD**: Floating translucent on-screen feedback with progress bars for volume, brightness, mute state, and window actions.
- ⚡ **Taptic Engine Haptic Feedback**: Subtle physical clicks felt on your trackpad as gestures trigger.
- 📡 **Live Trackpad Touch Radar**: Real-time visual touch canvas inside the settings popover showing finger positions.
- 🎨 **Modern macOS Native UI**: Built with pure SwiftUI, macOS vibrancy materials, custom menu bar icons, and instant `UserDefaults` persistence.

---

## 🖐️ Gesture & Feature Matrix

| Gesture | Default Setting | Supported Actions |
|---|---|---|
| **4-Finger Swipe Up / Down** | 🔊 **System Volume (Active)** | Volume, Brightness, Track Navigation, Snapping, Apps |
| **4-Finger Swipe Left / Right** | *Disabled* | Next/Prev Track, Window Snapping, Mission Control |
| **4-Finger Quick Tap** | *Disabled* | Launch App, Screenshot, Lock Screen, Desktop |
| **4-Finger Pinch In / Out** | *Disabled* | Show Desktop, Mission Control, Maximize Window |
| **3-Finger Quick Tap** | *Disabled* | **Middle Click**, Play/Pause, Mute, App Launch |
| **3-Finger Swipe Left / Right** | *Disabled* | Next / Previous Media Track, Snap Windows |
| **3-Finger Swipe Up / Down** | *Disabled* | Volume, Brightness, Play/Pause Media |
| **2-Finger Quick Tap** | *Disabled* | Any custom action |
| **Trackpad Corner Taps** | *Disabled* | Top-Left, Top-Right, Bottom-Left, Bottom-Right actions |

---

## 🚀 Quick Start & Installation

### Option 1: Run with Swift CLI (Recommended for Developers)

```bash
# 1. Clone the repository
git clone https://github.com/ImTheCloud/MacGestureControl.git
cd MacGestureControl

# 2. Build and launch directly
swift run
```

### Option 2: Build Release Binary

```bash
# Build optimized binary
swift build -c release

# Launch in background
./.build/release/MacGestureControl &
```

---

## 🔒 Permissions & Security

MacGestureControl requires **Accessibility (Input Monitoring)** permissions to listen to global multi-touch trackpad events and manage window positions:

1. On first launch, macOS will prompt you to grant Accessibility access.
2. Open **System Settings → Privacy & Security → Accessibility**.
3. Toggle the switch **ON** for your Terminal (or `MacGestureControl` app).

---

## 🛠️ Architecture & Technologies

- **SwiftUI & AppKit**: Seamlessly blends modern declarative SwiftUI with native `NSPopover`, `NSStatusItem`, and `NSVisualEffectView`.
- **Private MultitouchSupport Framework**: Dynamically loaded via `dlopen`/`dlsym` to access real-time finger count, coordinate deltas, and velocity without private header linking issues.
- **CoreAudio & AudioToolbox**: Direct hardware device volume manipulation (`kAudioHardwareServiceDeviceProperty_VirtualMainVolume`).
- **macOS Accessibility API (`AXUIElement`)**: Zero-dependency window positioning and resizing.
- **NSHapticFeedbackManager**: Direct Taptic Engine driver for responsive gesture triggers.

---

## 🤝 Contributing

Contributions, feature suggestions, and pull requests are welcome!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingGesture`)
3. Commit your Changes (`git commit -m 'Add AmazingGesture'`)
4. Push to the Branch (`git push origin feature/AmazingGesture`)
5. Open a Pull Request

---

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for more information.
