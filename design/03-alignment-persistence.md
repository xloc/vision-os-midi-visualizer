# Slice 3: Alignment Persistence

## Goal

Persist the keyboard alignment across app launches so the user doesn't need to re-align every session.

## Problem

ARKit establishes a new world coordinate origin each session. Raw (x, y, z) values saved to `UserDefaults` are meaningless on the next launch because the origin has moved.

## Solution: WorldAnchor

ARKit's `WorldTrackingProvider` supports persistent world anchors that survive across sessions. The system relocalizes them to the same physical point in the room, providing a stable reference regardless of where the device starts.

**On lock-in:** `AlignmentManager` creates a `WorldAnchor` at the keyboard origin with the yaw rotation baked into the transform, then saves its UUID and the physical scale to `UserDefaults`.

**On next launch:** `WorldTrackingProvider` runs alongside `HandTrackingProvider` from app start. When the system relocalizes the saved anchor, it emits an update and `AlignmentManager` restores `KeyboardTransform` from the anchor's world transform.

**Graceful fallback:** If the user is in a different room and ARKit can't relocalize the anchor, nothing happens — the keyboard stays at its default position and the user can re-align.

For implementation details see [03-implementation-details.md](03-implementation-details.md).

## Definition of Done

- [x] After locking in alignment, closing and reopening the app restores the keyboard to the same physical position
- [x] Scale is preserved across sessions
- [x] Re-running alignment overwrites the previous anchor
- [x] If the user is in a different room, the app starts at the default position without error
