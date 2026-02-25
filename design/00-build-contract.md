# Build Contract: AR Piano Effect

## Goal

Build a visionOS app that connects to a BLE MIDI device and visualizes piano key presses in AR.

## User Stories

As a user, I can:

1. Scan for and connect to a BLE MIDI device from the app
2. See a virtual keyboard overlay in my AR view
3. Manually position and align the virtual keyboard to match my physical piano
4. See visual feedback on a key when I press it on the physical piano
5. See the visual feedback disappear when I release the key

## Definition of Done

- [ ] App builds and runs on visionOS simulator (and device if available)
- [ ] Can discover BLE MIDI devices
- [ ] Can connect to a BLE MIDI device
- [ ] Receives Note On/Off MIDI messages
- [ ] Displays a virtual 88-key piano keyboard in AR space
- [ ] Manual alignment controls work (position, rotation, scale)
- [ ] Note names appear/disappear on key press/release

## Constraints

- **Platform:** visionOS 26+
- **Language:** Swift, SwiftUI, RealityKit
- **MIDI:** CoreMIDI with BLE MIDI support
- **No camera access:** Manual alignment only (Vision Pro API limitation)

## Not Doing (for now)

- Piano detection/auto-alignment via computer vision
- MIDI recording/playback
- Multiple MIDI device connections
- Audio synthesis
- Persistence of alignment settings
