# AR Piano Effect

`AR Piano Effect` is a visionOS app that connects to a BLE MIDI piano/controller and overlays an 88-key virtual keyboard in mixed reality. When you play notes, the matching AR keys light up and animated note effects rise from the keyboard.

## What It Does

- Scans for and connects to a single BLE MIDI device
- Displays active note names and a debug log in the main window
- Opens an immersive mixed-reality keyboard view
- Renders a procedurally generated 88-key piano for MIDI notes `21...108`
- Aligns the virtual keyboard to a physical piano using two-hand pinch gestures
- Persists keyboard placement with an ARKit `WorldAnchor`
- Visualizes notes with glowing bars and optional "thrown" note labels that collide with scene geometry

## App Flow

- `Connection` tab: scan for BLE MIDI devices, connect, and inspect the debug log.
- `Notes` tab: verify incoming note data and see the current MIDI delay readout.
- `AR` tab: open the immersive view, toggle keyboard/effects, and run alignment.

To align the keyboard:

1. Open the AR view.
2. Choose the left and right reference notes.
3. Tap `Align Keyboard`.
4. Pinch thumb + index finger on both hands at the matching physical keys.
5. Hold still until the countdown completes and the transform locks in.

## Current Scope

- Single BLE MIDI connection
- Note on/off visualization only
- Keyboard transform persistence for the same physical room when ARKit can relocalize
- No audio synthesis, recording, playback, or computer-vision piano detection

The BLE MIDI parser is intentionally minimal and currently targets the note on/off messages used by this project.

## Project Layout

- [ARPianoEffect](/Users/olir/workspace/ar-piano-effect/ARPianoEffect): app source
- [design](/Users/olir/workspace/ar-piano-effect/design): build contract, implementation slices, and design notes
