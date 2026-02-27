import Foundation
import Observation

@Observable
@MainActor
final class KeyboardTransform {
    var x: Float = 0
    var y: Float = -0.5
    var z: Float = -1.0
    var yaw: Float = 0      // degrees
    var scale: Float = 1.0

    var isKeyboardVisible: Bool = (UserDefaults.standard.object(forKey: "kt.isKeyboardVisible") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(isKeyboardVisible, forKey: "kt.isKeyboardVisible") }
    }
}
