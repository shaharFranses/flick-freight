# Flick Freight

A physics loading game for the web (Godot 4.3). Drag back and release to throw cargo
from the loading dock into the truck. 15 levels across 3 worlds, 1–3 stars each.

![cover](marketing/covers/cover_landscape_1920x1080.png)

## How it plays

- **Controls:** press anywhere, drag back, release. The dotted arc previews the throw.
  `P` pauses, `R` restarts. Touch works the same way.
- **Goal:** load enough cargo to pass (1★); load more for 2★; load everything for 3★.
- **Trucks** leave when full and a new one drives in.
- **Mechanics** (introduced one at a time): moving trucks, heavy crates (need more power),
  barrels (tip over), fragile cargo (breaks on walls/road), pillars and low beams, wind, tall tailgates.
- Progress (stars, mute, tutorial) is saved locally. New players land straight in level 1.

## Project layout

```
scripts/
  main.gd        boot + level flow + pause
  game.gd        one level: scene build, cargo queue, aiming, scoring
  truck.gd       side-view truck (code-drawn), motion, carried cargo
  cargo.gd       cargo physics + resolve (delivered / missed / broken)
  levels.gd      ALL level data (add a level = add a dictionary)
  hud.gd         top bar, banners, pop-ups, tutorial
  screens.gd     pause, results (stars), level select
  ui_theme.gd    shared theme (Fredoka font, buttons, cards)
  save_data.gd   user:// persistence
  sfx.gd, fx.gd  audio + particles
tools/
  bot.gd         QA bot: solves throws ballistically, plays every level
  cover.gd       renders the CrazyGames cover images
  make_music.py  synthesizes the music loop
art/v2/          Kenney CC0 art + Fredoka (OFL) — see art/v2/CREDITS.md
marketing/covers 1920x1080, 800x1200, 800x800 covers for portal submission
```

## Build & test

```bash
godot --headless --import
godot --headless --export-release "Web" export/index.html     # single-threaded web build

# play every level with perfect aim (exit 1 if any level can't be passed)
godot --headless --fixed-fps 60 -s res://tools/bot.gd -- --levels=1-15 --error=0
# simulate a human (aim error)
godot --headless --fixed-fps 60 -s res://tools/bot.gd -- --levels=1-15 --error=0.5

# covers (needs a display, e.g. xvfb-run)
godot --rendering-driver opengl3 -s res://tools/cover.gd -- --out=marketing/covers
```

`?level=N` in the URL (or `-- --level=N` on the command line) jumps to a level for testing.
