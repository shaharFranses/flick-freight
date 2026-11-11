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
detected from the image height. The delivered `truck_v0.png` is 940x396 (the 198 slot)
and has no baked rear post; Build draws the post in code at each level's `wall_h`.

`art/v3/fx/fx_atlas.png` holds the four flat particles (spark, star, puff, ring) that
`scripts/fx.gd` uses; it is part of the web export.

Import settings for PNGs: lossless, no mipmaps, linear filter, no VRAM compression
(see asset-plan.md §3).

The four backgrounds `bg_harbor`, `bg_snow`, `bg_construction` and `bg_sky_port` and the
`ui/home.png` icon are generated in this repo: `python tools/art/make_bg.py` and
`python tools/art/make_ui.py` (needs Pillow). The full list of what is swapped is in
`docs/ART_SWAP_MAP.md`.
