class_name ArtPalette
extends RefCounted
## Phase 0 / v3 colour tokens from asset-plan.md §2.2 (phase0/ffart.py PAL).
## Gameplay code keeps using its current literals until each art slice lands.
## Truck body red is selected in ArtAssets (USE_PALETTE_B), not here.

const INK := Color("#1B2A41")
const AMBER := Color("#F2B134")
const GOLD := Color("#FFD34E")
const MINT := Color("#3DDC97")
const CORAL := Color("#E4572E")
const CREAM := Color("#FFF6E0")
const SLATE := Color("#2B3E5C")

# Truck red options (asset-plan.md §2.2 / R17). Shahar has not picked yet.
const TRUCK_RED_A := Color("#F0563E")
const TRUCK_SHADE_A := Color("#C2432A")
const TRUCK_HIGHLIGHT_A := Color("#FF8A6B")
const TRUCK_RED_B := Color("#DC2638")
const TRUCK_SHADE_B := Color("#A51A2B")
const TRUCK_HIGHLIGHT_B := Color("#F5606A")
const TRUCK_RED_C := Color("#B82D2A")
const TRUCK_SHADE_C := Color("#86211F")
const TRUCK_HIGHLIGHT_C := Color("#D9564A")
## Shipping look today (coral; same as FRAGILE tape). Default until the flag flips.
const TRUCK_RED_CURRENT := Color("#E4572E")
const TRUCK_SHADE_CURRENT := Color("#B83F1F")

const GLASS := Color("#8FD0F5")
const HEADLIGHT := Color("#FFE27A")
const CHROME := Color("#C9D1DA")
const TYRE := Color("#2B2F3A")
const WELL := Color("#22283A")
const BED_WALL := Color("#8E9BB0")
const BED_POST := Color("#7D8AA0")
const BED_RAIL := Color("#5A6680")
const DECK_PLATE := Color("#B8C3D1")

const BOX := Color("#F2B134")
const CRATE := Color("#9A6234")
const BARREL := Color("#3D8BDB")
const FRAGILE := Color("#FFF6E0")
