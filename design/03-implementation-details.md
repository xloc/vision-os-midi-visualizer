# Implementation Notes: Alignment Persistence

## Anchor creation (on lock-in)

Build a `simd_float4x4` from the keyboard's yaw rotation + translation and create a `WorldAnchor` at that transform:

```swift
var t = simd_float4x4(simd_quatf(angle: kt.yaw * .pi / 180, axis: SIMD3<Float>(0, 1, 0)))
t.columns.3 = SIMD4<Float>(kt.x, kt.y, kt.z, 1)
let anchor = WorldAnchor(originFromAnchorTransform: t)
try await worldProvider?.addAnchor(anchor)
UserDefaults.standard.set(anchor.id.uuidString, forKey: "kt.anchorId")
UserDefaults.standard.set(kt.scale, forKey: "kt.scale")
```

## Anchor restoration (on next launch)

The rotation matrix for yaw θ around Y gives column 0 = `(cos θ, 0, -sin θ, 0)`, so yaw is recoverable as `atan2(-col0.z, col0.x)` — the same formula used in alignment math. Scale has no spatial meaning and is stored directly in `UserDefaults`.

```swift
kt.x = t.columns.3.x
kt.y = t.columns.3.y
kt.z = t.columns.3.z
kt.yaw = atan2(-t.columns.0.z, t.columns.0.x) * 180 / .pi
kt.scale = UserDefaults.standard.float(forKey: "kt.scale")
```

## Session setup

`startTracking(kt:)` runs both providers in the same ARKit session. The world anchor loop runs in a separate unstructured `Task`; hand tracking runs in the current task (unchanged from slice 2).

```
WorldTrackingProvider  →  processWorldAnchor  →  KeyboardTransform (restore)
HandTrackingProvider   →  processHand         →  KeyboardTransform (align)
```

## Key invariant

`storedKT` is set in `startTracking` (so restoration is available immediately on launch) and re-set in `startAlignment` (for active alignment). Both paths write through the same `KeyboardTransform` reference.
