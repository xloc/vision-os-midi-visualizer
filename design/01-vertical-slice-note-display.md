# Slice 1: BLE MIDI to Note Display

## Goal

Connect to a BLE MIDI device and display note names in a window when keys are pressed.

## Scope

This slice proves the MIDI pipeline works:

```
BLE MIDI device → CoreMIDI → Note On/Off → SwiftUI text
```

## What to Build

1. **MIDI Connection**
   - Scan for BLE MIDI devices
   - Connect to selected device
   - Receive Note On/Off messages

2. **Note Display (Window)**
   - Show currently pressed note names (e.g., "C4", "F#5") in a SwiftUI view
   - Update in real-time as keys are pressed/released

## Definition of Done

- [ ] Can see BLE MIDI devices in a list
- [ ] Can tap to connect to a device
- [ ] Pressing a key on physical piano shows note name in window
- [ ] Releasing key removes the note name

## Not In This Slice

- AR / immersive space (slice 2)
- Virtual keyboard visualization (slice 2)
- Error handling / reconnection logic
- UI polish
