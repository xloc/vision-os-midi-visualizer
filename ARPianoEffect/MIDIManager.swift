import CoreMIDI
@preconcurrency import CoreBluetooth
import Observation

@Observable
@MainActor
final class MIDIManager: NSObject {
    var bleDevices: [CBPeripheral] = []
    var connectedPeripheral: CBPeripheral?
    var activeNotes: Set<UInt8> = []
    var isScanning = false
    var bluetoothStatus = "Initializing..."
    var connectionStatus = ""
    var debugLog: [String] = []

    private var centralManager: CBCentralManager!
    private var midiCharacteristic: CBCharacteristic?

    // BLE MIDI UUIDs
    private static let midiServiceUUID = CBUUID(string: "03B80E5A-EDE8-4B33-A751-6CE34EC4C700")
    private static let midiCharacteristicUUID = CBUUID(string: "7772E5DB-3868-4112-A1A9-F2669D106BF3")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    private func log(_ message: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        debugLog.append("[\(timestamp)] \(message)")
        if debugLog.count > 50 { debugLog.removeFirst() }
        print("[\(timestamp)] \(message)")
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            log("Cannot scan: Bluetooth not ready")
            return
        }
        bleDevices = []
        isScanning = true
        log("Starting BLE scan...")
        centralManager.scanForPeripherals(withServices: [Self.midiServiceUUID], options: nil)
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        log("Stopped scanning")
    }

    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        log("Connecting to \(peripheral.name ?? "unknown")...")
        connectionStatus = "Connecting..."
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            resetConnectionState()
            log("Disconnected")
        }
    }

    private func resetConnectionState() {
        connectedPeripheral = nil
        midiCharacteristic = nil
        activeNotes = []
        connectionStatus = ""
    }

    private func parseBLEMIDI(_ bytes: [UInt8]) {
        // BLE MIDI format: [header] [timestamp] [status] [note] [velocity]
        guard bytes.count >= 5 else { return }

        let status = bytes[2] & 0xF0
        let note = bytes[3]
        let velocity = bytes[4]

        if status == 0x90 && velocity > 0 {
            activeNotes.insert(note)
            log("Note ON: \(Self.noteName(for: note)) vel=\(velocity)")
        } else if status == 0x80 || (status == 0x90 && velocity == 0) {
            activeNotes.remove(note)
            log("Note OFF: \(Self.noteName(for: note))")
        }
    }

    static func noteName(for note: UInt8) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(note) / 12 - 1
        let name = names[Int(note) % 12]
        return "\(name)\(octave)"
    }
}

extension MIDIManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Task { @MainActor in
            switch state {
            case .poweredOn:
                self.bluetoothStatus = "Bluetooth ready"
                self.log("Bluetooth powered on")
            case .poweredOff:
                self.bluetoothStatus = "Bluetooth off"
            case .unauthorized:
                self.bluetoothStatus = "Bluetooth unauthorized"
            case .unsupported:
                self.bluetoothStatus = "Bluetooth unsupported"
            default:
                self.bluetoothStatus = "Bluetooth unavailable"
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let id = peripheral.identifier
        let name = peripheral.name
        Task { @MainActor in
            if !self.bleDevices.contains(where: { $0.identifier == id }) {
                self.bleDevices.append(peripheral)
                self.log("Found: \(name ?? "unknown")")
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.log("Connected to \(peripheral.name ?? "unknown")")
            self.connectedPeripheral = peripheral
            self.connectionStatus = "Connected, discovering services..."
            peripheral.delegate = self
            peripheral.discoverServices([Self.midiServiceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.log("Failed to connect: \(error?.localizedDescription ?? "unknown")")
            self.connectionStatus = "Connection failed"
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.log("Disconnected: \(error?.localizedDescription ?? "clean")")
            self.resetConnectionState()
        }
    }
}

extension MIDIManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.log("Service discovery error: \(error.localizedDescription)")
                return
            }

            guard let services = peripheral.services else {
                self.log("No services found")
                return
            }

            self.log("Found \(services.count) service(s)")
            for service in services {
                self.log("  Service: \(service.uuid)")
                if service.uuid == Self.midiServiceUUID {
                    self.connectionStatus = "Found MIDI service, discovering characteristic..."
                    peripheral.discoverCharacteristics([Self.midiCharacteristicUUID], for: service)
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.log("Characteristic discovery error: \(error.localizedDescription)")
                return
            }

            guard let characteristics = service.characteristics else {
                self.log("No characteristics found")
                return
            }

            self.log("Found \(characteristics.count) characteristic(s)")
            for char in characteristics {
                self.log("  Char: \(char.uuid), properties: \(char.properties.rawValue)")
                if char.uuid == Self.midiCharacteristicUUID {
                    self.midiCharacteristic = char
                    self.connectionStatus = "Subscribing to MIDI notifications..."
                    peripheral.setNotifyValue(true, for: char)
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.log("Notification error: \(error.localizedDescription)")
                self.connectionStatus = "Notification failed"
                return
            }

            if characteristic.isNotifying {
                self.log("Subscribed to MIDI notifications - ready!")
                self.connectionStatus = "Ready - play your piano!"
            } else {
                self.log("Unsubscribed from notifications")
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        let bytes = [UInt8](data)
        Task { @MainActor in
            self.parseBLEMIDI(bytes)
        }
    }
}
