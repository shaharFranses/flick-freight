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
const CRATE := Color("#5F6A78")  # steel (guide rule 6: heavy cargo is grey metal)
const BARREL := Color("#3D8BDB")
const FRAGILE := Color("#FFF6E0")

# ---- v3 "Morning Hybrid" tokens used by ArtDraw (style guide pages 5-6) ---------
const WHITE := Color("#FFFFFF")
const HUD_LIP := Color("#0F1A2B")  # 4 px plate lip
const TYRE_RING := Color("#4A5163")
const STEEL := Color("#5F6A78")  # heavy / machine steel (crate, canister, girders)
const STEEL_LIGHT := Color("#7A8697")
const STEEL_SHADE := Color("#56606C")
const STEEL_GLINT := Color("#8592A1")
const RIVET := Color("#B4BFCD")
const DOCK_STEEL := Color("#5B6574")  # steel lip
const BELT := Color("#34496B")
const CONCRETE := Color("#C9CED6")
const CONCRETE_SEAM := Color("#AEB5BF")
const ROAD := Color("#5A5F70")
const ROAD_EDGE := Color("#4A4F5C")
const CURB := Color("#E9EEF4")
const CURB_SHADE := Color("#C9D3E0")
const LANE_DASH := Color("#F2F2EC")
const AMBER_HI := Color("#FFC95C")
const AMBER_SHADE := Color("#C98E1D")
const CORAL_HI := Color("#F58A66")
const CORAL_SHADE := Color("#B8401F")
const CREAM_SHADE := Color("#F0E2C2")
const MINT_HI := Color("#7BF0BE")
const MINT_SHADE := Color("#2BB078")
const BLUE := Color("#3D8BDB")  # barrel blue
const BLUE_HI := Color("#73B2F0")
const BLUE_SHADE := Color("#2A6BB0")
const PLANK := Color("#E8B96E")  # the only wood
const PLANK_HI := Color("#F6D49A")
const PLANK_SHADE := Color("#D9A65C")
const PLANK_GRAIN := Color("#C99550")
const KRAFT := Color("#D6B07C")
const KRAFT_SHADE := Color("#B8925E")
# new tones for the special vehicles and props (added here, never inline)
const GREEN := Color("#45B36B")  # garbage truck, leaves
const GREEN_HI := Color("#7FD79A")
const GREEN_SHADE := Color("#2F8A4E")
const SLATE_BLUE := Color("#4F6A93")  # flatbed cab (dock trim highlight)
const SLATE_BLUE_HI := Color("#7F96BC")
const SLATE_BLUE_SHADE := Color("#2E4366")
const TRUNK := Color("#A07457")
const TRUNK_SHADE := Color("#7F5A42")
const WATER := Color("#4A9DE6")
const WATER_HI := Color("#8FD0F5")
const WATER_SHADE := Color("#3D7FC1")
## tinted ink for scenery / background props (never on things you play with)
const BG_INK := Color("#4A5875")
const ICE := Color("#A8DDF2")
const ICE_HI := Color("#E2F6FD")

## [body, shade, highlight] per special vehicle. The V0 truck stays the only red one.
const VEHICLE := {
	"pickup": [BLUE, BLUE_SHADE, BLUE_HI],
	"garbage": [GREEN, GREEN_SHADE, GREEN_HI],
	"dump": [AMBER, AMBER_SHADE, AMBER_HI],
	"flatbed": [SLATE_BLUE, SLATE_BLUE_SHADE, SLATE_BLUE_HI],
	"flatcar": [STEEL, STEEL_SHADE, STEEL_LIGHT],
	"mailvan": [CREAM, CREAM_SHADE, WHITE],
	"foodtruck": [MINT, MINT_SHADE, MINT_HI],
	"heli": [AMBER, AMBER_SHADE, AMBER_HI],
	"balloon": [CORAL, CORAL_SHADE, CORAL_HI],
}
