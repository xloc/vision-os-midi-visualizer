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

A new **AR** tab in `ContentView` with:

- **Open / Close AR View** button (toggles the immersive space)
- **Position** — X (left/right), Y (height), Z (depth) sliders, range ±2m
- **Y Rotation** — slider, –180° to +180°
- **Scale** — slider, 0.5× to 2×

These bind to the root keyboard entity's transform via a shared `@Observable` `KeyboardTransform` state object.

## Definition of Done

- [ ] Tapping "Open AR View" opens the immersive space; "Close" dismisses it
- [ ] 88-key keyboard is visible floating in the mixed-reality view
- [ ] White and black keys have correct relative proportions and positions
- [ ] Playing a note on the physical piano lights up the corresponding key in AR
- [ ] Releasing the note restores the key's original color
- [ ] Sliders reposition / rotate / scale the keyboard in real time

## Not In This Slice

- Drag gestures directly on the keyboard entity in AR
- Note name labels on keys
- Visual effects (glow, particles, animations)
- Persistence of alignment settings across launches
