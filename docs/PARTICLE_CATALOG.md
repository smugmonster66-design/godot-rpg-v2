# Particle Image Catalog

## Stats
- **Total images:** 958
- **All images:** 512x512 unless noted, PNG with transparency
- **Folders:** 3 top-level categories (Basic, Color, Complex) + 6 root-level images
- **Preview note:** White-on-transparent images were composited onto dark (#1E1E1E) backgrounds for inspection.

---

## Root-level (`assets/particles/`) — 6 images

| File | Description |
|------|-------------|
| **circle_05.png** | Soft white glowing orb with smooth Gaussian blur falloff. Simple radial glow particle for light points, ambient particles, or energy effects. |
| **smoke_02.png** | Detailed billowy smoke/cloud texture with organic wisps, dark patches, and turbulent structure. High-quality smoke particle. |
| **star_06.png** (64x64) | Tiny 4-pointed star/diamond sparkle. Clean, minimal twinkle sprite. |
| **star_09.png** (256x256) | 6-pointed star flare with bright glowing center and a subtle circular halo ring. Magical sparkle or lens flare. |
| **light_02.png** | Blurry, irregular ring/vortex shape — a swirling energy ring or portal-like circle with uneven brightness. Paint-stroke ring feel. |
| **fire_02_a.png** | Detailed turbulent fire/smoke cloud texture with organic wisps and bright hot spots. High-quality fire or explosion cloud. |

---

## Basic (`assets/particles/Basic/`) — 413 images

All white on transparent. Flat, hard-edged vector-style silhouettes from a dingbats font set. Designed to be color-tinted at runtime via Godot's particle modulate.

### ding bang — 78 images
Comic-book **onomatopoeia / sound-effect text** graphics. Each image is a different word or phrase in bold, hand-drawn lettering styles. Words include: **TAKA!, KABOOM!, BOOM!, KAPOW!, RIIIIP!, ZARTZ!, EEEHAAA!** and many more. Mix of outlined, filled, graffiti, brush, and block lettering. Useful as combat hit/impact text overlays.

### ding blood — 48 images
**Blood/liquid splatter** silhouettes. Hard-edged, high-contrast flat splat shapes with spiky edges, scattered satellite droplets, and directional spray trails. Variations range from compact single splats to broad multi-point spray patterns. Great for damage hit effects, wound marks, or paint splatter overlays.

### ding circles — 92 images
**Geometric circle-based designs.** Includes spirals, concentric rings, dotted circles, molecular/node network patterns (circles connected by lines), mandala-like floral arrangements, and ornamental circular motifs.

### ding shapes — 92 images
**Geometric shape silhouettes.** Includes stars (various point counts), snowflakes, crosses, asterisks, polygons, arrows, and abstract geometric symbols. Flat vector shapes suitable as particle textures or UI decorations.

### spiral — 40 images
**Spiral and ring-based designs.** More complex/organic than ding circles. Includes jagged zigzag corona rings, concentric broken-ring vortex patterns, gear/wheel shapes with cutout holes, and turbine-like designs.

### star — 21 images
**Star shape variations.** Solid stars, outlined stars, nested star-within-star (double/echo effect), varying point counts (5-pointed, 6-pointed), and different sizes. Clean geometric vector shapes.

### targets — 40 images
**Targeting/crosshair designs.** Polygon outlines, segmented concentric arc rings, tri-arrow formations, radar/HUD-style reticles with gradient opacity, and geometric targeting symbols. Sci-fi lock-on / aim overlay style.

---

## Color (`assets/particles/Color/`) — 210 images

Pre-colored particle textures with shading, gradients, and lighting. More detailed and render-ready than Basic shapes.

### burst — 30 images (`color_burst_`)
**Radial starburst / explosion flashes.** Spiky rays radiating outward from a bright hollow center, with soft glow falloff. Each variant has a different color palette — ranges include: white/gray, warm gold/amber, pink/coral, cool cyan/aqua, green/lime, iridescent pastel rainbow, purple/lavender, peach/salmon, and cyan/white. Variants alternate between "clean" bursts (rays only) and "dirty" bursts (with scattered bokeh particle dots in the center). Great for spell impact flashes, explosions, and energy release effects.

### energyball — 10 images (`energyball_`)
**Swirling energy sphere / vortex orbs.** Spherical shapes with spiraling internal wisps converging to a bright center. Painterly, soft-edged. Each variant is a different color: blue swirl, green filament vortex, and other hues. Good for charging effects, magic projectiles, or elemental orbs.

### fire — 40 images (`fire_`)
**Realistic fire and explosion textures.** Full-color, pre-rendered fire effects in orange/yellow/amber with detailed turbulent structure, embers, and hot spots. Variants range from compact fireball explosions to tall column flames. High-quality, ready to use as-is for fire spell effects, burning, or explosions.

### magic particles — 20 images (`magic_particles_`)
**Soft glowing magic cloud textures.** Nebula-like diffuse clouds with a bright core and smoky falloff. Different color variants including warm amber/gold and cool blue/electric. More atmospheric and diffuse than the energyball orbs — good for ambient magic auras, status effect clouds, or mystical fog.

### spirowires — 10 images (`color_spirowires_`)
**Spirograph-style geometric wire designs.** Intricate mathematical curve patterns forming open ring/rosette shapes made of many fine lines. Pre-colored in vibrant neon hues — magenta/pink, cyan/aqua, and others. Decorative, psychedelic wireframe feel. Good for magical circles, spell charging rings, or portal effects.

### star — 100 images (`color_star_`)
**3D-rendered metallic/glossy star shapes.** Five-pointed stars with realistic shading, beveled edges, and reflective highlights. Each variant is a different color, material, or style — includes: polished gold, bright yellow, brushed brass, nested/layered concentric stars, glowing neon-outlined stars, textured/speckled stars, pink/rose crystal, and many more. High quality, icon-grade. Ideal for rewards, ratings, collectibles, or flashy UI elements.

---

## Complex (`assets/particles/Complex/`) — 336 images

Grayscale/white particle textures with complex shading, gradients, and 3D-like lighting. More sophisticated than Basic but uncolored (designed to be tinted at runtime).

### circle/ — 105 images (4 styles)

| Style | Count | Description |
|-------|-------|-------------|
| **circle_** | 5 | Subtle, faintly-lit **sphere outlines** with soft rim-light glow on a dark interior. Bubble or force-field particle. |
| **rounded_** | 30 | **Sectored disc shapes** — circles divided into quadrants/segments with alternating bright/dark patches and a glowing cross-shaped center. Rotating energy shield or segmented orb feel. |
| **sphere_** | 50 | **3D-lit solid spheres** with realistic top-left highlight and smooth gradient shading. Classic ball/orb/droplet particle. Very clean. |
| **spiky_** | 20 | **Pinwheel / starburst rosettes** — radiating curved petal/blade shapes spinning around a glowing center, with dramatic light/shadow contrast. Spinning energy disc or shuriken effect. |

### flare/ — 31 images

| Style | Count | Description |
|-------|-------|-------------|
| **flare_** | 31 | **Lens flare / light bloom sparkles.** Small bright point source with elongated diffraction spikes radiating outward. Soft glow falloff. Classic camera flare or magic twinkle. Variations differ in spike count, length, and brightness. |

### impacts/ — 20 images

| Style | Count | Description |
|-------|-------|-------------|
| **impact_** | 20 | **Soft ring / shockwave shapes.** Blurry, faintly-glowing hollow circles with diffuse edges — like the expanding shockwave ring from an impact. Very subtle, designed to layer with other effects. |

### lines/ — 10 images

| Style | Count | Description |
|-------|-------|-------------|
| **lines_** | 10 | **Vertical light streaks / pillars.** Tall, narrow, softly-glowing elongated ellipses — like a light beam, laser line, or rain streak. Bright center with smooth Gaussian falloff to edges. |

### muzzle flash/ — 20 images

| Style | Count | Description |
|-------|-------|-------------|
| **muzzle_flash_** | 20 | **Upward-pointing flame/flash bursts.** Teardrop/cone-shaped blasts with a bright base and ragged, fiery edges spreading upward. Detailed, textured with spark debris particles. Weapon fire, blast origin, or directional explosion effect. |

### others/ — 60 images (4 styles)

| Style | Count | Description |
|-------|-------|-------------|
| **lightrays_** | 10 | **Downward-pointing volumetric light cones.** Soft, fading god-ray beams emanating from a point source above, spreading as they descend. Spotlight, divine light, or sunbeam effect. |
| **spirowires_** | 20 | **Spirograph wireframe rosettes.** Intricate mathematical curve patterns forming open ring shapes from many fine white lines. Flowing, organic-geometry feel (like the Color/spirowires but uncolored). Decorative spell circle or magic seal. |
| **squared_** | 10 | **Rounded-square glow shapes.** Four bright rounded-corner quadrants separated by dark cross-shaped gaps. Soft gradient shading. Unique shape — good for tech/UI or shield particle effects. |
| **turbine_** | 20 | **Turbine / fan blade rosettes.** 8 curved metallic-looking blades radiating from a glowing center hub, with 3D shading and highlights. Spinning fan, propeller, or wind/air vortex effect. |

### smoke/ — 80 images (3 styles)

| Style | Count | Description |
|-------|-------|-------------|
| **smoke_** | 30 | **Detailed volumetric smoke rings.** Thick, billowy donut/torus-shaped smoke clouds with visible internal structure and soft organic edges. Most detailed of the three — good for large smoke puffs or explosion afterclouds. |
| **smoke2_** | 30 | **Soft diffuse smoke puffs.** Smaller, more uniform, and more transparent than smoke_. Gentle, wispy cloud clusters with subtle internal detail. Good for ambient fog, breath, or light haze. |
| **smoke3_** | 20 | **Blobby cloud clusters.** Brighter, more defined than smoke2_, with visible individual blob sub-shapes creating a clustered cloud texture. Mid-range between the detailed smoke_ and the diffuse smoke2_. Good for steam, dust, or medium smoke effects. |

### star/ — 10 images

| Style | Count | Description |
|-------|-------|-------------|
| **star_** | 10 | **3D-shaded solid 5-pointed stars.** Smooth gradient shading with a bright upper-left highlight, giving a soft metallic or matte-lit 3D appearance. Uncolored (grayscale), designed to be tinted. Good for reward, sparkle, or collectible particles. |
