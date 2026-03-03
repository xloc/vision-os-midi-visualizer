import SwiftUI
import RealityKit

struct PianoKeyboardView: View {
    @Environment(MIDIManager.self) private var midi
    @Environment(KeyboardTransform.self) private var kt
    @Environment(AlignmentManager.self) private var alignment

    // MARK: - Bar constants

    private static let barSpeed: Float = 0.15       // m/s (local units) — same for growing and floating
    private static let barWidth: Float = 0.006     // 4 mm thin strip
    private static let barDepth: Float = 0.006      // 6 mm slab
    private static let barCornerRadius: Float = 0.002
    private static let worldCeilingY: Float = 2.5   // world-space Y where bars start shrinking from the top

    // MARK: - Throw constants

    private static let throwSpeed: Float = 1.0
    private static let throwLifetime: Float = 3.0

    // MARK: - Data

    private struct BarRecord {
        let entity: ModelEntity
        let keyTopY: Float
        let xCenter: Float
        let zOffset: Float
        let pressTime: Date
        var releaseTime: Date?  // nil = key is still held
        var currentHeight: Float
    }

    private struct ThrowRecord {
        let entity: ModelEntity
        let spawnTime: Date
    }

    private final class KeyData {
        var keys: [UInt8: ModelEntity] = [:]
        var root: Entity?
        var worldRoot: Entity?
        var meshEntities: [UUID: ModelEntity] = [:]
        var leftSphere: ModelEntity?
        var rightSphere: ModelEntity?
        var activeBars: [UInt8: BarRecord] = [:]
        var floatingBars: [BarRecord] = []
        var activeThrows: [ThrowRecord] = []
        var previousNotes: Set<UInt8> = []
    }
    @State private var keyData = KeyData()

    // MARK: - Body

    var body: some View {
        TimelineView(.animation) { context in
            RealityView { content in
                buildKeyboard(content: content)
            } update: { _ in
                tickBars(now: context.date)
                processMeshUpdates()
                applyTransform()
                updateColors()
                updatePinchSpheres()
            }
            .task {
                await alignment.startTracking(kt: kt)
            }
        }
    }

    // MARK: - Build keyboard

    private func buildKeyboard(content: RealityViewContent) {
        let root = Entity()
        let wS = AlignmentManager.whiteKeySize
        let bS = AlignmentManager.blackKeySize

        for noteInt in 21...108 {
            let note = UInt8(noteInt)
            let isBlack = AlignmentManager.blackSet.contains(noteInt % 12)
            let size = isBlack ? bS : wS
            let xCenter = AlignmentManager.keyXCenter(for: note)
            let yOffset: Float = isBlack ? (wS.y + bS.y) / 2 : 0
            let zOffset: Float = isBlack ? -(wS.z - bS.z) / 2 : 0

            var mat = SimpleMaterial()
            mat.color = .init(tint: isBlack ? UIColor(white: 0.15, alpha: 1) : .white)
            let mesh = MeshResource.generateBox(size: size)
            let entity = ModelEntity(mesh: mesh, materials: [mat])
            entity.position = SIMD3(xCenter, yOffset, zOffset)

            root.addChild(entity)
            keyData.keys[note] = entity
        }

        keyData.root = root
        content.add(root)

        let worldRoot = Entity()
        keyData.worldRoot = worldRoot
        content.add(worldRoot)

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

    // MARK: - Per-frame updates (SwiftUI-driven)

    private func applyTransform() {
        guard let root = keyData.root else { return }
        root.transform = Transform(
            scale: SIMD3(repeating: kt.scale),
            rotation: simd_quatf(angle: kt.yaw * .pi / 180, axis: SIMD3(0, 1, 0)),
            translation: SIMD3(kt.x, kt.y, kt.z)
        )
    }

    private func updateColors() {
        let alpha: CGFloat = alignment.isAligning ? 0.45 : 1.0
        for (note, entity) in keyData.keys {
            entity.isEnabled = kt.isKeyboardVisible
            let isActive = midi.activeNotes.contains(note)
            let isBlack = AlignmentManager.blackSet.contains(Int(note) % 12)
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

    // MARK: - Bar animation (display-synchronized via TimelineView)

    @MainActor
    private func tickBars(now: Date) {
        guard let root = keyData.root else { return }

        // Detect note on/off
        let current = midi.activeNotes
        let pressed = current.subtracting(keyData.previousNotes)
        let released = keyData.previousNotes.subtracting(current)
        keyData.previousNotes = current

        for note in pressed {
            spawnBar(for: note, root: root, at: now)
            if kt.throwEnabled {
                let vel = midi.noteVelocities[note] ?? 64
                spawnThrow(for: note, velocity: vel, root: root, at: now)
            }
        }
        for note in released {
            releaseBar(for: note, at: now)
        }

        // Grow active bars
        for note in keyData.activeBars.keys {
            guard var bar = keyData.activeBars[note] else { continue }
            let elapsed = Float(now.timeIntervalSince(bar.pressTime))
            let h = max(Self.barSpeed * elapsed, 0.001)
            bar.currentHeight = h
            bar.entity.scale = SIMD3(1, h, 1)
            bar.entity.position = SIMD3(bar.xCenter, bar.keyTopY + h / 2, bar.zOffset)
            keyData.activeBars[note] = bar
        }

        // Float released bars upward; shrink from top when hitting ceiling
        let ceilingLocalY = kt.scale > 0 ? (Self.worldCeilingY - kt.y) / kt.scale : Self.worldCeilingY
        keyData.floatingBars = keyData.floatingBars.compactMap { bar in
            guard let releaseTime = bar.releaseTime else { return nil }
            let elapsed = Float(now.timeIntervalSince(releaseTime))
            let bottomY = bar.keyTopY + Self.barSpeed * elapsed
            let top = min(bottomY + bar.currentHeight, ceilingLocalY)
            let actualHeight = top - bottomY
            if actualHeight <= 0 {
                bar.entity.removeFromParent()
                return nil
            }
            bar.entity.scale.y = actualHeight
            bar.entity.position.y = bottomY + actualHeight / 2
            return bar
        }

        // Remove expired throw entities (physics handles position)
        keyData.activeThrows = keyData.activeThrows.filter { record in
            let alive = now.timeIntervalSince(record.spawnTime) < Double(Self.throwLifetime)
            if !alive { record.entity.removeFromParent() }
            return alive
        }
    }

    private func spawnBar(for note: UInt8, root: Entity, at now: Date) {
        // If a bar is already active for this note (re-press), move it to floating
        if var existing = keyData.activeBars.removeValue(forKey: note) {
            existing.releaseTime = now
            keyData.floatingBars.append(existing)
        }

        let wS = AlignmentManager.whiteKeySize
        let bS = AlignmentManager.blackKeySize
        let isBlack = AlignmentManager.blackSet.contains(Int(note) % 12)
        let xCenter = AlignmentManager.keyXCenter(for: note)
        let zOffset: Float = isBlack ? -(wS.z - bS.z) / 2 : 0
        let keyTopY: Float = (isBlack ? wS.y / 2 + bS.y : wS.y / 2) + 0.01  // 1cm above key surface

        let mesh = MeshResource.generateBox(size: SIMD3(Self.barWidth, 1, Self.barDepth), cornerRadius: Self.barCornerRadius)
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: .white)
        mat.emissiveColor = .init(color: .white)
        mat.emissiveIntensity = 3.0
        let entity = ModelEntity(mesh: mesh, materials: [mat])
        let initialH: Float = 0.001
        entity.scale = SIMD3(1, initialH, 1)
        entity.position = SIMD3(xCenter, keyTopY + initialH / 2, zOffset)
        root.addChild(entity)

        keyData.activeBars[note] = BarRecord(
            entity: entity,
            keyTopY: keyTopY,
            xCenter: xCenter,
            zOffset: zOffset,
            pressTime: now,
            releaseTime: nil,
            currentHeight: initialH
        )
    }

    private func releaseBar(for note: UInt8, at now: Date) {
        guard var bar = keyData.activeBars.removeValue(forKey: note) else { return }
        bar.releaseTime = now
        keyData.floatingBars.append(bar)
    }

    @MainActor
    private func processMeshUpdates() {
        guard keyData.worldRoot != nil, !alignment.pendingMeshUpdates.isEmpty else { return }
        let updates = alignment.pendingMeshUpdates
        alignment.pendingMeshUpdates.removeAll()
        for update in updates {
            let anchor = update.anchor
            switch update.event {
            case .added, .updated:
                Task { @MainActor in
                    guard let shape = try? await ShapeResource.generateStaticMesh(from: anchor),
                          let worldRoot = keyData.worldRoot else { return }
                    let entity: ModelEntity
                    if let existing = keyData.meshEntities[anchor.id] {
                        entity = existing
                    } else {
                        entity = ModelEntity()
                        keyData.meshEntities[anchor.id] = entity
                        worldRoot.addChild(entity)
                    }
                    entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
                    entity.components.set(CollisionComponent(shapes: [shape]))
                    entity.components.set(PhysicsBodyComponent(shapes: [shape], mass: 0, material: .default, mode: .static))
                }
            case .removed:
                keyData.meshEntities[anchor.id]?.removeFromParent()
                keyData.meshEntities.removeValue(forKey: anchor.id)
            @unknown default:
                break
            }
        }
    }

    private func spawnThrow(for note: UInt8, velocity: UInt8, root: Entity, at now: Date) {
        guard let worldRoot = keyData.worldRoot else { return }
        let speed = Self.throwSpeed * Float(velocity) / 64.0 * kt.throwVelocityFactor

        let wS = AlignmentManager.whiteKeySize
        let bS = AlignmentManager.blackKeySize
        let isBlack = AlignmentManager.blackSet.contains(Int(note) % 12)
        let xCenter = AlignmentManager.keyXCenter(for: note)
        let zOffset: Float = isBlack ? -(wS.z - bS.z) / 2 : 0
        let keyTopY: Float = isBlack ? wS.y / 2 + bS.y : wS.y / 2
        let worldPos = root.convert(position: SIMD3(xCenter, keyTopY, zOffset), to: nil)

        let pitchMin = kt.throwPitchMin * .pi / 180
        let pitchMax = max(kt.throwPitchMax * .pi / 180, pitchMin)
        let yawRange = kt.throwYawSpread * .pi / 180
        let pitch = Float.random(in: pitchMin...pitchMax)
        let yaw   = Float.random(in: -yawRange...yawRange)
        let lx =  speed * cos(pitch) * sin(yaw)
        let ly =  speed * sin(pitch)
        let lz = -speed * cos(pitch) * cos(yaw)
        let worldVelocity = root.transform.rotation.act(SIMD3(lx, ly, lz)) * kt.scale

        let noteName = MIDIManager.noteName(for: note)
        let mesh = MeshResource.generateText(
            noteName,
            extrusionDepth: 0.003,
            font: .systemFont(ofSize: 0.018, weight: .bold),
            containerFrame: CGRect(x: -0.04, y: -0.01, width: 0.08, height: 0.025),
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: .white)
        mat.emissiveColor = .init(color: .white)
        mat.emissiveIntensity = 5.0
        let entity = ModelEntity(mesh: mesh, materials: [mat])
        entity.name = "throw"
        entity.position = worldPos

        let shape = ShapeResource.generateBox(size: SIMD3(0.05, 0.02, 0.004))
        let bounceMaterial = PhysicsMaterialResource.generate(friction: 0.5, restitution: 0.4)
        entity.components.set(CollisionComponent(shapes: [shape]))
        entity.components.set(PhysicsBodyComponent(shapes: [shape], mass: 0.001, material: bounceMaterial, mode: .dynamic))
        entity.components.set(PhysicsMotionComponent(
            linearVelocity: worldVelocity,
            angularVelocity: SIMD3(
                Float.random(in: -5...5),
                Float.random(in: -5...5),
                Float.random(in: -5...5)
            )
        ))

        worldRoot.addChild(entity)
        keyData.activeThrows.append(ThrowRecord(entity: entity, spawnTime: now))
    }
}
