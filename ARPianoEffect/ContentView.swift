import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("AR Piano Effect")
                .font(.largeTitle)
            Text("Connect to a BLE MIDI device to begin")
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
