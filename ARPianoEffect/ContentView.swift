import SwiftUI

struct ContentView: View {
    @Environment(MIDIManager.self) private var midi
    @Environment(KeyboardTransform.self) private var keyboardTransform
    @Environment(AlignmentManager.self) private var alignment
    @State private var isImmersiveSpaceOpen = false
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    private let cNotes: [(note: UInt8, name: String)] = [
        (24, "C1"), (36, "C2"), (48, "C3"), (60, "C4"),
        (72, "C5"), (84, "C6"), (96, "C7"), (108, "C8")
    ]

    var body: some View {
        @Bindable var am = alignment
        @Bindable var kt = keyboardTransform

        TabView {
            // Connection tab
            HStack(alignment: .top, spacing: 40) {
                // Left: Device panel
                VStack(alignment: .leading, spacing: 16) {
                    Text("BLE MIDI")
                        .font(.headline)

                    if midi.connectionStatus.isEmpty {
                        Text(midi.bluetoothStatus)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(midi.connectionStatus)
                            .foregroundStyle(.green)
                    }

                    Divider()

                    Button(midi.isScanning ? "Stop Scan" : "Scan") {
                        if midi.isScanning {
                            midi.stopScanning()
                        } else {
                            midi.startScanning()
                        }
                    }

                    if midi.bleDevices.isEmpty && !midi.isScanning {
                        Text("No devices found")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(midi.bleDevices, id: \.identifier) { peripheral in
                        let isConnected = midi.connectedPeripheral?.identifier == peripheral.identifier
                        HStack {
                            Image(systemName: isConnected ? "checkmark.circle.fill" : "circle")
                            Text(peripheral.name ?? "Unknown")
                            Spacer()
                            if isConnected {
                                Button("Disconnect") { midi.disconnect() }
                            } else {
                                Button("Connect") { midi.connect(to: peripheral) }
                            }
                        }
                    }

                    Spacer()
                }
                .frame(width: 280, alignment: .leading)

                // Right: Debug log
                VStack(alignment: .leading, spacing: 8) {
                    Text("Debug Log")
                        .font(.headline)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(midi.debugLog, id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 11, design: .monospaced))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(40)
            .tabItem { Label("Connection", systemImage: "antenna.radiowaves.left.and.right") }

            // Notes tab
            VStack(spacing: 20) {
                if midi.activeNotes.isEmpty {
                    Text("—")
                        .font(.system(size: 72))
                        .foregroundStyle(.secondary)
                } else {
                    Text(midi.activeNotes.sorted().map { MIDIManager.noteName(for: $0) }.joined(separator: " "))
                        .font(.system(size: 72, weight: .bold, design: .monospaced))
                }
                Text("MIDI delay: \(String(format: "%.1f", midi.lastMidiDelay)) ms")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .tabItem { Label("Notes", systemImage: "pianokeys") }

            // AR tab
            VStack(alignment: .leading, spacing: 20) {
                Button(isImmersiveSpaceOpen ? "Close AR View" : "Open AR View") {
                    Task {
                        if isImmersiveSpaceOpen {
                            alignment.stopAlignment()
                            await dismissImmersiveSpace()
                            isImmersiveSpaceOpen = false
                        } else {
                            let result = await openImmersiveSpace(id: "keyboard")
                            if case .opened = result { isImmersiveSpaceOpen = true }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                Divider()

                Toggle("Show Keyboard", isOn: $kt.isKeyboardVisible)

                Divider()

                Toggle("Throw notes", isOn: $kt.throwEnabled)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Throw velocity: \(kt.throwVelocityFactor, specifier: "%.1f")×")
                    Slider(value: $kt.throwVelocityFactor, in: 0.1...5.0)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pitch: \(Int(kt.throwPitchMin))°–\(Int(kt.throwPitchMax))°")
                    HStack {
                        Text("Min").frame(width: 28)
                        Slider(value: $kt.throwPitchMin, in: 0...kt.throwPitchMax)
                    }
                    HStack {
                        Text("Max").frame(width: 28)
                        Slider(value: $kt.throwPitchMax, in: kt.throwPitchMin...90)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Yaw spread: ±\(Int(kt.throwYawSpread))°")
                    Slider(value: $kt.throwYawSpread, in: 0...180)
                }

                Divider()

                // Note selectors — configure before or during alignment
                HStack(spacing: 12) {
                    Text("Left pinch:").frame(width: 90, alignment: .leading)
                    Picker("", selection: $am.leftNote) {
                        ForEach(cNotes, id: \.note) { Text($0.name).tag($0.note) }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                }
                HStack(spacing: 12) {
                    Text("Right pinch:").frame(width: 90, alignment: .leading)
                    Picker("", selection: $am.rightNote) {
                        ForEach(cNotes, id: \.note) { Text($0.name).tag($0.note) }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                }

                Divider()

                // Align / Cancel button
                if alignment.isAligning {
                    Button("Cancel") { alignment.stopAlignment() }
                } else {
                    Button("Align Keyboard") { alignment.startAlignment(kt: keyboardTransform) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isImmersiveSpaceOpen)
                }

                // Status
                Group {
                    if alignment.isAligning {
                        if let seconds = alignment.countdown {
                            Text("Locking in \(seconds)…")
                                .foregroundStyle(.orange)
                        } else if alignment.leftPinchPos != nil && alignment.rightPinchPos != nil {
                            Text("Hold still…")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Pinch both index fingers at the reference keys.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .font(.callout)

                Spacer()
            }
            .padding(40)
            .tabItem { Label("AR", systemImage: "arkit") }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(MIDIManager())
        .environment(KeyboardTransform())
        .environment(AlignmentManager())
}
