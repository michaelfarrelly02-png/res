# BarTrack — iOS prototype

BarTrack is a SwiftUI prototype for tracking barbell performance with an AirPod attached to the bar.
This version runs fully on **simulated data** (Demo Mode), so it works in the iOS Simulator with no AirPods or gym equipment.

> Speed scores are **relative (0–100) and experimental**. They are not validated m/s velocity measurements.

## Features

- Back Squat tracking (other lifts shown as "coming soon")
- Live rep counter with Slow / Medium / Fast relative speed
- Target speed zone (in zone / too slow / too fast)
- Speed-drop limit: "stop the set" alert when reps slow down past your limit
- Hands-free sets: timer starts on the first rep, set ends after a pause, rest timer starts
- Estimated mean/peak velocity (m/s), power (W) and range of motion (cm), always marked EST. and hideable in Settings
- Results, history, progress charts, kg/lb, themes, Demo Mode

## Requirements

- A Mac with **Xcode 16 or newer** (free from the Mac App Store)
- iOS 17+ Simulator (included with Xcode)
- No third-party dependencies

## Run it on your MacBook

1. Get the code onto your Mac:
   ```bash
   git clone https://github.com/michaelfarrelly02-png/res.git
   ```
   ```bash
   cd res && git checkout claude/lucid-mayer-9m4pk8
   ```
2. Open the project:
   ```bash
   open BarTrack/BarTrack.xcodeproj
   ```
3. In Xcode's toolbar, pick the **BarTrack** scheme and a simulator such as **iPhone 16 Pro**.
4. Press **⌘R** (Product → Run). The Simulator launches with the app.

### Try the full flow

1. **Home** → tap **START WORKOUT**.
2. Choose an exercise, enter the weight, optionally set target reps → **Start Set**.
3. On the live screen use the **Demo Mode** buttons (SLOW / MEDIUM / FAST / AUTO) or **Auto-Simulate Set**. Watch the rep counter, speed label and chart update.
4. Tap **Finish Set** → review the results. Tap any bar in the chart to see that rep.
5. Tap **Another Set** to keep going, or **Save Workout**.
6. Open **History** to browse saved workouts, filter by exercise and see progress charts.
7. Tip: **Settings → Load sample workouts** fills the history with five weeks of realistic data.

### Running on a real iPhone (optional)

Select your iPhone as the run destination, then in the **BarTrack** target → **Signing & Capabilities** choose your Apple ID team. If the bundle ID `com.bartrack.prototype` is taken, change it to something unique (e.g. `com.yourname.bartrack`).

## Project structure

The Xcode project uses a *synchronized folder*: every file inside `BarTrack/BarTrack/` is part of the app automatically. Add new files in Finder or Xcode and they are picked up with no project-file edits.

```
BarTrack/
├── BarTrack.xcodeproj               Xcode project (open this)
└── BarTrack/
    ├── App/
    │   ├── BarTrackApp.swift         App entry point, SwiftData container
    │   ├── RootView.swift            Tab bar: Home · Workout · History · Settings
    │   ├── AppRouter.swift           Shared tab selection
    │   └── AppearanceConfigurator.swift  Dark tab/navigation bar styling
    ├── DesignSystem/
    │   ├── Theme.swift               Colours, fonts, radii, settings keys
    │   ├── Components.swift          Cards, metric tiles, badges, buttons, logo
    │   └── RepSpeedChart.swift       Reusable tappable rep bar chart
    ├── Models/
    │   ├── Exercise.swift            The five barbell lifts
    │   ├── SpeedClass.swift          SLOW / MEDIUM / FAST + classifier thresholds
    │   ├── RepRecord.swift           Rep, set result and set analytics
    │   ├── WorkoutModels.swift       SwiftData models (WorkoutSession, SetEntry)
    │   └── WeightUnit.swift          kg / lb conversion and formatting
    ├── Tracking/                     Kept separate from the UI
    │   ├── TrackingService.swift     Protocol every data source implements
    │   ├── SimulatedTrackingService.swift   Demo Mode (manual + auto reps)
    │   ├── RepSimulationModel.swift  Fatigue model for simulated reps
    │   ├── CSVReplayTrackingService.swift   Replays recorded motion CSVs
    │   ├── AirPodsMotionTrackingService.swift  CMHeadphoneMotionManager (Phase 2, not wired up)
    │   ├── RepDetector.swift         Placeholder detector — port Python v0.6.1 here
    │   └── MotionConnectionState.swift  Not connected / connected / streaming
    ├── Features/
    │   ├── Home/HomeView.swift       Screen 1 — dashboard
    │   ├── Workout/
    │   │   ├── WorkoutSetupView.swift      Screen 2 — start workout
    │   │   ├── LiveWorkoutView.swift       Screen 3 — live tracking
    │   │   ├── LiveWorkoutViewModel.swift  Set timer, rep handling
    │   │   ├── WorkoutFlowController.swift Live → Results → Save flow
    │   │   └── WorkoutFlowView.swift       Full-screen container
    │   ├── Results/SetResultsView.swift    Screen 4 — set results
    │   ├── History/                  Screen 5 — list, detail, progress charts
    │   └── Settings/SettingsView.swift     Screen 6 — settings
    ├── Preview/SampleData.swift      Realistic sample workouts for previews
    ├── Utilities/Formatting.swift
    └── Assets.xcassets               App icon and accent colour
```

## Architecture

```
Screen (SwiftUI)  →  LiveWorkoutViewModel  →  TrackingService (protocol)
                                                ├─ SimulatedTrackingService   ← used now
                                                ├─ CSVReplayTrackingService   ← imported data
                                                └─ AirPodsMotionTrackingService ← Phase 2
```

- Screens never talk to sensors. They receive `TrackingEvent`s (status changes and detected reps).
- Every source reports a **relative score**; `SpeedClassifier` turns it into SLOW / MEDIUM / FAST (Fast ≥ 70, Slow < 45).
- `MotionConnectionState` keeps "AirPods connected" separate from "motion data streaming". Only real samples arriving count as streaming.
- Saved workouts live in SwiftData on the device. Reps are stored as JSON on each set, so validated fields (mean concentric velocity, peak velocity) can be added later without a schema rewrite.

## Next steps (Phase 2)

1. Port the Python v0.6.1 rep detection and classification into `RepDetector` (or a new type that returns `DetectedRep`).
2. Validate it by replaying recorded CSVs through `CSVReplayTrackingService`.
3. Add an AirPods option on the Start Workout screen that creates `AirPodsMotionTrackingService` and drives the connection status from it.
