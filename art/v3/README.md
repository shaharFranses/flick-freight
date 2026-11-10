# art/v3 — Phase 1+ swap-in slots

Drop files here using the names in `/workspace/ff-art-directions/build-swap-in-points.md`.
If a file is missing, the current (v2 / code-drawn) look is used unchanged.

After a drop, run `godot --headless --import` so Godot writes the `.import` file.
No code change is required for a correctly named drop.

Already on: `ArtAssets.USE_PALETTE_B` (truck red B `#DC2638` / `#A51A2B`), Lilita One
at `art/v3/font/title.ttf` for the in-game “FLICK FREIGHT” wordmark, the open-cutaway
bed, the v3 far-wall draw behind cargo, and the Phase 1 Town PNG drop (truck, Town sky,
clouds, dock, C1–C4).

The truck slot accepts 470x190 (origin 157,112) or 470x198 (origin 157,120), 1x or 2x,
detected from the image height. The delivered `truck_v0.png` is 940x396 (the 198 slot).

`art/v3/fx/fx_atlas.png` is reserved and unused; it is excluded from the web export.

Import settings for PNGs: lossless, no mipmaps, linear filter, no VRAM compression
(see asset-plan.md §3).
