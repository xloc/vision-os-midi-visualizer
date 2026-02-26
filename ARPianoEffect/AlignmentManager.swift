import ARKit
import RealityKit
import Observation

@Observable
@MainActor
final class AlignmentManager {

    // MARK: - Keyboard geometry (single source of truth)

    static let blackSet: Set<Int> = [1, 3, 6, 8, 10]
    static let whiteKeySize = SIMD3<Float>(0.023, 0.010, 0.150)
    static let blackKeySize = SIMD3<Float>(0.013, 0.015, 0.095)

    // MARK: - Observable state

    var isAligning = false
    var countdown: Int? = nil           // nil = not counting, 5…1 = counting down
    var leftPinchPos: SIMD3<Float>?     // world-space midpoint of left pinch, nil when not pinching
    var rightPinchPos: SIMD3<Float>?    // world-space midpoint of right pinch, nil when not pinching

    var leftNote: UInt8 = 36            // C2
    var rightNote: UInt8 = 60           // C4

    // MARK: - Private state

    private var storedKT: KeyboardTransform?
    private var lastMovementTime: Date = .distantPast
    private var lastLeftPos: SIMD3<Float>?
    private var lastRightPos: SIMD3<Float>?
    private let movementThreshold: Float = 0.01     // 1 cm
    private let stableSeconds: Double = 5.0
    private var countdownTask: Task<Void, Never>?

    // MARK: - Public actions

    func startAlignment(kt: KeyboardTransform) {
        storedKT = kt
        isAligning = true
        countdown = nil
        leftPinchPos = nil
        rightPinchPos = nil
        lastLeftPos = nil
        lastRightPos = nil
        lastMovementTime = Date()
        startCountdownLoop()
    }

    func stopAlignment() {
        countdownTask?.cancel()
        isAligning = false
        countdown = nil
        leftPinchPos = nil
        rightPinchPos = nil
        lastLeftPos = nil
        lastRightPos = nil
    }

    // MARK: - ARKit session (called once from PianoKeyboardView .task)

    func startTracking() async {
        guard HandTrackingProvider.isSupported else { return }
        let session = ARKitSession()
        let provider = HandTrackingProvider()
        do {
            try await session.run([provider])
        } catch {
            print("Hand tracking failed: \(error)")
            return
        }
        for await update in provider.anchorUpdates {
            guard isAligning, let skeleton = update.anchor.handSkeleton else { continue }
            processHand(update.anchor, skeleton: skeleton)
        }
    }

    // MARK: - Per-frame hand processing

    private func processHand(_ anchor: HandAnchor, skeleton: HandSkeleton) {
        let chirality = anchor.chirality
        if isPinching(skeleton) {
            let tf = anchor.originFromAnchorTransform
            let idx = tf * skeleton.joint(.indexFingerTip).anchorFromJointTransform
            let thm = tf * skeleton.joint(.thumbTip).anchorFromJointTransform
            let pos = (SIMD3<Float>(idx.columns.3.x, idx.columns.3.y, idx.columns.3.z)
                     + SIMD3<Float>(thm.columns.3.x, thm.columns.3.y, thm.columns.3.z)) / 2

            switch chirality {
            case .left:
                recordMovement(newPos: pos, prevPos: lastLeftPos)
                lastLeftPos = pos
                leftPinchPos = pos
            case .right:
                recordMovement(newPos: pos, prevPos: lastRightPos)
                lastRightPos = pos
                rightPinchPos = pos
            @unknown default:
                break
            }

            // Real-time keyboard update when both hands are pinching
            if let kt = storedKT, let lp = leftPinchPos, let rp = rightPinchPos {
                applyAlignment(lp: lp, rp: rp, to: kt)
            }
        } else {
            // Pinch released — treat as movement so countdown resets
            switch chirality {
            case .left:
                if leftPinchPos != nil {
                    leftPinchPos = nil
                    lastLeftPos = nil
                    lastMovementTime = Date()
                }
            case .right:
                if rightPinchPos != nil {
                    rightPinchPos = nil
                    lastRightPos = nil
                    lastMovementTime = Date()
                }
            @unknown default:
                break
            }
        }
    }

    private func recordMovement(newPos: SIMD3<Float>, prevPos: SIMD3<Float>?) {
        if let prev = prevPos {
            if distance(newPos, prev) > movementThreshold {
                lastMovementTime = Date()
            }
        } else {
            // First frame of this pinch
            lastMovementTime = Date()
        }
    }

    private func isPinching(_ skeleton: HandSkeleton) -> Bool {
        let t = skeleton.joint(.thumbTip).anchorFromJointTransform
        let i = skeleton.joint(.indexFingerTip).anchorFromJointTransform
        let d = distance(
            SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z),
            SIMD3<Float>(i.columns.3.x, i.columns.3.y, i.columns.3.z)
        )
        return d < 0.025   // 2.5 cm
    }

    // MARK: - Countdown loop

    private func startCountdownLoop() {
        countdownTask?.cancel()
        countdownTask = Task { @MainActor [weak self] in
            while let self, self.isAligning, !Task.isCancelled {
                self.tickCountdown()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func tickCountdown() {
        guard isAligning, leftPinchPos != nil, rightPinchPos != nil else {
            countdown = nil
            return
        }
        let elapsed = Date().timeIntervalSince(lastMovementTime)
        if elapsed >= stableSeconds {
            if let kt = storedKT, let lp = leftPinchPos, let rp = rightPinchPos {
                applyAlignment(lp: lp, rp: rp, to: kt)
            }
            isAligning = false
            countdown = nil
            leftPinchPos = nil
            rightPinchPos = nil
        } else {
            countdown = Int(ceil(stableSeconds - elapsed))
        }
    }

    // MARK: - Alignment math

    private func applyAlignment(lp: SIMD3<Float>, rp: SIMD3<Float>, to kt: KeyboardTransform) {
        let lx = Self.keyXCenter(for: leftNote)
        let rx = Self.keyXCenter(for: rightNote)
        let virtualDist = rx - lx

        let worldVec = SIMD3<Float>(rp.x - lp.x, 0, rp.z - lp.z)
        let worldDist = length(worldVec)
        guard virtualDist > 0, worldDist > 0.01 else { return }

        kt.scale = worldDist / virtualDist

        let dir = worldVec / worldDist
        kt.yaw = atan2(-dir.z, dir.x) * 180 / .pi

        let angle = kt.yaw * .pi / 180
        let rotation = simd_quatf(angle: angle, axis: SIMD3(0, 1, 0))
        // Reference point is the front-top-center edge of the key, not the geometric center
        let yAnchor = Self.whiteKeySize.y / 2
        let zAnchor = Self.whiteKeySize.z / 2
        let rotatedAnchor = rotation.act(SIMD3<Float>(kt.scale * lx, kt.scale * yAnchor, kt.scale * zAnchor))
        kt.x = lp.x - rotatedAnchor.x
        kt.y = (lp.y + rp.y) / 2 - kt.scale * yAnchor
        kt.z = lp.z - rotatedAnchor.z
    }

    static func keyXCenter(for note: UInt8) -> Float {
        let wW = whiteKeySize.x
        let centerOffset = Float(52) * wW / 2
        var whiteIndex = 0
        for n in 21...108 {
            let isBlack = blackSet.contains(n % 12)
            let xCenter: Float
            if isBlack {
                xCenter = Float(whiteIndex) * wW
            } else {
                xCenter = (Float(whiteIndex) + 0.5) * wW
                whiteIndex += 1
            }
            if n == Int(note) { return xCenter - centerOffset }
        }
        return 0
    }
}
