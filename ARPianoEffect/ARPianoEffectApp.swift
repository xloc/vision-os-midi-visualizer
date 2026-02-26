import SwiftUI

@main
struct ARPianoEffectApp: App {
    @State private var midi = MIDIManager()
    @State private var keyboardTransform = KeyboardTransform()
    @State private var alignment = AlignmentManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(midi)
                .environment(keyboardTransform)
                .environment(alignment)
        }

        ImmersiveSpace(id: "keyboard") {
            PianoKeyboardView()
                .environment(midi)
                .environment(keyboardTransform)
                .environment(alignment)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
