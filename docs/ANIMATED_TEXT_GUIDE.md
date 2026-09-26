# Animated Text Effects Guide

This guide covers all BBCode text effects available in the dialogue system. Effects are typed directly into the **Line Node** text field in the Dialogue Editor.

---

## Quick Start

Wrap any text in BBCode tags to apply an effect:

```
The ground [tremble rate=20 amp=3]shakes violently[/tremble] beneath you.
```

Effects can be **nested** and **combined**:

```
[shout][color=#ff4444]WATCH OUT![/color][/shout]
[whisper][i]I don't think we're alone...[/i][/whisper]
```

Parameters are optional — every effect has sensible defaults:

```
[ember]flames[/ember]              ← uses default rate=3, amp=0.15
[ember rate=6 amp=0.3]flames[/ember]  ← custom values
```

---

## Built-In Godot Effects

These come free with Godot's RichTextLabel and require no setup.

### Text Formatting

| Tag | Example | Result |
|-----|---------|--------|
| `[b]text[/b]` | `[b]bold words[/b]` | **bold words** |
| `[i]text[/i]` | `[i]italic words[/i]` | *italic words* |
| `[u]text[/u]` | `[u]underlined[/u]` | underlined text |
| `[s]text[/s]` | `[s]struck through[/s]` | ~~struck through~~ |
| `[color=X]text[/color]` | `[color=#ff0000]red text[/color]` | colored text |
| `[font_size=X]text[/font_size]` | `[font_size=48]big text[/font_size]` | resized text |

### Built-In Animations

| Tag | Parameters | What It Does |
|-----|-----------|-------------|
| `[wave amp=30 freq=2]` | `amp` (height), `freq` (speed) | Sine wave vertical motion |
| `[shake rate=10 level=5]` | `rate` (speed), `level` (intensity) | Random jitter |
| `[rainbow freq=0.2]` | `freq` (cycle speed) | Rainbow color cycling |
| `[fade start=2 length=3]` | `start` (char index), `length` (fade span) | Left-to-right fade-in |
| `[tornado radius=5 freq=2]` | `radius` (px), `freq` (speed) | Circular character motion |

---

## Custom Effects — Original

### Pulse

Smooth scale oscillation. Good for glowing objects, pulsing magic, or "click to continue" prompts.

```
[pulse]Click to continue...[/pulse]
[pulse freq=4 amp=0.25]the orb throbs with energy[/pulse]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `freq` | `2.0` | Oscillations per second |
| `amp` | `0.15` | Scale amount (0.15 = 15% size change) |

### Appear

Per-character fade-in with upward slide. Good for text that materializes letter by letter.

```
[appear]A message forms in the air...[/appear]
[appear speed=20]text appears quickly[/appear]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `speed` | `10.0` | Characters revealed per second |

### Tremble

Shake/vibrate each character independently. Good for fear, cold, instability.

```
[tremble]your hands are shaking[/tremble]
[tremble rate=25 amp=4]EARTHQUAKE![/tremble]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `rate` | `15.0` | Vibration cycles per second |
| `amp` | `2.0` | Displacement in pixels |

### Ghost

Per-character staggered alpha fade. Each letter fades at a slightly different time, creating a ripple. Good for spirits, ethereal speech, fading memories.

```
[ghost]the spirit whispers...[/ghost]
[ghost freq=0.5 min=0.1]barely visible[/ghost]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `freq` | `1.0` | Fade cycles per second |
| `min` | `0.3` | Minimum opacity (0.0–1.0) |

---

## Custom Effects — Element-Themed

### Ember

Orange-red tint with random per-character brightness flicker. Good for fire NPCs, flame magic references, heated moments.

```
[ember]the forge burns bright[/ember]
[ember rate=6 amp=0.3]INFERNO![/ember]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `rate` | `3.0` | Flicker speed |
| `amp` | `0.15` | Brightness variance |

### Frost

Icy blue-white tint with slow downward character drift (like settling snow). Good for ice magic, cold environments, frozen speech.

```
[frost]the air freezes around you[/frost]
[frost drift=2 amp=1.0]a blizzard howls[/frost]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `drift` | `1.0` | Drift cycle speed |
| `amp` | `0.5` | Downward drift in pixels |

### Zap

Sharp, staccato horizontal jitter — characters snap sideways in sudden bursts then hold still. More electric and sudden than `tremble`. Good for lightning, electricity, shock damage.

```
[zap]sparks crackle[/zap]
[zap rate=30 amp=6]LIGHTNING STRIKES![/zap]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `rate` | `20.0` | Jitter frequency |
| `amp` | `4.0` | Horizontal displacement in pixels |

### Toxic

Green tint with a sawtooth downward drip — characters slide down then snap back to the top. Alpha fades slightly at the bottom of each drip. Good for poison, acid, corruption, sickness.

```
[toxic]venom drips from the blade[/toxic]
[toxic rate=0.5 amp=5]the poison spreads slowly[/toxic]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `rate` | `1.0` | Drip cycle speed |
| `amp` | `3.0` | Drip distance in pixels |

### Shadow

Dark purple tint with a trailing offset — characters wander slowly and leave a motion-trail impression. Good for shadow element, sinister NPCs, dark magic, void entities.

```
[shadow]a dark presence watches[/shadow]
[shadow lag=0.3 amp=4]shadows twist and writhe[/shadow]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `lag` | `0.15` | Trail delay in seconds |
| `amp` | `2.0` | Wander distance in pixels |

---

## Custom Effects — Dramatic / Narrative

### Whisper

Small, faint, with a gentle horizontal sway. No parameters — designed to "just work." Good for hushed dialogue, inner thoughts, secrets.

```
[whisper]I don't think we should be here...[/whisper]
[whisper][i]What was that sound?[/i][/whisper]
```

*Fixed values: 85% scale, 60% opacity, slow sway.*

### Shout

Scaled up with a rapid shake. Good for yelling, urgent warnings, battle cries.

```
[shout]RUN![/shout]
[shout amp=0.2 rate=12]THE WALLS ARE CLOSING IN![/shout]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `amp` | `0.12` | Shake intensity multiplier |
| `rate` | `8.0` | Shake speed |

### Impact

Characters slam in from above with an overshoot bounce, staggered per character. Good for dramatic reveals, boss introductions, ground-shaking moments.

```
[impact]The ancient door opens.[/impact]
[impact duration=0.8 bounce=1.5]COLOSSUS AWAKENS[/impact]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `duration` | `0.5` | Total animation time in seconds |
| `bounce` | `1.3` | Overshoot amount (1.0 = no bounce, higher = more) |

### Heartbeat

Rhythmic double-pulse scale — thump-thump, pause, thump-thump. Good for tension, fear, life-or-death moments, horror.

```
[heartbeat]your pulse quickens[/heartbeat]
[heartbeat bpm=120]panic sets in[/heartbeat]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `bpm` | `72.0` | Beats per minute (72 = resting, 120+ = panicked) |

### Glitch

Random characters momentarily jump to wrong positions and snap back. Glitches are rare and sudden — most of the time the text is still. Good for magical interference, cursed items, eldritch entities, broken artifacts.

```
[glitch]the inscription shifts[/glitch]
[glitch rate=6 amp=8]R̸E̵A̶L̷I̸T̵Y̶ ̸F̵R̶A̷C̶T̸U̵R̸E̷S̶[/glitch]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `rate` | `3.0` | Glitch frequency (higher = more frequent) |
| `amp` | `5.0` | Displacement distance in pixels |

### Fade Pulse

All characters fade in and out together as one unit — no per-character stagger (unlike `ghost`). Good for ethereal speech, dreamy sequences, fading in/out of consciousness.

```
[fade_pulse]the vision blurs...[/fade_pulse]
[fade_pulse freq=0.5 min=0.1]fading from reality[/fade_pulse]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `freq` | `1.0` | Fade cycles per second |
| `min` | `0.3` | Minimum opacity (0.0–1.0) |

---

## Tips & Recipes

### Combine Effects for Richer Results

```
[ember][tremble rate=10 amp=1]the volcano erupts[/tremble][/ember]
[frost][ghost freq=0.5 min=0.4]a frozen phantom[/ghost][/frost]
[shadow][whisper]the void speaks[/whisper][/shadow]
[zap][color=#88ccff]chain lightning arcs[/color][/zap]
```

### Use with Color for Element Identity

```
[ember][color=#ff6633]Flame Strike[/color][/ember]
[frost][color=#88ddff]Frost Spike[/color][/frost]
[zap][color=#ffee44]Lightning Bolt[/color][/zap]
[toxic][color=#44ff44]Venom Lance[/color][/toxic]
[shadow][color=#9966cc]Shadow Bolt[/color][/shadow]
```

### Dramatic Dialogue Patterns

```
# Tense conversation
[whisper]Did you hear that?[/whisper]

# Building dread
Your [heartbeat bpm=90]heart begins to race[/heartbeat].

# Sudden danger
[impact][shout][color=red]BEHIND YOU![/color][/shout][/impact]

# Eldritch horror
[glitch][shadow]The words rearrange themselves on the page.[/shadow][/glitch]

# Dying NPC
[ghost freq=0.3 min=0.1][whisper]Tell them... I tried...[/whisper][/ghost]
```

### Per-Line Speed Control

The typewriter reveal speed can be overridden per line in the Dialogue Editor's Line Node via `text_speed_override`. Set it to a lower value for slow, dramatic reveals or higher for urgent speech. Default is 35 characters per second.

---

## Ghost vs Fade Pulse

These two effects both fade text, but feel different:

| | Ghost | Fade Pulse |
|---|-------|-----------|
| **Stagger** | Each character fades at a different time | All characters fade together |
| **Feel** | Rippling, alive, individual | Breathing, unified, dreamlike |
| **Best for** | Spirits, ethereal beings | Visions, fading consciousness |

---

## Adding New Effects

New effects are added in `scripts/ui/dialogue/dialogue_text_effects.gd`. Create a class extending `RichTextEffect`, set `var bbcode` to your tag name, implement `_process_custom_fx()`, and add it to `register_all()`. See that file for examples.

**Outline safety:** If your effect modifies `char_fx.color` (especially `.a`), wrap the change in `if not char_fx.outline:` so the text outline stroke remains visible.
