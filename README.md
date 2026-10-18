# Flick Freight

A fast-paced physics-based loading game built with Godot 4.3. Flick packages into a moving truck bay before time runs out!

## Game Overview

**Objective**: Load 8 packages into the moving truck bay within 45 seconds.

**Controls**: 
- Touch/Mouse: Click and drag on a package, then release to flick it toward the truck
- Pause: Pause button in top UI
- Mute: Mute button in top UI

## Gameplay Mechanics

### Packages
Three types of packages with different characteristics:

- **Box** (48×48px): Light and easy to flick. Worth 1 point.
- **Crate** (64×64px): Medium weight, tighter hit zone. Worth 2 points.
- **Barrel** (56×72px): Heavy and challenging, smallest hit zone. Worth 3 points.

Packages spawn one at a time at the bottom of the screen. After each package lands or misses, the next spawns in 0.35 seconds.

### Truck Bay
The truck bay opening (110px wide) moves side-to-side in a sine wave pattern:
- Starts with a 3.2-second cycle
- Speeds up to a 2.0-second cycle over 30 seconds
- Moves ±180px from center

### Scoring
- Base points: Each package has a point value (1-3)
- Streak bonus: Consecutive successful loads add +1, +2, +3... to your score
- Missing resets your streak to 0

### Win/Lose Conditions
- **Win**: Successfully load 8 packages before the 45-second timer expires
- **Lose**: Timer reaches 0 with fewer than 8 packages loaded

## Technical Details

### Physics Parameters (from design brief)
- Flick impulse: drag_vector × 8.5
- Speed limits: 220-900 px/s
- Gravity: 1400 px/s²
- Air drag: 0.02
- Drag deadzone: 12px

### Package Stats
| Package | Size (px) | Mass | Hitbox Scale | Points | Spawn Weight (Early→Late) |
|---------|-----------|------|--------------|--------|---------------------------|
| Box     | 48×48     | 1.0  | 1.0          | 1      | 50% → 30%                 |
| Crate   | 64×64     | 1.35 | 0.85         | 2      | 35% → 40%                 |
| Barrel  | 56×72     | 1.7  | 0.7          | 3      | 15% → 30%                 |

## Development

### Prerequisites
- Godot 4.3 or higher
- HTML5 export templates installed

### Running Locally
1. Open the project in Godot Editor
2. Press F5 to run, or use Project → Export → Web

### Building for Web
```bash
godot --headless --export-release "Web" export/index.html
```

Then serve the `export/` directory with any web server:
```bash
python -m http.server 8000 -d export/
```

## Project Structure
```
flick-freight/
├── scenes/
│   ├── main.tscn              # Main game scene
│   ├── package_box.tscn       # Box package
│   ├── package_crate.tscn     # Crate package
│   └── package_barrel.tscn    # Barrel package
├── scripts/
│   ├── game_manager.gd        # Core game logic
│   ├── package_base.gd        # Package physics & input
│   ├── truck_bay.gd           # Truck bay movement
│   └── ui_manager.gd          # UI updates
├── export/                     # Web build output
├── project.godot              # Godot project file
└── export_presets.cfg         # Export configuration
```

## Week 1 Vertical Slice Features

✅ **Implemented**:
- Single dock/map gameplay
- Three package types (Box, Crate, Barrel) with exact stats from design brief
- Sine-wave moving truck bay
- 8 loads / 45 seconds win/fail condition
- Streak scoring system
- Touch + mouse flick controls with physics
- One-at-a-time spawn with 0.35s delay
- Spawn weight lerping (early→late over 30s)
- Mute/Pause buttons
- Midroll ad stub hooks
- Web export preset
- Complete flick→hit/miss gameplay loop

## Out of Scope (Week 1)
- Polish and animations
- Meta progression
- Multiple docks/levels
- Full portal SDK integration
- Sound effects and music

## License
Created for Flick Freight vertical slice demonstration.
