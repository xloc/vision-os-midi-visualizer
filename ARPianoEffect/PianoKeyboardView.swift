import SwiftUI
import RealityKit

struct PianoKeyboardView: View {
    @Environment(MIDIManager.self) private var midi
    @Environment(KeyboardTransform.self) private var kt
    @Environment(AlignmentManager.self) private var alignment

    private final class KeyData {
        var keys: [UInt8: ModelEntity] = [:]
        var root: Entity?
        var leftSphere: ModelEntity?
        var rightSphere: ModelEntity?
    }
    @State private var keyData = KeyData()

    private static let whiteSize = SIMD3<Float>(0.023, 0.010, 0.150)
    private static let blackSize = SIMD3<Float>(0.013, 0.015, 0.095)
    private static let blackSet: Set<Int> = [1, 3, 6, 8, 10]

    var body: some View {
        _ = midi.activeNotes
        _ = (kt.x, kt.y, kt.z, kt.yaw, kt.scale)
        _ = (alignment.isAligning, alignment.leftPinchPos, alignment.rightPinchPos)

        return RealityView { content in
            buildKeyboard(content: content)
        } update: { _ in
            applyTransform()
            updateColors()
            updatePinchSpheres()
        }
        .task {
            await alignment.startTracking()
        }
    }

    private func buildKeyboard(content: RealityViewContent) {
        let root = Entity()
        let wW = Self.whiteSize.x
        let centerOffset = Float(52) * wW / 2
        var whiteIndex = 0

        for noteInt in 21...108 {
            let note = UInt8(noteInt)
            let isBlack = Self.blackSet.contains(noteInt % 12)
            let size = isBlack ? Self.blackSize : Self.whiteSize

            let xCenter: Float
            if isBlack {
                xCenter = Float(whiteIndex) * wW
            } else {
                xCenter = (Float(whiteIndex) + 0.5) * wW
                whiteIndex += 1
            }

            let yOffset: Float = isBlack ? (Self.whiteSize.y + Self.blackSize.y) / 2 : 0
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
        content.add(root)

        // Pinch position spheres: blue = left, orange = right
        let sphereMesh = MeshResource.generateSphere(radius: 0.015)
        var leftMat = SimpleMaterial()
        leftMat.color = .init(tint: UIColor.systemBlue)
        var rightMat = SimpleMaterial()
        rightMat.color = .init(tint: UIColor.systemOrange)

        let leftSphere = ModelEntity(mesh: sphereMesh, materials: [leftMat])
        let rightSphere = ModelEntity(mesh: sphereMesh, materials: [rightMat])
        leftSphere.isEnabled = false
        rightSphere.isEnabled = false

        keyData.leftSphere = leftSphere
        keyData.rightSphere = rightSphere
        content.add(leftSphere)
        content.add(rightSphere)
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
        // Use reduced opacity during alignment so user can see through the keyboard
        let alpha: CGFloat = alignment.isAligning ? 0.45 : 1.0
        for (note, entity) in keyData.keys {
            let isActive = midi.activeNotes.contains(note)
            let isBlack = Self.blackSet.contains(Int(note) % 12)
            let base: UIColor = isActive ? .cyan : (isBlack ? UIColor(white: 0.15, alpha: 1) : .white)
            var mat = SimpleMaterial()
            mat.color = .init(tint: base.withAlphaComponent(alpha))
            entity.model?.materials = [mat]
        }
    }

    private func updatePinchSpheres() {
        if alignment.isAligning, let pos = alignment.leftPinchPos {
            keyData.leftSphere?.isEnabled = true
            keyData.leftSphere?.position = pos
        } else {
            keyData.leftSphere?.isEnabled = false
        }
        if alignment.isAligning, let pos = alignment.rightPinchPos {
            keyData.rightSphere?.isEnabled = true
            keyData.rightSphere?.position = pos
        } else {
            keyData.rightSphere?.isEnabled = false
        }
    }
}
