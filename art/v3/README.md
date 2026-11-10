# art/v3 — Phase 1+ swap-in slots

Drop files here using the names in `/workspace/ff-art-directions/build-swap-in-points.md`.
If a file is missing, the current (v2 / code-drawn) look is used unchanged.

After a drop, run `godot --headless --import` so Godot writes the `.import` file.
No code change is required for a correctly named drop. The only flag to flip by hand
is `ArtAssets.USE_PALETTE_B` in `scripts/art/assets.gd` (truck red B `#DC2638`).

Import settings for PNGs: lossless, no mipmaps, linear filter, no VRAM compression
(see asset-plan.md §3).
