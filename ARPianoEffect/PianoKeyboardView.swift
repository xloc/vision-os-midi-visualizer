import SwiftUI
import RealityKit

struct PianoKeyboardView: View {
    @Environment(MIDIManager.self) private var midi
    @Environment(KeyboardTransform.self) private var kt

    private final class KeyData {
        var keys: [UInt8: ModelEntity] = [:]
        var root: Entity?
    }
    @State private var keyData = KeyData()

    private static let whiteSize = SIMD3<Float>(0.023, 0.010, 0.150)
    private static let blackSize = SIMD3<Float>(0.013, 0.015, 0.095)
    private static let blackSet: Set<Int> = [1, 3, 6, 8, 10]

    var body: some View {
        // Explicitly read observable properties so SwiftUI tracks them as
        // dependencies and calls the update closure when they change.
        _ = midi.activeNotes
        _ = (kt.x, kt.y, kt.z, kt.yaw, kt.scale)

        return RealityView { content in
            buildKeyboard()
            if let root = keyData.root { content.add(root) }
        } update: { _ in
            applyTransform()
            updateColors()
        }
    }

    private func buildKeyboard() {
        let root = Entity()
        let wW = Self.whiteSize.x
        let centerOffset = Float(52) * wW / 2
        var whiteIndex = 0

        for noteInt in 21...108 {
            let note = UInt8(noteInt)
            let isBlack = Self.blackSet.contains(noteInt % 12)
            let size = isBlack ? Self.blackSize : Self.whiteSize

            // x: black keys sit at the border between adjacent white keys
            let xCenter: Float
            if isBlack {
                xCenter = Float(whiteIndex) * wW
            } else {
                xCenter = (Float(whiteIndex) + 0.5) * wW
                whiteIndex += 1
            }

            // y: black keys sit on top of white keys
            let yOffset: Float = isBlack ? (Self.whiteSize.y + Self.blackSize.y) / 2 : 0
            // z: black keys align to the back of the keyboard
            let zOffset: Float = isBlack ? -(Self.whiteSize.z - Self.blackSize.z) / 2 : 0

            var mat = SimpleMaterial()
            mat.color = .init(tint: isBlack ? UIColor(white: 0.15, alpha: 1) : .white)
            let mesh = MeshResource.generateBox(size: size)
            let entity = ModelEntity(mesh: mesh, materials: [mat])
            entity.position = SIMD3(xCenter - centerOffset, yOffset, zOffset)

            root.addChild(entity)
            keyData.keys[note] = entity
        }

        keyData.root = root
    }

    private func applyTransform() {
        guard let root = keyData.root else { return }
        root.transform = Transform(
            scale: SIMD3(repeating: kt.scale),
            rotation: simd_quatf(angle: kt.yaw * .pi / 180, axis: SIMD3(0, 1, 0)),
            translation: SIMD3(kt.x, kt.y, kt.z)
        )
    }

    private func updateColors() {
        for (note, entity) in keyData.keys {
            let isActive = midi.activeNotes.contains(note)
            let isBlack = Self.blackSet.contains(Int(note) % 12)
            let color: UIColor = isActive ? .cyan : (isBlack ? UIColor(white: 0.15, alpha: 1) : .white)
            var mat = SimpleMaterial()
            mat.color = .init(tint: color)
            entity.model?.materials = [mat]
        }
    }
}
