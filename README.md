# Flick Freight

A one-thumb browser game: **flick cargo into a moving truck** before the timer runs out. Built with **Godot 4.3**, with a web (HTML5) export targeting browser-game portals (CrazyGames, Poki, GameDistribution).

## Run it

1. Install [Godot 4.3](https://godotengine.org/download) (standard build, not .NET).
2. Clone this repo, open Godot, **Import** → select `project.godot`.
3. Press **F5** to play (mouse or touch: drag a package and release to flick it).

## Web export

Install the Web export templates (Editor → Manage Export Templates), then Project → Export → Web (preset in `export_presets.cfg`), or headless:

```
godot --headless --export-release "Web" export/index.html
python -m http.server 8000 -d export/
```

`export/` is git-ignored (build output only). `custom_html/custom_shell.html` is the custom web shell.

Known issue: the stock Godot 4.3 web template (~34 MB WASM) can run out of memory on iPhone Safari; a stripped custom template is being worked on.

## Layout

```
project.godot
scenes/        main + package_box / package_crate / package_barrel
scripts/       game_manager, package_base, truck_bay, ui_manager
custom_html/   custom web shell
docs/          original week-1 slice notes (mechanics + physics parameters)
```
