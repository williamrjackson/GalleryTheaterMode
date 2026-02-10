# TheaterModePlayer

A lightweight macOS fullscreen video playback tool designed for museum and gallery environments.

**TheaterModePlayer** presents a selected video in a clean, borderless, black fullscreen window — ideal for projection surfaces and controlled presentation spaces. It allows precise width control and live vertical positioning adjustments.

Built using native macOS frameworks (Swift + AVFoundation).

---

## Features

- Borderless fullscreen playback 
- Solid black background for projection environments
- Adjustable target video width, maintaining aspect ratio
- Customizable "Ready State" supporting placeholder image
- Ready State controls to adjust height/width live
- Animated "house lights down" fade on initial play from Ready State
- Keyboard-based transport controls
- Settings persistence (remembers width, Y offset & Ready State colors)
- Hides mouse in Presentation Mode
- Automatically prefers external display 
- No runtime dependencies beyond macOS

---
![UI](TheaterModeScreenshot_0.png)
![Presentation](TheaterModeScreenshot_1.png)


## Controls

In Ready State:

| Key | Ready State Action | Playback Action 
|-----|--------------------|----------------
| **Space** | Start Presentation | Play / Pause |
| **← / →** | Player Width Adjustment | Seek ±3 Seconds |
| **Shift + ← / →** | Coarse Width Adjustment | Seek ±10 Seconds |
| **Option + ← / →** | Fine Width Adjustment | Seek by Frame |
| **↑ / ↓** | Player Vertical Position Adjustment | Seek ±1 Minute |
| **Shift + ↑ / ↓** | Coarse Vertical Adjustment | Seek ±5 Minutes |
| **Option + ↑ / ↓** | Fine Vertical Adjustment | Seek ±30 Seconds |
| **Esc** | N/A | Exit playback |


If a non-handled key is pressed, an on-screen overlay briefly reappears showing the controls.

---

## How It Works

1. Launch the app.
2. Optionally select Ready State placeholder image.
3. Choose a video file.
4. Playback opens fullscreen on the preferred display (external projector if connected).
5. Adjust width and positioning using arrow keys if needed.
6. Begin presentation by typing SPACE
7. During playback SPACE pauses & ESC exits playback.

Settings persist between launches.

## Steps to Circumvent MacOS Security Block

If you see “The app can’t be opened because it is from an unidentified developer”:

1. Go to System Settings → Privacy & Security.
2. Scroll down.
3. You should see a message about TheaterModePlayer being blocked.
4. Click “Open Anyway”.
5. Confirm.

*Should only be required at first launch