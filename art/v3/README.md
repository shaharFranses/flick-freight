# art/v3 — Phase 1+ swap-in slots

Drop files here using the names in `/workspace/ff-art-directions/build-swap-in-points.md`.
If a file is missing, the current (v2 / code-drawn) look is used unchanged.

After a drop, run `godot --headless --import` so Godot writes the `.import` file.
No code change is required for a correctly named drop.

Already on: `ArtAssets.USE_PALETTE_B` (truck red B `#DC2638` / `#A51A2B`), Lilita One
at `art/v3/font/title.ttf` for the in-game “FLICK FREIGHT” wordmark, and the open-cutaway
bed (near-side rails removed from `_draw_front`).

Import settings for PNGs: lossless, no mipmaps, linear filter, no VRAM compression
(see asset-plan.md §3).
