# Slice 2: AR Keyboard Visualization

## Goal

Display a virtual 88-key piano keyboard in the AR immersive space, with keys lighting up when pressed on the physical piano.

## Scope

This slice proves the AR rendering + MIDI feedback loop:

```
activeNotes (MIDIManager) → RealityKit entities → key color changes
```

## What to Build

### 1. Immersive Space

Add an `ImmersiveSpace` scene (`.mixed` style) to `ARPianoEffectApp`. The window remains open alongside it.

### 2. Piano Keyboard Entity

A `RealityView` that procedurally generates 88 key entities (MIDI notes 21–108):

- **White keys**: box mesh, 23mm × 150mm × 10mm, white material
- **Black keys**: box mesh, 13mm × 95mm × 15mm, dark gray material, offset +5mm in y so they sit higher
- All keys are children of a single root entity for easy transform control
- Store a `[UInt8: ModelEntity]` lookup so note on/off can find keys instantly

### 3. Key Highlighting

Observe `MIDIManager.activeNotes`. On change, diff the previous set and update affected keys:
- Note On → key material becomes light blue (`SimpleMaterial(color: .cyan)`)
- Note Off → restore original white or dark-gray material

### 4. Alignment Controls

A new **AR** tab in `ContentView` with a real-time pinch-based alignment flow:

1. User opens the immersive space and selects which note each hand will reference (default C2 / C4)
2. User taps **Align Keyboard** to enter alignment mode — keyboard turns semi-transparent (45% opacity)
3. User pinches thumb + index finger together on both hands and places them at the two reference keys
4. The keyboard mesh moves in real time to match the pinch positions
5. When both hands hold still for 5 seconds, a countdown ("Locking in 5…4…3…") is shown in the panel; the keyboard locks in at full opacity
6. Any movement resets the countdown; **Cancel** aborts

During alignment, colored spheres mark each pinch position in AR (blue = left hand, orange = right hand). Alignment runs automatically on lock-in with no extra tap needed.

`AlignmentManager` owns the ARKit `HandTrackingProvider` session (started from `PianoKeyboardView.task`) and writes x / y / z / yaw / scale into `KeyboardTransform`.

**Alignment math** (given two live pinch world positions and their known x-positions in keyboard local space):
- **Scale**: `worldDist / virtualDist` (distances projected onto the xz plane)
- **Yaw**: `atan2(-dir.z, dir.x)` where `dir` is the unit xz direction from left pinch to right pinch
- **Reference point**: the **front-top-center edge** of each key (x-center, y = +height/2, z = +depth/2 from geometric center) — the point the fingertip naturally rests on
- **Translation**: `kt.x/y/z` computed so the left pinch maps to the left key's front-top-center in world space

## Definition of Done

- [ ] Tapping "Open AR View" opens the immersive space; "Close" dismisses it
- [ ] 88-key keyboard is visible floating in the mixed-reality view
- [ ] White and black keys have correct relative proportions and positions
- [ ] Playing a note on the physical piano lights up the corresponding key in AR
- [ ] Releasing the note restores the key's original color
- [ ] Pinch both hands at two reference keys → keyboard moves in real time to match
- [ ] Keyboard is semi-transparent during alignment; blue/orange spheres show pinch positions
- [ ] 5-second stability countdown locks the alignment automatically
- [ ] Keyboard correctly positions, rotates, and scales to match the physical piano after lock-in

## Not In This Slice

- Drag gestures directly on the keyboard entity in AR
- Note name labels on keys
- Visual effects (glow, particles, animations)
- Persistence of alignment settings across launches
