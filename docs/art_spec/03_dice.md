# 03: Dice

Dice are the game's main visual element. They appear in the hand, in action-field sockets, in enemy dice rows and in the HUD dice grid.

**Elements, rarity and roll animation are handled by shaders**, so the art request is small but has to be precise. It comes down to **one fill layer and one stroke layer per die type**.

## How a die is drawn
Each die is a stack of layers, from bottom to top:

1. **Fill**: the die body, greyscale. A shader tints it per element (fire, ice, etc.) or by the die's colour, and warps it during the roll animation.
2. **Stroke**: the outline and edge detail, drawn over the fill. It is also tinted and animated.
3. **Value**: the rolled number. **The game draws this as text**, 40–60 px with an outline, **centred**. Don't paint numbers or pips.
4. Effects: a rarity glow (a shader outline built from the **fill's alpha**) and affix particles.

Displayed at **124 px** in the hand, **62 px** in action-field sockets, **36 px** in enemy dice bars, **24 px** in the enemy hand row, and about **37 px** in the map dice grid.

## Assets

| ID | Deliver as (**overwrite the existing file**) | Die | Source | Tint | Prio | Status |
|---|---|---|---|---|---|---|
| DIE-D4-F / DIE-D4-S | `assets/dice/d4s/d4-fill-basic.png` / `d4-stroke-basic.png` | D4: triangle | 256×256 | ✔ | P0 | REDO |
| DIE-D6-F / DIE-D6-S | `assets/dice/D6s/d6-basic-fill.png` / `d6-basic-stroke.png` | D6: square | 256×256 | ✔ | P0 | REDO |
| DIE-D8-F / DIE-D8-S | `assets/dice/d8s/d8-fill-basic.png` / `d8-stroke-basic.png` | D8: diamond | 256×256 | ✔ | P0 | REDO |
| DIE-D10-F / DIE-D10-S | `assets/dice/d10s/d10-fill-basic.png` / `d10-stroke-basic.png` | D10: kite | 256×256 | ✔ | P0 | REDO |
| DIE-D12-F / DIE-D12-S | `assets/dice/d12s/d12-basic-fill.png` / `d12-basic-stroke.png` | D12: pentagon | 256×256 | ✔ | P0 | REDO |
| DIE-D20-F / DIE-D20-S | `assets/dice/d20s/d20-fill-basic.png` / `d20-stroke-basic.png` | D20: hexagon outline with a triangular centre face | 256×256 | ✔ | P0 | REDO |

> **Why overwrite instead of new names?** More than 100 enemy and die resources point at these exact paths. Keeping the names means every die updates without re-linking. The file names break the naming convention on purpose.

## Rules
- **Greyscale only.** White areas take the full element colour; darker values shade it. No hue anywhere.
- **Fill and stroke share one canvas and must line up pixel for pixel.** The stroke sits on top of the fill.
- **Every die type uses the same canvas (256×256).** The shape is centred, and the die's visual centre is the canvas centre, because the number is drawn there.
- **The centre face must stay clear**: a flat area of at least **45% of the canvas width**, so a white number with a black outline reads on every element colour.
- **The silhouette must identify the type at 24 px.** Players choose actions by die size, so the six shapes must not be confused.
- **Clean alpha edge on the fill.** The rarity glow is traced from it, so no soft drop shadow should be baked in.
- Draw the dice **flat, facing the viewer** (top-down), not in 3D perspective. The roll animation is a 2D shader warp.

## Optional: per-element overlays (P3)
The engine supports extra per-die overlay textures (`DiceAffix.fill_overlay_texture` / `stroke_overlay_texture`, drawn over the die), for example frost cracks, embers, or poison drips.

These are **not requested now**, because elements are shader-driven. If style direction wants painted element detail, the request would be 8 elements × 2 layers at 256×256, greyscale, on the same canvas rules as above.
