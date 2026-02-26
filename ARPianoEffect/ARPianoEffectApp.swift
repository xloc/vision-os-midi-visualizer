import SwiftUI

@main
struct ARPianoEffectApp: App {
    @State private var midi = MIDIManager()
    @State private var keyboardTransform = KeyboardTransform()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(midi)
                .environment(keyboardTransform)
        }

        ImmersiveSpace(id: "keyboard") {
            PianoKeyboardView()
                .environment(midi)
                .environment(keyboardTransform)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
