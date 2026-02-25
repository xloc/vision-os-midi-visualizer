import SwiftUI

struct ContentView: View {
    @State private var midi = MIDIManager()

    var body: some View {
        HStack(spacing: 40) {
            // Device list
            VStack(alignment: .leading, spacing: 16) {
                Text("BLE MIDI")
                    .font(.headline)

                Text(midi.bluetoothStatus)
                    .foregroundStyle(.secondary)

                if !midi.connectionStatus.isEmpty {
                    Text(midi.connectionStatus)
                        .foregroundStyle(.green)
                }

                Divider()

                if midi.bleDevices.isEmpty && !midi.isScanning {
                    Text("Tap Scan to find devices")
                        .foregroundStyle(.secondary)
                }

                ForEach(midi.bleDevices, id: \.identifier) { peripheral in
                    Button {
                        if midi.connectedPeripheral?.identifier == peripheral.identifier {
                            midi.disconnect()
                        } else {
                            midi.connect(to: peripheral)
                        }
                    } label: {
                        HStack {
                            Image(systemName: midi.connectedPeripheral?.identifier == peripheral.identifier ? "checkmark.circle.fill" : "circle")
                            Text(peripheral.name ?? "Unknown")
                        }
                    }
                }

                Button(midi.isScanning ? "Stop Scan" : "Scan") {
                    if midi.isScanning {
                        midi.stopScanning()
                    } else {
                        midi.startScanning()
                    }
                }
            }
            .frame(width: 280, alignment: .leading)

            // Active notes display
            VStack(spacing: 20) {
                Text("Active Notes")
                    .font(.headline)

                if midi.activeNotes.isEmpty {
                    Text("—")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                } else {
                    Text(midi.activeNotes.sorted().map { MIDIManager.noteName(for: $0) }.joined(separator: " "))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                }

                Divider()

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
                .frame(height: 200)
            }
            .frame(minWidth: 400)
        }
        .padding(40)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
