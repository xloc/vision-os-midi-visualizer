# Slice 4: Note Visualization

## Goal

When a key is played, a glowing white bar rises above it in AR. Releasing the key cuts the bar loose — it floats upward at the same speed until it reaches the ceiling, where it shrinks from the top down and disappears.

## What to Build

### 1. Rising Bar Effect

**While a key is held:**
- A glowing bar appears directly above the key, anchored 1cm above the key surface.
- The bar grows upward in real time. Bottom stays fixed; top rises at a constant speed.

**On release:**
- The bar is "cut" at its current height.
- The freed segment continues floating upward at the same speed (bottom and top both rise).

**At the ceiling (world Y = 2.5m):**
- The bar's top is clamped at the ceiling. The bottom keeps rising, so the bar shrinks from the top down — the inverse of how it grew.
- When the bottom reaches the ceiling, the bar is removed.

**Speed:** A single `barSpeed` constant governs both the upward growth (while held) and the float speed (after release). This ensures a released bar always stays ahead of any newly spawned bar on the same key.

### 2. Appearance

- **Shape:** Thin strip (4mm wide × 6mm deep), same width for all keys, centered on the key's x position.
- **Edges:** Rounded with `cornerRadius: 1.5mm` — no hard box edges.
- **Material:** `PhysicallyBasedMaterial` with white `emissiveColor` and `emissiveIntensity: 3.0`. On Vision Pro's HDR display this produces a natural bloom halo, making the bar look like a self-illuminated neon strip.

### 3. Keyboard Visibility Toggle

A toggle in the AR tab to show or hide the rendered piano keyboard mesh. The bar effect continues working regardless of keyboard visibility. The toggle value is persisted across launches via `UserDefaults`.

## Definition of Done

- [x] Pressing a key spawns a glowing bar above it that grows upward while held.
- [x] Releasing the key cuts the bar; it continues floating upward at the same speed.
- [x] Bar shrinks from the top when it reaches the 2.5m world ceiling and disappears.
- [x] The bar has rounded edges and an emissive glow.
- [x] A toggle in the AR tab shows/hides the keyboard mesh; state is persisted.
- [x] The bar effect works with the keyboard hidden.

## Not In This Slice

- Velocity-sensitive bar width or brightness
- Per-note or per-octave color variation
- Particle effects or trails
- Scene-reconstruction-based ceiling detection (fixed world Y used instead)
