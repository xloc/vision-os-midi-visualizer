import SwiftUI

struct ContentView: View {
    @State private var midi = MIDIManager()

    var body: some View {
        TabView {
            // Connection tab
            HStack(alignment: .top, spacing: 40) {
                // Left: Device panel
                VStack(alignment: .leading, spacing: 16) {
                    Text("BLE MIDI")
                        .font(.headline)

                    // Combined status - show connectionStatus if active, otherwise bluetoothStatus
                    if midi.connectionStatus.isEmpty {
                        Text(midi.bluetoothStatus)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(midi.connectionStatus)
                            .foregroundStyle(.green)
                    }

                    Divider()

                    // Scan button at top (fixed position)
                    Button(midi.isScanning ? "Stop Scan" : "Scan") {
                        if midi.isScanning {
                            midi.stopScanning()
                        } else {
                            midi.startScanning()
                        }
                    }

                    // Device list
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
                                Button("Disconnect") {
                                    midi.disconnect()
                                }
                            } else {
                                Button("Connect") {
                                    midi.connect(to: peripheral)
                                }
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
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
