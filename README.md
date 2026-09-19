# DoorSign: Phase 1 (Local status engine)

A macOS menubar app that detects your work status on the Mac and lets you override it.
Phase 1 is local only. Nothing is sent to Google Chat or a server yet; changes are written to the system log.

## Files

| File | Purpose |
|---|---|
| `DoorSignApp.swift` | App entry point, menubar icon |
| `MenuContentView.swift` | Menubar panel: current status, quick statuses, settings, detected signals |
| `StatusEngine.swift` | Priority rules, change delay, manual override with expiry, saved settings |
| `CallDetector.swift` | Checks whether any app is using the mic or camera |
| `SystemMonitor.swift` | Screen lock, display sleep, idle time |
| `StatusPublisher.swift` | Output seam. Logs now, Google Chat and team board plug in later |
| `Models.swift` | Status types, durations, settings |

## Building

The Xcode project is committed, so the manual setup below is already done:
agent app (no Dock icon), no App Sandbox, macOS 13.0 deployment target,
Swift 5 language mode, ad-hoc signing so it builds without a Developer ID.

```
open DoorSign.xcodeproj
```

Then press Cmd+R. Or from the command line:

```
./scripts/build.sh
open build/Build/Products/Debug/DoorSign.app
```

A emoji appears in the menubar. There is no Dock icon and no window; click the
menubar emoji to open the panel.

<details>
<summary>Manual setup, if you ever need to recreate the project by hand</summary>

1. Xcode > New Project > macOS > App. Name: `DoorSign`. Interface: SwiftUI. Language: Swift.
2. Set Deployment Target to **macOS 13.0** or later (needed for `MenuBarExtra`).
3. Delete the generated `ContentView.swift` and the generated `DoorSignApp.swift`.
4. Drag all `.swift` files from `DoorSign/` into the project (check "Copy items if needed").
5. Target > Info tab: add `Application is agent (UIElement)` = `YES`. This hides the Dock icon.
6. Target > Signing & Capabilities: remove **App Sandbox** for Phase 1. The app will be distributed internally with Developer ID, not the App Store, so the sandbox is not required, and removing it avoids issues with device and lock notifications. Revisit in Phase 6.
7. Set Swift Language Version to **5** (Swift 6 strict concurrency rejects `SystemMonitor`'s notification handlers; see `docs/phase1-test-checklist.md`).

</details>

No permission prompts are expected. The app only reads whether the mic or camera is running, not the audio or video itself.

## Viewing status changes

Open Console.app, filter by subsystem `com.qburst.doorsign`, or run:

```
log stream --predicate 'subsystem == "com.qburst.doorsign"' --level info
```

## Test checklist

Set "Change delay" to 5 sec in Detection settings to speed up testing.

| # | Scenario | Expected |
|---|---|---|
| 1 | Launch app, use Mac normally | 🟢 Available |
| 2 | Join a Google Meet with mic on | 🎧 In a call within ~10s |
| 3 | Mute mic in Meet but keep camera on | Still 🎧 In a call |
| 4 | Leave the call | 🟢 Available after delay |
| 5 | Play a YouTube video (no mic) | Stays 🟢 Available |
| 6 | Lock screen (Ctrl+Cmd+Q) outside lunch window | 💤 Away after delay |
| 7 | Unlock quickly (under the delay) | No change, no flicker |
| 8 | Set lunch window to include now, lock screen | 🍽️ Lunch break |
| 9 | Pick "Focus time" for 30 minutes | 🎯 Focus time, subtitle shows end time |
| 10 | While on manual status, join a call | Manual status stays (manual wins) |
| 11 | Click Clear | Returns to automatic status immediately |
| 12 | Turn off "Automatic status" | 🟢 Available, subtitle says paused |
| 13 | Quit and relaunch | Settings and any active manual status are kept |
| 14 | Connect AirPods and join a call | 🎧 In a call |

Note on test 3: some meeting apps release the mic when muted. The camera check covers video calls; audio-only muted calls may show Available. Phase 2 fixes most of this with calendar meetings.

## Known limits in Phase 1

- Detection polls every 5 seconds. Good enough for status; switch to CoreAudio listeners later if needed.
- Focus mode is manual only. macOS has no reliable public API to read the current Focus.
- Not signed or notarized yet. Colleagues can run it by building locally until Phase 6.
