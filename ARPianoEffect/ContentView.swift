import SwiftUI

struct ContentView: View {
    @Environment(MIDIManager.self) private var midi
    @Environment(KeyboardTransform.self) private var keyboardTransform
    @State private var isImmersiveSpaceOpen = false
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
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
            }
            .padding(40)
            .tabItem { Label("Notes", systemImage: "pianokeys") }

            // AR tab
            VStack(alignment: .leading, spacing: 20) {
                Button(isImmersiveSpaceOpen ? "Close AR View" : "Open AR View") {
                    Task {
                        if isImmersiveSpaceOpen {
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

                VStack(spacing: 12) {
                    HStack {
                        Text("Left / Right").frame(width: 100, alignment: .leading)
                        Slider(value: $kt.x, in: -2...2)
                        Text(String(format: "%.2f m", kt.x)).frame(width: 64, alignment: .trailing)
                    }
                    HStack {
                        Text("Height").frame(width: 100, alignment: .leading)
                        Slider(value: $kt.y, in: -2...2)
                        Text(String(format: "%.2f m", kt.y)).frame(width: 64, alignment: .trailing)
                    }
                    HStack {
                        Text("Distance").frame(width: 100, alignment: .leading)
                        Slider(value: $kt.z, in: -3...0)
                        Text(String(format: "%.2f m", kt.z)).frame(width: 64, alignment: .trailing)
                    }
                    HStack {
                        Text("Rotation").frame(width: 100, alignment: .leading)
                        Slider(value: $kt.yaw, in: -180...180)
                        Text(String(format: "%.0f°", kt.yaw)).frame(width: 64, alignment: .trailing)
                    }
                    HStack {
                        Text("Scale").frame(width: 100, alignment: .leading)
                        Slider(value: $kt.scale, in: 0.5...2.0)
                        Text(String(format: "%.2f×", kt.scale)).frame(width: 64, alignment: .trailing)
                    }
                }
                .disabled(!isImmersiveSpaceOpen)

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
}
