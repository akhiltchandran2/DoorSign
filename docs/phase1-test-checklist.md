# Phase 1 test walkthrough

Static review was done without a compiler (no macOS in the build environment).
Everything below is either a change already applied, or a prediction to confirm
on your Mac. Work top to bottom.

## Before you start

Two terminals, repo root:

```
# terminal 1
./scripts/build.sh && open build/Build/Products/Debug/TeamStatus.app

# terminal 2
./scripts/watch-log.sh
```

Then in the menubar panel:

1. Open **Detection settings**, set **Change delay** to **5 sec**.
2. Open **What the app detects** and leave it expanded. This panel is the
   ground truth for every test below. If a status looks wrong, check the raw
   signals here first: it tells you whether the problem is detection
   (`CallDetector` / `SystemMonitor`) or the priority rules (`StatusEngine`).

Note that the poll interval is 5 seconds and is separate from the change delay.
With both at 5s, a transition lands 5 to 10 seconds after the signal changes,
not exactly 5. That is expected, not a bug.

## Changes already applied

| File | Change | Why |
|---|---|---|
| `MenuContentView.swift` | Added `import AppKit` | `NSApplication.shared.terminate` is AppKit. `import SwiftUI` re-exports it on most SDKs, but not reliably. One line, removes the risk. |
| `CallDetector.swift` | Replaced `kCMIOObjectPropertyElementMain` with a local `CMIOObjectPropertyElement(0)` | CoreMediaIO never got CoreAudio's `Master` to `Main` rename, so that constant may not exist depending on the SDK. The element value is 0 in every version, so this is correct and compiles everywhere. |
| `TeamStatus.xcodeproj` | `SWIFT_VERSION = 5.0` | See "Swift 6" below. |
| `TeamStatus.xcodeproj` | `CODE_SIGN_IDENTITY = "-"` | Builds on any Mac without configuring a Developer ID team. Phase 6 replaces this. |

No other code was touched. `StatusEngine` still owns the priority rules,
`CallDetector` and `SystemMonitor` still only read signals, `StatusPublisher`
is still the only output seam.

## Predicted issues, highest impact first

### 1. Test 5 will likely fail if AirPods or a USB headset are connected — HIGH

`CallDetector.isRunningSomewhere` queries
`kAudioDevicePropertyDeviceIsRunningSomewhere` on **global** scope. On a device
that has both input and output streams (AirPods, most USB headsets), that flag
goes true when the device is running for **playback** too, not just capture.
`hasInputStreams` does not help: AirPods genuinely have an input stream.

So: play a YouTube video through AirPods and the app reports mic in use, giving
🎧 In a call when the checklist expects 🟢 Available.

On a bare MacBook with built-in speakers this passes, because the built-in mic
and built-in output are separate CoreAudio devices.

**How to confirm:** connect AirPods, play a YouTube video, watch
"Microphone in use" in the What the app detects panel. If it says Yes, this is it.

**Fix if it reproduces** (input scope first, global as fallback, so we do not
break the built-in mic if the driver rejects the scoped query):

```swift
private func isRunningSomewhere(_ device: AudioDeviceID) -> Bool {
    for scope in [kAudioDevicePropertyScopeInput, kAudioObjectPropertyScopeGlobal] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &address) else { continue }
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr else { continue }
        return running != 0
    }
    return false
}
```

Re-run tests 2, 5 and 14 together after this change. They trade off against
each other, so they have to pass as a set.

### 2. If the menubar emoji never changes but the panel is correct — MEDIUM

That is a `MenuBarExtra` rendering issue, not the status engine. `MenuBarExtra`
with `.menuBarExtraStyle(.window)` had known label-refresh bugs on early macOS
13.x. Diagnose by opening the panel: if the header shows the right status and
the menubar emoji is stale, the engine is fine. Tell me and I will switch the
label to a `Text` driven by an explicit `@ObservedObject`, or move to
`NSStatusItem`.

### 3. Swift 6 language mode will not compile this — MEDIUM, already pre-empted

`SystemMonitor` is a plain non-`Sendable` class captured by escaping
notification handlers, and `Timer.scheduledTimer`'s block is `@Sendable`. Under
Swift 6 strict concurrency both are errors, not warnings. The project pins
`SWIFT_VERSION = 5.0`, so this should not bite. If Xcode ever prompts you to
migrate to Swift 6, say no until we do it deliberately, because the fix is to
make `SystemMonitor` a `@MainActor` class and that is a real change to the
detection layer.

### 4. Test 9's duration picker is in the wrong place — MEDIUM, design issue

Test 9 is "Pick Focus time for 30 minutes". In the current panel the
**Clear after** picker sits *below* the six status buttons, and clicking a
status fires immediately using whatever duration is currently selected
(default: 1 hour). So the natural reading order produces the wrong result:
you click Focus time, then notice the duration control underneath.

A control that parameterises an action has to come before it. Recommendation:
move the duration picker and the custom message field **above** the status
grid, and change the label from "Clear after" to "For how long". That is a
pure layout change in `quickStatuses`, no engine change.

Say the word and I will make it. I left it alone because it is outside the
"fix compile errors" scope you gave me.

### 5. Adjusting any setting snaps the status instantly — LOW, by design but surprising

Every `settings` change calls `evaluate(immediate: true)`, which bypasses the
change delay. So while you are tuning sliders during testing, statuses jump
with no delay. This is intentional (you want settings to take effect at once)
but it can read as "the change delay is not working". It only applies to the
first evaluation after a settings change.

### 6. Settings will silently reset when the struct changes — LOW now, matters in Phase 2

`AutoStatusSettings` uses synthesized `Codable`, which requires every key to be
present when decoding. Add one property in Phase 2 and every existing user's
saved settings fail to decode, `load` returns `nil`, and they silently get
defaults back. Worth a custom `init(from:)` with per-key `decodeIfPresent`
before Phase 2 ships to anyone. Not a Phase 1 blocker.

### 7. Lunch window cannot cross midnight — LOW, out of scope

`isInLunchWindow` is `minutes >= start && minutes < end`, so a window like
23:00 to 01:00 is always false. Irrelevant for a lunch break. Noting it only
because Phase 5 reuses this shape for commute windows, which *can* cross
midnight.

## The 14 steps

Mark each one. For any failure, paste me the row from the What the app detects
panel plus the `log stream` output and I will fix it.

| # | Scenario | Expected | Result |
|---|---|---|---|
| 1 | Launch app, use Mac normally | 🟢 Available | |
| 2 | Join a Google Meet with mic on | 🎧 In a call within ~10s | |
| 3 | Mute mic in Meet but keep camera on | Still 🎧 In a call | |
| 4 | Leave the call | 🟢 Available after delay | |
| 5 | Play a YouTube video (no mic) | Stays 🟢 Available | see issue 1 |
| 6 | Lock screen (Ctrl+Cmd+Q) outside lunch window | 💤 Away after delay | |
| 7 | Unlock quickly (under the delay) | No change, no flicker | |
| 8 | Set lunch window to include now, lock screen | 🍽️ Lunch break | |
| 9 | Pick "Focus time" for 30 minutes | 🎯 Focus time, subtitle shows end time | see issue 4 |
| 10 | While on manual status, join a call | Manual status stays (manual wins) | |
| 11 | Click Clear | Returns to automatic status immediately | |
| 12 | Turn off "Automatic status" | 🟢 Available, subtitle says paused | |
| 13 | Quit and relaunch | Settings and any active manual status are kept | |
| 14 | Connect AirPods and join a call | 🎧 In a call | |

Notes on steps that need care:

- **Step 4** can take longer than the delay. Some meeting apps hold the audio
  device open for a few seconds after you leave. Watch "Microphone in use"
  rather than the clock.
- **Step 7** is the one that proves the change delay works. Lock, wait 2
  seconds, unlock. The status must never leave 🟢 Available. The
  "Changing to" row should appear and then disappear.
- **Step 13**: quit via the Quit button in the panel, not Force Quit.
  `UserDefaults` is written on every change, so either should work, but Quit is
  the supported path.
