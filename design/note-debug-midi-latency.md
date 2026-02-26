# Debug: MIDI Latency Display

Temporary instrumentation to measure main-actor queuing delay for MIDI events.
Added to investigate the hypothesis that `startTracking()` running on `@MainActor`
at ~90 Hz (ARKit hand tracking rate) causes MIDI events to queue behind it.

## What to remove

### MIDIManager.swift

```swift
var lastMidiDelay: Double = 0   // ms from BLE callback to main actor
```

```swift
let received = Date()
Task { @MainActor in
    self.lastMidiDelay = Date().timeIntervalSince(received) * 1000
    self.parseBLEMIDI(bytes)
}
```
→ restore to:
```swift
Task { @MainActor in
    self.parseBLEMIDI(bytes)
}
```

### ContentView.swift

```swift
Text("MIDI delay: \(String(format: "%.1f", midi.lastMidiDelay)) ms")
    .font(.system(size: 14, design: .monospaced))
    .foregroundStyle(.secondary)
```
